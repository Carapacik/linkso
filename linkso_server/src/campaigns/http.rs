use axum::{
    Extension, Json, Router,
    extract::{Path, State, rejection::JsonRejection},
    http::{HeaderMap, StatusCode, header},
    response::IntoResponse,
    routing::{get, post, put},
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use url::Url;
use uuid::Uuid;

use crate::{
    admin::{AdministrativeRole, BootstrapAdminToken},
    api_error::ApiError,
    request_id::RequestId,
};

use super::{
    AdCampaign, AdCampaignRepository, AdCampaignRepositoryError, CampaignBody, CampaignTitle,
    CampaignUrl, CampaignUrlField, CampaignValidationError, WriteAdCampaign,
};

#[derive(Clone)]
struct CampaignState {
    repository: AdCampaignRepository,
    public_base_url: Url,
    admin_token: BootstrapAdminToken,
}

pub fn routes(pool: PgPool, public_base_url: Url, admin_token: BootstrapAdminToken) -> Router {
    let state = CampaignState {
        repository: AdCampaignRepository::new(pool),
        public_base_url,
        admin_token,
    };
    Router::new()
        .route("/api/v1/admin/ad-campaigns", post(create_campaign))
        .route("/api/v1/admin/ad-campaigns/{id}", put(update_campaign))
        .route(
            "/api/v1/admin/ad-campaigns/{id}/enable",
            post(enable_campaign),
        )
        .route(
            "/api/v1/admin/ad-campaigns/{id}/disable",
            post(disable_campaign),
        )
        .route("/api/v1/ad-campaigns/active", get(active_campaign))
        .with_state(state)
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct WriteCampaignRequest {
    title: String,
    body: String,
    image_url: Option<String>,
    advertiser_url: String,
    starts_at: DateTime<Utc>,
    ends_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
struct CampaignResponse {
    id: Uuid,
    title: String,
    body: String,
    image_url: Option<String>,
    advertiser_url: String,
    starts_at: DateTime<Utc>,
    ends_at: DateTime<Utc>,
    is_active: bool,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
struct ActiveCampaignResponse {
    id: Uuid,
    title: String,
    body: String,
    image_url: Option<String>,
    advertiser_url: String,
    ends_at: DateTime<Utc>,
}

async fn create_campaign(
    State(state): State<CampaignState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    payload: Result<Json<WriteCampaignRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    require_administrator(&state, &headers, &request_id)?;
    let Json(payload) = parse_payload(payload, &request_id)?;
    let input = validate_payload(payload, &state.public_base_url, &request_id)?;
    let campaign = state
        .repository
        .create(input)
        .await
        .map_err(|error| repository_error(error, &request_id))?;
    Ok((StatusCode::CREATED, Json(CampaignResponse::from(campaign))))
}

async fn update_campaign(
    State(state): State<CampaignState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
    payload: Result<Json<WriteCampaignRequest>, JsonRejection>,
) -> Result<Json<CampaignResponse>, ApiError> {
    require_administrator(&state, &headers, &request_id)?;
    let id = parse_campaign_id(&raw_id, &request_id)?;
    let Json(payload) = parse_payload(payload, &request_id)?;
    let input = validate_payload(payload, &state.public_base_url, &request_id)?;
    let campaign = state
        .repository
        .update(id, input)
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    Ok(Json(CampaignResponse::from(campaign)))
}

async fn enable_campaign(
    State(state): State<CampaignState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<Json<CampaignResponse>, ApiError> {
    set_campaign_active(state, headers, raw_id, true, request_id).await
}

async fn disable_campaign(
    State(state): State<CampaignState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<Json<CampaignResponse>, ApiError> {
    set_campaign_active(state, headers, raw_id, false, request_id).await
}

async fn set_campaign_active(
    state: CampaignState,
    headers: HeaderMap,
    raw_id: String,
    is_active: bool,
    request_id: RequestId,
) -> Result<Json<CampaignResponse>, ApiError> {
    require_administrator(&state, &headers, &request_id)?;
    let id = parse_campaign_id(&raw_id, &request_id)?;
    let campaign = state
        .repository
        .set_active(id, is_active)
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    Ok(Json(CampaignResponse::from(campaign)))
}

async fn active_campaign(
    State(state): State<CampaignState>,
    Extension(request_id): Extension<RequestId>,
) -> Result<Json<ActiveCampaignResponse>, ApiError> {
    let campaign = state
        .repository
        .find_active_at(Utc::now())
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    Ok(Json(ActiveCampaignResponse::from(campaign)))
}

fn require_administrator(
    state: &CampaignState,
    headers: &HeaderMap,
    request_id: &RequestId,
) -> Result<(), ApiError> {
    let authorization = headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok());
    let principal = state
        .admin_token
        .authenticate_bearer(authorization)
        .ok_or_else(|| ApiError::admin_authentication_required(request_id))?;
    match principal.role() {
        AdministrativeRole::Administrator => Ok(()),
    }
}

fn parse_payload(
    payload: Result<Json<WriteCampaignRequest>, JsonRejection>,
    request_id: &RequestId,
) -> Result<Json<WriteCampaignRequest>, ApiError> {
    payload.map_err(|_| {
        ApiError::invalid_request(
            "invalid_json",
            "The request body must be valid campaign JSON",
            None,
            request_id,
        )
    })
}

fn validate_payload(
    payload: WriteCampaignRequest,
    public_base_url: &Url,
    request_id: &RequestId,
) -> Result<WriteAdCampaign, ApiError> {
    let title =
        CampaignTitle::parse(payload.title).map_err(|error| validation_error(error, request_id))?;
    let body =
        CampaignBody::parse(payload.body).map_err(|error| validation_error(error, request_id))?;
    let image_url = payload
        .image_url
        .map(|url| CampaignUrl::parse(url, public_base_url, CampaignUrlField::Image))
        .transpose()
        .map_err(|error| validation_error(error, request_id))?;
    let advertiser_url = CampaignUrl::parse(
        payload.advertiser_url,
        public_base_url,
        CampaignUrlField::Advertiser,
    )
    .map_err(|error| validation_error(error, request_id))?;
    WriteAdCampaign::new(
        title,
        body,
        image_url,
        advertiser_url,
        payload.starts_at,
        payload.ends_at,
    )
    .map_err(|error| validation_error(error, request_id))
}

fn parse_campaign_id(raw_id: &str, request_id: &RequestId) -> Result<Uuid, ApiError> {
    Uuid::parse_str(raw_id).map_err(|_| ApiError::not_found(request_id))
}

fn validation_error(error: CampaignValidationError, request_id: &RequestId) -> ApiError {
    let (code, message, field) = match error {
        CampaignValidationError::Title(_) => (
            "invalid_campaign_title",
            "The campaign title must be plain text between 1 and 120 characters",
            "title",
        ),
        CampaignValidationError::Body(_) => (
            "invalid_campaign_body",
            "The campaign body must be plain text between 1 and 500 characters",
            "body",
        ),
        CampaignValidationError::Url { field, .. } => (
            "invalid_campaign_url",
            "The campaign URL must be an external HTTP or HTTPS URL without credentials",
            field.api_field(),
        ),
        CampaignValidationError::InvalidPeriod => (
            "invalid_campaign_period",
            "The campaign end time must be later than its start time",
            "ends_at",
        ),
    };
    ApiError::invalid_request(code, message, Some(field), request_id)
}

fn repository_error(error: AdCampaignRepositoryError, request_id: &RequestId) -> ApiError {
    tracing::error!(%error, "advertising campaign repository operation failed");
    ApiError::internal(request_id)
}

impl From<AdCampaign> for CampaignResponse {
    fn from(campaign: AdCampaign) -> Self {
        Self {
            id: campaign.id,
            title: campaign.title,
            body: campaign.body,
            image_url: campaign.image_url,
            advertiser_url: campaign.advertiser_url,
            starts_at: campaign.starts_at,
            ends_at: campaign.ends_at,
            is_active: campaign.is_active,
            created_at: campaign.created_at,
            updated_at: campaign.updated_at,
        }
    }
}

impl From<AdCampaign> for ActiveCampaignResponse {
    fn from(campaign: AdCampaign) -> Self {
        Self {
            id: campaign.id,
            title: campaign.title,
            body: campaign.body,
            image_url: campaign.image_url,
            advertiser_url: campaign.advertiser_url,
            ends_at: campaign.ends_at,
        }
    }
}
