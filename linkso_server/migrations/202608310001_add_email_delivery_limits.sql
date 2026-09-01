ALTER TABLE auth_rate_limits DROP CONSTRAINT auth_rate_limit_kind;
ALTER TABLE auth_rate_limits ADD CONSTRAINT auth_rate_limit_kind
    CHECK (kind IN ('login', 'password_reset', 'verification', 'email_change'));
