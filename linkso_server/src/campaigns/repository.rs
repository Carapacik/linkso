use std::{error::Error, fmt};

use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use super::{AdCampaign, WriteAdCampaign};

#[derive(Clone)]
pub struct AdCampaignRepository {
    pool: PgPool,
}

impl AdCampaignRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn create(
        &self,
        input: WriteAdCampaign,
    ) -> Result<AdCampaign, AdCampaignRepositoryError> {
        sqlx::query_as::<_, AdCampaign>(
            r#"
            INSERT INTO ad_campaigns (
                id, title, body, image_url, advertiser_url, starts_at, ends_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id, title, body, image_url, advertiser_url, starts_at, ends_at,
                      is_active, created_at, updated_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.title.as_str())
        .bind(input.body.as_str())
        .bind(input.image_url.as_ref().map(|url| url.as_str()))
        .bind(input.advertiser_url.as_str())
        .bind(input.starts_at)
        .bind(input.ends_at)
        .fetch_one(&self.pool)
        .await
        .map_err(AdCampaignRepositoryError::database)
    }

    pub async fn update(
        &self,
        id: Uuid,
        input: WriteAdCampaign,
    ) -> Result<Option<AdCampaign>, AdCampaignRepositoryError> {
        sqlx::query_as::<_, AdCampaign>(
            r#"
            UPDATE ad_campaigns
            SET title = $2,
                body = $3,
                image_url = $4,
                advertiser_url = $5,
                starts_at = $6,
                ends_at = $7,
                updated_at = NOW()
            WHERE id = $1
            RETURNING id, title, body, image_url, advertiser_url, starts_at, ends_at,
                      is_active, created_at, updated_at
            "#,
        )
        .bind(id)
        .bind(input.title.as_str())
        .bind(input.body.as_str())
        .bind(input.image_url.as_ref().map(|url| url.as_str()))
        .bind(input.advertiser_url.as_str())
        .bind(input.starts_at)
        .bind(input.ends_at)
        .fetch_optional(&self.pool)
        .await
        .map_err(AdCampaignRepositoryError::database)
    }

    pub async fn set_active(
        &self,
        id: Uuid,
        is_active: bool,
    ) -> Result<Option<AdCampaign>, AdCampaignRepositoryError> {
        sqlx::query_as::<_, AdCampaign>(
            r#"
            UPDATE ad_campaigns
            SET is_active = $2, updated_at = NOW()
            WHERE id = $1
            RETURNING id, title, body, image_url, advertiser_url, starts_at, ends_at,
                      is_active, created_at, updated_at
            "#,
        )
        .bind(id)
        .bind(is_active)
        .fetch_optional(&self.pool)
        .await
        .map_err(AdCampaignRepositoryError::database)
    }

    pub async fn find_active_at(
        &self,
        at: DateTime<Utc>,
    ) -> Result<Option<AdCampaign>, AdCampaignRepositoryError> {
        sqlx::query_as::<_, AdCampaign>(
            r#"
            SELECT id, title, body, image_url, advertiser_url, starts_at, ends_at,
                   is_active, created_at, updated_at
            FROM ad_campaigns
            WHERE is_active = TRUE
              AND starts_at <= $1
              AND ends_at > $1
            ORDER BY starts_at DESC, created_at DESC, id
            LIMIT 1
            "#,
        )
        .bind(at)
        .fetch_optional(&self.pool)
        .await
        .map_err(AdCampaignRepositoryError::database)
    }
}

pub struct AdCampaignRepositoryError(sqlx::Error);

impl AdCampaignRepositoryError {
    fn database(error: sqlx::Error) -> Self {
        Self(error)
    }
}

impl fmt::Debug for AdCampaignRepositoryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for AdCampaignRepositoryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("advertising campaign database operation failed")
    }
}

impl Error for AdCampaignRepositoryError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        Some(&self.0)
    }
}
