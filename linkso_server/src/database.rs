use std::{error::Error, fmt, time::Duration};

use sqlx::{PgPool, migrate::Migrator, postgres::PgPoolOptions};

use crate::config::Config;

static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct PoolSettings {
    pub max_connections: u32,
    pub acquire_timeout: Duration,
}

impl From<&Config> for PoolSettings {
    fn from(config: &Config) -> Self {
        Self {
            max_connections: config.database_max_connections(),
            acquire_timeout: config.database_acquire_timeout(),
        }
    }
}

pub async fn connect(config: &Config) -> Result<PgPool, DatabaseError> {
    let settings = PoolSettings::from(config);
    let pool = PgPoolOptions::new()
        .max_connections(settings.max_connections)
        .acquire_timeout(settings.acquire_timeout)
        .connect(config.database_url().as_str())
        .await
        .map_err(DatabaseError::connect)?;

    if let Err(error) = sqlx::query("SELECT 1").execute(&pool).await {
        pool.close().await;
        return Err(DatabaseError::verify(error));
    }

    tracing::info!(
        max_connections = settings.max_connections,
        acquire_timeout_seconds = settings.acquire_timeout.as_secs(),
        "PostgreSQL connection pool ready"
    );

    Ok(pool)
}

pub async fn migrate(pool: &PgPool) -> Result<(), DatabaseError> {
    MIGRATOR.run(pool).await.map_err(DatabaseError::migrate)?;
    tracing::info!("PostgreSQL migrations are up to date");
    Ok(())
}

pub struct DatabaseError {
    operation: &'static str,
    source: Box<dyn Error + Send + Sync>,
}

impl DatabaseError {
    fn connect(source: sqlx::Error) -> Self {
        Self {
            operation: "connect to PostgreSQL",
            source: Box::new(source),
        }
    }

    fn verify(source: sqlx::Error) -> Self {
        Self {
            operation: "verify PostgreSQL connection",
            source: Box::new(source),
        }
    }

    fn migrate(source: sqlx::migrate::MigrateError) -> Self {
        Self {
            operation: "apply PostgreSQL migrations",
            source: Box::new(source),
        }
    }
}

impl fmt::Debug for DatabaseError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for DatabaseError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "failed to {}", self.operation)
    }
}

impl Error for DatabaseError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        Some(self.source.as_ref())
    }
}

#[cfg(test)]
mod tests {
    use std::{collections::HashMap, io, time::Duration};

    use crate::config::Config;

    use super::{DatabaseError, MIGRATOR, PoolSettings};

    #[test]
    fn migrations_are_embedded() {
        let migrations = MIGRATOR.iter().collect::<Vec<_>>();

        assert_eq!(migrations.len(), 18);
        assert_eq!(migrations[0].version, 202_608_270_001);
        assert_eq!(migrations[0].description, "initialize migrations");
        assert_eq!(migrations[1].version, 202_608_270_002);
        assert_eq!(migrations[1].description, "create links");
        assert_eq!(migrations[2].version, 202_608_280_001);
        assert_eq!(migrations[2].description, "add redirect count");
        assert_eq!(migrations[3].version, 202_608_280_002);
        assert_eq!(migrations[3].description, "create password link flow");
        assert_eq!(migrations[4].version, 202_608_280_003);
        assert_eq!(migrations[4].description, "create ad campaigns");
        assert_eq!(migrations[5].version, 202_608_280_004);
        assert_eq!(migrations[5].description, "create advertising link flow");
        assert_eq!(migrations[6].version, 202_608_280_005);
        assert_eq!(migrations[6].description, "create users and sessions");
        assert_eq!(migrations[7].version, 202_608_290_001);
        assert_eq!(migrations[7].description, "create auth lifecycle");
        assert_eq!(migrations[8].version, 202_608_290_002);
        assert_eq!(migrations[8].description, "add link ownership");
        assert_eq!(migrations[9].version, 202_608_290_003);
        assert_eq!(migrations[9].description, "create link tags");
        assert_eq!(migrations[10].version, 202_608_290_004);
        assert_eq!(migrations[10].description, "create link analytics");
        assert_eq!(migrations[11].version, 202_608_290_005);
        assert_eq!(migrations[11].description, "add user settings");
        assert_eq!(migrations[12].version, 202_608_290_006);
        assert_eq!(migrations[12].description, "add link creation rate limits");
        assert_eq!(migrations[13].version, 202_608_300_001);
        assert_eq!(migrations[13].description, "add abuse protection");
        assert_eq!(migrations[14].version, 202_608_300_002);
        assert_eq!(
            migrations[14].description,
            "add redirect ticket rate limits"
        );
        assert_eq!(migrations[15].version, 202_608_300_003);
        assert_eq!(
            migrations[15].description,
            "allow ad sessions without campaign"
        );
        assert_eq!(migrations[16].version, 202_608_300_004);
        assert_eq!(
            migrations[16].description,
            "remove server appearance preferences"
        );
    }

    #[test]
    fn startup_error_does_not_expose_database_details() {
        let source = sqlx::Error::Configuration(Box::new(io::Error::other(
            "postgres://linkso:secret@private-host/linkso",
        )));
        let error = DatabaseError::connect(source);
        let output = format!("{error:?}");

        assert_eq!(output, "failed to connect to PostgreSQL");
        assert!(!output.contains("secret"));
        assert!(!output.contains("private-host"));
    }

    #[test]
    fn migration_error_does_not_expose_database_details() {
        let source = sqlx::migrate::MigrateError::Execute(sqlx::Error::Configuration(Box::new(
            io::Error::other("postgres://linkso:secret@private-host/linkso"),
        )));
        let error = DatabaseError::migrate(source);
        let output = format!("{error:?}");

        assert_eq!(output, "failed to apply PostgreSQL migrations");
        assert!(!output.contains("secret"));
        assert!(!output.contains("private-host"));
    }

    #[test]
    fn pool_settings_are_loaded_from_the_example_configuration() {
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
            .expect("example configuration must be valid");
        let settings = PoolSettings::from(&config);

        assert_eq!(settings.max_connections, 10);
        assert_eq!(settings.acquire_timeout, Duration::from_secs(5));
    }
}
