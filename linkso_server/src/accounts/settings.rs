use std::{error::Error, fmt};

use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use super::{AuthToken, AuthTokenCodec, AuthTokenCodecError, Email, UserPasswordHash, UserStatus};

const EMAIL_CHANGE_PURPOSE: &str = "email-change";
const SESSION_PURPOSE: &str = "user-session";

pub const SUPPORTED_TIMEZONES: [&str; 8] = [
    "UTC",
    "Europe/Moscow",
    "Europe/London",
    "Europe/Berlin",
    "America/New_York",
    "America/Los_Angeles",
    "Asia/Tokyo",
    "Asia/Shanghai",
];

#[derive(Clone)]
pub struct SettingsRepository {
    pool: PgPool,
    tokens: AuthTokenCodec,
}

impl SettingsRepository {
    pub fn new(pool: PgPool, tokens: AuthTokenCodec) -> Self {
        Self { pool, tokens }
    }

    pub async fn profile(&self, user_id: Uuid) -> Result<Option<AccountProfile>, SettingsError> {
        sqlx::query_as::<_, ProfileRow>(
            r#"
            SELECT id, email, display_name, status, email_verified_at, created_at, timezone
            FROM users
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(SettingsError::database)?
        .map(AccountProfile::try_from)
        .transpose()
    }

    pub async fn update_display_name(
        &self,
        user_id: Uuid,
        display_name: Option<&str>,
    ) -> Result<Option<AccountProfile>, SettingsError> {
        sqlx::query_as::<_, ProfileRow>(
            r#"
            UPDATE users
            SET display_name = $2, updated_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING id, email, display_name, status, email_verified_at, created_at, timezone
            "#,
        )
        .bind(user_id)
        .bind(display_name)
        .fetch_optional(&self.pool)
        .await
        .map_err(SettingsError::database)?
        .map(AccountProfile::try_from)
        .transpose()
    }

    pub async fn update_timezone(
        &self,
        user_id: Uuid,
        timezone: &str,
    ) -> Result<Option<AccountProfile>, SettingsError> {
        sqlx::query_as::<_, ProfileRow>(
            r#"
            UPDATE users
            SET timezone = $2, updated_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING id, email, display_name, status, email_verified_at, created_at, timezone
            "#,
        )
        .bind(user_id)
        .bind(timezone)
        .fetch_optional(&self.pool)
        .await
        .map_err(SettingsError::database)?
        .map(AccountProfile::try_from)
        .transpose()
    }

    pub async fn issue_email_change(
        &self,
        user_id: Uuid,
        target_email: &Email,
    ) -> Result<AuthToken, SettingsError> {
        let email_taken = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM users WHERE lower(email) = lower($1) AND id <> $2 AND deleted_at IS NULL)",
        )
        .bind(target_email.as_str())
        .bind(user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(SettingsError::database)?;
        if email_taken {
            return Err(SettingsError::EmailTaken);
        }
        let token = self
            .tokens
            .generate(EMAIL_CHANGE_PURPOSE)
            .map_err(SettingsError::Token)?;
        let mut transaction = self.pool.begin().await.map_err(SettingsError::database)?;
        sqlx::query("SELECT id FROM users WHERE id = $1 FOR UPDATE")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(SettingsError::database)?;
        sqlx::query("DELETE FROM email_change_tokens WHERE user_id = $1 AND consumed_at IS NULL")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(SettingsError::database)?;
        sqlx::query(
            r#"
            INSERT INTO email_change_tokens (id, user_id, target_email, token_hash, expires_at)
            VALUES ($1, $2, $3, $4, NOW() + INTERVAL '24 hours')
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(user_id)
        .bind(target_email.as_str())
        .bind(token.hash())
        .execute(&mut *transaction)
        .await
        .map_err(SettingsError::database)?;
        insert_user_audit(&mut transaction, user_id, "account.email_change_requested").await?;
        transaction
            .commit()
            .await
            .map_err(SettingsError::database)?;
        Ok(token)
    }

    pub async fn confirm_email_change(
        &self,
        user_id: Uuid,
        raw_token: &str,
        current_session: &str,
    ) -> Result<Option<AccountProfile>, SettingsError> {
        let token_hash = self
            .tokens
            .hash(EMAIL_CHANGE_PURPOSE, raw_token)
            .map_err(SettingsError::Token)?;
        let session_hash = self
            .tokens
            .hash(SESSION_PURPOSE, current_session)
            .map_err(SettingsError::Token)?;
        let mut transaction = self.pool.begin().await.map_err(SettingsError::database)?;
        let target_email = sqlx::query_scalar::<_, String>(
            r#"
            UPDATE email_change_tokens
            SET consumed_at = NOW()
            WHERE user_id = $1 AND token_hash = $2 AND consumed_at IS NULL AND expires_at > NOW()
            RETURNING target_email
            "#,
        )
        .bind(user_id)
        .bind(token_hash)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(SettingsError::database)?;
        let Some(target_email) = target_email else {
            transaction
                .rollback()
                .await
                .map_err(SettingsError::database)?;
            return Ok(None);
        };
        let row = sqlx::query_as::<_, ProfileRow>(
            r#"
            UPDATE users
            SET email = $2, email_verified_at = NOW(), updated_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING id, email, display_name, status, email_verified_at, created_at, timezone
            "#,
        )
        .bind(user_id)
        .bind(target_email)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(SettingsError::database)?;
        sqlx::query(
            "UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, NOW()) WHERE user_id = $1 AND token_hash <> $2",
        )
        .bind(user_id)
        .bind(session_hash)
        .execute(&mut *transaction)
        .await
        .map_err(SettingsError::database)?;
        // A link sent to the previous address must not reset the updated account.
        sqlx::query("DELETE FROM password_reset_tokens WHERE user_id = $1")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(SettingsError::database)?;
        insert_user_audit(&mut transaction, user_id, "account.email_changed").await?;
        transaction
            .commit()
            .await
            .map_err(SettingsError::database)?;
        row.map(AccountProfile::try_from).transpose()
    }

    pub async fn change_password(
        &self,
        user_id: Uuid,
        password_hash: &UserPasswordHash,
        current_session: &str,
    ) -> Result<bool, SettingsError> {
        let session_hash = self
            .tokens
            .hash(SESSION_PURPOSE, current_session)
            .map_err(SettingsError::Token)?;
        let mut transaction = self.pool.begin().await.map_err(SettingsError::database)?;
        let updated = sqlx::query(
            "UPDATE users SET password_hash = $2, updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL",
        )
        .bind(user_id)
        .bind(password_hash.as_str())
        .execute(&mut *transaction)
        .await
        .map_err(SettingsError::database)?
        .rows_affected();
        if updated == 0 {
            transaction
                .rollback()
                .await
                .map_err(SettingsError::database)?;
            return Ok(false);
        }
        sqlx::query(
            "UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, NOW()) WHERE user_id = $1 AND token_hash <> $2",
        )
        .bind(user_id)
        .bind(session_hash)
        .execute(&mut *transaction)
        .await
        .map_err(SettingsError::database)?;
        sqlx::query("DELETE FROM password_reset_tokens WHERE user_id = $1")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(SettingsError::database)?;
        insert_user_audit(&mut transaction, user_id, "account.password_changed").await?;
        transaction
            .commit()
            .await
            .map_err(SettingsError::database)?;
        Ok(true)
    }

    pub async fn active_sessions(
        &self,
        user_id: Uuid,
        current_session: &str,
    ) -> Result<Vec<ActiveSession>, SettingsError> {
        let session_hash = self
            .tokens
            .hash(SESSION_PURPOSE, current_session)
            .map_err(SettingsError::Token)?;
        sqlx::query_as::<_, SessionRow>(
            r#"
            SELECT id, created_at, last_seen_at, expires_at, token_hash = $2 AS is_current
            FROM user_sessions
            WHERE user_id = $1 AND revoked_at IS NULL AND expires_at > NOW()
            ORDER BY is_current DESC, last_seen_at DESC, id
            "#,
        )
        .bind(user_id)
        .bind(session_hash)
        .fetch_all(&self.pool)
        .await
        .map_err(SettingsError::database)
        .map(|rows| rows.into_iter().map(ActiveSession::from).collect())
    }

    pub async fn revoke_session(
        &self,
        user_id: Uuid,
        session_id: Uuid,
        current_session: &str,
    ) -> Result<Option<bool>, SettingsError> {
        let session_hash = self
            .tokens
            .hash(SESSION_PURPOSE, current_session)
            .map_err(SettingsError::Token)?;
        let is_current = sqlx::query_scalar::<_, bool>(
            "SELECT token_hash = $3 FROM user_sessions WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL AND expires_at > NOW()",
        )
        .bind(session_id)
        .bind(user_id)
        .bind(session_hash)
        .fetch_optional(&self.pool)
        .await
        .map_err(SettingsError::database)?;
        if is_current == Some(false) {
            sqlx::query(
                "UPDATE user_sessions SET revoked_at = NOW() WHERE id = $1 AND user_id = $2",
            )
            .bind(session_id)
            .bind(user_id)
            .execute(&self.pool)
            .await
            .map_err(SettingsError::database)?;
        }
        Ok(is_current)
    }

    pub async fn delete_account(&self, user_id: Uuid) -> Result<bool, SettingsError> {
        let mut transaction = self.pool.begin().await.map_err(SettingsError::database)?;
        sqlx::query(
            "UPDATE links SET status = 'disabled', blocked_reason = NULL, blocked_at = NULL, blocked_by = NULL, deleted_at = COALESCE(deleted_at, NOW()), updated_at = NOW() WHERE owner_id = $1",
        )
        .bind(user_id)
        .execute(&mut *transaction)
        .await
        .map_err(SettingsError::database)?;
        sqlx::query("DELETE FROM tags WHERE owner_id = $1")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(SettingsError::database)?;
        sqlx::query("DELETE FROM email_verification_tokens WHERE user_id = $1")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(SettingsError::database)?;
        sqlx::query("DELETE FROM password_reset_tokens WHERE user_id = $1")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(SettingsError::database)?;
        sqlx::query("DELETE FROM email_change_tokens WHERE user_id = $1")
            .bind(user_id)
            .execute(&mut *transaction)
            .await
            .map_err(SettingsError::database)?;
        sqlx::query(
            "UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, NOW()) WHERE user_id = $1",
        )
        .bind(user_id)
        .execute(&mut *transaction)
        .await
        .map_err(SettingsError::database)?;
        let tombstone_email = format!("deleted-{user_id}@deleted.invalid");
        let updated = sqlx::query(
            r#"
            UPDATE users
            SET email = $2, display_name = NULL, password_hash = 'deleted', status = 'disabled',
                email_verified_at = NULL, timezone = 'UTC', deleted_at = NOW(), updated_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(user_id)
        .bind(tombstone_email)
        .execute(&mut *transaction)
        .await
        .map_err(SettingsError::database)?
        .rows_affected();
        if updated == 1 {
            insert_user_audit(&mut transaction, user_id, "account.deleted").await?;
        }
        transaction
            .commit()
            .await
            .map_err(SettingsError::database)?;
        Ok(updated == 1)
    }
}

async fn insert_user_audit(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    user_id: Uuid,
    action: &str,
) -> Result<(), SettingsError> {
    sqlx::query(
        "INSERT INTO security_audit_log (id, actor_type, actor_id, action, target_type, target_id) VALUES ($1, 'user', $2, $3, 'user', $2)",
    )
    .bind(Uuid::new_v4())
    .bind(user_id)
    .bind(action)
    .execute(&mut **transaction)
    .await
    .map_err(SettingsError::database)?;
    Ok(())
}

#[derive(Debug, Serialize)]
pub struct AccountProfile {
    pub id: Uuid,
    pub email: String,
    pub display_name: Option<String>,
    pub status: UserStatus,
    pub email_verified: bool,
    pub created_at: DateTime<Utc>,
    pub timezone: String,
}

#[derive(Debug, Serialize)]
pub struct ActiveSession {
    pub id: Uuid,
    pub created_at: DateTime<Utc>,
    pub last_seen_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub is_current: bool,
}

#[derive(FromRow)]
struct ProfileRow {
    id: Uuid,
    email: String,
    display_name: Option<String>,
    status: String,
    email_verified_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    timezone: String,
}

impl TryFrom<ProfileRow> for AccountProfile {
    type Error = SettingsError;

    fn try_from(row: ProfileRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            email: row.email,
            display_name: row.display_name,
            status: row.status.parse().map_err(|_| SettingsError::CorruptData)?,
            email_verified: row.email_verified_at.is_some(),
            created_at: row.created_at,
            timezone: row.timezone,
        })
    }
}

#[derive(FromRow)]
struct SessionRow {
    id: Uuid,
    created_at: DateTime<Utc>,
    last_seen_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    is_current: bool,
}

impl From<SessionRow> for ActiveSession {
    fn from(row: SessionRow) -> Self {
        Self {
            id: row.id,
            created_at: row.created_at,
            last_seen_at: row.last_seen_at,
            expires_at: row.expires_at,
            is_current: row.is_current,
        }
    }
}

pub enum SettingsError {
    EmailTaken,
    Database(sqlx::Error),
    Token(AuthTokenCodecError),
    CorruptData,
}

impl SettingsError {
    fn database(error: sqlx::Error) -> Self {
        if error.as_database_error().is_some_and(|database_error| {
            database_error.code().as_deref() == Some("23505")
                && database_error.constraint() == Some("users_email_unique")
        }) {
            Self::EmailTaken
        } else {
            Self::Database(error)
        }
    }
}

impl fmt::Debug for SettingsError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for SettingsError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::EmailTaken => "account email is already registered",
            Self::Database(_) | Self::Token(_) | Self::CorruptData => {
                "account settings operation failed"
            }
        })
    }
}

impl Error for SettingsError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Database(error) => Some(error),
            Self::Token(error) => Some(error),
            Self::EmailTaken | Self::CorruptData => None,
        }
    }
}
