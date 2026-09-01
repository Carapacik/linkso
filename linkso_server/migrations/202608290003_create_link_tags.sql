CREATE TABLE tags (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT tags_name_length CHECK (CHAR_LENGTH(name) BETWEEN 1 AND 32),
    CONSTRAINT tags_normalized_name_length CHECK (CHAR_LENGTH(normalized_name) BETWEEN 1 AND 32),
    CONSTRAINT tags_owner_normalized_unique UNIQUE (owner_id, normalized_name)
);

CREATE TABLE link_tags (
    link_id UUID NOT NULL REFERENCES links (id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
    position SMALLINT NOT NULL,
    CONSTRAINT link_tags_primary_key PRIMARY KEY (link_id, tag_id),
    CONSTRAINT link_tags_position_unique UNIQUE (link_id, position),
    CONSTRAINT link_tags_position_range CHECK (position BETWEEN 0 AND 9)
);

CREATE INDEX link_tags_tag_link_idx ON link_tags (tag_id, link_id);
CREATE INDEX tags_owner_name_idx ON tags (owner_id, normalized_name, id);
