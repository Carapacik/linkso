CREATE TABLE users (
    id UUID PRIMARY KEY,
    email TEXT NOT NULL,
    display_name VARCHAR(120),
    password_hash TEXT NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    email_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT users_email_length CHECK (char_length(email) BETWEEN 3 AND 320),
    CONSTRAINT users_email_shape CHECK (position('@' IN email) > 1),
    CONSTRAINT users_display_name_length CHECK (
        display_name IS NULL OR char_length(display_name) BETWEEN 1 AND 120
    ),
    CONSTRAINT users_password_hash_present CHECK (char_length(password_hash) > 0),
    CONSTRAINT users_status_allowed CHECK (status IN ('pending', 'active', 'disabled'))
);

CREATE UNIQUE INDEX users_email_unique
    ON users (lower(email))
    WHERE deleted_at IS NULL;

CREATE TABLE user_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT user_sessions_token_hash_present CHECK (char_length(token_hash) >= 32),
    CONSTRAINT user_sessions_expiration CHECK (expires_at > created_at),
    CONSTRAINT user_sessions_last_seen CHECK (last_seen_at >= created_at),
    CONSTRAINT user_sessions_revoked CHECK (revoked_at IS NULL OR revoked_at >= created_at)
);

CREATE INDEX user_sessions_user_id_idx ON user_sessions (user_id);
CREATE INDEX user_sessions_expires_at_idx ON user_sessions (expires_at);
