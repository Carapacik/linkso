CREATE TABLE link_creation_rate_limits (
    scope VARCHAR(16) NOT NULL,
    key_hash VARCHAR(64) NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (scope, key_hash),
    CONSTRAINT link_creation_rate_limit_scope
        CHECK (scope IN ('anonymous', 'authenticated')),
    CONSTRAINT link_creation_rate_limit_attempts CHECK (attempts >= 0)
);

CREATE INDEX link_creation_rate_limits_updated_idx
ON link_creation_rate_limits (updated_at);
