CREATE TABLE password_link_sessions (
    id UUID PRIMARY KEY,
    link_id UUID NOT NULL REFERENCES links(id) ON DELETE CASCADE,
    failed_attempts SMALLINT NOT NULL DEFAULT 0,
    blocked_until TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT password_link_sessions_failed_attempts CHECK (
        failed_attempts BETWEEN 0 AND 5
    ),
    CONSTRAINT password_link_sessions_expiration CHECK (
        expires_at > created_at
    )
);

CREATE INDEX password_link_sessions_link_id_idx
    ON password_link_sessions (link_id);
CREATE INDEX password_link_sessions_expires_at_idx
    ON password_link_sessions (expires_at);

CREATE TABLE password_redirect_tickets (
    id UUID PRIMARY KEY,
    link_id UUID NOT NULL REFERENCES links(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT password_redirect_tickets_expiration CHECK (
        expires_at > created_at
    ),
    CONSTRAINT password_redirect_tickets_used_after_creation CHECK (
        used_at IS NULL OR used_at >= created_at
    )
);

CREATE INDEX password_redirect_tickets_expires_at_idx
    ON password_redirect_tickets (expires_at);
