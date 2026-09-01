CREATE TABLE ad_sessions (
    id UUID PRIMARY KEY,
    link_id UUID NOT NULL REFERENCES links(id) ON DELETE CASCADE,
    campaign_id UUID NOT NULL REFERENCES ad_campaigns(id) ON DELETE RESTRICT,
    unlocks_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ad_sessions_unlock_after_creation CHECK (
        unlocks_at > created_at
    ),
    CONSTRAINT ad_sessions_expire_after_unlock CHECK (
        expires_at > unlocks_at
    ),
    CONSTRAINT ad_sessions_completion CHECK (
        completed_at IS NULL OR completed_at >= unlocks_at
    )
);

CREATE INDEX ad_sessions_link_id_idx ON ad_sessions (link_id);
CREATE INDEX ad_sessions_expires_at_idx ON ad_sessions (expires_at);

CREATE TABLE ad_redirect_tickets (
    id UUID PRIMARY KEY,
    link_id UUID NOT NULL REFERENCES links(id) ON DELETE CASCADE,
    session_id UUID NOT NULL UNIQUE REFERENCES ad_sessions(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ad_redirect_tickets_expiration CHECK (
        expires_at > created_at
    ),
    CONSTRAINT ad_redirect_tickets_used_after_creation CHECK (
        used_at IS NULL OR used_at >= created_at
    )
);

CREATE INDEX ad_redirect_tickets_expires_at_idx ON ad_redirect_tickets (expires_at);
