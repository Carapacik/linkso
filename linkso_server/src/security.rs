use axum::{
    extract::{Request, State},
    http::{HeaderValue, Method, header},
    middleware::Next,
    response::{IntoResponse, Response},
};
use url::Url;

use crate::{api_error::ApiError, request_id::RequestId};

#[derive(Clone)]
pub struct WebSecurityConfig {
    public_origin: String,
}

impl WebSecurityConfig {
    pub fn new(public_base_url: &Url) -> Self {
        Self {
            public_origin: public_base_url.origin().ascii_serialization(),
        }
    }
}

pub async fn enforce_csrf(
    State(config): State<WebSecurityConfig>,
    request: Request,
    next: Next,
) -> Response {
    if is_unsafe(request.method()) && has_session_cookie(request.headers()) {
        let origin_matches = request
            .headers()
            .get(header::ORIGIN)
            .and_then(|value| value.to_str().ok())
            .is_some_and(|origin| origin == config.public_origin);
        if !origin_matches {
            let request_id = request
                .extensions()
                .get::<RequestId>()
                .cloned()
                .expect("request ID middleware must run before CSRF protection");
            return ApiError::forbidden(
                "csrf_origin_rejected",
                "The request origin is not allowed",
                None,
                &request_id,
            )
            .into_response();
        }
    }
    next.run(request).await
}

pub async fn add_security_headers(request: Request, next: Next) -> Response {
    let mut response = next.run(request).await;
    let headers = response.headers_mut();
    headers.insert(
        header::X_CONTENT_TYPE_OPTIONS,
        HeaderValue::from_static("nosniff"),
    );
    headers.insert(header::X_FRAME_OPTIONS, HeaderValue::from_static("DENY"));
    headers.insert(
        header::REFERRER_POLICY,
        HeaderValue::from_static("no-referrer"),
    );
    headers.insert(
        "permissions-policy",
        HeaderValue::from_static("camera=(), microphone=(), geolocation=()"),
    );
    headers.insert(
        header::CONTENT_SECURITY_POLICY,
        HeaderValue::from_static(
            "default-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
        ),
    );
    response
}

fn is_unsafe(method: &Method) -> bool {
    matches!(
        *method,
        Method::POST | Method::PUT | Method::PATCH | Method::DELETE
    )
}

fn has_session_cookie(headers: &axum::http::HeaderMap) -> bool {
    headers
        .get_all(header::COOKIE)
        .iter()
        .filter_map(|value| value.to_str().ok())
        .flat_map(|value| value.split(';'))
        .map(str::trim)
        .any(|cookie| cookie.starts_with("linkso_session="))
}

#[cfg(test)]
mod tests {
    use axum::http::{HeaderMap, HeaderValue, Method, header};

    use super::{has_session_cookie, is_unsafe};

    #[test]
    fn recognizes_cookie_bound_unsafe_requests() {
        let mut headers = HeaderMap::new();
        headers.insert(
            header::COOKIE,
            HeaderValue::from_static("theme=dark; linkso_session=secret"),
        );
        assert!(has_session_cookie(&headers));
        assert!(is_unsafe(&Method::POST));
        assert!(!is_unsafe(&Method::GET));
    }

    #[test]
    fn does_not_accept_cookie_name_prefixes() {
        let mut headers = HeaderMap::new();
        headers.insert(
            header::COOKIE,
            HeaderValue::from_static("not_linkso_session=secret"),
        );
        assert!(!has_session_cookie(&headers));
    }
}
