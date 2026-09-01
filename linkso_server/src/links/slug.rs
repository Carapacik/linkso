use std::{error::Error, fmt};

const SLUG_ALPHABET: &[u8; 62] = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
const UNBIASED_BYTE_LIMIT: u8 = 248;
const RANDOM_BATCH_SIZE: usize = 16;

pub const GENERATED_SLUG_LENGTH: usize = 8;
pub const MIN_SLUG_LENGTH: usize = 3;
pub const MAX_SLUG_LENGTH: usize = 64;

const RESERVED_SLUGS: &[&str] = &[
    "ad", "admin", "api", "auth", "go", "health", "p", "settings",
];

#[derive(Clone, Debug, Eq, Hash, PartialEq)]
pub struct Slug(String);

impl Slug {
    pub fn parse(value: impl Into<String>) -> Result<Self, SlugError> {
        let value = value.into();
        let length = value.len();
        if length < MIN_SLUG_LENGTH {
            return Err(SlugError::TooShort);
        }
        if length > MAX_SLUG_LENGTH {
            return Err(SlugError::TooLong);
        }

        let bytes = value.as_bytes();
        if !bytes[0].is_ascii_alphanumeric() || !bytes[length - 1].is_ascii_alphanumeric() {
            return Err(SlugError::InvalidBoundary);
        }
        if !bytes
            .iter()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
        {
            return Err(SlugError::InvalidCharacter);
        }
        if RESERVED_SLUGS
            .iter()
            .any(|reserved| value.eq_ignore_ascii_case(reserved))
        {
            return Err(SlugError::Reserved);
        }

        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }

    pub fn into_string(self) -> String {
        self.0
    }
}

impl fmt::Display for Slug {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SlugError {
    TooShort,
    TooLong,
    InvalidBoundary,
    InvalidCharacter,
    Reserved,
}

impl fmt::Display for SlugError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let message = match self {
            Self::TooShort => "slug is too short",
            Self::TooLong => "slug is too long",
            Self::InvalidBoundary => "slug must start and end with a letter or digit",
            Self::InvalidCharacter => "slug contains an invalid character",
            Self::Reserved => "slug is reserved",
        };
        formatter.write_str(message)
    }
}

impl Error for SlugError {}

pub trait SlugGenerator: Send + Sync {
    fn generate(&self) -> Result<Slug, SlugGenerationError>;
}

#[derive(Clone, Copy, Debug, Default)]
pub struct SecureSlugGenerator;

impl SlugGenerator for SecureSlugGenerator {
    fn generate(&self) -> Result<Slug, SlugGenerationError> {
        loop {
            let mut value = String::with_capacity(GENERATED_SLUG_LENGTH);

            while value.len() < GENERATED_SLUG_LENGTH {
                let mut random = [0_u8; RANDOM_BATCH_SIZE];
                getrandom::fill(&mut random).map_err(|_| SlugGenerationError)?;

                for byte in random {
                    if byte >= UNBIASED_BYTE_LIMIT {
                        continue;
                    }
                    value.push(SLUG_ALPHABET[(byte % SLUG_ALPHABET.len() as u8) as usize] as char);
                    if value.len() == GENERATED_SLUG_LENGTH {
                        break;
                    }
                }
            }

            match Slug::parse(value) {
                Ok(slug) => return Ok(slug),
                Err(SlugError::Reserved) => continue,
                Err(_) => return Err(SlugGenerationError),
            }
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct SlugGenerationError;

impl fmt::Display for SlugGenerationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("failed to generate a secure slug")
    }
}

impl Error for SlugGenerationError {}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;

    use super::{
        GENERATED_SLUG_LENGTH, MAX_SLUG_LENGTH, SecureSlugGenerator, Slug, SlugError, SlugGenerator,
    };

    #[test]
    fn accepts_canonical_custom_slugs() {
        for value in ["abc", "a8F3kd2Q", "my-link", "my_link", "A-1"] {
            assert_eq!(Slug::parse(value).unwrap().as_str(), value);
        }
    }

    #[test]
    fn rejects_invalid_and_reserved_custom_slugs() {
        assert_eq!(Slug::parse("ab"), Err(SlugError::TooShort));
        assert_eq!(
            Slug::parse("a".repeat(MAX_SLUG_LENGTH + 1)),
            Err(SlugError::TooLong)
        );
        assert_eq!(Slug::parse("-abc"), Err(SlugError::InvalidBoundary));
        assert_eq!(Slug::parse("abc_"), Err(SlugError::InvalidBoundary));
        assert_eq!(Slug::parse("ab.c"), Err(SlugError::InvalidCharacter));
        assert_eq!(Slug::parse("api"), Err(SlugError::Reserved));
        assert_eq!(Slug::parse("API"), Err(SlugError::Reserved));
        assert_eq!(Slug::parse("health"), Err(SlugError::Reserved));
    }

    #[test]
    fn secure_generator_returns_base62_slugs() {
        let generator = SecureSlugGenerator;
        let mut generated = HashSet::new();

        for _ in 0..256 {
            let slug = generator.generate().unwrap();
            assert_eq!(slug.as_str().len(), GENERATED_SLUG_LENGTH);
            assert!(
                slug.as_str()
                    .bytes()
                    .all(|byte| byte.is_ascii_alphanumeric())
            );
            assert!(generated.insert(slug));
        }
    }
}
