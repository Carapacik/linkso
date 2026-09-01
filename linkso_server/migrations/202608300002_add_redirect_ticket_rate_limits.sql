ALTER TABLE public_request_rate_limits
DROP CONSTRAINT public_request_rate_limit_scope;

ALTER TABLE public_request_rate_limits
ADD CONSTRAINT public_request_rate_limit_scope CHECK (scope IN (
    'direct_redirect',
    'password_session',
    'password_verify',
    'password_ticket',
    'advertising_session',
    'advertising_continue',
    'advertising_ticket',
    'link_report'
));
