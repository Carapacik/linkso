ALTER TABLE users
ADD COLUMN locale_preference VARCHAR(8) NOT NULL DEFAULT 'system',
ADD COLUMN theme_preference VARCHAR(8) NOT NULL DEFAULT 'system',
ADD COLUMN timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
ADD CONSTRAINT users_locale_preference_allowed
    CHECK (locale_preference IN ('system', 'en', 'ru')),
ADD CONSTRAINT users_theme_preference_allowed
    CHECK (theme_preference IN ('system', 'light', 'dark')),
ADD CONSTRAINT users_timezone_allowed
    CHECK (timezone IN (
        'UTC',
        'Europe/Moscow',
        'Europe/London',
        'Europe/Berlin',
        'America/New_York',
        'America/Los_Angeles',
        'Asia/Tokyo',
        'Asia/Shanghai'
    ));

CREATE TABLE email_change_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_email TEXT NOT NULL,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT email_change_target_length CHECK (char_length(target_email) BETWEEN 3 AND 320),
    CONSTRAINT email_change_target_shape CHECK (position('@' IN target_email) > 1),
    CONSTRAINT email_change_expiration CHECK (expires_at > created_at),
    CONSTRAINT email_change_consumed CHECK (consumed_at IS NULL OR consumed_at >= created_at)
);

CREATE INDEX email_change_tokens_user_idx ON email_change_tokens (user_id);
CREATE INDEX email_change_tokens_expiry_idx ON email_change_tokens (expires_at);
