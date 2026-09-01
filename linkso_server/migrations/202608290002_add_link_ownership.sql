ALTER TABLE links
ADD CONSTRAINT links_owner_foreign_key
FOREIGN KEY (owner_id) REFERENCES users (id) ON DELETE SET NULL;

CREATE INDEX links_owner_created_idx
ON links (owner_id, created_at DESC, id DESC)
WHERE deleted_at IS NULL;

CREATE INDEX links_owner_redirect_count_idx
ON links (owner_id, redirect_count DESC, id DESC)
WHERE deleted_at IS NULL;
