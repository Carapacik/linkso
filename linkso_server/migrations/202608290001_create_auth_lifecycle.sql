CREATE TABLE email_verification_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT email_verification_expiration CHECK (expires_at > created_at),
    CONSTRAINT email_verification_consumed CHECK (consumed_at IS NULL OR consumed_at >= created_at)
);

CREATE INDEX email_verification_tokens_user_idx ON email_verification_tokens (user_id);
CREATE INDEX email_verification_tokens_expiry_idx ON email_verification_tokens (expires_at);

CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT password_reset_expiration CHECK (expires_at > created_at),
    CONSTRAINT password_reset_consumed CHECK (consumed_at IS NULL OR consumed_at >= created_at)
);

CREATE INDEX password_reset_tokens_user_idx ON password_reset_tokens (user_id);
CREATE INDEX password_reset_tokens_expiry_idx ON password_reset_tokens (expires_at);

CREATE TABLE auth_rate_limits (
    kind VARCHAR(16) NOT NULL,
    key_hash VARCHAR(64) NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    blocked_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (kind, key_hash),
    CONSTRAINT auth_rate_limit_kind CHECK (kind IN ('login', 'password_reset')),
    CONSTRAINT auth_rate_limit_attempts CHECK (attempts >= 0)
);

CREATE INDEX auth_rate_limits_blocked_idx ON auth_rate_limits (blocked_until);
