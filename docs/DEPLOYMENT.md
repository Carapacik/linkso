# Linux deployment

This guide deploys the current HTTP build with Mailpit for test email. It contains no real host address, account, password or private environment value.

## Requirements

- Linux x86_64 with at least 2 GB RAM for runtime and free disk space for Docker images
- Git, Docker Engine, Docker Compose 2.33.1 or newer, and the Compose buildx plugin
- SSH-key access for a non-root operator
- inbound TCP 80 and SSH access; PostgreSQL, the Rust API and Mailpit remain private

Clone a verified revision into `/opt/linkso` and work from that directory.

## Private environment

Create `/opt/linkso/.env.trial` with mode `600`. Replace every placeholder and never commit the file:

```dotenv
LINKSO_ENV=development
LINKSO_HTTP_HOST=0.0.0.0
LINKSO_HTTP_PORT=8080
LINKSO_PUBLIC_BASE_URL=http://SERVER_ADDRESS
LINKSO_DATABASE_URL=postgres://linkso:URL_ENCODED_DATABASE_PASSWORD@postgres:5432/linkso
LINKSO_DATABASE_MAX_CONNECTIONS=10
LINKSO_DATABASE_ACQUIRE_TIMEOUT_SECONDS=5
LINKSO_LOG=linkso_server=info
LINKSO_COOKIE_SECURE=false
LINKSO_SMTP_HOST=mailpit
LINKSO_SMTP_PORT=1025
LINKSO_SMTP_SECURITY=none
LINKSO_SMTP_USERNAME=
LINKSO_SMTP_PASSWORD=
LINKSO_MAIL_FROM=LinkSo <noreply@linkso.test>
LINKSO_SMTP_TIMEOUT_SECONDS=10
LINKSO_SESSION_SECRET=GENERATE_AT_LEAST_32_RANDOM_BYTES
LINKSO_ADMIN_TOKEN=GENERATE_AN_INDEPENDENT_RANDOM_TOKEN
LINKSO_POSTGRES_DB=linkso
LINKSO_POSTGRES_USER=linkso
LINKSO_POSTGRES_PASSWORD=GENERATE_A_RANDOM_DATABASE_PASSWORD
LINKSO_IMAGE_TAG=RELEASE_OR_COMMIT_ID
```

The public URL must exactly match what users open in a browser. URL-encode the database password inside `LINKSO_DATABASE_URL`.

## Build and start

Build the versioned x86_64 images on a development machine or in CI and transfer/pull them to a small server. If images must be built on the host, provide at least 4 GB of available memory including swap; `docker-compose.trial.yaml` also limits Cargo to one build job.

For an on-host build, run `docker compose --env-file .env.trial -f docker-compose.trial.yaml build`. For an external build, use the same Compose configuration on an x86_64 builder, export both version-tagged images with `docker save`, transfer the archive over SSH and import it on the server with `docker load`.

```sh
docker compose --env-file .env.trial -f docker-compose.trial.yaml config --quiet
docker compose --env-file .env.trial -f docker-compose.trial.yaml up -d --no-build --wait
docker compose --env-file .env.trial -f docker-compose.trial.yaml ps
curl --fail http://127.0.0.1/health/ready
```

Only Nginx publishes port 80. Mailpit is bound to the server loopback and can be viewed through an SSH tunnel from the operator computer:

```sh
ssh -N -L 8025:127.0.0.1:8025 operator@SERVER_ADDRESS
```

Then open `http://127.0.0.1:8025` locally. Mailpit captures messages and never delivers them to real inboxes.

## Update and rollback

Before an update, record the running revision and image tag and make a verified backup. Pull or copy a verified revision, choose a new immutable image tag, validate Compose, and run `up -d --build --wait` again. Check the home page, deep links, all three redirect modes, account email through Mailpit, health, protected metrics and container logs.

Rollback only to an application version compatible with the current database schema. Change the image tag/revision and repeat the smoke checks; never remove the PostgreSQL volume as a rollback method.

## Backups

Create a restricted directory outside the repository and verify every new backup in the isolated restore database:

```sh
sudo install -d -m 700 -o operator -g operator /var/backups/linkso
LINKSO_COMPOSE_FILE=docker-compose.trial.yaml LINKSO_ENV_FILE=.env.trial \
  sh tool/sh/backup_database.sh /var/backups/linkso
LINKSO_COMPOSE_FILE=docker-compose.trial.yaml LINKSO_ENV_FILE=.env.trial \
  sh tool/sh/verify_database_restore.sh /var/backups/linkso/linkso_TIMESTAMP.dump
```

The provided `deploy/systemd/linkso-backup.service` and `.timer` schedule daily local backups with retention. They default to the production Compose/environment filenames; change both `Environment` lines to the trial filenames before installing them for this HTTP stack. Keep an encrypted copy on another machine or storage provider and test restoring it periodically.
