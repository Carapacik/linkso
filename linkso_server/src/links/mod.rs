use std::{error::Error, fmt, str::FromStr};

use serde::{Deserialize, Serialize};

mod advertising_flow;
mod creation_rate_limit;
mod moderation;
mod password;
mod password_flow;
mod public_rate_limit;
mod repository;
mod slug;
mod tag;
mod target_url;

pub mod http;

pub use advertising_flow::{
    AD_COUNTDOWN_SECONDS, AD_SESSION_LIFETIME_MINUTES, AD_TICKET_LIFETIME_SECONDS,
    AdvertisingContinuation, AdvertisingFlowError, AdvertisingFlowRepository,
    AdvertisingRedirectTicket, AdvertisingSession, ConsumedAdvertisingRedirect,
};
pub use creation_rate_limit::{
    ANONYMOUS_CREATION_LIMIT, AUTHENTICATED_CREATION_LIMIT, CREATION_RATE_LIMIT_WINDOW_SECONDS,
    LinkCreationRateLimitError, LinkCreationRateLimiter, LinkCreationSubject,
};
pub use moderation::{LinkModerationError, LinkModerationRepository, LinkReport, ReportReason};
pub use password::{
    LinkPassword, LinkPasswordError, LinkPasswordHash, LinkPasswordHashError,
    LinkPasswordVerifyError, MAX_LINK_PASSWORD_LENGTH, MIN_LINK_PASSWORD_LENGTH,
    hash_link_password, verify_link_password,
};
pub use password_flow::{
    ConsumedPasswordRedirect, PASSWORD_LOCK_SECONDS, PASSWORD_MAX_FAILED_ATTEMPTS,
    PASSWORD_SESSION_LIFETIME_MINUTES, PASSWORD_TICKET_LIFETIME_SECONDS, PasswordFlowError,
    PasswordFlowRepository, PasswordRedirectTicket, PasswordSession, PasswordVerification,
};
pub use public_rate_limit::{PublicRateLimitError, PublicRateLimitKind, PublicRateLimiter};
pub use repository::{
    CreateDirectLink, CreateLink, CreateLinkError, LinkRecord, LinkRepository, LinkRepositoryError,
    MAX_SLUG_ATTEMPTS, OwnedLinkExpiration, OwnedLinkPage, OwnedLinkQuery, OwnedLinkSort,
    OwnedTagSummary, PasswordHashUpdate, PublicLinkResolution, SortDirection, UpdateOwnedLink,
};
pub use slug::{
    GENERATED_SLUG_LENGTH, MAX_SLUG_LENGTH, MIN_SLUG_LENGTH, SecureSlugGenerator, Slug, SlugError,
    SlugGenerationError, SlugGenerator,
};
pub use tag::{LinkTag, LinkTagError, MAX_TAG_NAME_LENGTH, MAX_TAGS_PER_LINK};
pub use target_url::{MAX_TARGET_URL_LENGTH, TargetUrl, TargetUrlError};

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LinkKind {
    Direct,
    Password,
    Advertising,
}

impl LinkKind {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Direct => "direct",
            Self::Password => "password",
            Self::Advertising => "advertising",
        }
    }
}

impl fmt::Display for LinkKind {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

impl FromStr for LinkKind {
    type Err = ParseLinkKindError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "direct" => Ok(Self::Direct),
            "password" => Ok(Self::Password),
            "advertising" => Ok(Self::Advertising),
            _ => Err(ParseLinkKindError),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ParseLinkKindError;

impl fmt::Display for ParseLinkKindError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("invalid link kind")
    }
}

impl Error for ParseLinkKindError {}

#[derive(Clone, Copy, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LinkStatus {
    Active,
    Disabled,
    Blocked,
}

impl LinkStatus {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Disabled => "disabled",
            Self::Blocked => "blocked",
        }
    }
}

impl fmt::Display for LinkStatus {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

impl FromStr for LinkStatus {
    type Err = ParseLinkStatusError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "active" => Ok(Self::Active),
            "disabled" => Ok(Self::Disabled),
            "blocked" => Ok(Self::Blocked),
            _ => Err(ParseLinkStatusError),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ParseLinkStatusError;

impl fmt::Display for ParseLinkStatusError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("invalid link status")
    }
}

impl Error for ParseLinkStatusError {}

#[cfg(test)]
mod tests {
    use std::str::FromStr;

    use super::{LinkKind, LinkStatus};

    #[test]
    fn link_kinds_have_stable_string_representations() {
        let cases = [
            (LinkKind::Direct, "direct"),
            (LinkKind::Password, "password"),
            (LinkKind::Advertising, "advertising"),
        ];

        for (kind, value) in cases {
            assert_eq!(kind.as_str(), value);
            assert_eq!(kind.to_string(), value);
            assert_eq!(LinkKind::from_str(value), Ok(kind));
            assert_eq!(
                serde_json::to_string(&kind).unwrap(),
                format!(r#""{value}""#)
            );
            assert_eq!(
                serde_json::from_str::<LinkKind>(&format!(r#""{value}""#)).unwrap(),
                kind
            );
        }
    }

    #[test]
    fn link_kind_rejects_non_canonical_values_without_fallback() {
        for value in ["", "DIRECT", "Direct", " direct", "direct ", "unknown"] {
            let error = LinkKind::from_str(value).unwrap_err();
            assert_eq!(error.to_string(), "invalid link kind");
        }
    }

    #[test]
    fn link_statuses_have_stable_string_representations() {
        let cases = [
            (LinkStatus::Active, "active"),
            (LinkStatus::Disabled, "disabled"),
            (LinkStatus::Blocked, "blocked"),
        ];

        for (status, value) in cases {
            assert_eq!(status.as_str(), value);
            assert_eq!(status.to_string(), value);
            assert_eq!(LinkStatus::from_str(value), Ok(status));
            assert_eq!(
                serde_json::to_string(&status).unwrap(),
                format!(r#""{value}""#)
            );
            assert_eq!(
                serde_json::from_str::<LinkStatus>(&format!(r#""{value}""#)).unwrap(),
                status
            );
        }
    }

    #[test]
    fn link_status_rejects_non_canonical_values_without_fallback() {
        for value in ["", "ACTIVE", "Active", " active", "active ", "unknown"] {
            let error = LinkStatus::from_str(value).unwrap_err();
            assert_eq!(error.to_string(), "invalid link status");
        }
    }
}
