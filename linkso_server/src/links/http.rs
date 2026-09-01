use std::net::{IpAddr, Ipv4Addr, SocketAddr};

use axum::{
    Extension, Json, Router,
    extract::{
        ConnectInfo, Path, Query, State,
        rejection::{JsonRejection, QueryRejection},
    },
    http::{HeaderMap, HeaderValue, StatusCode, header},
    response::IntoResponse,
    routing::{get, post},
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use url::Url;
use uuid::Uuid;

use crate::{
    accounts::{
        AuthRepository, AuthTokenCodec,
        http::{AuthHttpConfig, session_token},
    },
    admin::BootstrapAdminToken,
    analytics::{AnalyticsEventType, AnalyticsRepository, is_obvious_bot},
    api_error::ApiError,
    observability::Metrics,
    request_id::RequestId,
};

use super::{
    AdvertisingContinuation, AdvertisingFlowError, AdvertisingFlowRepository, CreateLink,
    CreateLinkError, LinkCreationRateLimiter, LinkCreationSubject, LinkKind, LinkModerationError,
    LinkModerationRepository, LinkPassword, LinkPasswordError, LinkRecord, LinkReport,
    LinkRepository, LinkRepositoryError, LinkStatus, LinkTag, LinkTagError, OwnedLinkExpiration,
    OwnedLinkQuery, OwnedLinkSort, PASSWORD_MAX_FAILED_ATTEMPTS, PasswordFlowError,
    PasswordFlowRepository, PasswordHashUpdate, PasswordVerification, PublicLinkResolution,
    PublicRateLimitKind, PublicRateLimiter, ReportReason, Slug, SlugError, SortDirection,
    TargetUrl, TargetUrlError, UpdateOwnedLink, hash_link_password,
};

#[derive(Clone)]
struct LinksState {
    repository: LinkRepository,
    password_flow: PasswordFlowRepository,
    advertising_flow: AdvertisingFlowRepository,
    creation_rate_limit: LinkCreationRateLimiter,
    public_rate_limit: PublicRateLimiter,
    moderation: LinkModerationRepository,
    reporter_tokens: AuthTokenCodec,
    auth: AuthRepository,
    analytics: AnalyticsRepository,
    public_base_url: Url,
    admin_token: BootstrapAdminToken,
    metrics: Metrics,
}

pub fn routes(
    pool: PgPool,
    public_base_url: Url,
    auth_config: AuthHttpConfig,
    admin_token: BootstrapAdminToken,
    metrics: Metrics,
) -> Router {
    let token_codec = auth_config.token_codec();
    let state = LinksState {
        repository: LinkRepository::new(pool.clone()),
        password_flow: PasswordFlowRepository::new(pool.clone()),
        advertising_flow: AdvertisingFlowRepository::new(pool.clone()),
        creation_rate_limit: LinkCreationRateLimiter::new(pool.clone(), token_codec.clone()),
        public_rate_limit: PublicRateLimiter::new(pool.clone(), token_codec.clone()),
        moderation: LinkModerationRepository::new(pool.clone()),
        reporter_tokens: token_codec.clone(),
        auth: AuthRepository::new(pool.clone(), token_codec),
        analytics: AnalyticsRepository::new(pool),
        public_base_url,
        admin_token,
        metrics,
    };

    Router::new()
        .route("/api/v1/links", post(create_link))
        .route("/api/v1/me/links", get(list_owned_links))
        .route("/api/v1/me/tags", get(list_owned_tags))
        .route(
            "/api/v1/me/links/{id}",
            get(get_owned_link)
                .put(update_owned_link)
                .delete(delete_owned_link),
        )
        .route("/api/v1/me/links/{id}/enable", post(enable_owned_link))
        .route("/api/v1/me/links/{id}/disable", post(disable_owned_link))
        .route("/api/v1/links/{slug}/reports", post(report_link))
        .route("/api/v1/admin/link-reports", get(list_link_reports))
        .route(
            "/api/v1/admin/link-reports/{id}/dismiss",
            post(dismiss_link_report),
        )
        .route("/api/v1/admin/links/{id}/block", post(block_link))
        .route("/api/v1/admin/links/{id}/unblock", post(unblock_link))
        .route(
            "/api/v1/password-links/{slug}/sessions",
            post(start_password_session),
        )
        .route(
            "/api/v1/password-links/{slug}/verify",
            post(verify_password),
        )
        .route(
            "/api/v1/password-links/tickets/{ticket}",
            get(consume_password_ticket),
        )
        .route(
            "/api/v1/advertising-links/{slug}/sessions",
            post(start_advertising_session),
        )
        .route(
            "/api/v1/advertising-links/{slug}/sessions/{session_id}/continue",
            post(continue_advertising_session),
        )
        .route(
            "/api/v1/advertising-links/tickets/{ticket}",
            get(consume_advertising_ticket),
        )
        .route("/{slug}", get(redirect_direct_link))
        .with_state(state)
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct CreateLinkRequest {
    target_url: String,
    #[serde(default = "default_link_kind")]
    kind: LinkKind,
    slug: Option<String>,
    title: Option<String>,
    expires_at: Option<DateTime<Utc>>,
    password: Option<String>,
    #[serde(default)]
    tags: Vec<String>,
}

#[derive(Debug, Serialize)]
struct CreateLinkResponse {
    id: Uuid,
    owner_id: Option<Uuid>,
    slug: String,
    short_url: String,
    target_url: String,
    title: Option<String>,
    kind: LinkKind,
    status: LinkStatus,
    expires_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    tags: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct OwnedLinksQueryRequest {
    page: Option<u32>,
    page_size: Option<u32>,
    query: Option<String>,
    kind: Option<String>,
    status: Option<String>,
    expiration: Option<String>,
    sort: Option<String>,
    direction: Option<String>,
    tag: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct UpdateOwnedLinkRequest {
    target_url: String,
    slug: String,
    title: Option<String>,
    kind: LinkKind,
    expires_at: Option<DateTime<Utc>>,
    password: Option<String>,
    tags: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
struct OwnedLinkResponse {
    id: Uuid,
    slug: String,
    short_url: String,
    target_url: String,
    title: Option<String>,
    kind: LinkKind,
    status: LinkStatus,
    blocked_reason: Option<String>,
    blocked_at: Option<DateTime<Utc>>,
    blocked_by: Option<String>,
    expires_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    redirect_count: i64,
    tags: Vec<String>,
}

#[derive(Debug, Serialize)]
struct OwnedTagResponse {
    name: String,
    link_count: i64,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct ReportLinkRequest {
    reason: String,
    details: Option<String>,
}

#[derive(Debug, Serialize)]
struct ReportLinkResponse {
    accepted: bool,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct BlockLinkRequest {
    reason: String,
}

#[derive(Debug, Serialize)]
struct OwnedLinksPageResponse {
    items: Vec<OwnedLinkResponse>,
    pagination: PaginationResponse,
}

#[derive(Debug, Serialize)]
struct PaginationResponse {
    page: u32,
    page_size: u32,
    total_items: i64,
    total_pages: u32,
}

#[derive(Debug, Serialize)]
struct PasswordSessionResponse {
    session_id: Uuid,
    expires_at: DateTime<Utc>,
    max_attempts: i16,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct VerifyPasswordRequest {
    session_id: Uuid,
    password: String,
}

#[derive(Debug, Serialize)]
struct VerifyPasswordResponse {
    redirect_url: String,
    expires_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
struct AdvertisingCampaignResponse {
    id: Uuid,
    title: String,
    body: String,
    image_url: Option<String>,
    advertiser_url: String,
    ends_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
struct AdvertisingSessionResponse {
    session_id: Uuid,
    unlocks_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    campaign: Option<AdvertisingCampaignResponse>,
}

#[derive(Debug, Serialize)]
struct AdvertisingContinuationResponse {
    redirect_url: String,
    expires_at: DateTime<Utc>,
}

async fn create_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    payload: Result<Json<CreateLinkRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let Json(payload) = payload.map_err(|_| {
        ApiError::invalid_request(
            "invalid_json",
            "The request body must be valid JSON",
            None,
            &request_id,
        )
    })?;

    let CreateLinkRequest {
        target_url,
        kind,
        slug,
        title,
        expires_at,
        password,
        tags,
    } = payload;
    let tags = LinkTag::parse_many(tags).map_err(|error| tag_error(error, &request_id))?;
    let target_url = TargetUrl::parse(&target_url, &state.public_base_url)
        .map_err(|error| target_url_error(error, &request_id))?;
    let custom_slug = slug
        .map(Slug::parse)
        .transpose()
        .map_err(|error| slug_error(error, &request_id))?;
    let owner_id = match session_token(&headers) {
        Some(token) => Some(
            state
                .auth
                .authenticate_session(token)
                .await
                .map_err(|error| {
                    tracing::error!(%error, "failed to authenticate link owner");
                    ApiError::internal(&request_id)
                })?
                .ok_or_else(|| {
                    ApiError::unauthorized(
                        "authentication_required",
                        "Authentication is required",
                        None,
                        &request_id,
                    )
                })?
                .id(),
        ),
        None => None,
    };
    let subject = owner_id.map_or_else(
        || {
            LinkCreationSubject::Anonymous(creation_client_ip(
                &headers,
                connect_info.map(|Extension(ConnectInfo(address))| address),
            ))
        },
        LinkCreationSubject::Authenticated,
    );
    if let Some(retry_after_seconds) =
        state
            .creation_rate_limit
            .register(subject)
            .await
            .map_err(|error| {
                tracing::error!(%error, "failed to apply link creation rate limit");
                ApiError::internal(&request_id)
            })?
    {
        return Err(ApiError::too_many_requests_for_field(
            "link_creation_rate_limited",
            "Too many links were created in a short period",
            None,
            retry_after_seconds,
            &request_id,
        ));
    }
    let input = match kind {
        LinkKind::Direct => {
            reject_unexpected_password(password, &request_id)?;
            CreateLink::direct(target_url, custom_slug, title, expires_at)
        }
        LinkKind::Advertising => {
            reject_unexpected_password(password, &request_id)?;
            CreateLink::advertising(target_url, custom_slug, title, expires_at)
        }
        LinkKind::Password => {
            let password = password.ok_or_else(|| password_required_error(&request_id))?;
            let password = LinkPassword::parse(password)
                .map_err(|error| password_error(error, &request_id))?;
            let password_hash = hash_link_password(password).await.map_err(|error| {
                tracing::error!(%error, "failed to hash link password");
                ApiError::internal(&request_id)
            })?;
            CreateLink::password(target_url, custom_slug, title, expires_at, password_hash)
        }
    }
    .map_err(|error| create_link_error(error, &request_id))?;

    if owner_id.is_none() && !tags.is_empty() {
        return Err(authentication_required(&request_id));
    }
    let record = state
        .repository
        .create(input, owner_id)
        .await
        .map_err(|error| repository_error(error, &request_id))?;
    let response_tags = if let Some(owner_id) = owner_id {
        state
            .repository
            .replace_owned_tags(owner_id, record.id(), &tags)
            .await
            .map_err(|error| repository_error(error, &request_id))?
            .ok_or_else(|| ApiError::not_found(&request_id))?
    } else {
        Vec::new()
    };
    let short_url = short_url(&state.public_base_url, record.slug());
    let response = response_from_record(record, short_url.clone(), response_tags);
    let location = HeaderValue::from_str(short_url.as_str())
        .expect("validated public base URL and slug must form a valid Location header");

    Ok((
        StatusCode::CREATED,
        [(header::LOCATION, location)],
        Json(response),
    ))
}

fn creation_client_ip(headers: &HeaderMap, peer: Option<SocketAddr>) -> IpAddr {
    let peer_ip = peer
        .map(|address| address.ip())
        .unwrap_or(IpAddr::V4(Ipv4Addr::LOCALHOST));
    if is_trusted_reverse_proxy(peer_ip)
        && let Some(forwarded_ip) = headers
            .get("x-forwarded-for")
            .and_then(|value| value.to_str().ok())
            .and_then(|value| value.split(',').next())
            .and_then(|value| value.trim().parse().ok())
    {
        return forwarded_ip;
    }
    peer_ip
}

fn is_trusted_reverse_proxy(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => ip.is_loopback() || ip.is_private(),
        IpAddr::V6(ip) => ip.is_loopback() || (ip.segments()[0] & 0xfe00) == 0xfc00,
    }
}

async fn enforce_public_rate_limit(
    state: &LinksState,
    kind: PublicRateLimitKind,
    headers: &HeaderMap,
    connect_info: Option<&Extension<ConnectInfo<SocketAddr>>>,
    request_id: &RequestId,
) -> Result<(), ApiError> {
    let peer = connect_info.map(|Extension(ConnectInfo(address))| *address);
    if let Some(retry_after_seconds) = state
        .public_rate_limit
        .register(kind, creation_client_ip(headers, peer))
        .await
        .map_err(|error| {
            tracing::error!(%error, scope = kind.as_str(), "failed to apply public endpoint rate limit");
            ApiError::internal(request_id)
        })?
    {
        return Err(ApiError::too_many_requests_for_field(
            "public_endpoint_rate_limited",
            "Too many requests were sent to this public endpoint",
            None,
            retry_after_seconds,
            request_id,
        ));
    }
    Ok(())
}

async fn list_owned_links(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    query: Result<Query<OwnedLinksQueryRequest>, QueryRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let owner_id = authenticated_owner_id(&state, &headers, &request_id).await?;
    let Query(query) = query.map_err(|_| invalid_query(&request_id))?;
    let query = parse_owned_links_query(query, &request_id)?;
    let page = state
        .repository
        .list_owned(owner_id, &query)
        .await
        .map_err(|error| repository_error(error, &request_id))?;
    let link_ids = page.items.iter().map(LinkRecord::id).collect::<Vec<_>>();
    let mut tags_by_link = state
        .repository
        .tags_for_owned_links(owner_id, &link_ids)
        .await
        .map_err(|error| repository_error(error, &request_id))?;
    let total_pages = if page.total_items == 0 {
        0
    } else {
        ((page.total_items - 1) / i64::from(query.page_size) + 1) as u32
    };
    let items = page
        .items
        .into_iter()
        .map(|record| {
            let tags = tags_by_link.remove(&record.id()).unwrap_or_default();
            owned_response_from_record(record, &state.public_base_url, tags)
        })
        .collect();
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(OwnedLinksPageResponse {
            items,
            pagination: PaginationResponse {
                page: query.page,
                page_size: query.page_size,
                total_items: page.total_items,
                total_pages,
            },
        }),
    ))
}

async fn list_owned_tags(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, ApiError> {
    let owner_id = authenticated_owner_id(&state, &headers, &request_id).await?;
    let tags = state
        .repository
        .list_owned_tags(owner_id)
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .into_iter()
        .map(|tag| OwnedTagResponse {
            name: tag.name,
            link_count: tag.link_count,
        })
        .collect::<Vec<_>>();
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(tags),
    ))
}

async fn get_owned_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<impl IntoResponse, ApiError> {
    let owner_id = authenticated_owner_id(&state, &headers, &request_id).await?;
    let id = parse_owned_link_id(&raw_id, &request_id)?;
    let record = state
        .repository
        .get_owned_by_id(owner_id, id)
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    let tags = state
        .repository
        .tags_for_owned_links(owner_id, &[record.id()])
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .remove(&record.id())
        .unwrap_or_default();
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(owned_response_from_record(
            record,
            &state.public_base_url,
            tags,
        )),
    ))
}

async fn update_owned_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
    payload: Result<Json<UpdateOwnedLinkRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let owner_id = authenticated_owner_id(&state, &headers, &request_id).await?;
    let id = parse_owned_link_id(&raw_id, &request_id)?;
    let current = state
        .repository
        .get_owned_by_id(owner_id, id)
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    let Json(payload) = payload.map_err(|_| {
        ApiError::invalid_request(
            "invalid_json",
            "The request body must be valid JSON",
            None,
            &request_id,
        )
    })?;
    let tags = payload
        .tags
        .map(LinkTag::parse_many)
        .transpose()
        .map_err(|error| tag_error(error, &request_id))?;
    let target_url = TargetUrl::parse(&payload.target_url, &state.public_base_url)
        .map_err(|error| target_url_error(error, &request_id))?;
    let slug = Slug::parse(payload.slug).map_err(|error| slug_error(error, &request_id))?;
    let password_hash = match payload.kind {
        LinkKind::Password => match payload.password {
            Some(password) => {
                let password = LinkPassword::parse(password)
                    .map_err(|error| password_error(error, &request_id))?;
                PasswordHashUpdate::Replace(hash_link_password(password).await.map_err(
                    |error| {
                        tracing::error!(%error, "failed to hash updated link password");
                        ApiError::internal(&request_id)
                    },
                )?)
            }
            None if current.kind() == LinkKind::Password => PasswordHashUpdate::Preserve,
            None => return Err(password_required_error(&request_id)),
        },
        LinkKind::Direct | LinkKind::Advertising => {
            reject_unexpected_password(payload.password, &request_id)?;
            PasswordHashUpdate::Remove
        }
    };
    let input = UpdateOwnedLink::new(
        target_url,
        slug,
        payload.title,
        payload.expires_at,
        payload.kind,
        password_hash,
    )
    .map_err(|error| create_link_error(error, &request_id))?;
    let record = state
        .repository
        .update_owned(owner_id, id, input)
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    let response_tags = match tags {
        Some(tags) => state
            .repository
            .replace_owned_tags(owner_id, id, &tags)
            .await
            .map_err(|error| repository_error(error, &request_id))?
            .ok_or_else(|| ApiError::not_found(&request_id))?,
        None => state
            .repository
            .tags_for_owned_links(owner_id, &[id])
            .await
            .map_err(|error| repository_error(error, &request_id))?
            .remove(&id)
            .unwrap_or_default(),
    };
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(owned_response_from_record(
            record,
            &state.public_base_url,
            response_tags,
        )),
    ))
}

async fn enable_owned_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<impl IntoResponse, ApiError> {
    set_owned_link_status(state, headers, raw_id, LinkStatus::Active, request_id).await
}

async fn disable_owned_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<impl IntoResponse, ApiError> {
    set_owned_link_status(state, headers, raw_id, LinkStatus::Disabled, request_id).await
}

async fn set_owned_link_status(
    state: LinksState,
    headers: HeaderMap,
    raw_id: String,
    status: LinkStatus,
    request_id: RequestId,
) -> Result<impl IntoResponse, ApiError> {
    let owner_id = authenticated_owner_id(&state, &headers, &request_id).await?;
    let id = parse_owned_link_id(&raw_id, &request_id)?;
    let record = state
        .repository
        .set_owned_status(owner_id, id, status)
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    let tags = state
        .repository
        .tags_for_owned_links(owner_id, &[record.id()])
        .await
        .map_err(|error| repository_error(error, &request_id))?
        .remove(&record.id())
        .unwrap_or_default();
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(owned_response_from_record(
            record,
            &state.public_base_url,
            tags,
        )),
    ))
}

async fn delete_owned_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<StatusCode, ApiError> {
    let owner_id = authenticated_owner_id(&state, &headers, &request_id).await?;
    let id = parse_owned_link_id(&raw_id, &request_id)?;
    if !state
        .repository
        .soft_delete_owned(owner_id, id)
        .await
        .map_err(|error| repository_error(error, &request_id))?
    {
        return Err(ApiError::not_found(&request_id));
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn report_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    Path(raw_slug): Path<String>,
    payload: Result<Json<ReportLinkRequest>, JsonRejection>,
) -> Result<(StatusCode, Json<ReportLinkResponse>), ApiError> {
    let slug = Slug::parse(raw_slug).map_err(|_| ApiError::not_found(&request_id))?;
    enforce_public_rate_limit(
        &state,
        PublicRateLimitKind::LinkReport,
        &headers,
        connect_info.as_ref(),
        &request_id,
    )
    .await?;
    let Json(payload) = payload.map_err(|_| {
        ApiError::invalid_request(
            "invalid_json",
            "The request body must be valid report JSON",
            None,
            &request_id,
        )
    })?;
    let reason = payload.reason.parse::<ReportReason>().map_err(|_| {
        ApiError::invalid_request(
            "invalid_report_reason",
            "The report reason is invalid",
            Some("reason"),
            &request_id,
        )
    })?;
    let details = payload
        .details
        .map(|value| value.trim().to_owned())
        .filter(|value| !value.is_empty());
    if details
        .as_ref()
        .is_some_and(|value| value.chars().count() > 500)
    {
        return Err(ApiError::invalid_request(
            "report_details_too_long",
            "Report details must not exceed 500 characters",
            Some("details"),
            &request_id,
        ));
    }
    let peer = connect_info.as_ref().map(|value| value.0.0);
    let reporter_key = state
        .reporter_tokens
        .hash(
            "link-report-reporter",
            &creation_client_ip(&headers, peer).to_string(),
        )
        .map_err(|error| {
            tracing::error!(%error, "failed to derive report identity");
            ApiError::internal(&request_id)
        })?;
    state
        .moderation
        .submit_report(&slug, &reporter_key, reason, details.as_deref())
        .await
        .map_err(|error| moderation_error(error, &request_id))?;
    Ok((
        StatusCode::ACCEPTED,
        Json(ReportLinkResponse { accepted: true }),
    ))
}

async fn list_link_reports(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
) -> Result<Json<Vec<LinkReport>>, ApiError> {
    require_administrator(&state, &headers, &request_id)?;
    state
        .moderation
        .list_pending()
        .await
        .map(Json)
        .map_err(|error| moderation_error(error, &request_id))
}

async fn block_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
    payload: Result<Json<BlockLinkRequest>, JsonRejection>,
) -> Result<StatusCode, ApiError> {
    require_administrator(&state, &headers, &request_id)?;
    let id = parse_owned_link_id(&raw_id, &request_id)?;
    let Json(payload) = payload.map_err(|_| {
        ApiError::invalid_request(
            "invalid_json",
            "The request body must be valid block request JSON",
            None,
            &request_id,
        )
    })?;
    let reason = payload.reason.trim();
    if reason.is_empty() || reason.chars().count() > 240 {
        return Err(ApiError::invalid_request(
            "invalid_block_reason",
            "Block reason must contain between 1 and 240 characters",
            Some("reason"),
            &request_id,
        ));
    }
    if !state
        .moderation
        .block_link(id, reason)
        .await
        .map_err(|error| moderation_error(error, &request_id))?
    {
        return Err(ApiError::not_found(&request_id));
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn unblock_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<StatusCode, ApiError> {
    require_administrator(&state, &headers, &request_id)?;
    let id = parse_owned_link_id(&raw_id, &request_id)?;
    if !state
        .moderation
        .unblock_link(id)
        .await
        .map_err(|error| moderation_error(error, &request_id))?
    {
        return Err(ApiError::not_found(&request_id));
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn dismiss_link_report(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<StatusCode, ApiError> {
    require_administrator(&state, &headers, &request_id)?;
    let id = parse_owned_link_id(&raw_id, &request_id)?;
    if !state
        .moderation
        .dismiss_report(id)
        .await
        .map_err(|error| moderation_error(error, &request_id))?
    {
        return Err(ApiError::not_found(&request_id));
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn redirect_direct_link(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    Path(raw_slug): Path<String>,
) -> Result<impl IntoResponse, ApiError> {
    let slug = Slug::parse(raw_slug).map_err(|_| ApiError::not_found(&request_id))?;
    enforce_public_rate_limit(
        &state,
        PublicRateLimitKind::DirectRedirect,
        &headers,
        connect_info.as_ref(),
        &request_id,
    )
    .await?;
    let resolution = state
        .repository
        .resolve_public_by_slug(&slug)
        .await
        .map_err(|error| lookup_error(error, &request_id))?;

    let record = match resolution {
        PublicLinkResolution::Active(record) => record,
        PublicLinkResolution::NotFound if accepts_html(&headers) => {
            return Ok(error_page_redirect(
                &state.public_base_url,
                "/errors/not-found",
            ));
        }
        PublicLinkResolution::Expired if accepts_html(&headers) => {
            return Ok(error_page_redirect(
                &state.public_base_url,
                "/errors/expired",
            ));
        }
        PublicLinkResolution::Disabled if accepts_html(&headers) => {
            return Ok(error_page_redirect(
                &state.public_base_url,
                "/errors/disabled",
            ));
        }
        PublicLinkResolution::Blocked if accepts_html(&headers) => {
            return Ok(error_page_redirect(
                &state.public_base_url,
                "/errors/blocked",
            ));
        }
        PublicLinkResolution::NotFound => return Err(ApiError::not_found(&request_id)),
        PublicLinkResolution::Expired => return Err(ApiError::link_expired(&request_id)),
        PublicLinkResolution::Disabled => return Err(ApiError::link_disabled(&request_id)),
        PublicLinkResolution::Blocked => return Err(ApiError::link_blocked(&request_id)),
    };
    if record.kind() == LinkKind::Password {
        let location = password_page_url(&state.public_base_url, record.slug());
        let location = HeaderValue::from_str(location.as_str())
            .expect("validated public URL and slug must form a valid Location header");
        return Ok((
            StatusCode::TEMPORARY_REDIRECT,
            [
                (header::LOCATION, location),
                (header::CACHE_CONTROL, HeaderValue::from_static("no-store")),
            ],
        ));
    }
    if record.kind() == LinkKind::Advertising {
        let location = advertising_page_url(&state.public_base_url, record.slug());
        let location = HeaderValue::from_str(location.as_str())
            .expect("validated public URL and slug must form a valid Location header");
        return Ok((
            StatusCode::TEMPORARY_REDIRECT,
            [
                (header::LOCATION, location),
                (header::CACHE_CONTROL, HeaderValue::from_static("no-store")),
            ],
        ));
    }
    if record.kind() != LinkKind::Direct {
        return Err(ApiError::not_found(&request_id));
    }
    let location = HeaderValue::from_str(record.target_url()).map_err(|_| {
        tracing::error!(link_id = %record.id(), "stored target URL cannot be used as a redirect");
        ApiError::internal(&request_id)
    })?;
    record_analytics(
        &state,
        record.id(),
        AnalyticsEventType::DirectRedirect,
        &headers,
    )
    .await;

    Ok((
        StatusCode::TEMPORARY_REDIRECT,
        [
            (header::LOCATION, location),
            (header::CACHE_CONTROL, HeaderValue::from_static("no-store")),
        ],
    ))
}

async fn start_password_session(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    Path(raw_slug): Path<String>,
) -> Result<Json<PasswordSessionResponse>, ApiError> {
    enforce_public_rate_limit(
        &state,
        PublicRateLimitKind::PasswordSession,
        &headers,
        connect_info.as_ref(),
        &request_id,
    )
    .await?;
    let record = resolve_password_link(&state, raw_slug, &request_id).await?;
    let session = state
        .password_flow
        .start_session(record.id())
        .await
        .map_err(|error| password_flow_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    record_analytics(
        &state,
        record.id(),
        AnalyticsEventType::PasswordPromptView,
        &headers,
    )
    .await;

    Ok(Json(PasswordSessionResponse {
        session_id: session.id,
        expires_at: session.expires_at,
        max_attempts: PASSWORD_MAX_FAILED_ATTEMPTS,
    }))
}

async fn verify_password(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    Path(raw_slug): Path<String>,
    payload: Result<Json<VerifyPasswordRequest>, JsonRejection>,
) -> Result<Json<VerifyPasswordResponse>, ApiError> {
    let Json(payload) = payload.map_err(|_| {
        ApiError::invalid_request(
            "invalid_json",
            "The request body must be valid JSON",
            None,
            &request_id,
        )
    })?;
    enforce_public_rate_limit(
        &state,
        PublicRateLimitKind::PasswordVerify,
        &headers,
        connect_info.as_ref(),
        &request_id,
    )
    .await?;
    let record = resolve_password_link(&state, raw_slug, &request_id).await?;
    let password = LinkPassword::parse(payload.password)
        .map_err(|error| password_error(error, &request_id))?;
    let verification = state
        .password_flow
        .verify(record.id(), payload.session_id, password)
        .await
        .map_err(|error| password_flow_error(error, &request_id))?;

    match verification {
        PasswordVerification::Incorrect => {
            record_analytics(
                &state,
                record.id(),
                AnalyticsEventType::PasswordRejected,
                &headers,
            )
            .await;
            Err(ApiError::unauthorized(
                "password_incorrect",
                "The password is incorrect",
                Some("password"),
                &request_id,
            ))
        }
        PasswordVerification::Locked {
            retry_after_seconds,
        } => {
            record_analytics(
                &state,
                record.id(),
                AnalyticsEventType::PasswordRejected,
                &headers,
            )
            .await;
            Err(ApiError::too_many_requests(
                "password_temporarily_locked",
                "Too many failed password attempts",
                retry_after_seconds,
                &request_id,
            ))
        }
        PasswordVerification::Ticket(ticket) => {
            record_analytics(
                &state,
                record.id(),
                AnalyticsEventType::PasswordUnlocked,
                &headers,
            )
            .await;
            let redirect_url = password_ticket_url(&state.public_base_url, ticket.id);
            Ok(Json(VerifyPasswordResponse {
                redirect_url: redirect_url.to_string(),
                expires_at: ticket.expires_at,
            }))
        }
    }
}

async fn consume_password_ticket(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    Path(raw_ticket): Path<String>,
) -> Result<impl IntoResponse, ApiError> {
    enforce_public_rate_limit(
        &state,
        PublicRateLimitKind::PasswordTicket,
        &headers,
        connect_info.as_ref(),
        &request_id,
    )
    .await?;
    let ticket_id = Uuid::parse_str(&raw_ticket).map_err(|_| ApiError::not_found(&request_id))?;
    let redirect = state
        .password_flow
        .consume_ticket(ticket_id)
        .await
        .map_err(|error| password_flow_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    let location = HeaderValue::from_str(&redirect.target_url).map_err(|_| {
        tracing::error!(%ticket_id, "stored target URL cannot be used as a redirect");
        ApiError::internal(&request_id)
    })?;
    record_analytics(
        &state,
        redirect.link_id,
        AnalyticsEventType::PasswordRedirect,
        &headers,
    )
    .await;

    Ok((
        StatusCode::TEMPORARY_REDIRECT,
        [
            (header::LOCATION, location),
            (header::CACHE_CONTROL, HeaderValue::from_static("no-store")),
        ],
    ))
}

async fn start_advertising_session(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    Path(raw_slug): Path<String>,
) -> Result<Json<AdvertisingSessionResponse>, ApiError> {
    enforce_public_rate_limit(
        &state,
        PublicRateLimitKind::AdvertisingSession,
        &headers,
        connect_info.as_ref(),
        &request_id,
    )
    .await?;
    let record = resolve_advertising_link(&state, raw_slug, &request_id).await?;
    let session = state
        .advertising_flow
        .start_session(record.id())
        .await
        .map_err(|error| advertising_flow_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    if session.campaign.is_some() {
        record_analytics(
            &state,
            record.id(),
            AnalyticsEventType::AdvertisingImpression,
            &headers,
        )
        .await;
    }
    Ok(Json(AdvertisingSessionResponse {
        session_id: session.id,
        unlocks_at: session.unlocks_at,
        expires_at: session.expires_at,
        campaign: session
            .campaign
            .map(|campaign| AdvertisingCampaignResponse {
                id: campaign.id,
                title: campaign.title,
                body: campaign.body,
                image_url: campaign.image_url,
                advertiser_url: campaign.advertiser_url,
                ends_at: campaign.ends_at,
            }),
    }))
}

async fn continue_advertising_session(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    Path((raw_slug, raw_session_id)): Path<(String, String)>,
) -> Result<Json<AdvertisingContinuationResponse>, ApiError> {
    enforce_public_rate_limit(
        &state,
        PublicRateLimitKind::AdvertisingContinue,
        &headers,
        connect_info.as_ref(),
        &request_id,
    )
    .await?;
    let record = resolve_advertising_link(&state, raw_slug, &request_id).await?;
    let session_id =
        Uuid::parse_str(&raw_session_id).map_err(|_| ApiError::not_found(&request_id))?;
    match state
        .advertising_flow
        .continue_session(record.id(), session_id)
        .await
        .map_err(|error| advertising_flow_error(error, &request_id))?
    {
        AdvertisingContinuation::NotReady {
            retry_after_seconds,
        } => Err(ApiError::too_early(
            "advertising_timer_not_finished",
            "The advertising timer has not finished",
            retry_after_seconds,
            &request_id,
        )),
        AdvertisingContinuation::Ticket(ticket) => {
            record_analytics(
                &state,
                record.id(),
                AnalyticsEventType::AdvertisingTimerComplete,
                &headers,
            )
            .await;
            let redirect_url = advertising_ticket_url(&state.public_base_url, ticket.id);
            Ok(Json(AdvertisingContinuationResponse {
                redirect_url: redirect_url.to_string(),
                expires_at: ticket.expires_at,
            }))
        }
    }
}

async fn consume_advertising_ticket(
    State(state): State<LinksState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    connect_info: Option<Extension<ConnectInfo<SocketAddr>>>,
    Path(raw_ticket): Path<String>,
) -> Result<impl IntoResponse, ApiError> {
    enforce_public_rate_limit(
        &state,
        PublicRateLimitKind::AdvertisingTicket,
        &headers,
        connect_info.as_ref(),
        &request_id,
    )
    .await?;
    let ticket_id = Uuid::parse_str(&raw_ticket).map_err(|_| ApiError::not_found(&request_id))?;
    let redirect = state
        .advertising_flow
        .consume_ticket(ticket_id)
        .await
        .map_err(|error| advertising_flow_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    let location = HeaderValue::from_str(&redirect.target_url).map_err(|_| {
        tracing::error!(%ticket_id, "stored target URL cannot be used as an advertising redirect");
        ApiError::internal(&request_id)
    })?;
    record_analytics(
        &state,
        redirect.link_id,
        AnalyticsEventType::AdvertisingRedirect,
        &headers,
    )
    .await;
    Ok((
        StatusCode::TEMPORARY_REDIRECT,
        [
            (header::LOCATION, location),
            (header::CACHE_CONTROL, HeaderValue::from_static("no-store")),
        ],
    ))
}

async fn resolve_password_link(
    state: &LinksState,
    raw_slug: String,
    request_id: &RequestId,
) -> Result<LinkRecord, ApiError> {
    let slug = Slug::parse(raw_slug).map_err(|_| ApiError::not_found(request_id))?;
    let resolution = state
        .repository
        .resolve_public_by_slug(&slug)
        .await
        .map_err(|error| lookup_error(error, request_id))?;
    match resolution {
        PublicLinkResolution::Active(record) if record.kind() == LinkKind::Password => Ok(*record),
        PublicLinkResolution::Active(_) | PublicLinkResolution::NotFound => {
            Err(ApiError::not_found(request_id))
        }
        PublicLinkResolution::Expired => Err(ApiError::link_expired(request_id)),
        PublicLinkResolution::Disabled => Err(ApiError::link_disabled(request_id)),
        PublicLinkResolution::Blocked => Err(ApiError::link_blocked(request_id)),
    }
}

async fn resolve_advertising_link(
    state: &LinksState,
    raw_slug: String,
    request_id: &RequestId,
) -> Result<LinkRecord, ApiError> {
    let slug = Slug::parse(raw_slug).map_err(|_| ApiError::not_found(request_id))?;
    let resolution = state
        .repository
        .resolve_public_by_slug(&slug)
        .await
        .map_err(|error| lookup_error(error, request_id))?;
    match resolution {
        PublicLinkResolution::Active(record) if record.kind() == LinkKind::Advertising => {
            Ok(*record)
        }
        PublicLinkResolution::Active(_) | PublicLinkResolution::NotFound => {
            Err(ApiError::not_found(request_id))
        }
        PublicLinkResolution::Expired => Err(ApiError::link_expired(request_id)),
        PublicLinkResolution::Disabled => Err(ApiError::link_disabled(request_id)),
        PublicLinkResolution::Blocked => Err(ApiError::link_blocked(request_id)),
    }
}

async fn authenticated_owner_id(
    state: &LinksState,
    headers: &HeaderMap,
    request_id: &RequestId,
) -> Result<Uuid, ApiError> {
    let token = session_token(headers).ok_or_else(|| authentication_required(request_id))?;
    state
        .auth
        .authenticate_session(token)
        .await
        .map_err(|error| {
            tracing::error!(%error, "failed to authenticate link owner");
            ApiError::internal(request_id)
        })?
        .map(|user| user.id())
        .ok_or_else(|| authentication_required(request_id))
}

async fn record_analytics(
    state: &LinksState,
    link_id: Uuid,
    event_type: AnalyticsEventType,
    headers: &HeaderMap,
) {
    state.metrics.record_link_event(event_type);
    let user_agent = headers
        .get(header::USER_AGENT)
        .and_then(|value| value.to_str().ok());
    if let Err(error) = state
        .analytics
        .record(link_id, event_type, is_obvious_bot(user_agent))
        .await
    {
        tracing::error!(%link_id, event_type = event_type.as_str(), %error, "failed to record analytics event");
    }
}

fn authentication_required(request_id: &RequestId) -> ApiError {
    ApiError::unauthorized(
        "authentication_required",
        "Authentication is required",
        None,
        request_id,
    )
}

fn parse_owned_link_id(raw_id: &str, request_id: &RequestId) -> Result<Uuid, ApiError> {
    Uuid::parse_str(raw_id).map_err(|_| ApiError::not_found(request_id))
}

fn parse_owned_links_query(
    value: OwnedLinksQueryRequest,
    request_id: &RequestId,
) -> Result<OwnedLinkQuery, ApiError> {
    let page = value.page.unwrap_or(1);
    let page_size = value.page_size.unwrap_or(20);
    if page == 0 || !(1..=100).contains(&page_size) {
        return Err(invalid_query(request_id));
    }
    let search = value
        .query
        .map(|query| query.trim().to_owned())
        .filter(|query| !query.is_empty());
    if search
        .as_ref()
        .is_some_and(|query| query.chars().count() > 200)
    {
        return Err(invalid_query(request_id));
    }
    let kind = value
        .kind
        .map(|kind| kind.parse())
        .transpose()
        .map_err(|_| invalid_query(request_id))?;
    let status = value
        .status
        .map(|status| status.parse())
        .transpose()
        .map_err(|_| invalid_query(request_id))?;
    let expiration = value
        .expiration
        .map(|expiration| match expiration.as_str() {
            "not_expired" => Ok(OwnedLinkExpiration::NotExpired),
            "expired" => Ok(OwnedLinkExpiration::Expired),
            "never" => Ok(OwnedLinkExpiration::Never),
            _ => Err(invalid_query(request_id)),
        })
        .transpose()?;
    let tag = value
        .tag
        .map(LinkTag::parse)
        .transpose()
        .map_err(|_| invalid_query(request_id))?
        .map(|tag| tag.normalized_name().to_owned());
    let sort = match value.sort.as_deref().unwrap_or("created_at") {
        "created_at" => OwnedLinkSort::CreatedAt,
        "redirect_count" => OwnedLinkSort::RedirectCount,
        _ => return Err(invalid_query(request_id)),
    };
    let direction = match value.direction.as_deref().unwrap_or("desc") {
        "asc" => SortDirection::Ascending,
        "desc" => SortDirection::Descending,
        _ => return Err(invalid_query(request_id)),
    };
    Ok(OwnedLinkQuery {
        page,
        page_size,
        search,
        kind,
        status,
        expiration,
        tag,
        sort,
        direction,
    })
}

fn invalid_query(request_id: &RequestId) -> ApiError {
    ApiError::invalid_request(
        "invalid_query",
        "The query parameters are invalid",
        None,
        request_id,
    )
}

fn owned_response_from_record(
    record: LinkRecord,
    public_base_url: &Url,
    tags: Vec<String>,
) -> OwnedLinkResponse {
    OwnedLinkResponse {
        id: record.id(),
        slug: record.slug().as_str().to_owned(),
        short_url: short_url(public_base_url, record.slug()).to_string(),
        target_url: record.target_url().to_owned(),
        title: record.title().map(str::to_owned),
        kind: record.kind(),
        status: record.status(),
        blocked_reason: record.blocked_reason().map(str::to_owned),
        blocked_at: record.blocked_at(),
        blocked_by: record.blocked_by().map(str::to_owned),
        expires_at: record.expires_at(),
        created_at: record.created_at(),
        updated_at: record.updated_at(),
        redirect_count: record.redirect_count(),
        tags,
    }
}

fn response_from_record(
    record: LinkRecord,
    short_url: Url,
    tags: Vec<String>,
) -> CreateLinkResponse {
    CreateLinkResponse {
        id: record.id(),
        owner_id: record.owner_id(),
        slug: record.slug().as_str().to_owned(),
        short_url: short_url.to_string(),
        target_url: record.target_url().to_owned(),
        title: record.title().map(str::to_owned),
        kind: record.kind(),
        status: record.status(),
        expires_at: record.expires_at(),
        created_at: record.created_at(),
        tags,
    }
}

const fn default_link_kind() -> LinkKind {
    LinkKind::Direct
}

fn short_url(public_base_url: &Url, slug: &Slug) -> Url {
    let mut url = public_base_url.clone();
    url.set_path(&format!("/{}", slug.as_str()));
    url.set_query(None);
    url.set_fragment(None);
    url
}

fn password_page_url(public_base_url: &Url, slug: &Slug) -> Url {
    let mut url = public_base_url.clone();
    url.set_path(&format!("/app/password/{}", slug.as_str()));
    url.set_query(None);
    url.set_fragment(None);
    url
}

fn advertising_page_url(public_base_url: &Url, slug: &Slug) -> Url {
    let mut url = public_base_url.clone();
    url.set_path(&format!("/app/advertising/{}", slug.as_str()));
    url.set_query(None);
    url.set_fragment(None);
    url
}

fn accepts_html(headers: &HeaderMap) -> bool {
    headers
        .get(header::ACCEPT)
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| {
            value
                .split(',')
                .any(|media_range| media_range.trim_start().starts_with("text/html"))
        })
}

fn error_page_redirect(
    public_base_url: &Url,
    path: &str,
) -> (StatusCode, [(header::HeaderName, HeaderValue); 2]) {
    let mut url = public_base_url.clone();
    url.set_path(path);
    url.set_query(None);
    url.set_fragment(None);
    let location = HeaderValue::from_str(url.as_str())
        .expect("validated public URL and static error path must form a valid Location header");
    (
        StatusCode::TEMPORARY_REDIRECT,
        [
            (header::LOCATION, location),
            (header::CACHE_CONTROL, HeaderValue::from_static("no-store")),
        ],
    )
}

fn password_ticket_url(public_base_url: &Url, ticket_id: Uuid) -> Url {
    let mut url = public_base_url.clone();
    url.set_path(&format!("/api/v1/password-links/tickets/{ticket_id}"));
    url.set_query(None);
    url.set_fragment(None);
    url
}

fn advertising_ticket_url(public_base_url: &Url, ticket_id: Uuid) -> Url {
    let mut url = public_base_url.clone();
    url.set_path(&format!("/api/v1/advertising-links/tickets/{ticket_id}"));
    url.set_query(None);
    url.set_fragment(None);
    url
}

fn target_url_error(error: TargetUrlError, request_id: &RequestId) -> ApiError {
    let (code, message) = match error {
        TargetUrlError::LinkSoUrlNotAllowed => (
            "linkso_target_not_allowed",
            "A LinkSo URL cannot be used as the target",
        ),
        TargetUrlError::DangerousHostNotAllowed => (
            "dangerous_target_not_allowed",
            "Local and non-public target hosts are not allowed",
        ),
        _ => ("invalid_target_url", "The target URL is invalid"),
    };
    ApiError::invalid_request(code, message, Some("target_url"), request_id)
}

fn slug_error(error: SlugError, request_id: &RequestId) -> ApiError {
    let (code, message) = match error {
        SlugError::Reserved => ("reserved_slug", "The requested slug is reserved"),
        _ => ("invalid_slug", "The requested slug is invalid"),
    };
    ApiError::invalid_request(code, message, Some("slug"), request_id)
}

fn tag_error(error: LinkTagError, request_id: &RequestId) -> ApiError {
    let (code, message) = match error {
        LinkTagError::TooMany => ("too_many_tags", "A link can have at most 10 tags"),
        LinkTagError::Empty | LinkTagError::TooLong | LinkTagError::InvalidCharacter => {
            ("invalid_tag", "A tag name is invalid")
        }
    };
    ApiError::invalid_request(code, message, Some("tags"), request_id)
}

fn create_link_error(error: CreateLinkError, request_id: &RequestId) -> ApiError {
    match error {
        CreateLinkError::TitleTooLong => ApiError::invalid_request(
            "invalid_title",
            "The title is too long",
            Some("title"),
            request_id,
        ),
        CreateLinkError::ExpirationNotFuture => ApiError::invalid_request(
            "invalid_expiration",
            "The expiration must be in the future",
            Some("expires_at"),
            request_id,
        ),
    }
}

fn password_required_error(request_id: &RequestId) -> ApiError {
    ApiError::invalid_request(
        "password_required",
        "A password is required for this link type",
        Some("password"),
        request_id,
    )
}

fn password_error(error: LinkPasswordError, request_id: &RequestId) -> ApiError {
    let message = match error {
        LinkPasswordError::TooShort => "The password must contain at least 8 characters",
        LinkPasswordError::TooLong => "The password must not exceed 128 characters",
    };
    ApiError::invalid_request("invalid_password", message, Some("password"), request_id)
}

fn reject_unexpected_password(
    password: Option<String>,
    request_id: &RequestId,
) -> Result<(), ApiError> {
    if password.is_some() {
        return Err(ApiError::invalid_request(
            "invalid_password",
            "A password is only allowed for password links",
            Some("password"),
            request_id,
        ));
    }
    Ok(())
}

fn require_administrator(
    state: &LinksState,
    headers: &HeaderMap,
    request_id: &RequestId,
) -> Result<(), ApiError> {
    let authorization = headers
        .get(header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok());
    state
        .admin_token
        .authenticate_bearer(authorization)
        .ok_or_else(|| ApiError::admin_authentication_required(request_id))?;
    Ok(())
}

fn moderation_error(error: LinkModerationError, request_id: &RequestId) -> ApiError {
    tracing::error!(%error, "link moderation operation failed");
    ApiError::internal(request_id)
}

fn repository_error(error: LinkRepositoryError, request_id: &RequestId) -> ApiError {
    match error {
        LinkRepositoryError::SlugTaken => ApiError::conflict(
            "slug_taken",
            "The requested slug is already in use",
            Some("slug"),
            request_id,
        ),
        error => {
            tracing::error!(%error, "link repository operation failed");
            ApiError::internal(request_id)
        }
    }
}

fn lookup_error(error: LinkRepositoryError, request_id: &RequestId) -> ApiError {
    tracing::error!(%error, "failed to resolve a public link");
    ApiError::internal(request_id)
}

fn password_flow_error(error: PasswordFlowError, request_id: &RequestId) -> ApiError {
    match error {
        PasswordFlowError::SessionUnavailable => ApiError::not_found(request_id),
        error => {
            tracing::error!(%error, "password flow operation failed");
            ApiError::internal(request_id)
        }
    }
}

fn advertising_flow_error(error: AdvertisingFlowError, request_id: &RequestId) -> ApiError {
    match error {
        AdvertisingFlowError::SessionUnavailable => ApiError::not_found(request_id),
        error => {
            tracing::error!(%error, "advertising flow operation failed");
            ApiError::internal(request_id)
        }
    }
}

#[cfg(test)]
mod tests {
    use std::net::{IpAddr, Ipv4Addr, SocketAddr};

    use axum::http::{HeaderMap, HeaderValue};
    use url::Url;

    use crate::links::Slug;

    use super::{creation_client_ip, short_url};

    #[test]
    fn short_url_uses_public_origin_and_clears_query_and_fragment() {
        let base = Url::parse("https://linkso.su/app?old=true#fragment").unwrap();
        let slug = Slug::parse("a8F3kd2Q").unwrap();

        assert_eq!(
            short_url(&base, &slug).as_str(),
            "https://linkso.su/a8F3kd2Q"
        );
    }

    #[test]
    fn forwarded_ip_is_used_only_for_a_trusted_reverse_proxy() {
        let mut headers = HeaderMap::new();
        headers.insert(
            "x-forwarded-for",
            HeaderValue::from_static("203.0.113.10, 127.0.0.1"),
        );

        assert_eq!(
            creation_client_ip(
                &headers,
                Some(SocketAddr::from((Ipv4Addr::LOCALHOST, 54321)))
            ),
            "203.0.113.10".parse::<IpAddr>().unwrap()
        );
        assert_eq!(
            creation_client_ip(
                &headers,
                Some(SocketAddr::from((Ipv4Addr::new(172, 20, 0, 2), 54321)))
            ),
            "203.0.113.10".parse::<IpAddr>().unwrap()
        );
        assert_eq!(
            creation_client_ip(
                &headers,
                Some(SocketAddr::from((Ipv4Addr::new(198, 51, 100, 4), 54321)))
            ),
            "198.51.100.4".parse::<IpAddr>().unwrap()
        );
    }
}
