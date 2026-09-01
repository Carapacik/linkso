use std::{collections::HashMap, error::Error, fmt, time::Duration};

use chrono::{DateTime, Duration as ChronoDuration, NaiveDate, Utc};
use serde::Serialize;
use sqlx::{FromRow, PgPool};
use tokio::task::JoinHandle;
use uuid::Uuid;

pub mod http;

pub const ANALYTICS_AGGREGATION_INTERVAL: Duration = Duration::from_secs(30);
pub const ANALYTICS_AGGREGATION_BATCH_SIZE: i64 = 1_000;
pub const ANALYTICS_RAW_RETENTION_DAYS: i64 = 7;
pub const DEFAULT_ANALYTICS_PERIOD_DAYS: u32 = 30;
pub const ALLOWED_ANALYTICS_PERIOD_DAYS: [u32; 3] = [7, 30, 90];

#[derive(Clone, Copy, Debug)]
pub struct AnalyticsPeriod {
    days: u32,
    from: NaiveDate,
    to: NaiveDate,
}

impl AnalyticsPeriod {
    pub fn new(days: u32) -> Option<Self> {
        if !ALLOWED_ANALYTICS_PERIOD_DAYS.contains(&days) {
            return None;
        }
        let to = Utc::now().date_naive();
        Some(Self {
            days,
            from: to - ChronoDuration::days(i64::from(days - 1)),
            to,
        })
    }

    pub const fn days(self) -> u32 {
        self.days
    }
}

#[derive(Debug, Serialize)]
pub struct AnalyticsPeriodResponse {
    days: u32,
    from: NaiveDate,
    to: NaiveDate,
}

#[derive(Debug, Serialize)]
pub struct AnalyticsSummary {
    links: i64,
    human_redirects: i64,
    bot_redirects: i64,
}

#[derive(Debug, Serialize)]
pub struct DailyRedirects {
    day: NaiveDate,
    human_redirects: i64,
    bot_redirects: i64,
}

#[derive(Debug, Serialize)]
pub struct AdvertisingFunnel {
    impressions: i64,
    timer_completions: i64,
    redirects: i64,
}

#[derive(Debug, Serialize)]
pub struct DashboardAnalytics {
    period: AnalyticsPeriodResponse,
    summary: AnalyticsSummary,
    series: Vec<DailyRedirects>,
    advertising_funnel: AdvertisingFunnel,
}

#[derive(Debug, Serialize)]
pub struct AnalyticsLink {
    id: Uuid,
    slug: String,
    title: Option<String>,
    kind: String,
}

#[derive(Debug, Serialize)]
pub struct LinkAnalytics {
    link: AnalyticsLink,
    period: AnalyticsPeriodResponse,
    summary: AnalyticsSummary,
    series: Vec<DailyRedirects>,
    advertising_funnel: AdvertisingFunnel,
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub enum AnalyticsEventType {
    DirectRedirect,
    PasswordPromptView,
    PasswordRejected,
    PasswordUnlocked,
    PasswordRedirect,
    AdvertisingImpression,
    AdvertisingTimerComplete,
    AdvertisingRedirect,
}

impl AnalyticsEventType {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::DirectRedirect => "direct_redirect",
            Self::PasswordPromptView => "password_prompt_view",
            Self::PasswordRejected => "password_rejected",
            Self::PasswordUnlocked => "password_unlocked",
            Self::PasswordRedirect => "password_redirect",
            Self::AdvertisingImpression => "advertising_impression",
            Self::AdvertisingTimerComplete => "advertising_timer_complete",
            Self::AdvertisingRedirect => "advertising_redirect",
        }
    }
}

#[derive(Clone)]
pub struct AnalyticsRepository {
    pool: PgPool,
}

impl AnalyticsRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn record(
        &self,
        link_id: Uuid,
        event_type: AnalyticsEventType,
        is_bot: bool,
    ) -> Result<(), AnalyticsError> {
        sqlx::query(
            r#"
            INSERT INTO link_analytics_events (id, link_id, event_type, is_bot)
            VALUES ($1, $2, $3, $4)
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(link_id)
        .bind(event_type.as_str())
        .bind(is_bot)
        .execute(&self.pool)
        .await
        .map_err(AnalyticsError::database)?;
        Ok(())
    }

    pub async fn aggregate_pending(&self, batch_size: i64) -> Result<u64, AnalyticsError> {
        let mut transaction = self.pool.begin().await.map_err(AnalyticsError::database)?;
        let events = sqlx::query_as::<_, PendingEventRow>(
            r#"
            SELECT id, link_id, event_type, occurred_at, is_bot
            FROM link_analytics_events
            WHERE aggregated_at IS NULL
            ORDER BY occurred_at, id
            LIMIT $1
            FOR UPDATE SKIP LOCKED
            "#,
        )
        .bind(batch_size.clamp(1, ANALYTICS_AGGREGATION_BATCH_SIZE))
        .fetch_all(&mut *transaction)
        .await
        .map_err(AnalyticsError::database)?;
        if events.is_empty() {
            transaction
                .commit()
                .await
                .map_err(AnalyticsError::database)?;
            return Ok(0);
        }

        let mut aggregates = HashMap::<AggregateKey, AggregateCounts>::new();
        let event_ids = events.iter().map(|event| event.id).collect::<Vec<_>>();
        for event in events {
            let key = AggregateKey {
                link_id: event.link_id,
                day: event.occurred_at.date_naive(),
                event_type: event.event_type,
            };
            let counts = aggregates.entry(key).or_default();
            if event.is_bot {
                counts.bot += 1;
            } else {
                counts.human += 1;
            }
        }
        for (key, counts) in aggregates {
            sqlx::query(
                r#"
                INSERT INTO link_daily_analytics (
                    link_id, day, event_type, human_count, bot_count
                )
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (link_id, day, event_type)
                DO UPDATE SET
                    human_count = link_daily_analytics.human_count + EXCLUDED.human_count,
                    bot_count = link_daily_analytics.bot_count + EXCLUDED.bot_count,
                    updated_at = NOW()
                "#,
            )
            .bind(key.link_id)
            .bind(key.day)
            .bind(key.event_type)
            .bind(counts.human)
            .bind(counts.bot)
            .execute(&mut *transaction)
            .await
            .map_err(AnalyticsError::database)?;
        }
        sqlx::query(
            r#"
            UPDATE links AS link
            SET redirect_count = link.redirect_count + direct.count
            FROM (
                SELECT link_id, COUNT(*)::BIGINT AS count
                FROM link_analytics_events
                WHERE id = ANY($1)
                  AND event_type = 'direct_redirect'
                GROUP BY link_id
            ) AS direct
            WHERE link.id = direct.link_id
            "#,
        )
        .bind(&event_ids)
        .execute(&mut *transaction)
        .await
        .map_err(AnalyticsError::database)?;
        sqlx::query("UPDATE link_analytics_events SET aggregated_at = NOW() WHERE id = ANY($1)")
            .bind(&event_ids)
            .execute(&mut *transaction)
            .await
            .map_err(AnalyticsError::database)?;
        transaction
            .commit()
            .await
            .map_err(AnalyticsError::database)?;
        Ok(event_ids.len() as u64)
    }

    pub async fn delete_expired_raw_events(&self) -> Result<u64, AnalyticsError> {
        sqlx::query(
            r#"
            DELETE FROM link_analytics_events
            WHERE aggregated_at IS NOT NULL
              AND occurred_at < NOW() - make_interval(days => $1)
            "#,
        )
        .bind(i32::try_from(ANALYTICS_RAW_RETENTION_DAYS).expect("retention fits i32"))
        .execute(&self.pool)
        .await
        .map(|result| result.rows_affected())
        .map_err(AnalyticsError::database)
    }

    pub async fn dashboard(
        &self,
        owner_id: Uuid,
        period: AnalyticsPeriod,
    ) -> Result<DashboardAnalytics, AnalyticsError> {
        let links = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM links WHERE owner_id = $1 AND deleted_at IS NULL",
        )
        .bind(owner_id)
        .fetch_one(&self.pool)
        .await
        .map_err(AnalyticsError::database)?;
        let rows = self.analytics_rows(owner_id, None, period).await?;
        Ok(build_dashboard(period, links, rows))
    }

    pub async fn link(
        &self,
        owner_id: Uuid,
        link_id: Uuid,
        period: AnalyticsPeriod,
    ) -> Result<Option<LinkAnalytics>, AnalyticsError> {
        let link = sqlx::query_as::<_, AnalyticsLinkRow>(
            r#"
            SELECT id, slug, title, kind
            FROM links
            WHERE id = $1 AND owner_id = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(link_id)
        .bind(owner_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(AnalyticsError::database)?;
        let Some(link) = link else {
            return Ok(None);
        };
        let rows = self.analytics_rows(owner_id, Some(link_id), period).await?;
        let dashboard = build_dashboard(period, 1, rows);
        Ok(Some(LinkAnalytics {
            link: AnalyticsLink {
                id: link.id,
                slug: link.slug,
                title: link.title,
                kind: link.kind,
            },
            period: dashboard.period,
            summary: dashboard.summary,
            series: dashboard.series,
            advertising_funnel: dashboard.advertising_funnel,
        }))
    }

    async fn analytics_rows(
        &self,
        owner_id: Uuid,
        link_id: Option<Uuid>,
        period: AnalyticsPeriod,
    ) -> Result<Vec<AnalyticsDayRow>, AnalyticsError> {
        sqlx::query_as::<_, AnalyticsDayRow>(
            r#"
            SELECT
                analytics.day,
                COALESCE(SUM(analytics.human_count) FILTER (
                    WHERE analytics.event_type IN (
                        'direct_redirect', 'password_redirect', 'advertising_redirect'
                    )
                ), 0)::BIGINT AS human_redirects,
                COALESCE(SUM(analytics.bot_count) FILTER (
                    WHERE analytics.event_type IN (
                        'direct_redirect', 'password_redirect', 'advertising_redirect'
                    )
                ), 0)::BIGINT AS bot_redirects,
                COALESCE(SUM(analytics.human_count) FILTER (
                    WHERE analytics.event_type = 'advertising_impression'
                ), 0)::BIGINT AS advertising_impressions,
                COALESCE(SUM(analytics.human_count) FILTER (
                    WHERE analytics.event_type = 'advertising_timer_complete'
                ), 0)::BIGINT AS advertising_timer_completions,
                COALESCE(SUM(analytics.human_count) FILTER (
                    WHERE analytics.event_type = 'advertising_redirect'
                ), 0)::BIGINT AS advertising_redirects
            FROM link_daily_analytics AS analytics
            INNER JOIN links ON links.id = analytics.link_id
            WHERE links.owner_id = $1
              AND ($2::UUID IS NULL OR links.id = $2)
              AND analytics.day BETWEEN $3 AND $4
            GROUP BY analytics.day
            ORDER BY analytics.day
            "#,
        )
        .bind(owner_id)
        .bind(link_id)
        .bind(period.from)
        .bind(period.to)
        .fetch_all(&self.pool)
        .await
        .map_err(AnalyticsError::database)
    }

    pub fn spawn_aggregator(&self) -> JoinHandle<()> {
        let repository = self.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(ANALYTICS_AGGREGATION_INTERVAL);
            interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
            loop {
                interval.tick().await;
                match repository
                    .aggregate_pending(ANALYTICS_AGGREGATION_BATCH_SIZE)
                    .await
                {
                    Ok(count) if count > 0 => {
                        tracing::debug!(count, "analytics events aggregated");
                    }
                    Ok(_) => {}
                    Err(error) => tracing::error!(%error, "analytics aggregation failed"),
                }
                if let Err(error) = repository.delete_expired_raw_events().await {
                    tracing::error!(%error, "analytics raw event cleanup failed");
                }
            }
        })
    }
}

fn build_dashboard(
    period: AnalyticsPeriod,
    links: i64,
    rows: Vec<AnalyticsDayRow>,
) -> DashboardAnalytics {
    let rows = rows
        .into_iter()
        .map(|row| (row.day, row))
        .collect::<HashMap<_, _>>();
    let mut series = Vec::with_capacity(period.days as usize);
    let mut human_redirects = 0;
    let mut bot_redirects = 0;
    let mut advertising_funnel = AdvertisingFunnel {
        impressions: 0,
        timer_completions: 0,
        redirects: 0,
    };
    for offset in 0..period.days {
        let day = period.from + ChronoDuration::days(i64::from(offset));
        let row = rows.get(&day);
        let human = row.map_or(0, |row| row.human_redirects);
        let bot = row.map_or(0, |row| row.bot_redirects);
        human_redirects += human;
        bot_redirects += bot;
        if let Some(row) = row {
            advertising_funnel.impressions += row.advertising_impressions;
            advertising_funnel.timer_completions += row.advertising_timer_completions;
            advertising_funnel.redirects += row.advertising_redirects;
        }
        series.push(DailyRedirects {
            day,
            human_redirects: human,
            bot_redirects: bot,
        });
    }
    DashboardAnalytics {
        period: AnalyticsPeriodResponse {
            days: period.days,
            from: period.from,
            to: period.to,
        },
        summary: AnalyticsSummary {
            links,
            human_redirects,
            bot_redirects,
        },
        series,
        advertising_funnel,
    }
}

pub fn is_obvious_bot(user_agent: Option<&str>) -> bool {
    let Some(user_agent) = user_agent else {
        return false;
    };
    let user_agent = user_agent.to_ascii_lowercase();
    [
        "bot",
        "crawler",
        "spider",
        "slurp",
        "headlesschrome",
        "facebookexternalhit",
        "preview",
    ]
    .iter()
    .any(|marker| user_agent.contains(marker))
}

#[derive(FromRow)]
struct PendingEventRow {
    id: Uuid,
    link_id: Uuid,
    event_type: String,
    occurred_at: DateTime<Utc>,
    is_bot: bool,
}

#[derive(FromRow)]
struct AnalyticsDayRow {
    day: NaiveDate,
    human_redirects: i64,
    bot_redirects: i64,
    advertising_impressions: i64,
    advertising_timer_completions: i64,
    advertising_redirects: i64,
}

#[derive(FromRow)]
struct AnalyticsLinkRow {
    id: Uuid,
    slug: String,
    title: Option<String>,
    kind: String,
}

#[derive(Eq, Hash, PartialEq)]
struct AggregateKey {
    link_id: Uuid,
    day: NaiveDate,
    event_type: String,
}

#[derive(Default)]
struct AggregateCounts {
    human: i64,
    bot: i64,
}

pub struct AnalyticsError(sqlx::Error);

impl AnalyticsError {
    fn database(error: sqlx::Error) -> Self {
        Self(error)
    }
}

impl fmt::Debug for AnalyticsError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for AnalyticsError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("analytics database operation failed")
    }
}

impl Error for AnalyticsError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        Some(&self.0)
    }
}

#[cfg(test)]
mod tests {
    use super::{AnalyticsEventType, is_obvious_bot};

    #[test]
    fn event_types_have_stable_database_values() {
        assert_eq!(
            AnalyticsEventType::DirectRedirect.as_str(),
            "direct_redirect"
        );
        assert_eq!(
            AnalyticsEventType::AdvertisingTimerComplete.as_str(),
            "advertising_timer_complete"
        );
    }

    #[test]
    fn marks_only_obvious_bot_user_agents() {
        assert!(is_obvious_bot(Some("Mozilla/5.0 Googlebot/2.1")));
        assert!(is_obvious_bot(Some("HeadlessChrome crawler")));
        assert!(!is_obvious_bot(Some(
            "Mozilla/5.0 Chrome/140 Safari/537.36"
        )));
        assert!(!is_obvious_bot(None));
    }
}
