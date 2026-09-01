use axum::{
    Extension, Json, Router,
    extract::{Path, State, rejection::JsonRejection},
    http::{HeaderMap, HeaderValue, StatusCode, header},
    response::IntoResponse,
    routing::{delete, get, post, put},
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use super::mail::{MailKind, MailService};
use crate::{api_error::ApiError, request_id::RequestId};

use super::{
    AccountRepository, AccountRepositoryError, AuthRateLimitKind, AuthRepository,
    AuthRepositoryError, AuthTokenCodec, Email, EmailError, RegisterUser, SUPPORTED_TIMEZONES,
    SettingsError, SettingsRepository, UserPassword, UserPasswordError, UserRecord, UserSession,
    UserStatus, hash_user_password, verify_user_password,
};

pub const SESSION_COOKIE_NAME: &str = "linkso_session";
const SESSION_MAX_AGE_SECONDS: i64 = 30 * 24 * 60 * 60;

#[derive(Clone)]
pub struct AuthHttpConfig {
    tokens: AuthTokenCodec,
    cookie_secure: bool,
    expose_development_tokens: bool,
    mail: Option<MailService>,
}

impl AuthHttpConfig {
    pub fn new(
        session_secret: impl AsRef<[u8]>,
        cookie_secure: bool,
        expose_development_tokens: bool,
    ) -> Result<Self, super::AuthTokenCodecError> {
        Ok(Self {
            tokens: AuthTokenCodec::new(session_secret)?,
            cookie_secure,
            expose_development_tokens,
            mail: None,
        })
    }

    pub fn local_test_default() -> Self {
        Self::new(
            "linkso local auth test secret with at least 32 bytes",
            false,
            true,
        )
        .expect("static local auth configuration must be valid")
    }

    pub fn token_codec(&self) -> AuthTokenCodec {
        self.tokens.clone()
    }

    pub fn with_mail(mut self, mail: MailService) -> Self {
        self.mail = Some(mail);
        self.expose_development_tokens = false;
        self
    }
}

#[derive(Clone)]
struct AccountState {
    accounts: AccountRepository,
    auth: AuthRepository,
    settings: SettingsRepository,
    config: AuthHttpConfig,
}

pub fn routes(pool: PgPool, config: AuthHttpConfig) -> Router {
    let token_codec = config.token_codec();
    let state = AccountState {
        accounts: AccountRepository::new(pool.clone()),
        auth: AuthRepository::new(pool.clone(), token_codec.clone()),
        settings: SettingsRepository::new(pool, token_codec),
        config,
    };
    Router::new()
        .route("/api/v1/auth/register", post(register))
        .route("/api/v1/auth/verify-email", post(verify_email))
        .route(
            "/api/v1/auth/verification-resend",
            post(resend_verification),
        )
        .route("/api/v1/auth/login", post(login))
        .route("/api/v1/mobile/auth/login", post(mobile_login))
        .route("/api/v1/auth/session", get(current_session))
        .route(
            "/api/v1/me/profile",
            get(profile).put(update_profile).delete(delete_account),
        )
        .route("/api/v1/me/preferences", put(update_preferences))
        .route("/api/v1/me/email-change", post(request_email_change))
        .route(
            "/api/v1/me/email-change/confirm",
            post(confirm_email_change),
        )
        .route("/api/v1/me/password", put(change_password))
        .route("/api/v1/me/sessions", get(active_sessions))
        .route("/api/v1/me/sessions/{id}", delete(revoke_active_session))
        .route("/api/v1/auth/logout", post(logout))
        .route("/api/v1/auth/logout-all", post(logout_all))
        .route("/api/v1/auth/password-reset", post(request_password_reset))
        .route(
            "/api/v1/auth/password-reset/confirm",
            post(confirm_password_reset),
        )
        .with_state(state)
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct RegisterRequest {
    email: String,
    password: String,
}

#[derive(Debug, Serialize)]
struct RegisterResponse {
    user: UserResponse,
    #[serde(skip_serializing_if = "Option::is_none")]
    development_verification_token: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct TokenRequest {
    token: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct LoginRequest {
    email: String,
    password: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct PasswordResetRequest {
    email: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct ConfirmPasswordResetRequest {
    token: String,
    password: String,
}

#[derive(Debug, Serialize)]
struct UserResponse {
    id: Uuid,
    email: String,
    status: UserStatus,
    email_verified: bool,
    created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
struct MobileLoginResponse {
    user: UserResponse,
    session_token: String,
    expires_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
struct PasswordResetResponse {
    accepted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    development_reset_token: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct UpdateProfileRequest {
    display_name: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct UpdatePreferencesRequest {
    timezone: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct EmailChangeRequest {
    email: String,
    current_password: String,
}

#[derive(Debug, Serialize)]
struct EmailChangeResponse {
    accepted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    development_confirmation_token: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct EmailChangeConfirmRequest {
    token: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct ChangePasswordRequest {
    current_password: String,
    new_password: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct DeleteAccountRequest {
    current_password: String,
    confirmation: String,
}

async fn register(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    payload: Result<Json<RegisterRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let Json(payload) = parse_json(payload, "registration", &request_id)?;
    let email = Email::parse(payload.email).map_err(|error| email_error(error, &request_id))?;
    let password = UserPassword::parse(payload.password)
        .map_err(|error| password_error(error, &request_id))?;
    limit_email_request(&state, AuthRateLimitKind::Verification, &email, &request_id).await?;
    let password_hash = hash_user_password(password).await.map_err(|error| {
        tracing::error!(%error, "failed to hash account password");
        ApiError::internal(&request_id)
    })?;
    let record = state
        .accounts
        .register(RegisterUser::new(email, password_hash))
        .await
        .map_err(|error| account_repository_error(error, &request_id))?;
    let verification = state
        .auth
        .issue_email_verification(record.id())
        .await
        .map_err(|error| auth_repository_error(error, &request_id))?;
    enqueue_email(
        &state,
        MailKind::Verification,
        record.email(),
        verification.raw(),
        &request_id,
    )?;
    let development_verification_token = state
        .config
        .expose_development_tokens
        .then(|| verification.raw().to_owned());

    Ok((
        StatusCode::CREATED,
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(RegisterResponse {
            user: UserResponse::from(record),
            development_verification_token,
        }),
    ))
}

async fn resend_verification(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    payload: Result<Json<PasswordResetRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let Json(payload) = parse_json(payload, "verification resend", &request_id)?;
    let email = Email::parse(payload.email).map_err(|error| email_error(error, &request_id))?;
    limit_email_request(&state, AuthRateLimitKind::Verification, &email, &request_id).await?;
    if let Some(credentials) = state
        .auth
        .credentials_by_email(&email)
        .await
        .map_err(|error| auth_repository_error(error, &request_id))?
        && credentials.user.status() == UserStatus::Pending
    {
        let token = state
            .auth
            .issue_email_verification(credentials.user.id())
            .await
            .map_err(|error| auth_repository_error(error, &request_id))?;
        // Never reveal account existence through SMTP availability or response fields.
        let _ = enqueue_email(
            &state,
            MailKind::Verification,
            email.as_str(),
            token.raw(),
            &request_id,
        );
    }
    Ok((
        StatusCode::ACCEPTED,
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(PasswordResetResponse {
            accepted: true,
            development_reset_token: None,
        }),
    ))
}

async fn limit_email_request(
    state: &AccountState,
    kind: AuthRateLimitKind,
    email: &Email,
    request_id: &RequestId,
) -> Result<(), ApiError> {
    if let Some(retry) = state
        .auth
        .register_auth_attempt(kind, email)
        .await
        .map_err(|error| auth_repository_error(error, request_id))?
    {
        return Err(ApiError::too_many_requests_for_field(
            "email_temporarily_limited",
            "Too many email requests",
            Some("email"),
            retry,
            request_id,
        ));
    }
    Ok(())
}

fn enqueue_email(
    state: &AccountState,
    kind: MailKind,
    recipient: &str,
    token: &str,
    request_id: &RequestId,
) -> Result<(), ApiError> {
    if let Some(mail) = &state.config.mail {
        mail.enqueue(kind, recipient, token).map_err(|_| {
            tracing::error!(
                ?kind,
                "email could not be queued; user can request a new message"
            );
            ApiError::service_unavailable(request_id)
        })?;
    }
    Ok(())
}

async fn verify_email(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    payload: Result<Json<TokenRequest>, JsonRejection>,
) -> Result<Json<UserResponse>, ApiError> {
    let Json(payload) = parse_json(payload, "email verification", &request_id)?;
    let user = state
        .auth
        .verify_email(&payload.token)
        .await
        .map_err(|error| auth_repository_error(error, &request_id))?
        .ok_or_else(|| invalid_token("verification_token_invalid", &request_id))?;
    Ok(Json(UserResponse::from(user)))
}

async fn login(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    payload: Result<Json<LoginRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let Json(payload) = parse_json(payload, "login", &request_id)?;
    let (user, session) = authenticate_login(&state, payload, &request_id).await?;
    let cookie = session_cookie(&session.token, state.config.cookie_secure, &request_id)?;
    Ok((
        StatusCode::OK,
        [
            (header::SET_COOKIE, cookie),
            (header::CACHE_CONTROL, HeaderValue::from_static("no-store")),
        ],
        Json(UserResponse::from(user)),
    ))
}

async fn mobile_login(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    payload: Result<Json<LoginRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let Json(payload) = parse_json(payload, "mobile login", &request_id)?;
    let (user, session) = authenticate_login(&state, payload, &request_id).await?;
    Ok((
        StatusCode::OK,
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(MobileLoginResponse {
            user: UserResponse::from(user),
            session_token: session.token,
            expires_at: session.expires_at,
        }),
    ))
}

async fn authenticate_login(
    state: &AccountState,
    payload: LoginRequest,
    request_id: &RequestId,
) -> Result<(UserRecord, UserSession), ApiError> {
    let email = Email::parse(payload.email).map_err(|_| invalid_credentials(request_id))?;
    if let Some(retry_after_seconds) = state
        .auth
        .register_auth_attempt(AuthRateLimitKind::Login, &email)
        .await
        .map_err(|error| auth_repository_error(error, request_id))?
    {
        return Err(ApiError::too_many_requests_for_field(
            "login_temporarily_limited",
            "Too many login attempts",
            Some("email"),
            retry_after_seconds,
            request_id,
        ));
    }
    let password =
        UserPassword::parse(payload.password).map_err(|_| invalid_credentials(request_id))?;
    let credentials = state
        .auth
        .credentials_by_email(&email)
        .await
        .map_err(|error| auth_repository_error(error, request_id))?
        .ok_or_else(|| invalid_credentials(request_id))?;
    if !verify_user_password(password, credentials.password_hash)
        .await
        .map_err(|error| {
            tracing::error!(%error, "failed to verify account password");
            ApiError::internal(request_id)
        })?
    {
        return Err(invalid_credentials(request_id));
    }
    if credentials.user.status() != UserStatus::Active {
        return Err(ApiError::forbidden(
            "email_not_verified",
            "The email address must be verified before login",
            Some("email"),
            request_id,
        ));
    }
    let session = state
        .auth
        .create_session(credentials.user.id())
        .await
        .map_err(|error| auth_repository_error(error, request_id))?;
    state
        .auth
        .clear_auth_attempts(AuthRateLimitKind::Login, &email)
        .await
        .map_err(|error| auth_repository_error(error, request_id))?;
    Ok((credentials.user, session))
}

async fn current_session(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, ApiError> {
    let user = authenticated_user(&state, &headers, &request_id).await?;
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(UserResponse::from(user)),
    ))
}

async fn profile(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, ApiError> {
    let user = authenticated_user(&state, &headers, &request_id).await?;
    let profile = state
        .settings
        .profile(user.id())
        .await
        .map_err(|error| settings_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(profile),
    ))
}

async fn update_profile(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    payload: Result<Json<UpdateProfileRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let user = authenticated_user(&state, &headers, &request_id).await?;
    let Json(payload) = parse_json(payload, "profile update", &request_id)?;
    let display_name = parse_display_name(payload.display_name, &request_id)?;
    let profile = state
        .settings
        .update_display_name(user.id(), display_name.as_deref())
        .await
        .map_err(|error| settings_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(profile),
    ))
}

async fn update_preferences(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    payload: Result<Json<UpdatePreferencesRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let user = authenticated_user(&state, &headers, &request_id).await?;
    let Json(payload) = parse_json(payload, "preferences update", &request_id)?;
    if !SUPPORTED_TIMEZONES.contains(&payload.timezone.as_str()) {
        return Err(ApiError::invalid_request(
            "invalid_preferences",
            "The account preferences are invalid",
            None,
            &request_id,
        ));
    }
    let profile = state
        .settings
        .update_timezone(user.id(), &payload.timezone)
        .await
        .map_err(|error| settings_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(profile),
    ))
}

async fn request_email_change(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    payload: Result<Json<EmailChangeRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let user = authenticated_user(&state, &headers, &request_id).await?;
    let Json(payload) = parse_json(payload, "email change", &request_id)?;
    verify_current_password(&state, user.id(), payload.current_password, &request_id).await?;
    let email = Email::parse(payload.email).map_err(|error| email_error(error, &request_id))?;
    let current_email = Email::parse(user.email()).map_err(|_| ApiError::internal(&request_id))?;
    limit_email_request(
        &state,
        AuthRateLimitKind::EmailChange,
        &current_email,
        &request_id,
    )
    .await?;
    if email.as_str() == user.email() {
        return Err(ApiError::invalid_request(
            "email_unchanged",
            "The new email address must be different",
            Some("email"),
            &request_id,
        ));
    }
    let token = state
        .settings
        .issue_email_change(user.id(), &email)
        .await
        .map_err(|error| settings_error(error, &request_id))?;
    enqueue_email(
        &state,
        MailKind::EmailChange,
        email.as_str(),
        token.raw(),
        &request_id,
    )?;
    Ok((
        StatusCode::ACCEPTED,
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(EmailChangeResponse {
            accepted: true,
            development_confirmation_token: state
                .config
                .expose_development_tokens
                .then(|| token.raw().to_owned()),
        }),
    ))
}

async fn confirm_email_change(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    payload: Result<Json<EmailChangeConfirmRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let (user, session) = authenticated_user_and_token(&state, &headers, &request_id).await?;
    let Json(payload) = parse_json(payload, "email change confirmation", &request_id)?;
    let profile = state
        .settings
        .confirm_email_change(user.id(), &payload.token, session)
        .await
        .map_err(|error| settings_error(error, &request_id))?
        .ok_or_else(|| invalid_token("email_change_token_invalid", &request_id))?;
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(profile),
    ))
}

async fn change_password(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    payload: Result<Json<ChangePasswordRequest>, JsonRejection>,
) -> Result<StatusCode, ApiError> {
    let (user, session) = authenticated_user_and_token(&state, &headers, &request_id).await?;
    let Json(payload) = parse_json(payload, "password change", &request_id)?;
    verify_current_password(&state, user.id(), payload.current_password, &request_id).await?;
    let new_password = UserPassword::parse(payload.new_password)
        .map_err(|error| new_password_error(error, &request_id))?;
    let password_hash = hash_user_password(new_password).await.map_err(|error| {
        tracing::error!(%error, "failed to hash changed account password");
        ApiError::internal(&request_id)
    })?;
    if !state
        .settings
        .change_password(user.id(), &password_hash, session)
        .await
        .map_err(|error| settings_error(error, &request_id))?
    {
        return Err(ApiError::not_found(&request_id));
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn active_sessions(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, ApiError> {
    let (user, session) = authenticated_user_and_token(&state, &headers, &request_id).await?;
    let sessions = state
        .settings
        .active_sessions(user.id(), session)
        .await
        .map_err(|error| settings_error(error, &request_id))?;
    Ok((
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(sessions),
    ))
}

async fn revoke_active_session(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    Path(raw_id): Path<String>,
) -> Result<StatusCode, ApiError> {
    let (user, session) = authenticated_user_and_token(&state, &headers, &request_id).await?;
    let session_id = Uuid::parse_str(&raw_id).map_err(|_| ApiError::not_found(&request_id))?;
    let is_current = state
        .settings
        .revoke_session(user.id(), session_id, session)
        .await
        .map_err(|error| settings_error(error, &request_id))?
        .ok_or_else(|| ApiError::not_found(&request_id))?;
    if is_current {
        return Err(ApiError::conflict(
            "current_session",
            "The current session must be closed with logout",
            None,
            &request_id,
        ));
    }
    Ok(StatusCode::NO_CONTENT)
}

async fn delete_account(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
    payload: Result<Json<DeleteAccountRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let user = authenticated_user(&state, &headers, &request_id).await?;
    let Json(payload) = parse_json(payload, "account deletion", &request_id)?;
    if payload.confirmation != "DELETE" {
        return Err(ApiError::invalid_request(
            "deletion_confirmation_invalid",
            "Type DELETE to confirm account deletion",
            Some("confirmation"),
            &request_id,
        ));
    }
    verify_current_password(&state, user.id(), payload.current_password, &request_id).await?;
    if !state
        .settings
        .delete_account(user.id())
        .await
        .map_err(|error| settings_error(error, &request_id))?
    {
        return Err(ApiError::not_found(&request_id));
    }
    Ok((
        StatusCode::NO_CONTENT,
        [(
            header::SET_COOKIE,
            clear_session_cookie(state.config.cookie_secure, &request_id)?,
        )],
    ))
}

async fn logout(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, ApiError> {
    if let Some(token) = session_token(&headers) {
        state
            .auth
            .revoke_session(token)
            .await
            .map_err(|error| auth_repository_error(error, &request_id))?;
    }
    Ok((
        StatusCode::NO_CONTENT,
        [(
            header::SET_COOKIE,
            clear_session_cookie(state.config.cookie_secure, &request_id)?,
        )],
    ))
}

async fn logout_all(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, ApiError> {
    let token = session_token(&headers).ok_or_else(|| authentication_required(&request_id))?;
    let user = state
        .auth
        .authenticate_session(token)
        .await
        .map_err(|error| auth_repository_error(error, &request_id))?
        .ok_or_else(|| authentication_required(&request_id))?;
    state
        .auth
        .revoke_all_sessions(user.id())
        .await
        .map_err(|error| auth_repository_error(error, &request_id))?;
    Ok((
        StatusCode::NO_CONTENT,
        [(
            header::SET_COOKIE,
            clear_session_cookie(state.config.cookie_secure, &request_id)?,
        )],
    ))
}

async fn request_password_reset(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    payload: Result<Json<PasswordResetRequest>, JsonRejection>,
) -> Result<impl IntoResponse, ApiError> {
    let Json(payload) = parse_json(payload, "password reset", &request_id)?;
    let email = Email::parse(payload.email).map_err(|error| email_error(error, &request_id))?;
    if let Some(retry_after_seconds) = state
        .auth
        .register_auth_attempt(AuthRateLimitKind::PasswordReset, &email)
        .await
        .map_err(|error| auth_repository_error(error, &request_id))?
    {
        return Err(ApiError::too_many_requests_for_field(
            "password_reset_temporarily_limited",
            "Too many password reset requests",
            Some("email"),
            retry_after_seconds,
            &request_id,
        ));
    }
    let token = match state
        .auth
        .credentials_by_email(&email)
        .await
        .map_err(|error| auth_repository_error(error, &request_id))?
    {
        Some(credentials) if credentials.user.status() == UserStatus::Active => Some(
            state
                .auth
                .issue_password_reset(credentials.user.id())
                .await
                .map_err(|error| auth_repository_error(error, &request_id))?,
        ),
        _ => None,
    };
    if let Some(token) = &token {
        // Background SMTP retries must not affect the reset response or its latency.
        let _ = enqueue_email(
            &state,
            MailKind::PasswordReset,
            email.as_str(),
            token.raw(),
            &request_id,
        );
    }
    let development_reset_token = if state.config.expose_development_tokens {
        token.map(|token| token.raw().to_owned())
    } else {
        None
    };
    Ok((
        StatusCode::ACCEPTED,
        [(header::CACHE_CONTROL, HeaderValue::from_static("no-store"))],
        Json(PasswordResetResponse {
            accepted: true,
            development_reset_token,
        }),
    ))
}

async fn confirm_password_reset(
    State(state): State<AccountState>,
    Extension(request_id): Extension<RequestId>,
    payload: Result<Json<ConfirmPasswordResetRequest>, JsonRejection>,
) -> Result<StatusCode, ApiError> {
    let Json(payload) = parse_json(payload, "password reset confirmation", &request_id)?;
    let password = UserPassword::parse(payload.password)
        .map_err(|error| password_error(error, &request_id))?;
    let password_hash = hash_user_password(password).await.map_err(|error| {
        tracing::error!(%error, "failed to hash reset account password");
        ApiError::internal(&request_id)
    })?;
    let reset = state
        .auth
        .reset_password(&payload.token, password_hash)
        .await
        .map_err(|error| auth_repository_error(error, &request_id))?;
    if !reset {
        return Err(invalid_token("password_reset_token_invalid", &request_id));
    }
    Ok(StatusCode::NO_CONTENT)
}

impl From<UserRecord> for UserResponse {
    fn from(record: UserRecord) -> Self {
        Self {
            id: record.id(),
            email: record.email().to_owned(),
            status: record.status(),
            email_verified: record.email_verified_at().is_some(),
            created_at: record.created_at(),
        }
    }
}

async fn authenticated_user(
    state: &AccountState,
    headers: &HeaderMap,
    request_id: &RequestId,
) -> Result<UserRecord, ApiError> {
    let token = session_token(headers).ok_or_else(|| authentication_required(request_id))?;
    state
        .auth
        .authenticate_session(token)
        .await
        .map_err(|error| auth_repository_error(error, request_id))?
        .ok_or_else(|| authentication_required(request_id))
}

async fn authenticated_user_and_token<'a>(
    state: &AccountState,
    headers: &'a HeaderMap,
    request_id: &RequestId,
) -> Result<(UserRecord, &'a str), ApiError> {
    let token = session_token(headers).ok_or_else(|| authentication_required(request_id))?;
    let user = state
        .auth
        .authenticate_session(token)
        .await
        .map_err(|error| auth_repository_error(error, request_id))?
        .ok_or_else(|| authentication_required(request_id))?;
    Ok((user, token))
}

async fn verify_current_password(
    state: &AccountState,
    user_id: Uuid,
    raw_password: String,
    request_id: &RequestId,
) -> Result<(), ApiError> {
    let password =
        UserPassword::parse(raw_password).map_err(|_| current_password_invalid(request_id))?;
    let credentials = state
        .auth
        .credentials_by_user_id(user_id)
        .await
        .map_err(|error| auth_repository_error(error, request_id))?
        .ok_or_else(|| authentication_required(request_id))?;
    let is_valid = verify_user_password(password, credentials.password_hash)
        .await
        .map_err(|error| {
            tracing::error!(%error, "failed to verify current account password");
            ApiError::internal(request_id)
        })?;
    if !is_valid {
        return Err(current_password_invalid(request_id));
    }
    Ok(())
}

fn parse_display_name(
    value: Option<String>,
    request_id: &RequestId,
) -> Result<Option<String>, ApiError> {
    let value = value.map(|value| value.trim().to_owned());
    if value.as_ref().is_some_and(|value| {
        value.is_empty() || value.chars().count() > 120 || value.chars().any(char::is_control)
    }) {
        return Err(ApiError::invalid_request(
            "invalid_display_name",
            "The display name must contain 1 to 120 characters",
            Some("display_name"),
            request_id,
        ));
    }
    Ok(value)
}

fn parse_json<T>(
    payload: Result<Json<T>, JsonRejection>,
    context: &'static str,
    request_id: &RequestId,
) -> Result<Json<T>, ApiError> {
    payload.map_err(|_| {
        tracing::debug!(context, "invalid authentication JSON payload");
        ApiError::invalid_request(
            "invalid_json",
            "The request body must be valid authentication JSON",
            None,
            request_id,
        )
    })
}

fn email_error(_error: EmailError, request_id: &RequestId) -> ApiError {
    ApiError::invalid_request(
        "invalid_email",
        "The email address is invalid",
        Some("email"),
        request_id,
    )
}

fn password_error(error: UserPasswordError, request_id: &RequestId) -> ApiError {
    let message = match error {
        UserPasswordError::TooShort => "The password must contain at least 12 characters",
        UserPasswordError::TooLong => "The password must not exceed 128 characters",
        UserPasswordError::ControlCharactersNotAllowed => {
            "The password must not contain control characters"
        }
    };
    ApiError::invalid_request("invalid_password", message, Some("password"), request_id)
}

fn new_password_error(error: UserPasswordError, request_id: &RequestId) -> ApiError {
    let message = match error {
        UserPasswordError::TooShort => "The new password must contain at least 12 characters",
        UserPasswordError::TooLong => "The new password must not exceed 128 characters",
        UserPasswordError::ControlCharactersNotAllowed => {
            "The new password must not contain control characters"
        }
    };
    ApiError::invalid_request(
        "invalid_password",
        message,
        Some("new_password"),
        request_id,
    )
}

fn current_password_invalid(request_id: &RequestId) -> ApiError {
    ApiError::unauthorized(
        "current_password_invalid",
        "The current password is incorrect",
        Some("current_password"),
        request_id,
    )
}

fn account_repository_error(error: AccountRepositoryError, request_id: &RequestId) -> ApiError {
    match error {
        AccountRepositoryError::EmailTaken => ApiError::conflict(
            "email_taken",
            "An account with this email already exists",
            Some("email"),
            request_id,
        ),
        error => {
            tracing::error!(%error, "account registration failed");
            ApiError::internal(request_id)
        }
    }
}

fn auth_repository_error(error: AuthRepositoryError, request_id: &RequestId) -> ApiError {
    tracing::error!(%error, "authentication operation failed");
    ApiError::internal(request_id)
}

fn settings_error(error: SettingsError, request_id: &RequestId) -> ApiError {
    match error {
        SettingsError::EmailTaken => ApiError::conflict(
            "email_taken",
            "An account with this email already exists",
            Some("email"),
            request_id,
        ),
        error => {
            tracing::error!(%error, "account settings operation failed");
            ApiError::internal(request_id)
        }
    }
}

fn invalid_credentials(request_id: &RequestId) -> ApiError {
    ApiError::unauthorized(
        "invalid_credentials",
        "The email or password is incorrect",
        None,
        request_id,
    )
}

fn authentication_required(request_id: &RequestId) -> ApiError {
    ApiError::unauthorized(
        "authentication_required",
        "Authentication is required",
        None,
        request_id,
    )
}

fn invalid_token(code: &'static str, request_id: &RequestId) -> ApiError {
    ApiError::invalid_request(
        code,
        "The authentication token is invalid or expired",
        Some("token"),
        request_id,
    )
}

pub fn session_token(headers: &HeaderMap) -> Option<&str> {
    bearer_session_token(headers).or_else(|| cookie_session_token(headers))
}

fn bearer_session_token(headers: &HeaderMap) -> Option<&str> {
    headers
        .get(header::AUTHORIZATION)?
        .to_str()
        .ok()?
        .strip_prefix("Bearer ")
        .filter(|value| !value.is_empty() && !value.chars().any(char::is_whitespace))
}

fn cookie_session_token(headers: &HeaderMap) -> Option<&str> {
    headers
        .get(header::COOKIE)?
        .to_str()
        .ok()?
        .split(';')
        .filter_map(|pair| pair.trim().split_once('='))
        .find_map(|(name, value)| (name == SESSION_COOKIE_NAME).then_some(value))
        .filter(|value| !value.is_empty())
}

fn session_cookie(
    token: &str,
    secure: bool,
    request_id: &RequestId,
) -> Result<HeaderValue, ApiError> {
    let secure_attribute = if secure { "; Secure" } else { "" };
    HeaderValue::from_str(&format!(
        "{SESSION_COOKIE_NAME}={token}; Path=/; Max-Age={SESSION_MAX_AGE_SECONDS}; HttpOnly; SameSite=Lax{secure_attribute}"
    ))
    .map_err(|_| ApiError::internal(request_id))
}

fn clear_session_cookie(secure: bool, request_id: &RequestId) -> Result<HeaderValue, ApiError> {
    let secure_attribute = if secure { "; Secure" } else { "" };
    HeaderValue::from_str(&format!(
        "{SESSION_COOKIE_NAME}=; Path=/; Max-Age=0; HttpOnly; SameSite=Lax{secure_attribute}"
    ))
    .map_err(|_| ApiError::internal(request_id))
}

#[cfg(test)]
mod tests {
    use axum::http::{HeaderMap, HeaderValue, header};

    use super::session_token;

    #[test]
    fn bearer_session_takes_precedence_over_the_web_cookie() {
        let mut headers = HeaderMap::new();
        headers.insert(
            header::AUTHORIZATION,
            HeaderValue::from_static("Bearer native-session"),
        );
        headers.insert(
            header::COOKIE,
            HeaderValue::from_static("linkso_session=web-session"),
        );

        assert_eq!(session_token(&headers), Some("native-session"));
    }

    #[test]
    fn malformed_bearer_falls_back_to_the_web_cookie() {
        let mut headers = HeaderMap::new();
        headers.insert(
            header::AUTHORIZATION,
            HeaderValue::from_static("Bearer invalid session"),
        );
        headers.insert(
            header::COOKIE,
            HeaderValue::from_static("linkso_session=web-session"),
        );

        assert_eq!(session_token(&headers), Some("web-session"));
    }
}
