CREATE TABLE ad_campaigns (
    id UUID PRIMARY KEY,
    title VARCHAR(120) NOT NULL,
    body VARCHAR(500) NOT NULL,
    image_url TEXT,
    advertiser_url TEXT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT ad_campaigns_title_length CHECK (
        char_length(title) BETWEEN 1 AND 120
    ),
    CONSTRAINT ad_campaigns_body_length CHECK (
        char_length(body) BETWEEN 1 AND 500
    ),
    CONSTRAINT ad_campaigns_image_url_length CHECK (
        image_url IS NULL OR char_length(image_url) BETWEEN 1 AND 2048
    ),
    CONSTRAINT ad_campaigns_advertiser_url_length CHECK (
        char_length(advertiser_url) BETWEEN 1 AND 2048
    ),
    CONSTRAINT ad_campaigns_active_period CHECK (
        ends_at > starts_at
    )
);

CREATE INDEX ad_campaigns_active_period_idx
    ON ad_campaigns (is_active, starts_at, ends_at);
