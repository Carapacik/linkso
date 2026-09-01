use std::{error::Error, fmt, net::IpAddr};

use sqlx::PgPool;
use uuid::Uuid;

use crate::accounts::{AuthTokenCodec, AuthTokenCodecError};

pub const ANONYMOUS_CREATION_LIMIT: i32 = 10;
pub const AUTHENTICATED_CREATION_LIMIT: i32 = 60;
pub const CREATION_RATE_LIMIT_WINDOW_SECONDS: i32 = 10 * 60;

const ANONYMOUS_PURPOSE: &str = "anonymous-link-creation-rate-limit";
const AUTHENTICATED_PURPOSE: &str = "authenticated-link-creation-rate-limit";

#[derive(Clone)]
pub struct LinkCreationRateLimiter {
    pool: PgPool,
    tokens: AuthTokenCodec,
}

impl LinkCreationRateLimiter {
    pub fn new(pool: PgPool, tokens: AuthTokenCodec) -> Self {
        Self { pool, tokens }
    }

    pub async fn register(
        &self,
        subject: LinkCreationSubject,
    ) -> Result<Option<u64>, LinkCreationRateLimitError> {
        let (scope, purpose, value, maximum_attempts) = match subject {
            LinkCreationSubject::Anonymous(ip) => (
                "anonymous",
                ANONYMOUS_PURPOSE,
                ip.to_string(),
                ANONYMOUS_CREATION_LIMIT,
            ),
            LinkCreationSubject::Authenticated(user_id) => (
                "authenticated",
                AUTHENTICATED_PURPOSE,
                user_id.to_string(),
                AUTHENTICATED_CREATION_LIMIT,
            ),
        };
        let key_hash = self
            .tokens
            .hash(purpose, &value)
            .map_err(LinkCreationRateLimitError::Token)?;
        let retry_after = sqlx::query_scalar::<_, i64>(
            r#"
            INSERT INTO link_creation_rate_limits (scope, key_hash, attempts)
            VALUES ($1, $2, 1)
            ON CONFLICT (scope, key_hash) DO UPDATE
            SET attempts = CASE
                    WHEN link_creation_rate_limits.window_started_at
                         <= NOW() - ($4 * INTERVAL '1 second')
                    THEN 1 ELSE link_creation_rate_limits.attempts + 1 END,
                window_started_at = CASE
                    WHEN link_creation_rate_limits.window_started_at
                         <= NOW() - ($4 * INTERVAL '1 second')
                    THEN NOW() ELSE link_creation_rate_limits.window_started_at END,
                updated_at = NOW()
            RETURNING CASE WHEN attempts > $3
                THEN GREATEST(
                    1,
                    CEIL(EXTRACT(EPOCH FROM (
                        window_started_at + ($4 * INTERVAL '1 second') - NOW()
                    )))::BIGINT
                )
                ELSE 0 END
            "#,
        )
        .bind(scope)
        .bind(key_hash)
        .bind(maximum_attempts)
        .bind(CREATION_RATE_LIMIT_WINDOW_SECONDS)
        .fetch_one(&self.pool)
        .await
        .map_err(LinkCreationRateLimitError::Database)?;
        Ok((retry_after > 0).then_some(retry_after as u64))
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LinkCreationSubject {
    Anonymous(IpAddr),
    Authenticated(Uuid),
}

pub enum LinkCreationRateLimitError {
    Database(sqlx::Error),
    Token(AuthTokenCodecError),
}

impl fmt::Debug for LinkCreationRateLimitError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for LinkCreationRateLimitError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("link creation rate limit operation failed")
    }
}

impl Error for LinkCreationRateLimitError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Database(error) => Some(error),
            Self::Token(error) => Some(error),
        }
    }
}
