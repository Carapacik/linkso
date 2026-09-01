use axum::{
    extract::Request,
    http::{HeaderName, HeaderValue},
    middleware::Next,
    response::Response,
};
use tracing::Instrument;
use uuid::Uuid;

pub const X_REQUEST_ID: HeaderName = HeaderName::from_static("x-request-id");

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RequestId(String);

impl RequestId {
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

pub async fn assign(mut request: Request, next: Next) -> Response {
    let request_id = request
        .headers()
        .get(&X_REQUEST_ID)
        .and_then(parse_request_id)
        .unwrap_or_else(generate_request_id);

    let method = request.method().clone();
    let uri = request.uri().clone();
    request.extensions_mut().insert(request_id.clone());

    let span = tracing::info_span!(
        "http_request",
        request_id = request_id.as_str(),
        %method,
        %uri
    );
    let mut response = next.run(request).instrument(span).await;
    response.headers_mut().insert(
        X_REQUEST_ID,
        HeaderValue::from_str(request_id.as_str())
            .expect("generated request IDs must be valid HTTP header values"),
    );
    response
}

fn parse_request_id(value: &HeaderValue) -> Option<RequestId> {
    let value = value.to_str().ok()?;
    let uuid = Uuid::parse_str(value).ok()?;
    Some(RequestId(uuid.hyphenated().to_string()))
}

fn generate_request_id() -> RequestId {
    RequestId(Uuid::new_v4().hyphenated().to_string())
}

#[cfg(test)]
mod tests {
    use axum::http::HeaderValue;

    use super::parse_request_id;

    #[test]
    fn rejects_non_uuid_request_id() {
        assert_eq!(
            parse_request_id(&HeaderValue::from_static("not-a-request-id")),
            None
        );
    }
}
