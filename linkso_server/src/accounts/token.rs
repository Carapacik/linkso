use std::{error::Error, fmt};

use hmac::{Hmac, KeyInit, Mac};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

#[derive(Clone)]
pub struct AuthTokenCodec {
    secret: Vec<u8>,
}

impl AuthTokenCodec {
    pub fn new(secret: impl AsRef<[u8]>) -> Result<Self, AuthTokenCodecError> {
        let secret = secret.as_ref();
        if secret.len() < 32 {
            return Err(AuthTokenCodecError);
        }
        Ok(Self {
            secret: secret.to_vec(),
        })
    }

    pub fn generate(&self, purpose: &'static str) -> Result<AuthToken, AuthTokenCodecError> {
        let mut bytes = [0_u8; 32];
        getrandom::fill(&mut bytes).map_err(|_| AuthTokenCodecError)?;
        let raw = encode_hex(&bytes);
        let hash = self.hash(purpose, &raw)?;
        Ok(AuthToken { raw, hash })
    }

    pub fn hash(&self, purpose: &'static str, value: &str) -> Result<String, AuthTokenCodecError> {
        let mut mac = HmacSha256::new_from_slice(&self.secret).map_err(|_| AuthTokenCodecError)?;
        mac.update(purpose.as_bytes());
        mac.update(&[0]);
        mac.update(value.as_bytes());
        Ok(encode_hex(&mac.finalize().into_bytes()))
    }
}

impl fmt::Debug for AuthTokenCodec {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("AuthTokenCodec([REDACTED])")
    }
}

pub struct AuthToken {
    raw: String,
    hash: String,
}

impl AuthToken {
    pub(crate) fn raw(&self) -> &str {
        &self.raw
    }

    pub(crate) fn hash(&self) -> &str {
        &self.hash
    }
}

impl fmt::Debug for AuthToken {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("AuthToken([REDACTED])")
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AuthTokenCodecError;

impl fmt::Display for AuthTokenCodecError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("failed to create a secure authentication token")
    }
}

impl Error for AuthTokenCodecError {}

fn encode_hex(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut output = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        output.push(char::from(DIGITS[usize::from(byte >> 4)]));
        output.push(char::from(DIGITS[usize::from(byte & 0x0f)]));
    }
    output
}

#[cfg(test)]
mod tests {
    use super::AuthTokenCodec;

    #[test]
    fn creates_unique_redacted_tokens_and_domain_separated_hashes() {
        let codec = AuthTokenCodec::new("a secure test secret with at least 32 bytes").unwrap();
        let first = codec.generate("session").unwrap();
        let second = codec.generate("session").unwrap();

        assert_eq!(first.raw().len(), 64);
        assert_eq!(first.hash().len(), 64);
        assert_ne!(first.raw(), second.raw());
        assert_ne!(first.hash(), second.hash());
        assert_ne!(
            codec.hash("session", first.raw()).unwrap(),
            codec.hash("password-reset", first.raw()).unwrap()
        );
        assert_eq!(format!("{codec:?}"), "AuthTokenCodec([REDACTED])");
        assert_eq!(format!("{first:?}"), "AuthToken([REDACTED])");
    }
}
