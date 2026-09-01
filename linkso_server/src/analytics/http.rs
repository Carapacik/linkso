use axum::{
    Extension, Json, Router,
    extract::{Path, Query, State, rejection::QueryRejection},
    http::{HeaderMap, HeaderValue, header},
    routing::get,
};
use serde::Deserialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    accounts::{
        AuthRepository,
        http::{AuthHttpConfig, session_token},
    },
    api_error::ApiError,
    request_id::RequestId,
};

use super::{AnalyticsPeriod, AnalyticsRepository, DEFAULT_ANALYTICS_PERIOD_DAYS};

#[derive(Clone)]
struct AnalyticsState {
    analytics: AnalyticsRepository,
    auth: AuthRepository,
}

pub fn routes(pool: PgPool, auth_config: AuthHttpConfig) -> Router {
    let state = AnalyticsState {
        analytics: AnalyticsRepository::new(pool.clone()),
        auth: AuthRepository::new(pool, auth_config.token_codec()),
    };
    Router::new()
        .route("/api/v1/me/analytics", get(dashboard))
        .route("/api/v1/me/links/{id}/analytics", get(link))
        .with_state(state)
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct PeriodQuery {
    days: Option<u32>,
}

async fn dashboard(
    State(state): State<AnalyticsState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    query: Result<Query<PeriodQuery>, QueryRejection>,
) -> Result<impl axum::response::IntoResponse, ApiError> {
    let owner_id = authenticated_owner_id(&state, &headers, &request_id).await?;
    let period = parse_period(query, &request_id)?;
    let analytics = state
        .analytics
        .dashboard(owner_id, period)
        .await
        .map_err(|error| {
            tracing::error!(%error, %owner_id, "failed to load owner analytics");
            ApiError::internal(&request_id)
        })?;
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(analytics),
    ))
}

async fn link(
    State(state): State<AnalyticsState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
    query: Result<Query<PeriodQuery>, QueryRejection>,
) -> Result<impl axum::response::IntoResponse, ApiError> {
    let owner_id = authenticated_owner_id(&state, &headers, &request_id).await?;
    let link_id = Uuid::parse_str(&raw_id).map_err(|_| ApiError::not_found(&request_id))?;
    let period = parse_period(query, &request_id)?;
    let analytics = state
        .analytics
        .link(owner_id, link_id, period)
        .await
        .map_err(|error| {
            tracing::error!(%error, %owner_id, %link_id, "failed to load link analytics");
            ApiError::internal(&request_id)
        })?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(analytics),
    ))
}

fn parse_period(
    query: Result<Query<PeriodQuery>, QueryRejection>,
    request_id: &RequestId,
) -> Result<AnalyticsPeriod, ApiError> {
    let Query(query) = query.map_err(|_| invalid_query(request_id))?;
    AnalyticsPeriod::new(query.days.unwrap_or(DEFAULT_ANALYTICS_PERIOD_DAYS))
        .ok_or_else(|| invalid_query(request_id))
}

async fn authenticated_owner_id(
    state: &AnalyticsState,
    headers: &HeaderMap,
    request_id: &RequestId,
) -> Result<Uuid, ApiError> {
    let token = session_token(headers).ok_or_else(|| authentication_required(request_id))?;
    state
        .auth
        .authenticate_session(token)
        .await
        .map_err(|error| {
            tracing::error!(%error, "failed to authenticate analytics owner");
            ApiError::internal(request_id)
        })?
        .map(|user| user.id())
        .ok_or_else(|| authentication_required(request_id))
}

fn authentication_required(request_id: &RequestId) -> ApiError {
    ApiError::unauthorized(
        "authentication_required",
        "Authentication is required",
        None,
        request_id,
    )
}

fn invalid_query(request_id: &RequestId) -> ApiError {
    ApiError::invalid_request(
        "invalid_query",
        "The query parameters are invalid",
        None,
        request_id,
    )
}
