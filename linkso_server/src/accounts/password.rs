use std::{error::Error, fmt};

use argon2::{Argon2, PasswordHash, PasswordHasher, PasswordVerifier, password_hash::SaltString};

pub const MIN_USER_PASSWORD_LENGTH: usize = 12;
pub const MAX_USER_PASSWORD_LENGTH: usize = 128;

pub struct UserPassword(String);

impl UserPassword {
    pub fn parse(value: String) -> Result<Self, UserPasswordError> {
        let length = value.chars().count();
        if length < MIN_USER_PASSWORD_LENGTH {
            return Err(UserPasswordError::TooShort);
        }
        if length > MAX_USER_PASSWORD_LENGTH {
            return Err(UserPasswordError::TooLong);
        }
        if value.chars().any(char::is_control) {
            return Err(UserPasswordError::ControlCharactersNotAllowed);
        }
        Ok(Self(value))
    }

    fn into_secret(self) -> String {
        self.0
    }
}

impl fmt::Debug for UserPassword {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("UserPassword([REDACTED])")
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum UserPasswordError {
    TooShort,
    TooLong,
    ControlCharactersNotAllowed,
}

impl fmt::Display for UserPasswordError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("invalid account password")
    }
}

impl Error for UserPasswordError {}

pub struct UserPasswordHash(String);

impl UserPasswordHash {
    pub(crate) fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Debug for UserPasswordHash {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("UserPasswordHash([REDACTED])")
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct UserPasswordHashError;

impl fmt::Display for UserPasswordHashError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("failed to hash account password")
    }
}

impl Error for UserPasswordHashError {}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct UserPasswordVerifyError;

impl fmt::Display for UserPasswordVerifyError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("failed to verify account password")
    }
}

impl Error for UserPasswordVerifyError {}

pub async fn hash_user_password(
    password: UserPassword,
) -> Result<UserPasswordHash, UserPasswordHashError> {
    tokio::task::spawn_blocking(move || {
        let mut salt_bytes = [0_u8; 16];
        getrandom::fill(&mut salt_bytes).map_err(|_| UserPasswordHashError)?;
        let salt = SaltString::encode_b64(&salt_bytes).map_err(|_| UserPasswordHashError)?;
        Argon2::default()
            .hash_password(password.into_secret().as_bytes(), &salt)
            .map(|hash| UserPasswordHash(hash.to_string()))
            .map_err(|_| UserPasswordHashError)
    })
    .await
    .map_err(|_| UserPasswordHashError)?
}

pub async fn verify_user_password(
    password: UserPassword,
    encoded_hash: String,
) -> Result<bool, UserPasswordVerifyError> {
    tokio::task::spawn_blocking(move || {
        let parsed = PasswordHash::new(&encoded_hash).map_err(|_| UserPasswordVerifyError)?;
        Ok(Argon2::default()
            .verify_password(password.into_secret().as_bytes(), &parsed)
            .is_ok())
    })
    .await
    .map_err(|_| UserPasswordVerifyError)?
}

#[cfg(test)]
mod tests {
    use argon2::{Argon2, PasswordHash, PasswordVerifier};

    use super::{
        MAX_USER_PASSWORD_LENGTH, MIN_USER_PASSWORD_LENGTH, UserPassword, UserPasswordError,
        hash_user_password,
    };

    #[test]
    fn validates_length_and_control_characters_without_exposing_the_secret() {
        assert!(matches!(
            UserPassword::parse("x".repeat(MIN_USER_PASSWORD_LENGTH - 1)),
            Err(UserPasswordError::TooShort)
        ));
        assert!(matches!(
            UserPassword::parse("x".repeat(MAX_USER_PASSWORD_LENGTH + 1)),
            Err(UserPasswordError::TooLong)
        ));
        assert!(matches!(
            UserPassword::parse("valid password\n".to_owned()),
            Err(UserPasswordError::ControlCharactersNotAllowed)
        ));
        assert_eq!(
            format!(
                "{:?}",
                UserPassword::parse("correct horse battery staple".to_owned()).unwrap()
            ),
            "UserPassword([REDACTED])"
        );
    }

    #[tokio::test]
    async fn creates_a_unique_argon2id_hash_outside_the_async_executor() {
        let plain = "correct horse battery staple";
        let first = hash_user_password(UserPassword::parse(plain.to_owned()).unwrap())
            .await
            .unwrap();
        let second = hash_user_password(UserPassword::parse(plain.to_owned()).unwrap())
            .await
            .unwrap();

        assert_ne!(first.as_str(), second.as_str());
        assert!(first.as_str().starts_with("$argon2id$v=19$"));
        assert!(!first.as_str().contains(plain));
        let parsed = PasswordHash::new(first.as_str()).unwrap();
        assert!(
            Argon2::default()
                .verify_password(plain.as_bytes(), &parsed)
                .is_ok()
        );
    }
}
