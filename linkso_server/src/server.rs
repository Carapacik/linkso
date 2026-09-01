use std::{future::Future, io, net::SocketAddr, pin::Pin, sync::Arc, time::Duration};

use axum::{
    Extension, Json, Router,
    extract::State,
    middleware::{self},
    routing::get,
};
use serde::Serialize;
use sqlx::PgPool;
use tokio::{net::TcpListener, signal};
use url::Url;

use crate::{
    accounts::http::AuthHttpConfig,
    admin::BootstrapAdminToken,
    analytics::{ANALYTICS_AGGREGATION_BATCH_SIZE, AnalyticsRepository},
    api_error::ApiError,
    config::Config,
    observability::{self, Metrics},
    request_id::{self, RequestId},
    security::{self, WebSecurityConfig},
};

#[derive(Serialize)]
struct LiveStatus {
    status: &'static str,
}

#[derive(Serialize)]
struct ReadyStatus {
    status: &'static str,
}

trait ReadinessProbe: Send + Sync {
    fn check(&self) -> Pin<Box<dyn Future<Output = bool> + Send + '_>>;
}

struct PostgresReadinessProbe {
    pool: PgPool,
}

impl ReadinessProbe for PostgresReadinessProbe {
    fn check(&self) -> Pin<Box<dyn Future<Output = bool> + Send + '_>> {
        Box::pin(async {
            matches!(
                tokio::time::timeout(
                    Duration::from_secs(1),
                    sqlx::query("SELECT 1").execute(&self.pool),
                )
                .await,
                Ok(Ok(_))
            )
        })
    }
}

#[derive(Clone)]
struct AppState {
    readiness: Arc<dyn ReadinessProbe>,
}

pub fn app(pool: PgPool) -> Router {
    app_with_links(
        pool,
        Url::parse("http://localhost:8080").expect("static public URL must be valid"),
    )
}

pub fn app_with_links(pool: PgPool, public_base_url: Url) -> Router {
    app_with_admin(pool, public_base_url, BootstrapAdminToken::disabled())
}

pub fn app_with_admin(
    pool: PgPool,
    public_base_url: Url,
    admin_token: BootstrapAdminToken,
) -> Router {
    app_with_admin_and_auth(
        pool,
        public_base_url,
        admin_token,
        AuthHttpConfig::local_test_default(),
    )
}

pub fn app_with_admin_and_auth(
    pool: PgPool,
    public_base_url: Url,
    admin_token: BootstrapAdminToken,
    auth_config: AuthHttpConfig,
) -> Router {
    let readiness = Arc::new(PostgresReadinessProbe { pool: pool.clone() });
    let web_security = WebSecurityConfig::new(&public_base_url);
    let metrics = Metrics::default();
    finalize_router(
        health_routes(readiness)
            .merge(observability::routes(metrics.clone(), admin_token.clone()))
            .merge(crate::accounts::http::routes(
                pool.clone(),
                auth_config.clone(),
            ))
            .merge(crate::analytics::http::routes(
                pool.clone(),
                auth_config.clone(),
            ))
            .merge(crate::links::http::routes(
                pool.clone(),
                public_base_url.clone(),
                auth_config,
                admin_token.clone(),
                metrics.clone(),
            ))
            .merge(crate::campaigns::http::routes(
                pool,
                public_base_url,
                admin_token,
            )),
        web_security,
        metrics,
    )
}

#[cfg(test)]
fn app_with_readiness(readiness: Arc<dyn ReadinessProbe>) -> Router {
    let public_url = Url::parse("http://localhost:8080").expect("static URL must be valid");
    finalize_router(
        health_routes(readiness),
        WebSecurityConfig::new(&public_url),
        Metrics::default(),
    )
}

fn health_routes(readiness: Arc<dyn ReadinessProbe>) -> Router {
    let state = AppState { readiness };

    Router::new()
        .route("/health/live", get(live))
        .route("/health/ready", get(ready))
        .with_state(state)
}

fn finalize_router(router: Router, web_security: WebSecurityConfig, metrics: Metrics) -> Router {
    router
        .fallback(not_found)
        .method_not_allowed_fallback(method_not_allowed)
        .layer(middleware::from_fn_with_state(
            web_security,
            security::enforce_csrf,
        ))
        .layer(middleware::from_fn_with_state(
            metrics,
            observability::observe_request,
        ))
        .layer(middleware::from_fn(security::add_security_headers))
        .layer(middleware::from_fn(request_id::assign))
}

pub async fn run(config: &Config, pool: PgPool) -> io::Result<()> {
    let (mail, mut mail_worker) = config
        .mail()
        .start(config.public_base_url())
        .map_err(io::Error::other)?;
    let address = SocketAddr::new(config.http_host(), config.http_port());
    let listener = TcpListener::bind(address).await?;

    tracing::info!(address = %listener.local_addr()?, "LinkSo HTTP server listening");

    let analytics = AnalyticsRepository::new(pool.clone());
    let aggregator = analytics.spawn_aggregator();
    let result = axum::serve(
        listener,
        app_with_admin_and_auth(
            pool,
            config.public_base_url().clone(),
            config.admin_token().clone(),
            AuthHttpConfig::new(config.session_secret(), config.cookie_secure(), false)
                .expect("validated session secret must create auth configuration")
                .with_mail(mail),
        )
        .into_make_service_with_connect_info::<SocketAddr>(),
    )
    .with_graceful_shutdown(shutdown_signal())
    .await;
    // Router drop closes the bounded queue. Drain briefly without delaying shutdown indefinitely.
    if tokio::time::timeout(Duration::from_secs(35), &mut mail_worker)
        .await
        .is_err()
    {
        tracing::warn!(
            "email shutdown drain timed out; pending messages require a new user request"
        );
        mail_worker.abort();
    }
    aggregator.abort();
    if let Err(error) = analytics
        .aggregate_pending(ANALYTICS_AGGREGATION_BATCH_SIZE)
        .await
    {
        tracing::error!(%error, "final analytics aggregation failed during shutdown");
    }
    result
}

async fn live() -> Json<LiveStatus> {
    Json(LiveStatus { status: "ok" })
}

async fn ready(
    State(state): State<AppState>,
    Extension(request_id): Extension<RequestId>,
) -> Result<Json<ReadyStatus>, ApiError> {
    if state.readiness.check().await {
        Ok(Json(ReadyStatus { status: "ready" }))
    } else {
        tracing::warn!("PostgreSQL readiness check failed");
        Err(ApiError::service_unavailable(&request_id))
    }
}

async fn not_found(Extension(request_id): Extension<RequestId>) -> ApiError {
    ApiError::not_found(&request_id)
}

async fn method_not_allowed(Extension(request_id): Extension<RequestId>) -> ApiError {
    ApiError::method_not_allowed(&request_id)
}

async fn shutdown_signal() {
    match signal::ctrl_c().await {
        Ok(()) => tracing::info!("shutdown signal received"),
        Err(error) => tracing::error!(%error, "failed to listen for shutdown signal"),
    }
}

#[cfg(test)]
mod tests {
    use std::{future::Future, pin::Pin, sync::Arc};

    use axum::{
        body::{Body, to_bytes},
        http::{Method, Request, StatusCode, header},
    };
    use tower::ServiceExt;
    use uuid::Uuid;

    use crate::request_id::X_REQUEST_ID;

    use super::{ReadinessProbe, app_with_readiness};

    struct StaticReadinessProbe(bool);

    impl ReadinessProbe for StaticReadinessProbe {
        fn check(&self) -> Pin<Box<dyn Future<Output = bool> + Send + '_>> {
            Box::pin(std::future::ready(self.0))
        }
    }

    fn app(is_ready: bool) -> axum::Router {
        app_with_readiness(Arc::new(StaticReadinessProbe(is_ready)))
    }

    #[tokio::test]
    async fn live_endpoint_returns_ok_json() {
        let response = app(true)
            .oneshot(
                Request::builder()
                    .uri("/health/live")
                    .body(Body::empty())
                    .expect("health request must be valid"),
            )
            .await
            .expect("health route must return a response");

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response.headers().get(header::CONTENT_TYPE),
            Some(&header::HeaderValue::from_static("application/json"))
        );

        let body = to_bytes(response.into_body(), 1024)
            .await
            .expect("health response body must be readable");
        assert_eq!(body.as_ref(), br#"{"status":"ok"}"#);
    }

    #[tokio::test]
    async fn responses_include_security_headers_without_cross_origin_cors() {
        let response = app(true)
            .oneshot(
                Request::builder()
                    .method(Method::OPTIONS)
                    .uri("/health/live")
                    .header(header::ORIGIN, "https://attacker.example")
                    .header(header::ACCESS_CONTROL_REQUEST_METHOD, "GET")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::METHOD_NOT_ALLOWED);
        assert_eq!(
            response.headers().get(header::X_CONTENT_TYPE_OPTIONS),
            Some(&header::HeaderValue::from_static("nosniff"))
        );
        assert_eq!(
            response.headers().get(header::X_FRAME_OPTIONS),
            Some(&header::HeaderValue::from_static("DENY"))
        );
        assert!(
            response
                .headers()
                .get(header::CONTENT_SECURITY_POLICY)
                .is_some()
        );
        assert!(
            response
                .headers()
                .get(header::ACCESS_CONTROL_ALLOW_ORIGIN)
                .is_none()
        );
    }

    #[tokio::test]
    async fn unsafe_cookie_request_requires_the_public_origin() {
        let response = app(true)
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/health/live")
                    .header(header::COOKIE, "linkso_session=attacker-controlled")
                    .header(header::ORIGIN, "https://attacker.example")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::FORBIDDEN);
        assert!(
            response_body(response)
                .await
                .contains(r#""code":"csrf_origin_rejected""#)
        );
    }

    #[tokio::test]
    async fn ready_endpoint_returns_ok_when_database_is_available() {
        let response = request(Method::GET, "/health/ready", None, true).await;

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(response_body(response).await, r#"{"status":"ready"}"#);
    }

    #[tokio::test]
    async fn ready_endpoint_returns_safe_error_when_database_is_unavailable() {
        let response = request(Method::GET, "/health/ready", None, false).await;
        assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);

        let request_id = response
            .headers()
            .get(&X_REQUEST_ID)
            .expect("error response must contain a request ID")
            .to_str()
            .expect("request ID must be valid ASCII")
            .to_owned();
        let body = response_body(response).await;

        assert_eq!(
            body,
            format!(
                r#"{{"error":{{"code":"service_unavailable","message":"The service is temporarily unavailable","request_id":"{request_id}"}}}}"#
            )
        );
    }

    #[tokio::test]
    async fn generates_request_id_when_header_is_missing() {
        let response = request(Method::GET, "/health/live", None, true).await;
        let request_id = response
            .headers()
            .get(&X_REQUEST_ID)
            .expect("response must contain a request ID")
            .to_str()
            .expect("request ID must be valid ASCII");

        assert!(Uuid::parse_str(request_id).is_ok());
    }

    #[tokio::test]
    async fn propagates_valid_incoming_request_id() {
        let request_id = "b8205a3d-65f9-44f7-afca-2f7f04334dcc";
        let response = request(Method::GET, "/health/live", Some(request_id), true).await;

        assert_eq!(
            response.headers().get(&X_REQUEST_ID),
            Some(&header::HeaderValue::from_static(request_id))
        );
    }

    #[tokio::test]
    async fn replaces_invalid_incoming_request_id() {
        let response = request(Method::GET, "/health/live", Some("not-a-uuid"), true).await;
        let request_id = response
            .headers()
            .get(&X_REQUEST_ID)
            .expect("response must contain a request ID")
            .to_str()
            .expect("request ID must be valid ASCII");

        assert_ne!(request_id, "not-a-uuid");
        assert!(Uuid::parse_str(request_id).is_ok());
    }

    #[tokio::test]
    async fn unknown_route_uses_api_error_envelope() {
        let response = request(Method::GET, "/missing", None, true).await;
        assert_eq!(response.status(), StatusCode::NOT_FOUND);

        let request_id = response
            .headers()
            .get(&X_REQUEST_ID)
            .expect("error response must contain a request ID")
            .to_str()
            .expect("request ID must be valid ASCII")
            .to_owned();
        let body = response_body(response).await;

        assert_eq!(
            body,
            format!(
                r#"{{"error":{{"code":"not_found","message":"The requested resource was not found","request_id":"{request_id}"}}}}"#
            )
        );
    }

    #[tokio::test]
    async fn unsupported_method_uses_api_error_envelope() {
        let response = request(Method::POST, "/health/live", None, true).await;
        assert_eq!(response.status(), StatusCode::METHOD_NOT_ALLOWED);

        let request_id = response
            .headers()
            .get(&X_REQUEST_ID)
            .expect("error response must contain a request ID")
            .to_str()
            .expect("request ID must be valid ASCII")
            .to_owned();
        let body = response_body(response).await;

        assert_eq!(
            body,
            format!(
                r#"{{"error":{{"code":"method_not_allowed","message":"The request method is not allowed for this resource","request_id":"{request_id}"}}}}"#
            )
        );
    }

    async fn request(
        method: Method,
        uri: &str,
        request_id: Option<&str>,
        is_ready: bool,
    ) -> axum::response::Response {
        let mut request = Request::builder().method(method).uri(uri);
        if let Some(request_id) = request_id {
            request = request.header(&X_REQUEST_ID, request_id);
        }

        app(is_ready)
            .oneshot(
                request
                    .body(Body::empty())
                    .expect("test request must be valid"),
            )
            .await
            .expect("router must return a response")
    }

    async fn response_body(response: axum::response::Response) -> String {
        let body = to_bytes(response.into_body(), 4096)
            .await
            .expect("response body must be readable");
        String::from_utf8(body.to_vec()).expect("API response must be UTF-8")
    }
}
