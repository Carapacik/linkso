ALTER TABLE links
ADD COLUMN redirect_count BIGINT NOT NULL DEFAULT 0,
ADD CONSTRAINT links_redirect_count_non_negative CHECK (redirect_count >= 0);
