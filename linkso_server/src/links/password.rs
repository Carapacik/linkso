use std::{error::Error, fmt};

use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier, password_hash::SaltString};

pub const MIN_LINK_PASSWORD_LENGTH: usize = 8;
pub const MAX_LINK_PASSWORD_LENGTH: usize = 128;

pub struct LinkPassword(String);

impl LinkPassword {
    pub fn parse(value: String) -> Result<Self, LinkPasswordError> {
        let length = value.chars().count();
        if length < MIN_LINK_PASSWORD_LENGTH {
            return Err(LinkPasswordError::TooShort);
        }
        if length > MAX_LINK_PASSWORD_LENGTH {
            return Err(LinkPasswordError::TooLong);
        }
        Ok(Self(value))
    }

    fn into_secret(self) -> String {
        self.0
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LinkPasswordError {
    TooShort,
    TooLong,
}

impl fmt::Display for LinkPasswordError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::TooShort => "link password is too short",
            Self::TooLong => "link password is too long",
        })
    }
}

impl Error for LinkPasswordError {}

pub struct LinkPasswordHash(String);

impl LinkPasswordHash {
    pub(crate) fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Debug for LinkPasswordHash {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("LinkPasswordHash([REDACTED])")
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct LinkPasswordHashError;

impl fmt::Display for LinkPasswordHashError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("failed to hash link password")
    }
}

impl Error for LinkPasswordHashError {}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct LinkPasswordVerifyError;

impl fmt::Display for LinkPasswordVerifyError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("failed to verify link password")
    }
}

impl Error for LinkPasswordVerifyError {}

pub async fn hash_link_password(
    password: LinkPassword,
) -> Result<LinkPasswordHash, LinkPasswordHashError> {
    tokio::task::spawn_blocking(move || {
        let mut salt_bytes = [0_u8; 16];
        getrandom::fill(&mut salt_bytes).map_err(|_| LinkPasswordHashError)?;
        let salt = SaltString::encode_b64(&salt_bytes).map_err(|_| LinkPasswordHashError)?;
        Argon2::default()
            .hash_password(password.into_secret().as_bytes(), &salt)
            .map(|hash| LinkPasswordHash(hash.to_string()))
            .map_err(|_| LinkPasswordHashError)
    })
    .await
    .map_err(|_| LinkPasswordHashError)?
}

pub async fn verify_link_password(
    password: LinkPassword,
    encoded_hash: String,
) -> Result<bool, LinkPasswordVerifyError> {
    tokio::task::spawn_blocking(move || {
        let parsed_hash = PasswordHash::new(&encoded_hash).map_err(|_| LinkPasswordVerifyError)?;
        Ok(Argon2::default()
            .verify_password(password.into_secret().as_bytes(), &parsed_hash)
            .is_ok())
    })
    .await
    .map_err(|_| LinkPasswordVerifyError)?
}

#[cfg(test)]
mod tests {
    use argon2::{Argon2, PasswordHash, PasswordVerifier};

    use super::{
        LinkPassword, LinkPasswordError, MAX_LINK_PASSWORD_LENGTH, MIN_LINK_PASSWORD_LENGTH,
        hash_link_password, verify_link_password,
    };

    #[test]
    fn validates_password_length_without_exposing_the_value() {
        assert!(matches!(
            LinkPassword::parse("x".repeat(MIN_LINK_PASSWORD_LENGTH - 1)),
            Err(LinkPasswordError::TooShort)
        ));
        assert!(LinkPassword::parse("x".repeat(MIN_LINK_PASSWORD_LENGTH)).is_ok());
        assert!(matches!(
            LinkPassword::parse("x".repeat(MAX_LINK_PASSWORD_LENGTH + 1)),
            Err(LinkPasswordError::TooLong)
        ));
    }

    #[tokio::test]
    async fn creates_unique_argon2id_phc_hashes_that_verify() {
        let first =
            hash_link_password(LinkPassword::parse("correct horse battery staple".into()).unwrap())
                .await
                .unwrap();
        let second =
            hash_link_password(LinkPassword::parse("correct horse battery staple".into()).unwrap())
                .await
                .unwrap();

        assert_ne!(first.as_str(), second.as_str());
        assert!(first.as_str().starts_with("$argon2id$v=19$"));
        assert!(!first.as_str().contains("correct horse battery staple"));
        let parsed = PasswordHash::new(first.as_str()).unwrap();
        assert!(
            Argon2::default()
                .verify_password(b"correct horse battery staple", &parsed)
                .is_ok()
        );
        assert!(
            Argon2::default()
                .verify_password(b"wrong password", &parsed)
                .is_err()
        );
    }

    #[tokio::test]
    async fn verifies_through_the_redacted_async_boundary() {
        let hash =
            hash_link_password(LinkPassword::parse("correct horse battery staple".into()).unwrap())
                .await
                .unwrap();

        assert!(
            verify_link_password(
                LinkPassword::parse("correct horse battery staple".into()).unwrap(),
                hash.as_str().to_owned(),
            )
            .await
            .unwrap()
        );
    }
}
