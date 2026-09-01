use std::{error::Error, fmt};

pub const MAX_EMAIL_LENGTH: usize = 320;
pub const MAX_EMAIL_LOCAL_PART_LENGTH: usize = 64;
pub const MAX_EMAIL_DOMAIN_LENGTH: usize = 255;

#[derive(Clone, Eq, PartialEq)]
pub struct Email(String);

impl Email {
    pub fn parse(value: impl AsRef<str>) -> Result<Self, EmailError> {
        let value = value.as_ref().trim().to_ascii_lowercase();
        if value.is_empty() {
            return Err(EmailError::Empty);
        }
        if value.chars().count() > MAX_EMAIL_LENGTH {
            return Err(EmailError::TooLong);
        }

        let (local, domain) = value.split_once('@').ok_or(EmailError::InvalidLocalPart)?;
        if domain.contains('@') || !valid_local_part(local) {
            return Err(EmailError::InvalidLocalPart);
        }
        if !valid_domain(domain) {
            return Err(EmailError::InvalidDomain);
        }

        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Debug for Email {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("Email([REDACTED])")
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum EmailError {
    Empty,
    TooLong,
    InvalidLocalPart,
    InvalidDomain,
}

impl fmt::Display for EmailError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("invalid account email")
    }
}

impl Error for EmailError {}

fn valid_local_part(value: &str) -> bool {
    let length = value.chars().count();
    length > 0
        && length <= MAX_EMAIL_LOCAL_PART_LENGTH
        && !value.starts_with('.')
        && !value.ends_with('.')
        && !value.contains("..")
        && value.chars().all(|character| {
            character.is_ascii_alphanumeric()
                || matches!(
                    character,
                    '!' | '#'
                        | '$'
                        | '%'
                        | '&'
                        | '\''
                        | '*'
                        | '+'
                        | '-'
                        | '/'
                        | '='
                        | '?'
                        | '^'
                        | '_'
                        | '`'
                        | '{'
                        | '|'
                        | '}'
                        | '~'
                        | '.'
                )
        })
}

fn valid_domain(value: &str) -> bool {
    let length = value.chars().count();
    length > 0
        && length <= MAX_EMAIL_DOMAIN_LENGTH
        && value.is_ascii()
        && value.split('.').all(|label| {
            !label.is_empty()
                && label.len() <= 63
                && label
                    .bytes()
                    .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-')
                && label
                    .as_bytes()
                    .first()
                    .is_some_and(u8::is_ascii_alphanumeric)
                && label
                    .as_bytes()
                    .last()
                    .is_some_and(u8::is_ascii_alphanumeric)
        })
}

#[cfg(test)]
mod tests {
    use super::{Email, EmailError, MAX_EMAIL_LENGTH};

    #[test]
    fn normalizes_a_supported_email_without_exposing_it_in_debug() {
        let email = Email::parse("  Person+News@Example.COM  ").unwrap();

        assert_eq!(email.as_str(), "person+news@example.com");
        assert_eq!(format!("{email:?}"), "Email([REDACTED])");
    }

    #[test]
    fn rejects_invalid_local_parts_and_domains() {
        for value in [
            "missing-at.example",
            "@example.com",
            ".person@example.com",
            "person..news@example.com",
            "person name@example.com",
            "person@-example.com",
            "person@example..com",
            "person@example_underscore.com",
            "person@example.invalid_underscore",
        ] {
            assert!(
                Email::parse(value).is_err(),
                "accepted invalid email: {value}"
            );
        }
    }

    #[test]
    fn enforces_the_database_length_limit() {
        assert_eq!(
            Email::parse(format!("{}@example.com", "a".repeat(MAX_EMAIL_LENGTH))),
            Err(EmailError::TooLong)
        );
    }
}
