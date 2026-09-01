use std::{error::Error, fmt, str::FromStr};

use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use super::Slug;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ReportReason {
    Phishing,
    Malware,
    Spam,
    Copyright,
    Other,
}

impl ReportReason {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Phishing => "phishing",
            Self::Malware => "malware",
            Self::Spam => "spam",
            Self::Copyright => "copyright",
            Self::Other => "other",
        }
    }
}

impl FromStr for ReportReason {
    type Err = ();

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "phishing" => Ok(Self::Phishing),
            "malware" => Ok(Self::Malware),
            "spam" => Ok(Self::Spam),
            "copyright" => Ok(Self::Copyright),
            "other" => Ok(Self::Other),
            _ => Err(()),
        }
    }
}

#[derive(Debug, FromRow, Serialize)]
pub struct LinkReport {
    pub id: Uuid,
    pub link_id: Uuid,
    pub slug: String,
    pub target_url: String,
    pub reason: String,
    pub details: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Clone)]
pub struct LinkModerationRepository {
    pool: PgPool,
}

impl LinkModerationRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn submit_report(
        &self,
        slug: &Slug,
        reporter_key_hash: &str,
        reason: ReportReason,
        details: Option<&str>,
    ) -> Result<bool, LinkModerationError> {
        let id = sqlx::query_scalar::<_, Uuid>(
            r#"
            INSERT INTO link_reports (id, link_id, reporter_key_hash, reason, details)
            SELECT $1, id, $3, $4, $5
            FROM links
            WHERE slug = $2 AND deleted_at IS NULL AND status <> 'blocked'
            ON CONFLICT (link_id, reporter_key_hash) DO NOTHING
            RETURNING id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(slug.as_str())
        .bind(reporter_key_hash)
        .bind(reason.as_str())
        .bind(details)
        .fetch_optional(&self.pool)
        .await
        .map_err(LinkModerationError::Database)?;
        Ok(id.is_some())
    }

    pub async fn list_pending(&self) -> Result<Vec<LinkReport>, LinkModerationError> {
        sqlx::query_as::<_, LinkReport>(
            r#"
            SELECT r.id, r.link_id, l.slug, l.target_url, r.reason, r.details, r.created_at
            FROM link_reports r
            JOIN links l ON l.id = r.link_id
            WHERE r.status = 'pending'
            ORDER BY r.created_at, r.id
            LIMIT 200
            "#,
        )
        .fetch_all(&self.pool)
        .await
        .map_err(LinkModerationError::Database)
    }

    pub async fn block_link(&self, id: Uuid, reason: &str) -> Result<bool, LinkModerationError> {
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(LinkModerationError::Database)?;
        let result = sqlx::query(
            r#"
            UPDATE links
            SET status = 'blocked', blocked_reason = $2, blocked_at = NOW(),
                blocked_by = 'admin', updated_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .bind(reason)
        .execute(&mut *transaction)
        .await
        .map_err(LinkModerationError::Database)?;
        if result.rows_affected() == 0 {
            return Ok(false);
        }
        sqlx::query(
            "UPDATE link_reports SET status = 'blocked', reviewed_at = NOW() WHERE link_id = $1 AND status = 'pending'",
        )
        .bind(id)
        .execute(&mut *transaction)
        .await
        .map_err(LinkModerationError::Database)?;
        insert_audit(&mut transaction, "link.blocked", "link", Some(id)).await?;
        transaction
            .commit()
            .await
            .map_err(LinkModerationError::Database)?;
        Ok(true)
    }

    pub async fn unblock_link(&self, id: Uuid) -> Result<bool, LinkModerationError> {
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(LinkModerationError::Database)?;
        let result = sqlx::query(
            r#"
            UPDATE links
            SET status = 'active', blocked_reason = NULL, blocked_at = NULL,
                blocked_by = NULL, updated_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL AND status = 'blocked'
            "#,
        )
        .bind(id)
        .execute(&mut *transaction)
        .await
        .map_err(LinkModerationError::Database)?;
        if result.rows_affected() == 0 {
            return Ok(false);
        }
        insert_audit(&mut transaction, "link.unblocked", "link", Some(id)).await?;
        transaction
            .commit()
            .await
            .map_err(LinkModerationError::Database)?;
        Ok(true)
    }

    pub async fn dismiss_report(&self, id: Uuid) -> Result<bool, LinkModerationError> {
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(LinkModerationError::Database)?;
        let result = sqlx::query(
            "UPDATE link_reports SET status = 'dismissed', reviewed_at = NOW() WHERE id = $1 AND status = 'pending'",
        )
        .bind(id)
        .execute(&mut *transaction)
        .await
        .map_err(LinkModerationError::Database)?;
        if result.rows_affected() == 0 {
            return Ok(false);
        }
        insert_audit(
            &mut transaction,
            "link_report.dismissed",
            "link_report",
            Some(id),
        )
        .await?;
        transaction
            .commit()
            .await
            .map_err(LinkModerationError::Database)?;
        Ok(true)
    }
}

async fn insert_audit(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    action: &str,
    target_type: &str,
    target_id: Option<Uuid>,
) -> Result<(), LinkModerationError> {
    sqlx::query(
        "INSERT INTO security_audit_log (id, actor_type, action, target_type, target_id) VALUES ($1, 'admin', $2, $3, $4)",
    )
    .bind(Uuid::new_v4())
    .bind(action)
    .bind(target_type)
    .bind(target_id)
    .execute(&mut **transaction)
    .await
    .map_err(LinkModerationError::Database)?;
    Ok(())
}

pub enum LinkModerationError {
    Database(sqlx::Error),
}

impl fmt::Debug for LinkModerationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for LinkModerationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("link moderation operation failed")
    }
}

impl Error for LinkModerationError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Database(error) => Some(error),
        }
    }
}
