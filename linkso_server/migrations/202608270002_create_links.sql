CREATE TABLE links (
    id UUID PRIMARY KEY,
    slug VARCHAR(64) NOT NULL,
    owner_id UUID,
    target_url TEXT NOT NULL,
    title VARCHAR(120),
    kind VARCHAR(16) NOT NULL,
    password_hash TEXT,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT links_slug_format CHECK (
        slug ~ '^[A-Za-z0-9][A-Za-z0-9_-]{1,62}[A-Za-z0-9]$'
    ),
    CONSTRAINT links_target_url_length CHECK (
        char_length(target_url) BETWEEN 1 AND 2048
    ),
    CONSTRAINT links_title_length CHECK (
        title IS NULL OR char_length(title) BETWEEN 1 AND 120
    ),
    CONSTRAINT links_kind_value CHECK (
        kind IN ('direct', 'password', 'advertising')
    ),
    CONSTRAINT links_status_value CHECK (
        status IN ('active', 'disabled', 'blocked')
    ),
    CONSTRAINT links_password_hash_matches_kind CHECK (
        (kind = 'password' AND password_hash IS NOT NULL)
        OR (kind <> 'password' AND password_hash IS NULL)
    )
);

CREATE UNIQUE INDEX links_slug_unique ON links (slug);
