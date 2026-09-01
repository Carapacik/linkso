use std::{error::Error, fmt, net::IpAddr};

use sqlx::PgPool;

use crate::accounts::{AuthTokenCodec, AuthTokenCodecError};

#[derive(Clone)]
pub struct PublicRateLimiter {
    pool: PgPool,
    tokens: AuthTokenCodec,
}

impl PublicRateLimiter {
    pub fn new(pool: PgPool, tokens: AuthTokenCodec) -> Self {
        Self { pool, tokens }
    }

    pub async fn register(
        &self,
        kind: PublicRateLimitKind,
        client_ip: IpAddr,
    ) -> Result<Option<u64>, PublicRateLimitError> {
        let (maximum_attempts, window_seconds) = kind.limits();
        let key_hash = self
            .tokens
            .hash(kind.purpose(), &client_ip.to_string())
            .map_err(PublicRateLimitError::Token)?;
        let retry_after = sqlx::query_scalar::<_, i64>(
            r#"
            INSERT INTO public_request_rate_limits (scope, key_hash, attempts)
            VALUES ($1, $2, 1)
            ON CONFLICT (scope, key_hash) DO UPDATE
            SET attempts = CASE
                    WHEN public_request_rate_limits.window_started_at
                         <= NOW() - ($4 * INTERVAL '1 second')
                    THEN 1 ELSE public_request_rate_limits.attempts + 1 END,
                window_started_at = CASE
                    WHEN public_request_rate_limits.window_started_at
                         <= NOW() - ($4 * INTERVAL '1 second')
                    THEN NOW() ELSE public_request_rate_limits.window_started_at END,
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
        .bind(kind.as_str())
        .bind(key_hash)
        .bind(maximum_attempts)
        .bind(window_seconds)
        .fetch_one(&self.pool)
        .await
        .map_err(PublicRateLimitError::Database)?;
        Ok((retry_after > 0).then_some(retry_after as u64))
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PublicRateLimitKind {
    DirectRedirect,
    PasswordSession,
    PasswordVerify,
    PasswordTicket,
    AdvertisingSession,
    AdvertisingContinue,
    AdvertisingTicket,
    LinkReport,
}

impl PublicRateLimitKind {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::DirectRedirect => "direct_redirect",
            Self::PasswordSession => "password_session",
            Self::PasswordVerify => "password_verify",
            Self::PasswordTicket => "password_ticket",
            Self::AdvertisingSession => "advertising_session",
            Self::AdvertisingContinue => "advertising_continue",
            Self::AdvertisingTicket => "advertising_ticket",
            Self::LinkReport => "link_report",
        }
    }

    const fn purpose(self) -> &'static str {
        match self {
            Self::DirectRedirect => "direct-redirect-rate-limit",
            Self::PasswordSession => "password-session-rate-limit",
            Self::PasswordVerify => "password-verify-rate-limit",
            Self::PasswordTicket => "password-ticket-rate-limit",
            Self::AdvertisingSession => "advertising-session-rate-limit",
            Self::AdvertisingContinue => "advertising-continue-rate-limit",
            Self::AdvertisingTicket => "advertising-ticket-rate-limit",
            Self::LinkReport => "link-report-rate-limit",
        }
    }

    pub const fn limits(self) -> (i32, i32) {
        match self {
            Self::DirectRedirect => (300, 60),
            Self::PasswordSession | Self::PasswordVerify | Self::AdvertisingSession => (30, 60),
            Self::PasswordTicket | Self::AdvertisingContinue | Self::AdvertisingTicket => (120, 60),
            Self::LinkReport => (5, 60 * 60),
        }
    }
}

pub enum PublicRateLimitError {
    Database(sqlx::Error),
    Token(AuthTokenCodecError),
}

impl fmt::Debug for PublicRateLimitError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for PublicRateLimitError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("public endpoint rate limit operation failed")
    }
}

impl Error for PublicRateLimitError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Database(error) => Some(error),
            Self::Token(error) => Some(error),
        }
    }
}
