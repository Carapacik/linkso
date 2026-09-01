use std::{env, error::Error, io};

use linkso_server::{config::Config, database, logging, server};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let command = parse_command(env::args().skip(1))?;
    load_dotenv_if_present()?;
    let config = Config::from_env()?;
    logging::init(&config)?;

    tracing::info!(
        environment = %config.environment(),
        http_host = %config.http_host(),
        http_port = config.http_port(),
        public_base_url = %config.public_base_url(),
        "LinkSo server configuration loaded"
    );

    let database = database::connect(&config).await?;
    if let Err(error) = database::migrate(&database).await {
        database.close().await;
        return Err(Box::new(error) as Box<dyn Error>);
    }
    if command == Command::Migrate {
        database.close().await;
        tracing::info!("production migration command completed");
        return Ok(());
    }
    let server_result = server::run(&config, database.clone()).await;

    database.close().await;
    tracing::info!("PostgreSQL connection pool closed");
    server_result?;

    Ok(())
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum Command {
    Serve,
    Migrate,
}

fn parse_command(arguments: impl IntoIterator<Item = String>) -> Result<Command, io::Error> {
    let arguments = arguments.into_iter().collect::<Vec<_>>();
    match arguments.as_slice() {
        [] => Ok(Command::Serve),
        [command] if command == "serve" => Ok(Command::Serve),
        [command] if command == "migrate" => Ok(Command::Migrate),
        _ => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "usage: linkso_server [serve|migrate]",
        )),
    }
}

fn load_dotenv_if_present() -> Result<(), dotenvy::Error> {
    match dotenvy::dotenv() {
        Ok(_) => Ok(()),
        Err(dotenvy::Error::Io(error)) if error.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error),
    }
}

#[cfg(test)]
mod tests {
    use super::{Command, parse_command};

    #[test]
    fn accepts_serve_and_migrate_commands_only() {
        assert_eq!(parse_command(Vec::new()).unwrap(), Command::Serve);
        assert_eq!(parse_command(["serve".to_owned()]).unwrap(), Command::Serve);
        assert_eq!(
            parse_command(["migrate".to_owned()]).unwrap(),
            Command::Migrate
        );
        assert!(parse_command(["unknown".to_owned()]).is_err());
        assert!(parse_command(["serve".to_owned(), "extra".to_owned()]).is_err());
    }
}
