ALTER TABLE links
ADD COLUMN blocked_reason VARCHAR(240),
ADD COLUMN blocked_at TIMESTAMPTZ,
ADD COLUMN blocked_by VARCHAR(16);

UPDATE links
SET blocked_reason = 'Legacy block', blocked_at = NOW(), blocked_by = 'system'
WHERE status = 'blocked';

ALTER TABLE links
ADD CONSTRAINT links_blocked_by_value
    CHECK (blocked_by IS NULL OR blocked_by IN ('admin', 'system')),
ADD CONSTRAINT links_blocked_state
    CHECK (
        (status = 'blocked' AND blocked_reason IS NOT NULL AND blocked_at IS NOT NULL AND blocked_by IS NOT NULL)
        OR
        (status <> 'blocked' AND blocked_reason IS NULL AND blocked_at IS NULL AND blocked_by IS NULL)
    );

CREATE TABLE public_request_rate_limits (
    scope VARCHAR(32) NOT NULL,
    key_hash VARCHAR(64) NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (scope, key_hash),
    CONSTRAINT public_request_rate_limit_scope CHECK (scope IN (
        'direct_redirect',
        'password_session',
        'password_verify',
        'advertising_session',
        'advertising_continue',
        'link_report'
    )),
    CONSTRAINT public_request_rate_limit_attempts CHECK (attempts >= 0)
);

CREATE INDEX public_request_rate_limits_updated_idx
ON public_request_rate_limits (updated_at);

CREATE TABLE link_reports (
    id UUID PRIMARY KEY,
    link_id UUID NOT NULL REFERENCES links(id) ON DELETE CASCADE,
    reporter_key_hash VARCHAR(64) NOT NULL,
    reason VARCHAR(24) NOT NULL,
    details VARCHAR(500),
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    CONSTRAINT link_report_reason CHECK (reason IN ('phishing', 'malware', 'spam', 'copyright', 'other')),
    CONSTRAINT link_report_details_length CHECK (details IS NULL OR char_length(details) BETWEEN 1 AND 500),
    CONSTRAINT link_report_status CHECK (status IN ('pending', 'dismissed', 'blocked')),
    CONSTRAINT link_report_review_state CHECK (
        (status = 'pending' AND reviewed_at IS NULL)
        OR
        (status <> 'pending' AND reviewed_at IS NOT NULL)
    ),
    UNIQUE (link_id, reporter_key_hash)
);

CREATE INDEX link_reports_status_created_idx
ON link_reports (status, created_at, id);

CREATE TABLE security_audit_log (
    id UUID PRIMARY KEY,
    actor_type VARCHAR(16) NOT NULL,
    actor_id UUID,
    action VARCHAR(64) NOT NULL,
    target_type VARCHAR(32) NOT NULL,
    target_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT security_audit_actor CHECK (actor_type IN ('user', 'admin', 'system')),
    CONSTRAINT security_audit_action_length CHECK (char_length(action) BETWEEN 1 AND 64),
    CONSTRAINT security_audit_target_type_length CHECK (char_length(target_type) BETWEEN 1 AND 32)
);

CREATE INDEX security_audit_log_created_idx
ON security_audit_log (created_at DESC, id DESC);

CREATE INDEX security_audit_log_target_idx
ON security_audit_log (target_type, target_id, created_at DESC);
