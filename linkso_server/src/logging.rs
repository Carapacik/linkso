use std::{error::Error, fmt};

use tracing::Dispatch;
use tracing_subscriber::EnvFilter;

use crate::config::{Config, Environment};

pub fn init(config: &Config) -> Result<(), LoggingError> {
    let dispatch = build_dispatch(config.environment(), config.log_filter())?;
    tracing::dispatcher::set_global_default(dispatch).map_err(LoggingError::SetGlobal)
}

fn build_dispatch(environment: Environment, log_filter: &str) -> Result<Dispatch, LoggingError> {
    let filter = EnvFilter::try_new(log_filter).map_err(LoggingError::InvalidFilter)?;

    let dispatch = match log_format(environment) {
        LogFormat::Compact => Dispatch::new(
            tracing_subscriber::fmt()
                .with_env_filter(filter)
                .with_target(true)
                .compact()
                .finish(),
        ),
        LogFormat::Json => Dispatch::new(
            tracing_subscriber::fmt()
                .with_env_filter(filter)
                .with_ansi(false)
                .with_target(true)
                .json()
                .flatten_event(true)
                .with_current_span(true)
                .finish(),
        ),
    };

    Ok(dispatch)
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum LogFormat {
    Compact,
    Json,
}

fn log_format(environment: Environment) -> LogFormat {
    match environment {
        Environment::Development | Environment::Test => LogFormat::Compact,
        Environment::Production => LogFormat::Json,
    }
}

#[derive(Debug)]
pub enum LoggingError {
    InvalidFilter(tracing_subscriber::filter::ParseError),
    SetGlobal(tracing::dispatcher::SetGlobalDefaultError),
}

impl fmt::Display for LoggingError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidFilter(error) => write!(formatter, "invalid LINKSO_LOG filter: {error}"),
            Self::SetGlobal(error) => write!(formatter, "failed to initialize logging: {error}"),
        }
    }
}

impl Error for LoggingError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::InvalidFilter(error) => Some(error),
            Self::SetGlobal(error) => Some(error),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn development_and_test_use_compact_logs() {
        assert_eq!(log_format(Environment::Development), LogFormat::Compact);
        assert_eq!(log_format(Environment::Test), LogFormat::Compact);
    }

    #[test]
    fn production_uses_json_logs() {
        assert_eq!(log_format(Environment::Production), LogFormat::Json);
    }

    #[test]
    fn rejects_invalid_filter() {
        let result = build_dispatch(
            Environment::Development,
            "linkso_server=definitely-not-a-level",
        );

        assert!(matches!(result, Err(LoggingError::InvalidFilter(_))));
    }

    #[test]
    fn dispatch_can_be_built_repeatedly_without_global_conflicts() {
        let first = build_dispatch(Environment::Development, "info");
        let second = build_dispatch(Environment::Production, "linkso_server=debug");

        assert!(first.is_ok());
        assert!(second.is_ok());
    }
}
