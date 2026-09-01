use std::{error::Error, fmt};

use chrono::{DateTime, Duration, Utc};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use super::{LinkPassword, LinkPasswordVerifyError, verify_link_password};

pub const PASSWORD_SESSION_LIFETIME_MINUTES: i64 = 10;
pub const PASSWORD_TICKET_LIFETIME_SECONDS: i64 = 60;
pub const PASSWORD_MAX_FAILED_ATTEMPTS: i16 = 5;
pub const PASSWORD_LOCK_SECONDS: i64 = 30;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PasswordSession {
    pub id: Uuid,
    pub expires_at: DateTime<Utc>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PasswordRedirectTicket {
    pub id: Uuid,
    pub expires_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ConsumedPasswordRedirect {
    pub link_id: Uuid,
    pub target_url: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PasswordVerification {
    Incorrect,
    Locked { retry_after_seconds: u64 },
    Ticket(PasswordRedirectTicket),
}

#[derive(Clone)]
pub struct PasswordFlowRepository {
    pool: PgPool,
}

impl PasswordFlowRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn start_session(
        &self,
        link_id: Uuid,
    ) -> Result<Option<PasswordSession>, PasswordFlowError> {
        let id = Uuid::new_v4();
        let expires_at = Utc::now() + Duration::minutes(PASSWORD_SESSION_LIFETIME_MINUTES);
        let row = sqlx::query_as::<_, PasswordSessionRow>(
            r#"
            INSERT INTO password_link_sessions (id, link_id, expires_at)
            SELECT $1, id, $2
            FROM links
            WHERE id = $3
              AND kind = 'password'
              AND status = 'active'
              AND deleted_at IS NULL
              AND (expires_at IS NULL OR expires_at > NOW())
            RETURNING id, expires_at
            "#,
        )
        .bind(id)
        .bind(expires_at)
        .bind(link_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(PasswordFlowError::database)?;

        Ok(row.map(|row| PasswordSession {
            id: row.id,
            expires_at: row.expires_at,
        }))
    }

    pub async fn verify(
        &self,
        link_id: Uuid,
        session_id: Uuid,
        password: LinkPassword,
    ) -> Result<PasswordVerification, PasswordFlowError> {
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(PasswordFlowError::database)?;
        let session = sqlx::query_as::<_, VerificationRow>(
            r#"
            SELECT s.expires_at, l.password_hash
            FROM password_link_sessions s
            JOIN links l ON l.id = s.link_id
            WHERE s.id = $1
              AND l.id = $2
              AND l.kind = 'password'
              AND l.status = 'active'
              AND l.deleted_at IS NULL
              AND (l.expires_at IS NULL OR l.expires_at > NOW())
            FOR UPDATE OF s, l
            "#,
        )
        .bind(session_id)
        .bind(link_id)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(PasswordFlowError::database)?
        .ok_or(PasswordFlowError::SessionUnavailable)?;
        let now = Utc::now();

        if session.expires_at <= now {
            sqlx::query("DELETE FROM password_link_sessions WHERE id = $1")
                .bind(session_id)
                .execute(&mut *transaction)
                .await
                .map_err(PasswordFlowError::database)?;
            transaction
                .commit()
                .await
                .map_err(PasswordFlowError::database)?;
            return Err(PasswordFlowError::SessionUnavailable);
        }

        let attempt_limit = sqlx::query_as::<_, AttemptLimitRow>(
            r#"
            SELECT
                COALESCE(SUM(failed_attempts), 0)::BIGINT AS failed_attempts,
                MAX(blocked_until) AS blocked_until
            FROM password_link_sessions
            WHERE link_id = $1 AND expires_at > NOW()
            "#,
        )
        .bind(link_id)
        .fetch_one(&mut *transaction)
        .await
        .map_err(PasswordFlowError::database)?;

        if let Some(blocked_until) = attempt_limit.blocked_until.filter(|value| *value > now) {
            let milliseconds = (blocked_until - now).num_milliseconds().max(1);
            transaction
                .commit()
                .await
                .map_err(PasswordFlowError::database)?;
            return Ok(PasswordVerification::Locked {
                retry_after_seconds: ((milliseconds + 999) / 1000) as u64,
            });
        }

        let failed_attempts = if attempt_limit.blocked_until.is_some() {
            sqlx::query(
                r#"
                UPDATE password_link_sessions
                SET failed_attempts = 0, blocked_until = NULL
                WHERE link_id = $1
                "#,
            )
            .bind(link_id)
            .execute(&mut *transaction)
            .await
            .map_err(PasswordFlowError::database)?;
            0
        } else {
            attempt_limit.failed_attempts
        };

        let password_hash = session
            .password_hash
            .ok_or(PasswordFlowError::StoredPasswordHashMissing)?;
        let is_valid = verify_link_password(password, password_hash)
            .await
            .map_err(PasswordFlowError::Verification)?;
        if !is_valid {
            let failed_attempts = failed_attempts + 1;
            let blocked_until = (failed_attempts >= i64::from(PASSWORD_MAX_FAILED_ATTEMPTS))
                .then(|| now + Duration::seconds(PASSWORD_LOCK_SECONDS));
            if let Some(blocked_until) = blocked_until {
                sqlx::query(
                    r#"
                    UPDATE password_link_sessions
                    SET failed_attempts = failed_attempts + CASE WHEN id = $2 THEN 1 ELSE 0 END,
                        blocked_until = $3
                    WHERE link_id = $1
                    "#,
                )
                .bind(link_id)
                .bind(session_id)
                .bind(blocked_until)
                .execute(&mut *transaction)
                .await
                .map_err(PasswordFlowError::database)?;
            } else {
                sqlx::query(
                    "UPDATE password_link_sessions SET failed_attempts = failed_attempts + 1 WHERE id = $1",
                )
                .bind(session_id)
                .execute(&mut *transaction)
                .await
                .map_err(PasswordFlowError::database)?;
            }
            transaction
                .commit()
                .await
                .map_err(PasswordFlowError::database)?;
            return Ok(match blocked_until {
                Some(_) => PasswordVerification::Locked {
                    retry_after_seconds: PASSWORD_LOCK_SECONDS as u64,
                },
                None => PasswordVerification::Incorrect,
            });
        }

        sqlx::query("DELETE FROM password_link_sessions WHERE link_id = $1")
            .bind(link_id)
            .execute(&mut *transaction)
            .await
            .map_err(PasswordFlowError::database)?;
        let ticket = PasswordRedirectTicket {
            id: Uuid::new_v4(),
            expires_at: now + Duration::seconds(PASSWORD_TICKET_LIFETIME_SECONDS),
        };
        sqlx::query(
            r#"
            INSERT INTO password_redirect_tickets (id, link_id, expires_at)
            VALUES ($1, $2, $3)
            "#,
        )
        .bind(ticket.id)
        .bind(link_id)
        .bind(ticket.expires_at)
        .execute(&mut *transaction)
        .await
        .map_err(PasswordFlowError::database)?;
        transaction
            .commit()
            .await
            .map_err(PasswordFlowError::database)?;

        Ok(PasswordVerification::Ticket(ticket))
    }

    pub async fn consume_ticket(
        &self,
        ticket_id: Uuid,
    ) -> Result<Option<ConsumedPasswordRedirect>, PasswordFlowError> {
        let redirect = sqlx::query_as::<_, ConsumedPasswordRedirectRow>(
            r#"
            WITH eligible AS (
                SELECT t.id AS ticket_id, l.id AS link_id, l.target_url
                FROM password_redirect_tickets t
                JOIN links l ON l.id = t.link_id
                WHERE t.id = $1
                  AND t.used_at IS NULL
                  AND t.expires_at > NOW()
                  AND l.kind = 'password'
                  AND l.status = 'active'
                  AND l.deleted_at IS NULL
                  AND (l.expires_at IS NULL OR l.expires_at > NOW())
                FOR UPDATE OF t
            ), consumed AS (
                UPDATE password_redirect_tickets t
                SET used_at = NOW()
                FROM eligible
                WHERE t.id = eligible.ticket_id
                RETURNING eligible.link_id, eligible.target_url
            )
            UPDATE links l
            SET redirect_count = redirect_count + 1
            FROM consumed
            WHERE l.id = consumed.link_id
            RETURNING consumed.link_id, consumed.target_url
            "#,
        )
        .bind(ticket_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(PasswordFlowError::database)?;

        Ok(redirect.map(|redirect| ConsumedPasswordRedirect {
            link_id: redirect.link_id,
            target_url: redirect.target_url,
        }))
    }
}

#[derive(FromRow)]
struct PasswordSessionRow {
    id: Uuid,
    expires_at: DateTime<Utc>,
}

#[derive(FromRow)]
struct VerificationRow {
    expires_at: DateTime<Utc>,
    password_hash: Option<String>,
}

#[derive(FromRow)]
struct AttemptLimitRow {
    failed_attempts: i64,
    blocked_until: Option<DateTime<Utc>>,
}

#[derive(FromRow)]
struct ConsumedPasswordRedirectRow {
    link_id: Uuid,
    target_url: String,
}

pub enum PasswordFlowError {
    SessionUnavailable,
    StoredPasswordHashMissing,
    Verification(LinkPasswordVerifyError),
    Database(sqlx::Error),
}

impl PasswordFlowError {
    fn database(error: sqlx::Error) -> Self {
        Self::Database(error)
    }
}

impl fmt::Debug for PasswordFlowError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for PasswordFlowError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::SessionUnavailable => "password session is unavailable",
            Self::StoredPasswordHashMissing => "stored password hash is missing",
            Self::Verification(_) => "password verification failed",
            Self::Database(_) => "password flow database operation failed",
        })
    }
}

impl Error for PasswordFlowError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Verification(error) => Some(error),
            Self::Database(error) => Some(error),
            Self::SessionUnavailable | Self::StoredPasswordHashMissing => None,
        }
    }
}
