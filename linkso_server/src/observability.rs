use std::{
    collections::BTreeMap,
    fmt::Write,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use axum::{
    Router,
    body::Body,
    extract::{Request, State},
    http::{HeaderMap, HeaderValue, Method, StatusCode, header},
    middleware::Next,
    response::{IntoResponse, Response},
    routing::get,
};

use crate::{
    admin::BootstrapAdminToken, analytics::AnalyticsEventType, api_error::ApiError,
    request_id::RequestId,
};

const LATENCY_BUCKETS_SECONDS: [f64; 10] =
    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0];
const SLOW_REQUEST_THRESHOLD: Duration = Duration::from_millis(500);

#[derive(Clone, Default)]
pub struct Metrics {
    inner: Arc<Mutex<MetricsSnapshot>>,
}

#[derive(Default)]
struct MetricsSnapshot {
    requests: BTreeMap<(&'static str, &'static str, &'static str), u64>,
    latency: BTreeMap<(&'static str, &'static str), Histogram>,
    redirects: BTreeMap<&'static str, u64>,
    advertising_funnel: BTreeMap<&'static str, u64>,
}

struct Histogram {
    buckets: [u64; LATENCY_BUCKETS_SECONDS.len()],
    count: u64,
    sum_seconds: f64,
}

impl Default for Histogram {
    fn default() -> Self {
        Self {
            buckets: [0; LATENCY_BUCKETS_SECONDS.len()],
            count: 0,
            sum_seconds: 0.0,
        }
    }
}

impl Metrics {
    fn record_http(
        &self,
        method: &'static str,
        route: &'static str,
        status: &'static str,
        elapsed: Duration,
    ) {
        let mut snapshot = self
            .inner
            .lock()
            .expect("metrics mutex must not be poisoned");
        *snapshot
            .requests
            .entry((method, route, status))
            .or_default() += 1;
        let histogram = snapshot.latency.entry((method, route)).or_default();
        let seconds = elapsed.as_secs_f64();
        histogram.count += 1;
        histogram.sum_seconds += seconds;
        for (index, upper_bound) in LATENCY_BUCKETS_SECONDS.iter().enumerate() {
            if seconds <= *upper_bound {
                histogram.buckets[index] += 1;
            }
        }
    }

    pub fn record_link_event(&self, event_type: AnalyticsEventType) {
        let mut snapshot = self
            .inner
            .lock()
            .expect("metrics mutex must not be poisoned");
        match event_type {
            AnalyticsEventType::DirectRedirect => {
                *snapshot.redirects.entry("direct").or_default() += 1;
            }
            AnalyticsEventType::PasswordRedirect => {
                *snapshot.redirects.entry("password").or_default() += 1;
            }
            AnalyticsEventType::AdvertisingImpression => {
                *snapshot.advertising_funnel.entry("impression").or_default() += 1;
            }
            AnalyticsEventType::AdvertisingTimerComplete => {
                *snapshot
                    .advertising_funnel
                    .entry("timer_complete")
                    .or_default() += 1;
            }
            AnalyticsEventType::AdvertisingRedirect => {
                *snapshot.redirects.entry("advertising").or_default() += 1;
                *snapshot.advertising_funnel.entry("redirect").or_default() += 1;
            }
            AnalyticsEventType::PasswordPromptView
            | AnalyticsEventType::PasswordRejected
            | AnalyticsEventType::PasswordUnlocked => {}
        }
    }

    fn render(&self) -> String {
        let snapshot = self
            .inner
            .lock()
            .expect("metrics mutex must not be poisoned");
        let mut output = String::with_capacity(4096);
        output
            .push_str("# HELP linkso_http_requests_total HTTP requests by bounded route group.\n");
        output.push_str("# TYPE linkso_http_requests_total counter\n");
        for ((method, route, status), count) in &snapshot.requests {
            writeln!(
                output,
                "linkso_http_requests_total{{method=\"{method}\",route=\"{route}\",status=\"{status}\"}} {count}"
            )
            .expect("writing to String cannot fail");
        }
        output.push_str(
            "# HELP linkso_http_request_duration_seconds HTTP request latency by bounded route group.\n",
        );
        output.push_str("# TYPE linkso_http_request_duration_seconds histogram\n");
        for ((method, route), histogram) in &snapshot.latency {
            for (index, upper_bound) in LATENCY_BUCKETS_SECONDS.iter().enumerate() {
                writeln!(
                    output,
                    "linkso_http_request_duration_seconds_bucket{{method=\"{method}\",route=\"{route}\",le=\"{upper_bound}\"}} {}",
                    histogram.buckets[index]
                )
                .expect("writing to String cannot fail");
            }
            writeln!(
                output,
                "linkso_http_request_duration_seconds_bucket{{method=\"{method}\",route=\"{route}\",le=\"+Inf\"}} {}",
                histogram.count
            )
            .expect("writing to String cannot fail");
            writeln!(
                output,
                "linkso_http_request_duration_seconds_sum{{method=\"{method}\",route=\"{route}\"}} {:.6}",
                histogram.sum_seconds
            )
            .expect("writing to String cannot fail");
            writeln!(
                output,
                "linkso_http_request_duration_seconds_count{{method=\"{method}\",route=\"{route}\"}} {}",
                histogram.count
            )
            .expect("writing to String cannot fail");
        }
        output.push_str("# HELP linkso_redirects_total Completed redirects by flow.\n");
        output.push_str("# TYPE linkso_redirects_total counter\n");
        for (flow, count) in &snapshot.redirects {
            writeln!(output, "linkso_redirects_total{{flow=\"{flow}\"}} {count}")
                .expect("writing to String cannot fail");
        }
        output.push_str("# HELP linkso_advertising_funnel_total Advertising funnel events.\n");
        output.push_str("# TYPE linkso_advertising_funnel_total counter\n");
        for (stage, count) in &snapshot.advertising_funnel {
            writeln!(
                output,
                "linkso_advertising_funnel_total{{stage=\"{stage}\"}} {count}"
            )
            .expect("writing to String cannot fail");
        }
        output
    }
}

#[derive(Clone)]
struct MetricsEndpointState {
    metrics: Metrics,
    admin_token: BootstrapAdminToken,
}

pub fn routes(metrics: Metrics, admin_token: BootstrapAdminToken) -> Router {
    Router::new()
        .route("/internal/metrics", get(export_metrics))
        .with_state(MetricsEndpointState {
            metrics,
            admin_token,
        })
}

async fn export_metrics(
    State(state): State<MetricsEndpointState>,
    axum::Extension(request_id): axum::Extension<RequestId>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let authorization = headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok());
    state
        .admin_token
        .authenticate_bearer(authorization)
        .ok_or_else(|| ApiError::admin_authentication_required(&request_id))?;
    let mut response = Body::from(state.metrics.render()).into_response();
    response.headers_mut().insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("text/plain; version=0.0.4; charset=utf-8"),
    );
    Ok(response)
}

pub async fn observe_request(
    State(metrics): State<Metrics>,
    request: Request,
    next: Next,
) -> Response {
    let method = normalized_method(request.method());
    let route = route_group(request.uri().path());
    let started = Instant::now();
    let response = next.run(request).await;
    let elapsed = started.elapsed();
    let status = status_group(response.status());
    metrics.record_http(method, route, status, elapsed);
    if elapsed >= SLOW_REQUEST_THRESHOLD {
        tracing::warn!(
            method,
            route,
            status = response.status().as_u16(),
            latency_ms = elapsed.as_millis(),
            "slow HTTP request"
        );
    }
    response
}

fn normalized_method(method: &Method) -> &'static str {
    match *method {
        Method::GET => "GET",
        Method::POST => "POST",
        Method::PUT => "PUT",
        Method::PATCH => "PATCH",
        Method::DELETE => "DELETE",
        Method::OPTIONS => "OPTIONS",
        _ => "OTHER",
    }
}

fn status_group(status: StatusCode) -> &'static str {
    match status.as_u16() {
        200..=299 => "2xx",
        300..=399 => "3xx",
        400..=499 => "4xx",
        _ => "5xx",
    }
}

fn route_group(path: &str) -> &'static str {
    if path == "/health/live" {
        "health_live"
    } else if path == "/health/ready" {
        "health_ready"
    } else if path == "/internal/metrics" {
        "internal_metrics"
    } else if path.starts_with("/api/v1/password-links/tickets/") {
        "password_ticket"
    } else if path.starts_with("/api/v1/password-links/") {
        "password_flow"
    } else if path.starts_with("/api/v1/advertising-links/tickets/") {
        "advertising_ticket"
    } else if path.starts_with("/api/v1/advertising-links/") {
        "advertising_flow"
    } else if path.starts_with("/api/v1/admin/") {
        "admin_api"
    } else if path.starts_with("/api/v1/auth/") {
        "auth_api"
    } else if path.starts_with("/api/v1/me/") {
        "owner_api"
    } else if path.starts_with("/api/v1/links") {
        "links_api"
    } else if path.starts_with("/api/") {
        "api_other"
    } else if path
        .strip_prefix('/')
        .is_some_and(|slug| !slug.contains('/'))
    {
        "short_link"
    } else {
        "not_found"
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use crate::analytics::AnalyticsEventType;

    use super::{Metrics, route_group};

    #[test]
    fn route_groups_never_include_user_controlled_identifiers() {
        assert_eq!(route_group("/SecretSlug42"), "short_link");
        assert_eq!(
            route_group("/api/v1/password-links/SecretSlug42/verify"),
            "password_flow"
        );
        assert_eq!(route_group("/anything/with/segments"), "not_found");
    }

    #[test]
    fn prometheus_output_contains_only_bounded_labels_and_funnel_values() {
        let metrics = Metrics::default();
        metrics.record_http("GET", "short_link", "3xx", Duration::from_millis(12));
        metrics.record_link_event(AnalyticsEventType::AdvertisingImpression);
        metrics.record_link_event(AnalyticsEventType::AdvertisingRedirect);
        let output = metrics.render();

        assert!(output.contains("route=\"short_link\""));
        assert!(output.contains("flow=\"advertising\"} 1"));
        assert!(output.contains("stage=\"impression\"} 1"));
        assert!(output.contains("stage=\"redirect\"} 1"));
        assert!(!output.contains("SecretSlug42"));
    }
}
