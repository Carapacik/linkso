use std::{env, fmt, net::IpAddr, time::Duration};

use url::Url;

use crate::{accounts::mail::MailConfig, admin::BootstrapAdminToken};

const ENVIRONMENT: &str = "LINKSO_ENV";
const HTTP_HOST: &str = "LINKSO_HTTP_HOST";
const HTTP_PORT: &str = "LINKSO_HTTP_PORT";
const PUBLIC_BASE_URL: &str = "LINKSO_PUBLIC_BASE_URL";
const DATABASE_URL: &str = "LINKSO_DATABASE_URL";
const DATABASE_MAX_CONNECTIONS: &str = "LINKSO_DATABASE_MAX_CONNECTIONS";
const DATABASE_ACQUIRE_TIMEOUT_SECONDS: &str = "LINKSO_DATABASE_ACQUIRE_TIMEOUT_SECONDS";
const LOG_FILTER: &str = "LINKSO_LOG";
const COOKIE_SECURE: &str = "LINKSO_COOKIE_SECURE";
const SESSION_SECRET: &str = "LINKSO_SESSION_SECRET";
const ADMIN_TOKEN: &str = "LINKSO_ADMIN_TOKEN";

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Environment {
    Development,
    Test,
    Production,
}

impl fmt::Display for Environment {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let value = match self {
            Self::Development => "development",
            Self::Test => "test",
            Self::Production => "production",
        };
        formatter.write_str(value)
    }
}

#[derive(Clone)]
pub struct Config {
    environment: Environment,
    http_host: IpAddr,
    http_port: u16,
    public_base_url: Url,
    database_url: Url,
    database_max_connections: u32,
    database_acquire_timeout: Duration,
    log_filter: String,
    cookie_secure: bool,
    session_secret: String,
    admin_token: BootstrapAdminToken,
    mail: MailConfig,
}

impl Config {
    pub fn from_env() -> Result<Self, ConfigError> {
        Self::from_lookup(|name| env::var(name).ok())
    }

    pub fn environment(&self) -> Environment {
        self.environment
    }

    pub fn http_host(&self) -> IpAddr {
        self.http_host
    }

    pub fn http_port(&self) -> u16 {
        self.http_port
    }

    pub fn public_base_url(&self) -> &Url {
        &self.public_base_url
    }

    pub fn database_url(&self) -> &Url {
        &self.database_url
    }

    pub fn database_max_connections(&self) -> u32 {
        self.database_max_connections
    }

    pub fn database_acquire_timeout(&self) -> Duration {
        self.database_acquire_timeout
    }

    pub fn log_filter(&self) -> &str {
        &self.log_filter
    }

    pub fn cookie_secure(&self) -> bool {
        self.cookie_secure
    }

    pub fn session_secret(&self) -> &str {
        &self.session_secret
    }

    pub fn admin_token(&self) -> &BootstrapAdminToken {
        &self.admin_token
    }

    pub fn mail(&self) -> &MailConfig {
        &self.mail
    }

    pub(crate) fn from_lookup<F>(lookup: F) -> Result<Self, ConfigError>
    where
        F: Fn(&str) -> Option<String>,
    {
        let required = |name| {
            lookup(name)
                .filter(|value| !value.trim().is_empty())
                .ok_or(ConfigError::Missing { name })
        };

        let environment = parse_environment(&required(ENVIRONMENT)?)?;
        let http_host = parse_value::<IpAddr>(HTTP_HOST, &required(HTTP_HOST)?)?;
        let http_port = parse_value::<u16>(HTTP_PORT, &required(HTTP_PORT)?)?;
        if http_port == 0 {
            return Err(ConfigError::invalid(HTTP_PORT, "must be greater than zero"));
        }

        let public_base_url = parse_public_base_url(&required(PUBLIC_BASE_URL)?)?;
        let database_url = parse_database_url(&required(DATABASE_URL)?)?;
        let database_max_connections = parse_value::<u32>(
            DATABASE_MAX_CONNECTIONS,
            &required(DATABASE_MAX_CONNECTIONS)?,
        )?;
        if !(1..=100).contains(&database_max_connections) {
            return Err(ConfigError::invalid(
                DATABASE_MAX_CONNECTIONS,
                "must be between 1 and 100",
            ));
        }

        let database_acquire_timeout_seconds = parse_value::<u64>(
            DATABASE_ACQUIRE_TIMEOUT_SECONDS,
            &required(DATABASE_ACQUIRE_TIMEOUT_SECONDS)?,
        )?;
        if !(1..=60).contains(&database_acquire_timeout_seconds) {
            return Err(ConfigError::invalid(
                DATABASE_ACQUIRE_TIMEOUT_SECONDS,
                "must be between 1 and 60",
            ));
        }
        let database_acquire_timeout = Duration::from_secs(database_acquire_timeout_seconds);
        let log_filter = required(LOG_FILTER)?;
        let cookie_secure = parse_bool(COOKIE_SECURE, &required(COOKIE_SECURE)?)?;
        let session_secret = required(SESSION_SECRET)?;
        if session_secret.len() < 32 {
            return Err(ConfigError::invalid(
                SESSION_SECRET,
                "must contain at least 32 bytes",
            ));
        }
        let admin_token = BootstrapAdminToken::parse(required(ADMIN_TOKEN)?)
            .map_err(|error| ConfigError::invalid(ADMIN_TOKEN, error.to_string()))?;
        let mail = MailConfig::from_lookup(&lookup, environment)?;
        if environment == Environment::Production
            && cookie_secure != (public_base_url.scheme() == "https")
        {
            return Err(ConfigError::invalid(
                COOKIE_SECURE,
                "must match the public URL scheme: false for HTTP, true for HTTPS",
            ));
        }
        if public_base_url.path() != "/" {
            return Err(ConfigError::invalid(
                PUBLIC_BASE_URL,
                "must be an origin without a path prefix",
            ));
        }

        Ok(Self {
            environment,
            http_host,
            http_port,
            public_base_url,
            database_url,
            database_max_connections,
            database_acquire_timeout,
            log_filter,
            cookie_secure,
            session_secret,
            admin_token,
            mail,
        })
    }
}

impl fmt::Debug for Config {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("Config")
            .field("environment", &self.environment)
            .field("http_host", &self.http_host)
            .field("http_port", &self.http_port)
            .field("public_base_url", &self.public_base_url)
            .field("database_url", &"[REDACTED]")
            .field("database_max_connections", &self.database_max_connections)
            .field("database_acquire_timeout", &self.database_acquire_timeout)
            .field("log_filter", &self.log_filter)
            .field("cookie_secure", &self.cookie_secure)
            .field("session_secret", &"[REDACTED]")
            .field("admin_token", &"[REDACTED]")
            .finish()
    }
}

#[derive(Debug, Eq, PartialEq)]
pub enum ConfigError {
    Missing { name: &'static str },
    Invalid { name: &'static str, reason: String },
}

impl ConfigError {
    pub(crate) fn invalid(name: &'static str, reason: impl Into<String>) -> Self {
        Self::Invalid {
            name,
            reason: reason.into(),
        }
    }
}

impl fmt::Display for ConfigError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Missing { name } => write!(formatter, "missing environment variable {name}"),
            Self::Invalid { name, reason } => {
                write!(formatter, "invalid environment variable {name}: {reason}")
            }
        }
    }
}

impl std::error::Error for ConfigError {}

fn parse_environment(value: &str) -> Result<Environment, ConfigError> {
    match value.trim().to_ascii_lowercase().as_str() {
        "development" => Ok(Environment::Development),
        "test" => Ok(Environment::Test),
        "production" => Ok(Environment::Production),
        _ => Err(ConfigError::invalid(
            ENVIRONMENT,
            "expected development, test, or production",
        )),
    }
}

fn parse_value<T>(name: &'static str, value: &str) -> Result<T, ConfigError>
where
    T: std::str::FromStr,
    T::Err: fmt::Display,
{
    value
        .trim()
        .parse::<T>()
        .map_err(|error| ConfigError::invalid(name, error.to_string()))
}

fn parse_bool(name: &'static str, value: &str) -> Result<bool, ConfigError> {
    match value.trim().to_ascii_lowercase().as_str() {
        "true" => Ok(true),
        "false" => Ok(false),
        _ => Err(ConfigError::invalid(name, "expected true or false")),
    }
}

fn parse_public_base_url(value: &str) -> Result<Url, ConfigError> {
    let url = Url::parse(value.trim())
        .map_err(|error| ConfigError::invalid(PUBLIC_BASE_URL, error.to_string()))?;

    if !matches!(url.scheme(), "http" | "https") {
        return Err(ConfigError::invalid(
            PUBLIC_BASE_URL,
            "scheme must be http or https",
        ));
    }
    if url.host().is_none() {
        return Err(ConfigError::invalid(PUBLIC_BASE_URL, "host is required"));
    }
    if !url.username().is_empty() || url.password().is_some() {
        return Err(ConfigError::invalid(
            PUBLIC_BASE_URL,
            "credentials are not allowed",
        ));
    }
    if url.query().is_some() || url.fragment().is_some() {
        return Err(ConfigError::invalid(
            PUBLIC_BASE_URL,
            "query and fragment are not allowed",
        ));
    }

    Ok(url)
}

fn parse_database_url(value: &str) -> Result<Url, ConfigError> {
    let url = Url::parse(value.trim())
        .map_err(|error| ConfigError::invalid(DATABASE_URL, error.to_string()))?;

    if !matches!(url.scheme(), "postgres" | "postgresql") {
        return Err(ConfigError::invalid(
            DATABASE_URL,
            "scheme must be postgres or postgresql",
        ));
    }
    if url.host().is_none() {
        return Err(ConfigError::invalid(DATABASE_URL, "host is required"));
    }
    if url.username().is_empty() {
        return Err(ConfigError::invalid(DATABASE_URL, "username is required"));
    }
    if url.path().trim_matches('/').is_empty() {
        return Err(ConfigError::invalid(
            DATABASE_URL,
            "database name is required",
        ));
    }

    Ok(url)
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::*;

    fn valid_values() -> HashMap<&'static str, String> {
        HashMap::from([
            (ENVIRONMENT, "development".into()),
            (HTTP_HOST, "127.0.0.1".into()),
            (HTTP_PORT, "8080".into()),
            (PUBLIC_BASE_URL, "http://localhost:8080".into()),
            (
                DATABASE_URL,
                "postgres://linkso:local_password@localhost:5432/linkso".into(),
            ),
            (DATABASE_MAX_CONNECTIONS, "10".into()),
            (DATABASE_ACQUIRE_TIMEOUT_SECONDS, "5".into()),
            (LOG_FILTER, "linkso_server=debug".into()),
            (COOKIE_SECURE, "false".into()),
            (
                SESSION_SECRET,
                "local_session_secret_with_more_than_32_bytes".into(),
            ),
            (
                ADMIN_TOKEN,
                "local_admin_token_with_more_than_32_bytes".into(),
            ),
        ])
    }

    fn from_values(values: &HashMap<&'static str, String>) -> Result<Config, ConfigError> {
        Config::from_lookup(|name| values.get(name).cloned())
    }

    #[test]
    fn loads_valid_configuration() {
        let config = from_values(&valid_values()).expect("configuration should be valid");

        assert_eq!(config.environment(), Environment::Development);
        assert_eq!(config.http_host(), "127.0.0.1".parse::<IpAddr>().unwrap());
        assert_eq!(config.http_port(), 8080);
        assert_eq!(config.public_base_url().as_str(), "http://localhost:8080/");
        assert_eq!(config.database_max_connections(), 10);
        assert_eq!(config.database_acquire_timeout(), Duration::from_secs(5));
        assert!(!config.cookie_secure());
    }

    #[test]
    fn reports_missing_variable_without_its_value() {
        let mut values = valid_values();
        values.remove(DATABASE_URL);

        assert_eq!(
            from_values(&values).unwrap_err(),
            ConfigError::Missing { name: DATABASE_URL }
        );
    }

    #[test]
    fn rejects_zero_port() {
        let mut values = valid_values();
        values.insert(HTTP_PORT, "0".into());

        assert!(matches!(
            from_values(&values),
            Err(ConfigError::Invalid {
                name: HTTP_PORT,
                ..
            })
        ));
    }

    #[test]
    fn rejects_non_http_public_url() {
        let mut values = valid_values();
        values.insert(PUBLIC_BASE_URL, "ftp://localhost".into());

        assert!(matches!(
            from_values(&values),
            Err(ConfigError::Invalid {
                name: PUBLIC_BASE_URL,
                ..
            })
        ));
    }

    #[test]
    fn rejects_non_postgres_database_url() {
        let mut values = valid_values();
        values.insert(
            DATABASE_URL,
            "mysql://linkso:password@localhost/linkso".into(),
        );

        assert!(matches!(
            from_values(&values),
            Err(ConfigError::Invalid {
                name: DATABASE_URL,
                ..
            })
        ));
    }

    #[test]
    fn rejects_zero_database_connections() {
        let mut values = valid_values();
        values.insert(DATABASE_MAX_CONNECTIONS, "0".into());

        assert!(matches!(
            from_values(&values),
            Err(ConfigError::Invalid {
                name: DATABASE_MAX_CONNECTIONS,
                ..
            })
        ));
    }

    #[test]
    fn rejects_excessive_database_acquire_timeout() {
        let mut values = valid_values();
        values.insert(DATABASE_ACQUIRE_TIMEOUT_SECONDS, "61".into());

        assert!(matches!(
            from_values(&values),
            Err(ConfigError::Invalid {
                name: DATABASE_ACQUIRE_TIMEOUT_SECONDS,
                ..
            })
        ));
    }

    #[test]
    fn rejects_short_session_secret() {
        let mut values = valid_values();
        values.insert(SESSION_SECRET, "too-short".into());

        assert!(matches!(
            from_values(&values),
            Err(ConfigError::Invalid {
                name: SESSION_SECRET,
                ..
            })
        ));
    }

    #[test]
    fn rejects_short_admin_token() {
        let mut values = valid_values();
        values.insert(ADMIN_TOKEN, "too-short".into());

        assert!(matches!(
            from_values(&values),
            Err(ConfigError::Invalid {
                name: ADMIN_TOKEN,
                ..
            })
        ));
    }

    #[test]
    fn redacts_secrets_from_debug_output() {
        let config = from_values(&valid_values()).expect("configuration should be valid");
        let debug = format!("{config:?}");

        assert!(!debug.contains("local_password"));
        assert!(!debug.contains("local_session_secret"));
        assert!(!debug.contains("local_admin_token"));
        assert_eq!(debug.matches("[REDACTED]").count(), 3);
    }

    #[test]
    fn env_example_contains_a_valid_configuration() {
        let values: HashMap<&str, String> = include_str!("../.env.example")
            .lines()
            .filter_map(|line| {
                let line = line.trim();
                if line.is_empty() || line.starts_with('#') {
                    return None;
                }
                let (name, value) = line.split_once('=')?;
                Some((name, value.to_owned()))
            })
            .collect();

        let config = Config::from_lookup(|name| values.get(name).cloned())
            .expect(".env.example should remain valid");

        assert_eq!(config.environment(), Environment::Development);
    }

    #[test]
    fn production_requires_email_and_cookies_matching_the_public_scheme() {
        let mut values = valid_values();
        values.insert(ENVIRONMENT, "production".into());
        assert!(from_values(&values).is_err());
        for (key, value) in [
            ("LINKSO_SMTP_HOST", "smtp.example.test"),
            ("LINKSO_SMTP_PORT", "587"),
            ("LINKSO_SMTP_SECURITY", "starttls"),
            ("LINKSO_SMTP_USERNAME", "user"),
            ("LINKSO_SMTP_PASSWORD", "password"),
            ("LINKSO_MAIL_FROM", "noreply@example.test"),
        ] {
            values.insert(key, value.into());
        }
        assert!(from_values(&values).is_ok());
        values.insert(COOKIE_SECURE, "true".into());
        assert!(from_values(&values).is_err());
        values.insert(COOKIE_SECURE, "false".into());
        values.insert(PUBLIC_BASE_URL, "https://example.test".into());
        assert!(from_values(&values).is_err());
        values.insert(COOKIE_SECURE, "true".into());
        assert!(from_values(&values).is_ok());
    }
}
