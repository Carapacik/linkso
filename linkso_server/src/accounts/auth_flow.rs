use std::{error::Error, fmt};

use chrono::{DateTime, Duration, Utc};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use super::{
    AuthToken, AuthTokenCodec, AuthTokenCodecError, CorruptUserRecord, Email, UserPasswordHash,
    UserRecord,
};

pub const EMAIL_VERIFICATION_LIFETIME_HOURS: i64 = 24;
pub const PASSWORD_RESET_LIFETIME_MINUTES: i64 = 30;
pub const USER_SESSION_LIFETIME_DAYS: i64 = 30;

const VERIFICATION_PURPOSE: &str = "email-verification";
const RESET_PURPOSE: &str = "password-reset";
const SESSION_PURPOSE: &str = "user-session";

#[derive(Clone)]
pub struct AuthRepository {
    pool: PgPool,
    tokens: AuthTokenCodec,
}

impl AuthRepository {
    pub fn new(pool: PgPool, tokens: AuthTokenCodec) -> Self {
        Self { pool, tokens }
    }

    pub async fn credentials_by_email(
        &self,
        email: &Email,
    ) -> Result<Option<AccountCredentials>, AuthRepositoryError> {
        let row = sqlx::query_as::<_, CredentialRow>(
            r#"
            SELECT id, email, password_hash, status, email_verified_at, created_at
            FROM users
            WHERE email = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(email.as_str())
        .fetch_optional(&self.pool)
        .await
        .map_err(AuthRepositoryError::database)?;
        row.map(AccountCredentials::try_from)
            .transpose()
            .map_err(AuthRepositoryError::CorruptData)
    }

    pub async fn credentials_by_user_id(
        &self,
        user_id: Uuid,
    ) -> Result<Option<AccountCredentials>, AuthRepositoryError> {
        let row = sqlx::query_as::<_, CredentialRow>(
            r#"
            SELECT id, email, password_hash, status, email_verified_at, created_at
            FROM users
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(AuthRepositoryError::database)?;
        row.map(AccountCredentials::try_from)
            .transpose()
            .map_err(AuthRepositoryError::CorruptData)
    }

    pub async fn register_auth_attempt(
        &self,
        kind: AuthRateLimitKind,
        email: &Email,
    ) -> Result<Option<u64>, AuthRepositoryError> {
        let key_hash = self
            .tokens
            .hash(kind.purpose(), email.as_str())
            .map_err(AuthRepositoryError::Token)?;
        let (maximum_attempts, window_seconds, block_seconds) = kind.limits();
        let retry_after = sqlx::query_scalar::<_, i64>(
            r#"
            INSERT INTO auth_rate_limits (kind, key_hash, attempts)
            VALUES ($1, $2, 1)
            ON CONFLICT (kind, key_hash) DO UPDATE
            SET attempts = CASE
                    WHEN auth_rate_limits.window_started_at <= NOW() - ($4 * INTERVAL '1 second')
                    THEN 1 ELSE auth_rate_limits.attempts + 1 END,
                window_started_at = CASE
                    WHEN auth_rate_limits.window_started_at <= NOW() - ($4 * INTERVAL '1 second')
                    THEN NOW() ELSE auth_rate_limits.window_started_at END,
                blocked_until = CASE
                    WHEN auth_rate_limits.blocked_until > NOW() THEN auth_rate_limits.blocked_until
                    WHEN (CASE
                        WHEN auth_rate_limits.window_started_at <= NOW() - ($4 * INTERVAL '1 second')
                        THEN 1 ELSE auth_rate_limits.attempts + 1 END) >= $3
                    THEN NOW() + ($5 * INTERVAL '1 second')
                    ELSE NULL END,
                updated_at = NOW()
            RETURNING CASE WHEN blocked_until > NOW()
                THEN CEIL(EXTRACT(EPOCH FROM (blocked_until - NOW())))::BIGINT
                ELSE 0 END
            "#,
        )
        .bind(kind.as_str())
        .bind(key_hash)
        .bind(maximum_attempts)
        .bind(window_seconds)
        .bind(block_seconds)
        .fetch_one(&self.pool)
        .await
        .map_err(AuthRepositoryError::database)?;
        Ok((retry_after > 0).then_some(retry_after as u64))
    }

    pub async fn clear_auth_attempts(
        &self,
        kind: AuthRateLimitKind,
        email: &Email,
    ) -> Result<(), AuthRepositoryError> {
        let key_hash = self
            .tokens
            .hash(kind.purpose(), email.as_str())
            .map_err(AuthRepositoryError::Token)?;
        sqlx::query("DELETE FROM auth_rate_limits WHERE kind = $1 AND key_hash = $2")
            .bind(kind.as_str())
            .bind(key_hash)
            .execute(&self.pool)
            .await
            .map_err(AuthRepositoryError::database)?;
        Ok(())
    }

    pub async fn issue_email_verification(
        &self,
        user_id: Uuid,
    ) -> Result<AuthToken, AuthRepositoryError> {
        let token = self
            .tokens
            .generate(VERIFICATION_PURPOSE)
            .map_err(AuthRepositoryError::Token)?;
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(AuthRepositoryError::database)?;
        sqlx::query("SELECT id FROM users WHERE id = $1 FOR UPDATE")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(AuthRepositoryError::database)?;
        sqlx::query(
            "DELETE FROM email_verification_tokens WHERE user_id = $1 AND consumed_at IS NULL",
        )
        .bind(user_id)
        .execute(&mut *transaction)
        .await
        .map_err(AuthRepositoryError::database)?;
        sqlx::query(
            r#"
            INSERT INTO email_verification_tokens (id, user_id, token_hash, expires_at)
            VALUES ($1, $2, $3, NOW() + INTERVAL '24 hours')
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(user_id)
        .bind(token.hash())
        .execute(&mut *transaction)
        .await
        .map_err(AuthRepositoryError::database)?;
        transaction
            .commit()
            .await
            .map_err(AuthRepositoryError::database)?;
        Ok(token)
    }

    pub async fn verify_email(
        &self,
        raw_token: &str,
    ) -> Result<Option<UserRecord>, AuthRepositoryError> {
        let token_hash = self
            .tokens
            .hash(VERIFICATION_PURPOSE, raw_token)
            .map_err(AuthRepositoryError::Token)?;
        let row = sqlx::query_as::<_, UserRow>(
            r#"
            WITH consumed AS (
                UPDATE email_verification_tokens
                SET consumed_at = NOW()
                WHERE token_hash = $1 AND consumed_at IS NULL AND expires_at > NOW()
                RETURNING user_id
            )
            UPDATE users
            SET status = 'active', email_verified_at = COALESCE(email_verified_at, NOW()), updated_at = NOW()
            FROM consumed
            WHERE users.id = consumed.user_id AND users.deleted_at IS NULL AND users.status = 'pending'
            RETURNING users.id, users.email, users.status, users.email_verified_at, users.created_at
            "#,
        )
        .bind(token_hash)
        .fetch_optional(&self.pool)
        .await
        .map_err(AuthRepositoryError::database)?;
        row.map(UserRecord::try_from)
            .transpose()
            .map_err(AuthRepositoryError::CorruptData)
    }

    pub async fn create_session(&self, user_id: Uuid) -> Result<UserSession, AuthRepositoryError> {
        let token = self
            .tokens
            .generate(SESSION_PURPOSE)
            .map_err(AuthRepositoryError::Token)?;
        let expires_at = Utc::now() + Duration::days(USER_SESSION_LIFETIME_DAYS);
        sqlx::query(
            r#"
            INSERT INTO user_sessions (id, user_id, token_hash, expires_at)
            VALUES ($1, $2, $3, $4)
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(user_id)
        .bind(token.hash())
        .bind(expires_at)
        .execute(&self.pool)
        .await
        .map_err(AuthRepositoryError::database)?;
        Ok(UserSession {
            token: token.raw().to_owned(),
            expires_at,
        })
    }

    pub async fn authenticate_session(
        &self,
        raw_token: &str,
    ) -> Result<Option<UserRecord>, AuthRepositoryError> {
        let token_hash = self
            .tokens
            .hash(SESSION_PURPOSE, raw_token)
            .map_err(AuthRepositoryError::Token)?;
        let row = sqlx::query_as::<_, UserRow>(
            r#"
            UPDATE user_sessions AS session
            SET last_seen_at = NOW()
            FROM users
            WHERE session.token_hash = $1
              AND session.user_id = users.id
              AND session.revoked_at IS NULL
              AND session.expires_at > NOW()
              AND users.status = 'active'
              AND users.deleted_at IS NULL
            RETURNING users.id, users.email, users.status, users.email_verified_at, users.created_at
            "#,
        )
        .bind(token_hash)
        .fetch_optional(&self.pool)
        .await
        .map_err(AuthRepositoryError::database)?;
        row.map(UserRecord::try_from)
            .transpose()
            .map_err(AuthRepositoryError::CorruptData)
    }

    pub async fn revoke_session(&self, raw_token: &str) -> Result<(), AuthRepositoryError> {
        let token_hash = self
            .tokens
            .hash(SESSION_PURPOSE, raw_token)
            .map_err(AuthRepositoryError::Token)?;
        sqlx::query(
            "UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, NOW()) WHERE token_hash = $1",
        )
        .bind(token_hash)
        .execute(&self.pool)
        .await
        .map_err(AuthRepositoryError::database)?;
        Ok(())
    }

    pub async fn revoke_all_sessions(&self, user_id: Uuid) -> Result<(), AuthRepositoryError> {
        sqlx::query(
            "UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, NOW()) WHERE user_id = $1",
        )
        .bind(user_id)
        .execute(&self.pool)
        .await
        .map_err(AuthRepositoryError::database)?;
        Ok(())
    }

    pub async fn issue_password_reset(
        &self,
        user_id: Uuid,
    ) -> Result<AuthToken, AuthRepositoryError> {
        let token = self
            .tokens
            .generate(RESET_PURPOSE)
            .map_err(AuthRepositoryError::Token)?;
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(AuthRepositoryError::database)?;
        sqlx::query("SELECT id FROM users WHERE id = $1 FOR UPDATE")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(AuthRepositoryError::database)?;
        sqlx::query("DELETE FROM password_reset_tokens WHERE user_id = $1 AND consumed_at IS NULL")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(AuthRepositoryError::database)?;
        sqlx::query(
            r#"
            INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at)
            VALUES ($1, $2, $3, NOW() + INTERVAL '30 minutes')
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(user_id)
        .bind(token.hash())
        .execute(&mut *transaction)
        .await
        .map_err(AuthRepositoryError::database)?;
        transaction
            .commit()
            .await
            .map_err(AuthRepositoryError::database)?;
        Ok(token)
    }

    pub async fn reset_password(
        &self,
        raw_token: &str,
        password_hash: UserPasswordHash,
    ) -> Result<bool, AuthRepositoryError> {
        let token_hash = self
            .tokens
            .hash(RESET_PURPOSE, raw_token)
            .map_err(AuthRepositoryError::Token)?;
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(AuthRepositoryError::database)?;
        let user_id = sqlx::query_scalar::<_, Uuid>(
            r#"
            UPDATE password_reset_tokens
            SET consumed_at = NOW()
            WHERE token_hash = $1 AND consumed_at IS NULL AND expires_at > NOW()
            RETURNING user_id
            "#,
        )
        .bind(token_hash)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(AuthRepositoryError::database)?;
        let Some(user_id) = user_id else {
            transaction
                .rollback()
                .await
                .map_err(AuthRepositoryError::database)?;
            return Ok(false);
        };
        sqlx::query("UPDATE users SET password_hash = $2, updated_at = NOW() WHERE id = $1")
            .bind(user_id)
            .bind(password_hash.as_str())
            .execute(&mut *transaction)
            .await
            .map_err(AuthRepositoryError::database)?;
        sqlx::query(
            "UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, NOW()) WHERE user_id = $1",
        )
        .bind(user_id)
        .execute(&mut *transaction)
        .await
        .map_err(AuthRepositoryError::database)?;
        transaction
            .commit()
            .await
            .map_err(AuthRepositoryError::database)?;
        Ok(true)
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AuthRateLimitKind {
    Login,
    PasswordReset,
    Verification,
    EmailChange,
}

impl AuthRateLimitKind {
    const fn as_str(self) -> &'static str {
        match self {
            Self::Login => "login",
            Self::PasswordReset => "password_reset",
            Self::Verification => "verification",
            Self::EmailChange => "email_change",
        }
    }

    const fn purpose(self) -> &'static str {
        match self {
            Self::Login => "login-rate-limit",
            Self::PasswordReset => "password-reset-rate-limit",
            Self::Verification => "verification-rate-limit",
            Self::EmailChange => "email-change-rate-limit",
        }
    }

    const fn limits(self) -> (i32, i32, i32) {
        match self {
            Self::Login => (5, 15 * 60, 30),
            Self::PasswordReset => (3, 60 * 60, 60 * 60),
            Self::Verification | Self::EmailChange => (4, 60 * 60, 60 * 60),
        }
    }
}

pub struct AccountCredentials {
    pub user: UserRecord,
    pub password_hash: String,
}

pub struct UserSession {
    pub token: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(FromRow)]
struct CredentialRow {
    id: Uuid,
    email: String,
    password_hash: String,
    status: String,
    email_verified_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
}

impl TryFrom<CredentialRow> for AccountCredentials {
    type Error = CorruptUserRecord;

    fn try_from(row: CredentialRow) -> Result<Self, Self::Error> {
        Ok(Self {
            user: UserRecord::from_stored(
                row.id,
                row.email,
                row.status,
                row.email_verified_at,
                row.created_at,
            )?,
            password_hash: row.password_hash,
        })
    }
}

#[derive(FromRow)]
struct UserRow {
    id: Uuid,
    email: String,
    status: String,
    email_verified_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
}

impl TryFrom<UserRow> for UserRecord {
    type Error = CorruptUserRecord;

    fn try_from(row: UserRow) -> Result<Self, Self::Error> {
        Self::from_stored(
            row.id,
            row.email,
            row.status,
            row.email_verified_at,
            row.created_at,
        )
    }
}

pub enum AuthRepositoryError {
    Database(sqlx::Error),
    Token(AuthTokenCodecError),
    CorruptData(CorruptUserRecord),
}

impl AuthRepositoryError {
    fn database(error: sqlx::Error) -> Self {
        Self::Database(error)
    }
}

impl fmt::Debug for AuthRepositoryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for AuthRepositoryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("authentication database operation failed")
    }
}

impl Error for AuthRepositoryError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Database(error) => Some(error),
            Self::Token(error) => Some(error),
            Self::CorruptData(error) => Some(error),
        }
    }
}
