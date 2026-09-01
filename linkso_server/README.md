# LinkSo Server

The Rust/Axum API and redirect service for LinkSo. PostgreSQL stores accounts, links, sessions, rate limits and aggregated analytics.

## Run

Requires Rust 1.98, PostgreSQL 18 and environment values from `.env.example`. From the repository root, the shortest command starts PostgreSQL, Mailpit, the API and Web client:

```sh
sh tool/sh/start.sh
```

To run only the server process, start PostgreSQL, copy `.env.example` to `linkso_server/.env`, then run from this directory:

```sh
cargo run --bin linkso_server -- serve
```
