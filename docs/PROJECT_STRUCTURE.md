# Project structure

## Repository

```text
LinkSo/
├── linkso_client/                 Flutter Web / Android / iOS
├── linkso_server/                 Rust API and redirect server
├── deploy/
│   ├── nginx/                    Local/production routing and headers
│   └── systemd/                  Scheduled Linux database backup
├── tool/
│   ├── win/                      Windows .bat commands
│   ├── sh/                       Equivalent Linux/macOS commands
│   ├── sql/                      Isolated test database setup
│   └── brand/                    Optional SVG-to-icon generator
├── docs/
│   ├── DEPLOYMENT.md             Generic Linux deployment guide
│   └── PROJECT_STRUCTURE.md      This document
├── screenshots/                  Reference Web screenshots
├── docker-compose.yaml           Local PostgreSQL / Rust / Web / Mailpit
├── docker-compose.trial.yaml     HTTP server trial with private Mailpit
├── docker-compose.production.yaml
├── .env.example                  Local Compose configuration template
├── .env.production.example       Production template without real secrets
├── LICENSE
└── README.md                     Short overview and documentation links
```

Legacy projects/scripts, historical plans and the repository backups directory have been removed. Database exports belong outside the repository; the PostgreSQL Docker volume is independent of the source tree. Application builds do not require Node or a local `node_modules` directory.

`tool/win/start_mail.bat` and `tool/sh/start_mail.sh` start only the local Mailpit inbox; the full-stack `app` profile also includes it. Mailpit has no persistent volume and no outbound relay. Rust sends account emails through the same SMTP adapter used for external providers.

## Flutter client

```text
linkso_client/
├── lib/
│   ├── main.dart                 Flutter and local preferences initialization
│   └── src/
│       ├── app/                  Root app, router and adaptive shell
│       ├── core/
│       │   ├── api/              HTTP transport and typed errors
│       │   ├── auth/             Web/native session token storage
│       │   ├── clipboard/        Native and HTTP-compatible Web copying
│       │   ├── config/           Compile-time API_BASE_URL
│       │   ├── layout/           Material 3 window size classes
│       │   ├── localization/     BuildContext.localizations
│       │   ├── navigation/       Path URL strategy and external redirects
│       │   ├── sharing/          PNG save/share
│       │   ├── theme/            Colors, Nunito and Material text styles
│       │   └── widgets/          Flyout and CustomPainter logo
│       ├── features/
│       │   ├── home/             Landing page
│       │   ├── shorten/          Creation, result, copy and QR
│       │   ├── password_link/    Password-protected redirect
│       │   ├── advertising_link/ Ad/placeholder and countdown
│       │   ├── auth/             Register, login, verification and reset
│       │   ├── my_links/         List, filters and editing
│       │   ├── analytics/        Dashboard, charts and funnel
│       │   ├── settings/         Profile, security and local preferences
│       │   └── system_pages/     Not found / expired / disabled / blocked
│       └── l10n/                 EN/RU ARB and generated localizations
├── assets/
│   ├── branding/                 SVG and PNG logo sources
│   └── fonts/                    Nunito variable normal
├── test/                         Feature-oriented unit/widget tests
├── android/                      Native runner and launcher resources
├── ios/                          Native runner and AppIcon catalog
├── web/                          Bootstrap, manifest and transparent icons
├── .env.example                  Public compile-time configuration
├── l10n.yaml                     ARB and generated localization paths
├── pubspec.yaml
├── pubspec.lock
├── Dockerfile                    Flutter release → Nginx
└── README.md
```

Features use `data/`, `domain/` and `presentation/` where needed: API access, models/validation, and screens/controllers respectively. Internal package imports begin with `package:linkso_client/src/`.

Web uses HttpOnly-cookie sessions; native apps use secure-storage Bearer sessions. UI is shared, with separate adapters only for platform APIs. Language/theme remain local; timezone belongs to the server profile. Do not hand-edit generated localizations or logo geometry.

## Rust server

```text
linkso_server/
├── src/
│   ├── main.rs                   serve/migrate commands
│   ├── lib.rs                    Library modules
│   ├── server.rs                 Router, middleware and lifecycle
│   ├── config.rs                 Environment validation and redaction
│   ├── database.rs               PostgreSQL pool and embedded migrations
│   ├── accounts/                 Users, tokens, sessions and settings
│   │   └── mail.rs               SMTP configuration, templates, bounded queue/retries
│   ├── links/                    CRUD, redirects, rate limits, tags,
│   │                             password/ad flows and moderation
│   ├── campaigns/                Advertising campaigns and admin API
│   ├── analytics.rs              Events, UTC aggregation and retention
│   ├── analytics/http.rs         Owner-scoped dashboard API
│   ├── admin.rs                  Separate admin credential verification
│   ├── security.rs               Security headers and Origin policy
│   ├── api_error.rs              Consistent safe API errors
│   ├── request_id.rs             Request identifiers
│   ├── logging.rs                Local/JSON logging
│   ├── observability.rs          Metrics and slow-request tracing
│   └── bin/redirect_load.rs      Redirect load-test CLI
├── migrations/                   Forward-only SQL embedded into the binary
├── tests/database_health.rs      PostgreSQL/HTTP integration tests
├── openapi.yaml                  Implemented HTTP route and DTO contract
├── .env.example                  Development server configuration
├── .env.test.example             Isolated linkso_test configuration
├── Cargo.toml
├── Cargo.lock
├── Dockerfile                    Multi-stage build, non-root runtime
└── README.md                     Minimal server startup instructions
```

The server is a modular monolith. HTTP handlers validate input/permissions, repositories execute SQL, and PostgreSQL enforces persistent state and single-use operations. Only the server authorizes redirects and ad timer completion. Rust serves `/api/*` and short `/{slug}` routes; Nginx serves `/` and `/app/*` from the Flutter release.

See the [deployment guide](DEPLOYMENT.md) for the Linux HTTP stack, private Mailpit access, updates and backups.
