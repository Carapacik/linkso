use std::{error::Error, fmt};

use chrono::{DateTime, Utc};
use url::Url;

mod repository;

pub mod http;

pub use repository::{AdCampaignRepository, AdCampaignRepositoryError};

pub const MAX_CAMPAIGN_TITLE_LENGTH: usize = 120;
pub const MAX_CAMPAIGN_BODY_LENGTH: usize = 500;
pub const MAX_CAMPAIGN_URL_LENGTH: usize = 2048;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CampaignTitle(String);

impl CampaignTitle {
    pub fn parse(value: impl Into<String>) -> Result<Self, CampaignValidationError> {
        let value = value.into().trim().to_owned();
        validate_plain_text(&value, MAX_CAMPAIGN_TITLE_LENGTH, false)
            .map_err(CampaignValidationError::Title)?;
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CampaignBody(String);

impl CampaignBody {
    pub fn parse(value: impl Into<String>) -> Result<Self, CampaignValidationError> {
        let value = value.into().trim().to_owned();
        validate_plain_text(&value, MAX_CAMPAIGN_BODY_LENGTH, true)
            .map_err(CampaignValidationError::Body)?;
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CampaignUrl(Url);

impl CampaignUrl {
    pub fn parse(
        value: impl AsRef<str>,
        public_base_url: &Url,
        field: CampaignUrlField,
    ) -> Result<Self, CampaignValidationError> {
        let value = value.as_ref().trim();
        let error = |reason| CampaignValidationError::Url { field, reason };
        if value.is_empty() || value.len() > MAX_CAMPAIGN_URL_LENGTH {
            return Err(error(CampaignUrlError::InvalidLength));
        }
        let mut url = Url::parse(value).map_err(|_| error(CampaignUrlError::Invalid))?;
        if !matches!(url.scheme(), "http" | "https") || url.host().is_none() {
            return Err(error(CampaignUrlError::Unsupported));
        }
        if !url.username().is_empty() || url.password().is_some() {
            return Err(error(CampaignUrlError::CredentialsNotAllowed));
        }
        if matches_linkso_host(&url, public_base_url) {
            return Err(error(CampaignUrlError::LinkSoUrlNotAllowed));
        }
        url.set_fragment(None);
        Ok(Self(url))
    }

    pub fn as_str(&self) -> &str {
        self.0.as_str()
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CampaignUrlField {
    Image,
    Advertiser,
}

impl CampaignUrlField {
    pub const fn api_field(self) -> &'static str {
        match self {
            Self::Image => "image_url",
            Self::Advertiser => "advertiser_url",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CampaignTextError {
    Empty,
    TooLong,
    MarkupNotAllowed,
    ControlCharactersNotAllowed,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CampaignUrlError {
    InvalidLength,
    Invalid,
    Unsupported,
    CredentialsNotAllowed,
    LinkSoUrlNotAllowed,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CampaignValidationError {
    Title(CampaignTextError),
    Body(CampaignTextError),
    Url {
        field: CampaignUrlField,
        reason: CampaignUrlError,
    },
    InvalidPeriod,
}

impl fmt::Display for CampaignValidationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Title(_) => "invalid campaign title",
            Self::Body(_) => "invalid campaign body",
            Self::Url { .. } => "invalid campaign URL",
            Self::InvalidPeriod => "invalid campaign activity period",
        })
    }
}

impl Error for CampaignValidationError {}

#[derive(Clone, Debug)]
pub struct WriteAdCampaign {
    pub title: CampaignTitle,
    pub body: CampaignBody,
    pub image_url: Option<CampaignUrl>,
    pub advertiser_url: CampaignUrl,
    pub starts_at: DateTime<Utc>,
    pub ends_at: DateTime<Utc>,
}

impl WriteAdCampaign {
    pub fn new(
        title: CampaignTitle,
        body: CampaignBody,
        image_url: Option<CampaignUrl>,
        advertiser_url: CampaignUrl,
        starts_at: DateTime<Utc>,
        ends_at: DateTime<Utc>,
    ) -> Result<Self, CampaignValidationError> {
        if ends_at <= starts_at {
            return Err(CampaignValidationError::InvalidPeriod);
        }
        Ok(Self {
            title,
            body,
            image_url,
            advertiser_url,
            starts_at,
            ends_at,
        })
    }
}

#[derive(Clone, Debug, sqlx::FromRow)]
pub struct AdCampaign {
    pub id: uuid::Uuid,
    pub title: String,
    pub body: String,
    pub image_url: Option<String>,
    pub advertiser_url: String,
    pub starts_at: DateTime<Utc>,
    pub ends_at: DateTime<Utc>,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

fn validate_plain_text(
    value: &str,
    maximum_length: usize,
    allows_line_breaks: bool,
) -> Result<(), CampaignTextError> {
    let length = value.chars().count();
    if length == 0 {
        return Err(CampaignTextError::Empty);
    }
    if length > maximum_length {
        return Err(CampaignTextError::TooLong);
    }
    if value.contains(['<', '>']) {
        return Err(CampaignTextError::MarkupNotAllowed);
    }
    if value.chars().any(|character| {
        character.is_control() && !(allows_line_breaks && matches!(character, '\n' | '\r' | '\t'))
    }) {
        return Err(CampaignTextError::ControlCharactersNotAllowed);
    }
    Ok(())
}

fn matches_linkso_host(candidate: &Url, public_base_url: &Url) -> bool {
    let Some(candidate_host) = candidate.host_str().map(str::to_ascii_lowercase) else {
        return false;
    };
    let Some(linkso_host) = public_base_url.host_str().map(str::to_ascii_lowercase) else {
        return false;
    };
    candidate_host == linkso_host || candidate_host.ends_with(&format!(".{linkso_host}"))
}

#[cfg(test)]
mod tests {
    use chrono::Duration;

    use super::*;

    #[test]
    fn accepts_safe_plain_text_and_rejects_markup_or_controls() {
        assert_eq!(
            CampaignTitle::parse("  Summer offer  ").unwrap().as_str(),
            "Summer offer"
        );
        assert!(CampaignBody::parse("Line one\nLine two").is_ok());
        assert!(matches!(
            CampaignBody::parse("<script>alert(1)</script>"),
            Err(CampaignValidationError::Body(
                CampaignTextError::MarkupNotAllowed
            ))
        ));
        assert!(CampaignTitle::parse("bad\u{0000}text").is_err());
    }

    #[test]
    fn accepts_only_external_http_urls_without_credentials() {
        let base = Url::parse("https://linkso.su").unwrap();
        assert_eq!(
            CampaignUrl::parse(
                "https://ads.example/path#ignored",
                &base,
                CampaignUrlField::Advertiser
            )
            .unwrap()
            .as_str(),
            "https://ads.example/path"
        );
        for value in [
            "javascript:alert(1)",
            "data:text/html,bad",
            "https://user:pass@ads.example",
            "https://app.linkso.su/loop",
        ] {
            assert!(CampaignUrl::parse(value, &base, CampaignUrlField::Advertiser).is_err());
        }
    }

    #[test]
    fn activity_period_must_move_forward() {
        let now = Utc::now();
        let title = CampaignTitle::parse("Title").unwrap();
        let body = CampaignBody::parse("Body").unwrap();
        let url = CampaignUrl::parse(
            "https://ads.example",
            &Url::parse("https://linkso.su").unwrap(),
            CampaignUrlField::Advertiser,
        )
        .unwrap();
        assert!(
            WriteAdCampaign::new(title.clone(), body.clone(), None, url.clone(), now, now).is_err()
        );
        assert!(
            WriteAdCampaign::new(title, body, None, url, now, now + Duration::minutes(1)).is_ok()
        );
    }
}
