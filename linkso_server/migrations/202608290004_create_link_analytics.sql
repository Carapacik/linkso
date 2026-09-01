CREATE TABLE link_analytics_events (
    id UUID PRIMARY KEY,
    link_id UUID NOT NULL REFERENCES links (id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_bot BOOLEAN NOT NULL,
    aggregated_at TIMESTAMPTZ,
    CONSTRAINT link_analytics_events_type CHECK (
        event_type IN (
            'direct_redirect',
            'password_prompt_view',
            'password_rejected',
            'password_unlocked',
            'password_redirect',
            'advertising_impression',
            'advertising_timer_complete',
            'advertising_redirect'
        )
    )
);

CREATE INDEX link_analytics_events_pending_idx
ON link_analytics_events (occurred_at, id)
WHERE aggregated_at IS NULL;

CREATE INDEX link_analytics_events_aggregated_idx
ON link_analytics_events (aggregated_at)
WHERE aggregated_at IS NOT NULL;

CREATE TABLE link_daily_analytics (
    link_id UUID NOT NULL REFERENCES links (id) ON DELETE CASCADE,
    day DATE NOT NULL,
    event_type TEXT NOT NULL,
    human_count BIGINT NOT NULL DEFAULT 0,
    bot_count BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT link_daily_analytics_primary_key PRIMARY KEY (link_id, day, event_type),
    CONSTRAINT link_daily_analytics_type CHECK (
        event_type IN (
            'direct_redirect',
            'password_prompt_view',
            'password_rejected',
            'password_unlocked',
            'password_redirect',
            'advertising_impression',
            'advertising_timer_complete',
            'advertising_redirect'
        )
    ),
    CONSTRAINT link_daily_analytics_human_non_negative CHECK (human_count >= 0),
    CONSTRAINT link_daily_analytics_bot_non_negative CHECK (bot_count >= 0)
);

CREATE INDEX link_daily_analytics_link_day_idx
ON link_daily_analytics (link_id, day DESC, event_type);
