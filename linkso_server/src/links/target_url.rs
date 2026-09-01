use std::{error::Error, fmt};

use std::net::{Ipv4Addr, Ipv6Addr};

use url::{Host, Url};

pub const MAX_TARGET_URL_LENGTH: usize = 2048;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TargetUrl(Url);

impl TargetUrl {
    pub fn parse(value: &str, public_base_url: &Url) -> Result<Self, TargetUrlError> {
        let value = value.trim();
        if value.is_empty() {
            return Err(TargetUrlError::Empty);
        }
        if value.len() > MAX_TARGET_URL_LENGTH {
            return Err(TargetUrlError::TooLong);
        }

        let url = Url::parse(value).map_err(|_| TargetUrlError::Invalid)?;
        if !matches!(url.scheme(), "http" | "https") {
            return Err(TargetUrlError::UnsupportedScheme);
        }
        if url.host().is_none() {
            return Err(TargetUrlError::MissingHost);
        }
        if !url.username().is_empty() || url.password().is_some() {
            return Err(TargetUrlError::CredentialsNotAllowed);
        }
        if belongs_to_public_service(&url, public_base_url) {
            return Err(TargetUrlError::LinkSoUrlNotAllowed);
        }
        if url.host().is_some_and(is_dangerous_host) {
            return Err(TargetUrlError::DangerousHostNotAllowed);
        }

        Ok(Self(url))
    }

    pub fn as_url(&self) -> &Url {
        &self.0
    }

    pub fn as_str(&self) -> &str {
        self.0.as_str()
    }
}

fn is_dangerous_host(host: Host<&str>) -> bool {
    match host {
        Host::Domain(domain) => {
            let domain = domain.trim_end_matches('.').to_ascii_lowercase();
            !domain.contains('.')
                || domain == "localhost"
                || domain.ends_with(".localhost")
                || domain.ends_with(".local")
                || domain.ends_with(".internal")
                || domain.ends_with(".lan")
                || domain.ends_with(".home")
                || domain.ends_with(".home.arpa")
                || domain.ends_with(".corp")
                || domain.ends_with(".test")
                || domain.ends_with(".example")
                || domain.ends_with(".invalid")
        }
        Host::Ipv4(address) => is_non_public_ipv4(address),
        Host::Ipv6(address) => is_non_public_ipv6(address),
    }
}

fn is_non_public_ipv4(address: Ipv4Addr) -> bool {
    let [first, second, third, _] = address.octets();
    first == 0
        || first == 10
        || first == 127
        || (first == 100 && (64..=127).contains(&second))
        || (first == 169 && second == 254)
        || (first == 172 && (16..=31).contains(&second))
        || (first == 192 && second == 0 && third == 0)
        || (first == 192 && second == 0 && third == 2)
        || (first == 192 && second == 88 && third == 99)
        || (first == 192 && second == 168)
        || (first == 198 && (second == 18 || second == 19))
        || (first == 198 && second == 51 && third == 100)
        || (first == 203 && second == 0 && third == 113)
        || first >= 224
}

fn is_non_public_ipv6(address: Ipv6Addr) -> bool {
    if let Some(address) = address.to_ipv4_mapped() {
        return is_non_public_ipv4(address);
    }
    let [first, second, ..] = address.segments();
    address.is_unspecified()
        || address.is_loopback()
        || address.is_multicast()
        || first & 0xfe00 == 0xfc00
        || first & 0xffc0 == 0xfe80
        || (first == 0x0100 && second == 0)
        || (first == 0x2001 && second == 0x0db8)
}

impl fmt::Display for TargetUrl {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.as_str())
    }
}

fn belongs_to_public_service(target: &Url, public_base_url: &Url) -> bool {
    match (target.host(), public_base_url.host()) {
        (Some(Host::Domain(target)), Some(Host::Domain(public))) => {
            target.eq_ignore_ascii_case(public)
                || target
                    .to_ascii_lowercase()
                    .ends_with(&format!(".{}", public.to_ascii_lowercase()))
        }
        (Some(target), Some(public)) => target == public,
        _ => false,
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TargetUrlError {
    Empty,
    TooLong,
    Invalid,
    UnsupportedScheme,
    MissingHost,
    CredentialsNotAllowed,
    LinkSoUrlNotAllowed,
    DangerousHostNotAllowed,
}

impl fmt::Display for TargetUrlError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let message = match self {
            Self::Empty => "target URL is empty",
            Self::TooLong => "target URL is too long",
            Self::Invalid => "target URL is invalid",
            Self::UnsupportedScheme => "target URL scheme is not supported",
            Self::MissingHost => "target URL host is missing",
            Self::CredentialsNotAllowed => "target URL credentials are not allowed",
            Self::LinkSoUrlNotAllowed => "LinkSo URLs cannot be shortened",
            Self::DangerousHostNotAllowed => "local and non-public target hosts are not allowed",
        };
        formatter.write_str(message)
    }
}

impl Error for TargetUrlError {}

#[cfg(test)]
mod tests {
    use url::Url;

    use super::{MAX_TARGET_URL_LENGTH, TargetUrl, TargetUrlError};

    fn public_url() -> Url {
        Url::parse("https://linkso.su").unwrap()
    }

    #[test]
    fn normalizes_http_urls_and_preserves_query_and_fragment() {
        let target = TargetUrl::parse(
            "  HTTPS://Example.COM:443/path?q=hello#section  ",
            &public_url(),
        )
        .unwrap();

        assert_eq!(target.as_str(), "https://example.com/path?q=hello#section");
    }

    #[test]
    fn rejects_unsupported_or_unsafe_shapes() {
        assert_eq!(
            TargetUrl::parse("ftp://example.com/file", &public_url()),
            Err(TargetUrlError::UnsupportedScheme)
        );
        assert_eq!(
            TargetUrl::parse("https://user:secret@example.com", &public_url()),
            Err(TargetUrlError::CredentialsNotAllowed)
        );
        assert_eq!(
            TargetUrl::parse("not a url", &public_url()),
            Err(TargetUrlError::Invalid)
        );
        assert_eq!(
            TargetUrl::parse(
                &format!("https://example.com/{}", "a".repeat(MAX_TARGET_URL_LENGTH)),
                &public_url()
            ),
            Err(TargetUrlError::TooLong)
        );
    }

    #[test]
    fn rejects_linkso_host_and_subdomains() {
        for value in [
            "https://linkso.su/abc",
            "http://linkso.su:8080/abc",
            "https://api.linkso.su/abc",
        ] {
            assert_eq!(
                TargetUrl::parse(value, &public_url()),
                Err(TargetUrlError::LinkSoUrlNotAllowed)
            );
        }

        assert!(TargetUrl::parse("https://notlinkso.su", &public_url()).is_ok());
    }

    #[test]
    fn rejects_local_private_and_reserved_hosts() {
        for value in [
            "http://localhost/admin",
            "http://router.local",
            "http://router.lan",
            "http://service.home.arpa",
            "http://service.test",
            "http://intranet/path",
            "http://127.0.0.1",
            "http://10.0.0.1",
            "http://169.254.169.254/latest/meta-data",
            "http://192.168.1.1",
            "http://2130706433",
            "http://[::1]",
            "http://[fc00::1]",
            "http://[fe80::1]",
        ] {
            assert_eq!(
                TargetUrl::parse(value, &public_url()),
                Err(TargetUrlError::DangerousHostNotAllowed),
                "{value} must be rejected"
            );
        }
        assert!(TargetUrl::parse("https://1.1.1.1/path", &public_url()).is_ok());
        assert!(TargetUrl::parse("https://example.com/path", &public_url()).is_ok());
    }
}
