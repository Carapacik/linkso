use std::{error::Error, fmt};

use chrono::{DateTime, Duration, Utc};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::campaigns::AdCampaign;

pub const AD_COUNTDOWN_SECONDS: i64 = 5;
pub const AD_SESSION_LIFETIME_MINUTES: i64 = 10;
pub const AD_TICKET_LIFETIME_SECONDS: i64 = 60;

#[derive(Clone, Debug)]
pub struct AdvertisingSession {
    pub id: Uuid,
    pub unlocks_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub campaign: Option<AdCampaign>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AdvertisingRedirectTicket {
    pub id: Uuid,
    pub expires_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ConsumedAdvertisingRedirect {
    pub link_id: Uuid,
    pub target_url: String,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AdvertisingContinuation {
    NotReady { retry_after_seconds: u64 },
    Ticket(AdvertisingRedirectTicket),
}

#[derive(Clone)]
pub struct AdvertisingFlowRepository {
    pool: PgPool,
}

impl AdvertisingFlowRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn start_session(
        &self,
        link_id: Uuid,
    ) -> Result<Option<AdvertisingSession>, AdvertisingFlowError> {
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(AdvertisingFlowError::database)?;
        let campaign = sqlx::query_as::<_, AdCampaign>(
            r#"
            SELECT id, title, body, image_url, advertiser_url, starts_at, ends_at,
                   is_active, created_at, updated_at
            FROM ad_campaigns
            WHERE is_active = TRUE
              AND starts_at <= NOW()
              AND ends_at > NOW()
            ORDER BY starts_at DESC, created_at DESC, id
            LIMIT 1
            FOR SHARE
            "#,
        )
        .fetch_optional(&mut *transaction)
        .await
        .map_err(AdvertisingFlowError::database)?;
        let id = Uuid::new_v4();
        let unlocks_at = Utc::now() + Duration::seconds(AD_COUNTDOWN_SECONDS);
        let expires_at = Utc::now() + Duration::minutes(AD_SESSION_LIFETIME_MINUTES);
        let inserted = sqlx::query_scalar::<_, Uuid>(
            r#"
            INSERT INTO ad_sessions (id, link_id, campaign_id, unlocks_at, expires_at)
            SELECT $1, l.id, $3, $4, $5
            FROM links l
            WHERE l.id = $2
              AND l.kind = 'advertising'
              AND l.status = 'active'
              AND l.deleted_at IS NULL
              AND (l.expires_at IS NULL OR l.expires_at > NOW())
            RETURNING id
            "#,
        )
        .bind(id)
        .bind(link_id)
        .bind(campaign.as_ref().map(|campaign| campaign.id))
        .bind(unlocks_at)
        .bind(expires_at)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(AdvertisingFlowError::database)?;
        transaction
            .commit()
            .await
            .map_err(AdvertisingFlowError::database)?;

        Ok(inserted.map(|_| AdvertisingSession {
            id,
            unlocks_at,
            expires_at,
            campaign,
        }))
    }

    pub async fn continue_session(
        &self,
        link_id: Uuid,
        session_id: Uuid,
    ) -> Result<AdvertisingContinuation, AdvertisingFlowError> {
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(AdvertisingFlowError::database)?;
        let session = sqlx::query_as::<_, AdvertisingSessionRow>(
            r#"
            SELECT s.unlocks_at, s.expires_at, s.completed_at
            FROM ad_sessions s
            JOIN links l ON l.id = s.link_id
            WHERE s.id = $1
              AND l.id = $2
              AND l.kind = 'advertising'
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
        .map_err(AdvertisingFlowError::database)?
        .ok_or(AdvertisingFlowError::SessionUnavailable)?;
        let now = Utc::now();
        if session.expires_at <= now || session.completed_at.is_some() {
            transaction
                .commit()
                .await
                .map_err(AdvertisingFlowError::database)?;
            return Err(AdvertisingFlowError::SessionUnavailable);
        }
        if session.unlocks_at > now {
            let milliseconds = (session.unlocks_at - now).num_milliseconds().max(1);
            transaction
                .commit()
                .await
                .map_err(AdvertisingFlowError::database)?;
            return Ok(AdvertisingContinuation::NotReady {
                retry_after_seconds: ((milliseconds + 999) / 1000) as u64,
            });
        }

        let completed = sqlx::query(
            "UPDATE ad_sessions SET completed_at = $2 WHERE id = $1 AND completed_at IS NULL",
        )
        .bind(session_id)
        .bind(now)
        .execute(&mut *transaction)
        .await
        .map_err(AdvertisingFlowError::database)?;
        if completed.rows_affected() != 1 {
            return Err(AdvertisingFlowError::SessionUnavailable);
        }
        let ticket = AdvertisingRedirectTicket {
            id: Uuid::new_v4(),
            expires_at: now + Duration::seconds(AD_TICKET_LIFETIME_SECONDS),
        };
        sqlx::query(
            r#"
            INSERT INTO ad_redirect_tickets (id, link_id, session_id, expires_at)
            VALUES ($1, $2, $3, $4)
            "#,
        )
        .bind(ticket.id)
        .bind(link_id)
        .bind(session_id)
        .bind(ticket.expires_at)
        .execute(&mut *transaction)
        .await
        .map_err(AdvertisingFlowError::database)?;
        transaction
            .commit()
            .await
            .map_err(AdvertisingFlowError::database)?;
        Ok(AdvertisingContinuation::Ticket(ticket))
    }

    pub async fn consume_ticket(
        &self,
        ticket_id: Uuid,
    ) -> Result<Option<ConsumedAdvertisingRedirect>, AdvertisingFlowError> {
        sqlx::query_as::<_, ConsumedAdvertisingRedirectRow>(
            r#"
            WITH eligible AS (
                SELECT t.id AS ticket_id, l.id AS link_id, l.target_url
                FROM ad_redirect_tickets t
                JOIN links l ON l.id = t.link_id
                WHERE t.id = $1
                  AND t.used_at IS NULL
                  AND t.expires_at > NOW()
                  AND l.kind = 'advertising'
                  AND l.status = 'active'
                  AND l.deleted_at IS NULL
                  AND (l.expires_at IS NULL OR l.expires_at > NOW())
                FOR UPDATE OF t
            ), consumed AS (
                UPDATE ad_redirect_tickets t
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
        .map(|redirect| {
            redirect.map(|redirect| ConsumedAdvertisingRedirect {
                link_id: redirect.link_id,
                target_url: redirect.target_url,
            })
        })
        .map_err(AdvertisingFlowError::database)
    }
}

#[derive(FromRow)]
struct AdvertisingSessionRow {
    unlocks_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    completed_at: Option<DateTime<Utc>>,
}

#[derive(FromRow)]
struct ConsumedAdvertisingRedirectRow {
    link_id: Uuid,
    target_url: String,
}

pub enum AdvertisingFlowError {
    SessionUnavailable,
    Database(sqlx::Error),
}

impl AdvertisingFlowError {
    fn database(error: sqlx::Error) -> Self {
        Self::Database(error)
    }
}

impl fmt::Debug for AdvertisingFlowError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for AdvertisingFlowError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::SessionUnavailable => "advertising session is unavailable",
            Self::Database(_) => "advertising flow database operation failed",
        })
    }
}

impl Error for AdvertisingFlowError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::SessionUnavailable => None,
            Self::Database(error) => Some(error),
        }
    }
}
