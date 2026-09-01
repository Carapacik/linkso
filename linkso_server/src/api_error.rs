use axum::{
    Json,
    http::{HeaderValue, StatusCode, header},
    response::IntoResponse,
};
use serde::Serialize;

use crate::request_id::RequestId;

#[derive(Debug)]
pub struct ApiError {
    status: StatusCode,
    body: ErrorEnvelope,
    bearer_authentication_required: bool,
}

#[derive(Debug, Serialize)]
struct ErrorEnvelope {
    error: ErrorBody,
}

#[derive(Debug, Serialize)]
struct ErrorBody {
    code: &'static str,
    message: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    field: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    retry_after_seconds: Option<u64>,
    request_id: String,
}

impl ApiError {
    pub fn not_found(request_id: &RequestId) -> Self {
        Self::new(
            StatusCode::NOT_FOUND,
            "not_found",
            "The requested resource was not found",
            None,
            request_id,
        )
    }

    pub fn method_not_allowed(request_id: &RequestId) -> Self {
        Self::new(
            StatusCode::METHOD_NOT_ALLOWED,
            "method_not_allowed",
            "The request method is not allowed for this resource",
            None,
            request_id,
        )
    }

    pub fn service_unavailable(request_id: &RequestId) -> Self {
        Self::new(
            StatusCode::SERVICE_UNAVAILABLE,
            "service_unavailable",
            "The service is temporarily unavailable",
            None,
            request_id,
        )
    }

    pub fn link_expired(request_id: &RequestId) -> Self {
        Self::new(
            StatusCode::GONE,
            "link_expired",
            "The link has expired",
            None,
            request_id,
        )
    }

    pub fn link_disabled(request_id: &RequestId) -> Self {
        Self::new(
            StatusCode::GONE,
            "link_disabled",
            "The link is disabled",
            None,
            request_id,
        )
    }

    pub fn link_blocked(request_id: &RequestId) -> Self {
        Self::new(
            StatusCode::FORBIDDEN,
            "link_blocked",
            "The link is blocked",
            None,
            request_id,
        )
    }

    pub fn invalid_request(
        code: &'static str,
        message: &'static str,
        field: Option<&'static str>,
        request_id: &RequestId,
    ) -> Self {
        Self::new(
            StatusCode::UNPROCESSABLE_ENTITY,
            code,
            message,
            field,
            request_id,
        )
    }

    pub fn conflict(
        code: &'static str,
        message: &'static str,
        field: Option<&'static str>,
        request_id: &RequestId,
    ) -> Self {
        Self::new(StatusCode::CONFLICT, code, message, field, request_id)
    }

    pub fn unauthorized(
        code: &'static str,
        message: &'static str,
        field: Option<&'static str>,
        request_id: &RequestId,
    ) -> Self {
        Self::new(StatusCode::UNAUTHORIZED, code, message, field, request_id)
    }

    pub fn forbidden(
        code: &'static str,
        message: &'static str,
        field: Option<&'static str>,
        request_id: &RequestId,
    ) -> Self {
        Self::new(StatusCode::FORBIDDEN, code, message, field, request_id)
    }

    pub fn admin_authentication_required(request_id: &RequestId) -> Self {
        let mut error = Self::new(
            StatusCode::UNAUTHORIZED,
            "admin_authentication_required",
            "A valid administrator bearer token is required",
            None,
            request_id,
        );
        error.bearer_authentication_required = true;
        error
    }

    pub fn too_many_requests(
        code: &'static str,
        message: &'static str,
        retry_after_seconds: u64,
        request_id: &RequestId,
    ) -> Self {
        let mut error = Self::new(
            StatusCode::TOO_MANY_REQUESTS,
            code,
            message,
            Some("password"),
            request_id,
        );
        error.body.error.retry_after_seconds = Some(retry_after_seconds);
        error
    }

    pub fn too_many_requests_for_field(
        code: &'static str,
        message: &'static str,
        field: Option<&'static str>,
        retry_after_seconds: u64,
        request_id: &RequestId,
    ) -> Self {
        let mut error = Self::new(
            StatusCode::TOO_MANY_REQUESTS,
            code,
            message,
            field,
            request_id,
        );
        error.body.error.retry_after_seconds = Some(retry_after_seconds);
        error
    }

    pub fn too_early(
        code: &'static str,
        message: &'static str,
        retry_after_seconds: u64,
        request_id: &RequestId,
    ) -> Self {
        let mut error = Self::new(StatusCode::TOO_EARLY, code, message, None, request_id);
        error.body.error.retry_after_seconds = Some(retry_after_seconds);
        error
    }

    pub fn internal(request_id: &RequestId) -> Self {
        Self::new(
            StatusCode::INTERNAL_SERVER_ERROR,
            "internal_error",
            "An internal error occurred",
            None,
            request_id,
        )
    }

    fn new(
        status: StatusCode,
        code: &'static str,
        message: &'static str,
        field: Option<&'static str>,
        request_id: &RequestId,
    ) -> Self {
        Self {
            status,
            bearer_authentication_required: false,
            body: ErrorEnvelope {
                error: ErrorBody {
                    code,
                    message,
                    field,
                    retry_after_seconds: None,
                    request_id: request_id.as_str().to_owned(),
                },
            },
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> axum::response::Response {
        let retry_after_seconds = self.body.error.retry_after_seconds;
        let bearer_authentication_required = self.bearer_authentication_required;
        let mut response = (self.status, Json(self.body)).into_response();
        if let Some(seconds) = retry_after_seconds {
            response.headers_mut().insert(
                header::RETRY_AFTER,
                HeaderValue::from_str(&seconds.to_string())
                    .expect("retry-after seconds must form a valid header"),
            );
        }
        if bearer_authentication_required {
            response.headers_mut().insert(
                header::WWW_AUTHENTICATE,
                HeaderValue::from_static("Bearer realm=\"linkso-admin\""),
            );
        }
        response
    }
}
