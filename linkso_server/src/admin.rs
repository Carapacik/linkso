use std::{error::Error, fmt};

pub const MIN_ADMIN_TOKEN_LENGTH: usize = 32;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AdministrativeRole {
    Administrator,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AdminPrincipal {
    role: AdministrativeRole,
}

impl AdminPrincipal {
    pub const fn role(self) -> AdministrativeRole {
        self.role
    }
}

#[derive(Clone)]
pub struct BootstrapAdminToken {
    secret: String,
    enabled: bool,
}

impl BootstrapAdminToken {
    pub fn parse(secret: String) -> Result<Self, BootstrapAdminTokenError> {
        if secret.len() < MIN_ADMIN_TOKEN_LENGTH {
            return Err(BootstrapAdminTokenError);
        }
        Ok(Self {
            secret,
            enabled: true,
        })
    }

    pub fn disabled() -> Self {
        Self {
            secret: String::new(),
            enabled: false,
        }
    }

    pub fn authenticate_bearer(&self, authorization: Option<&str>) -> Option<AdminPrincipal> {
        if !self.enabled {
            return None;
        }
        let provided = authorization?.strip_prefix("Bearer ")?;
        fixed_time_eq(self.secret.as_bytes(), provided.as_bytes()).then_some(AdminPrincipal {
            role: AdministrativeRole::Administrator,
        })
    }
}

impl fmt::Debug for BootstrapAdminToken {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("BootstrapAdminToken([REDACTED])")
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct BootstrapAdminTokenError;

impl fmt::Display for BootstrapAdminTokenError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "must contain at least {MIN_ADMIN_TOKEN_LENGTH} bytes"
        )
    }
}

impl Error for BootstrapAdminTokenError {}

fn fixed_time_eq(expected: &[u8], provided: &[u8]) -> bool {
    let maximum_length = expected.len().max(provided.len());
    let mut difference = expected.len() ^ provided.len();
    for index in 0..maximum_length {
        difference |= usize::from(expected.get(index).copied().unwrap_or_default())
            ^ usize::from(provided.get(index).copied().unwrap_or_default());
    }
    difference == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn authenticates_only_the_exact_bearer_token_as_an_administrator() {
        let token =
            BootstrapAdminToken::parse("a-secure-bootstrap-admin-token-12345".into()).unwrap();

        let principal = token
            .authenticate_bearer(Some("Bearer a-secure-bootstrap-admin-token-12345"))
            .unwrap();
        assert_eq!(principal.role(), AdministrativeRole::Administrator);
        assert!(token.authenticate_bearer(None).is_none());
        assert!(token.authenticate_bearer(Some("Basic token")).is_none());
        assert!(
            token
                .authenticate_bearer(Some("Bearer wrong-token"))
                .is_none()
        );
    }

    #[test]
    fn rejects_short_tokens_and_redacts_debug_output() {
        assert_eq!(
            BootstrapAdminToken::parse("too-short".into()).unwrap_err(),
            BootstrapAdminTokenError
        );
        let token =
            BootstrapAdminToken::parse("a-secure-bootstrap-admin-token-12345".into()).unwrap();
        let debug = format!("{token:?}");
        assert!(!debug.contains("a-secure"));
        assert!(debug.contains("[REDACTED]"));
    }
}
