use std::{
    collections::{HashMap, VecDeque},
    env,
    path::PathBuf,
    sync::Mutex,
    time::Duration,
};

use argon2::{Argon2, PasswordHash, PasswordVerifier};
use axum::{
    body::{Body, to_bytes},
    http::{Method, Request, StatusCode, header},
};
use linkso_server::{
    admin::BootstrapAdminToken,
    analytics::{AnalyticsEventType, AnalyticsRepository},
    database,
    links::{
        ANONYMOUS_CREATION_LIMIT, AUTHENTICATED_CREATION_LIMIT, CreateDirectLink, LinkRepository,
        Slug, SlugGenerationError, SlugGenerator, TargetUrl,
    },
    request_id::X_REQUEST_ID,
    server,
};
use serde_json::{Value, json};
use sqlx::{PgPool, postgres::PgPoolOptions};
use tokio::task::JoinSet;
use tower::ServiceExt;
use url::Url;
use uuid::Uuid;

const TEST_DATABASE_URL: &str = "LINKSO_TEST_DATABASE_URL";
const TEST_DATABASE_NAME: &str = "linkso_test";

struct CapturedMail(tokio::sync::mpsc::UnboundedSender<String>);

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn failed_registration_email_can_be_resent_and_verification_tokens_expire() {
    use linkso_server::accounts::{AuthRepository, http::AuthHttpConfig, mail::MailService};
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let public_url = Url::parse("https://linkso.su").unwrap();
    let (sender, mut inbox) = tokio::sync::mpsc::unbounded_channel();
    let delivery = std::sync::Arc::new(CapturedMail(sender));
    let (failed_mail, worker) = MailService::start(
        delivery.clone(),
        "noreply@linkso.test".parse().unwrap(),
        public_url.clone(),
        Duration::from_secs(1),
    );
    worker.abort();
    let _ = worker.await;
    let failed = server::app_with_admin_and_auth(
        pool.clone(),
        public_url.clone(),
        BootstrapAdminToken::disabled(),
        AuthHttpConfig::local_test_default().with_mail(failed_mail),
    );
    let email = "retry-delivery@example.test";
    let response = post_json(
        &failed,
        "/api/v1/auth/register",
        json!({"email": email, "password": "correct horse battery staple"}),
    )
    .await;
    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    let user_id: Uuid =
        sqlx::query_scalar("SELECT id FROM users WHERE email = $1 AND status = 'pending'")
            .bind(email)
            .fetch_one(&pool)
            .await
            .unwrap();
    let (mail, worker) = MailService::start(
        delivery,
        "noreply@linkso.test".parse().unwrap(),
        public_url.clone(),
        Duration::from_secs(1),
    );
    let app = server::app_with_admin_and_auth(
        pool.clone(),
        public_url,
        BootstrapAdminToken::disabled(),
        AuthHttpConfig::local_test_default().with_mail(mail),
    );
    for expired in [true, false] {
        let response = post_json(
            &app,
            "/api/v1/auth/verification-resend",
            json!({"email": email}),
        )
        .await;
        assert_eq!(response.status(), StatusCode::ACCEPTED);
        let token = captured_token(&mut inbox, "/app/auth/verify-email", "token").await;
        if expired {
            sqlx::query("UPDATE email_verification_tokens SET created_at = NOW() - INTERVAL '2 days', expires_at = NOW() - INTERVAL '1 minute' WHERE user_id = $1").bind(user_id).execute(&pool).await.unwrap();
        }
        assert_eq!(
            post_json(&app, "/api/v1/auth/verify-email", json!({"token": token}))
                .await
                .status(),
            if expired {
                StatusCode::UNPROCESSABLE_ENTITY
            } else {
                StatusCode::OK
            }
        );
    }
    // Rotation is serialized even when requests arrive concurrently.
    let repository = AuthRepository::new(
        pool.clone(),
        AuthHttpConfig::local_test_default().token_codec(),
    );
    let mut tasks = JoinSet::new();
    for _ in 0..8 {
        let repository = repository.clone();
        tasks.spawn(async move {
            repository.issue_email_verification(user_id).await.unwrap();
        });
    }
    while let Some(result) = tasks.join_next().await {
        result.unwrap();
    }
    let pending: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM email_verification_tokens WHERE user_id = $1 AND consumed_at IS NULL",
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(pending, 1);
    drop(app);
    drop(failed);
    worker.await.unwrap();
    pool.close().await;
}

impl linkso_server::accounts::mail::MailDelivery for CapturedMail {
    fn send<'a>(
        &'a self,
        message: &'a lettre::Message,
    ) -> std::pin::Pin<
        Box<
            dyn std::future::Future<Output = Result<(), linkso_server::accounts::mail::MailError>>
                + Send
                + 'a,
        >,
    > {
        Box::pin(async move {
            self.0
                .send(String::from_utf8(message.formatted()).unwrap())
                .map_err(|_| linkso_server::accounts::mail::MailError)
        })
    }
}

async fn captured_token(
    receiver: &mut tokio::sync::mpsc::UnboundedReceiver<String>,
    path: &str,
    parameter: &str,
) -> String {
    let message = tokio::time::timeout(Duration::from_secs(3), receiver.recv())
        .await
        .unwrap()
        .unwrap();
    let decoded = message.replace("=\r\n", "").replace("=3D", "=");
    let link = decoded
        .split_whitespace()
        .find(|word| word.starts_with("https://linkso.su/app/"))
        .unwrap();
    let url = Url::parse(link).unwrap();
    assert_eq!(url.path(), path);
    assert!(url.query().is_none());
    url::form_urlencoded::parse(url.fragment().unwrap().as_bytes())
        .find(|(key, _)| key == parameter)
        .unwrap()
        .1
        .into_owned()
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn delivered_account_links_hide_tokens_and_support_resend_expiry_and_replay_checks() {
    use linkso_server::accounts::{http::AuthHttpConfig, mail::MailService};
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let (sender, mut inbox) = tokio::sync::mpsc::unbounded_channel();
    let (mail, worker) = MailService::start(
        std::sync::Arc::new(CapturedMail(sender)),
        "noreply@linkso.test".parse().unwrap(),
        Url::parse("https://linkso.su").unwrap(),
        Duration::from_secs(1),
    );
    let app = server::app_with_admin_and_auth(
        pool.clone(),
        Url::parse("https://linkso.su").unwrap(),
        BootstrapAdminToken::disabled(),
        AuthHttpConfig::new(
            "linkso local auth test secret with at least 32 bytes",
            true,
            true,
        )
        .unwrap()
        .with_mail(mail),
    );
    let email = "delivered@example.test";
    let password = "correct horse battery staple";
    let registered = post_json(
        &app,
        "/api/v1/auth/register",
        json!({"email": email, "password": password}),
    )
    .await;
    assert_eq!(registered.status(), StatusCode::CREATED);
    let body = response_json(registered).await;
    assert!(body.get("development_verification_token").is_none());
    let user_id = Uuid::parse_str(body["user"]["id"].as_str().unwrap()).unwrap();
    let old = captured_token(&mut inbox, "/app/auth/verify-email", "token").await;
    let resend = post_json(
        &app,
        "/api/v1/auth/verification-resend",
        json!({"email": email}),
    )
    .await;
    assert_eq!(response_json(resend).await, json!({"accepted": true}));
    let fresh = captured_token(&mut inbox, "/app/auth/verify-email", "token").await;
    assert_ne!(old, fresh);
    assert_eq!(
        post_json(&app, "/api/v1/auth/verify-email", json!({"token": old}))
            .await
            .status(),
        StatusCode::UNPROCESSABLE_ENTITY
    );
    assert_eq!(
        post_json(&app, "/api/v1/auth/verify-email", json!({"token": fresh}))
            .await
            .status(),
        StatusCode::OK
    );
    assert_eq!(
        post_json(&app, "/api/v1/auth/verify-email", json!({"token": fresh}))
            .await
            .status(),
        StatusCode::UNPROCESSABLE_ENTITY
    );
    let login = post_json(
        &app,
        "/api/v1/auth/login",
        json!({"email": email, "password": password}),
    )
    .await;
    assert_eq!(login.status(), StatusCode::OK);
    let cookie = login.headers()[header::SET_COOKIE]
        .to_str()
        .unwrap()
        .split(';')
        .next()
        .unwrap()
        .to_owned();
    let stale_reset = post_json(&app, "/api/v1/auth/password-reset", json!({"email": email})).await;
    assert_eq!(stale_reset.status(), StatusCode::ACCEPTED);
    let stale_reset_token = captured_token(&mut inbox, "/app/auth/password-reset", "token").await;
    for expired in [true, false] {
        let response = request_with_cookie(
            &app,
            Method::POST,
            "/api/v1/me/email-change",
            Some(json!({"email": "changed-delivered@example.test", "current_password": password})),
            &cookie,
        )
        .await;
        assert_eq!(response_json(response).await, json!({"accepted": true}));
        let token = captured_token(&mut inbox, "/app/settings", "email_token").await;
        if expired {
            sqlx::query("UPDATE email_change_tokens SET created_at = NOW() - INTERVAL '2 days', expires_at = NOW() - INTERVAL '1 minute' WHERE user_id = $1").bind(user_id).execute(&pool).await.unwrap();
        }
        let response = request_with_cookie(
            &app,
            Method::POST,
            "/api/v1/me/email-change/confirm",
            Some(json!({"token": token})),
            &cookie,
        )
        .await;
        assert_eq!(
            response.status(),
            if expired {
                StatusCode::UNPROCESSABLE_ENTITY
            } else {
                StatusCode::OK
            }
        );
        if !expired {
            assert_eq!(
                request_with_cookie(
                    &app,
                    Method::POST,
                    "/api/v1/me/email-change/confirm",
                    Some(json!({"token": token})),
                    &cookie
                )
                .await
                .status(),
                StatusCode::UNPROCESSABLE_ENTITY
            );
        }
    }
    assert_eq!(
        post_json(
            &app,
            "/api/v1/auth/password-reset/confirm",
            json!({"token": stale_reset_token, "password": "new correct horse battery staple"})
        )
        .await
        .status(),
        StatusCode::UNPROCESSABLE_ENTITY
    );
    let email = "changed-delivered@example.test";
    for expired in [true, false] {
        let unknown = post_json(
            &app,
            "/api/v1/auth/password-reset",
            json!({"email": "unknown@example.test"}),
        )
        .await;
        let known = post_json(&app, "/api/v1/auth/password-reset", json!({"email": email})).await;
        assert_eq!(known.status(), unknown.status());
        assert_eq!(response_json(known).await, response_json(unknown).await);
        let token = captured_token(&mut inbox, "/app/auth/password-reset", "token").await;
        if expired {
            sqlx::query("UPDATE password_reset_tokens SET created_at = NOW() - INTERVAL '2 hours', expires_at = NOW() - INTERVAL '1 minute' WHERE user_id = $1").bind(user_id).execute(&pool).await.unwrap();
        }
        let payload = json!({"token": token, "password": "new correct horse battery staple"});
        let response =
            post_json(&app, "/api/v1/auth/password-reset/confirm", payload.clone()).await;
        assert_eq!(
            response.status(),
            if expired {
                StatusCode::UNPROCESSABLE_ENTITY
            } else {
                StatusCode::NO_CONTENT
            }
        );
        if !expired {
            assert_eq!(
                post_json(&app, "/api/v1/auth/password-reset/confirm", payload)
                    .await
                    .status(),
                StatusCode::UNPROCESSABLE_ENTITY
            );
        }
    }
    assert_eq!(
        request_with_cookie(&app, Method::GET, "/api/v1/auth/session", None, &cookie)
            .await
            .status(),
        StatusCode::UNAUTHORIZED
    );

    // The mail worker is unavailable: public reset responses still reveal nothing.
    worker.abort();
    let _ = worker.await;
    sqlx::query("DELETE FROM auth_rate_limits")
        .execute(&pool)
        .await
        .unwrap();
    for target in [email, "unknown@example.test"] {
        let response = post_json(
            &app,
            "/api/v1/auth/password-reset",
            json!({"email": target}),
        )
        .await;
        assert_eq!(response.status(), StatusCode::ACCEPTED);
        assert_eq!(response_json(response).await, json!({"accepted": true}));
    }
    for attempt in 0..4 {
        let response = post_json(
            &app,
            "/api/v1/auth/verification-resend",
            json!({"email": "unknown-verification@example.test"}),
        )
        .await;
        assert_eq!(
            response.status(),
            if attempt < 3 {
                StatusCode::ACCEPTED
            } else {
                StatusCode::TOO_MANY_REQUESTS
            }
        );
        if attempt == 3 {
            assert!(response.headers().contains_key(header::RETRY_AFTER));
        }
    }
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn migrations_are_idempotent_in_the_test_database() {
    let pool = connect_test_database().await;

    database::migrate(&pool)
        .await
        .expect("first migration run must succeed");
    let migrations_after_first_run = applied_migration_count(&pool).await;

    database::migrate(&pool)
        .await
        .expect("repeated migration run must succeed");
    let migrations_after_second_run = applied_migration_count(&pool).await;

    assert_eq!(migrations_after_first_run, migrations_after_second_run);
    assert!(migrations_after_second_run >= 7);
    pool.close().await;
}

async fn applied_migration_count(pool: &PgPool) -> i64 {
    sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM _sqlx_migrations WHERE success = TRUE")
        .fetch_one(pool)
        .await
        .expect("migration count query must succeed")
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn health_routes_reflect_the_test_database_state() {
    let pool = connect_test_database().await;
    database::migrate(&pool)
        .await
        .expect("test database migrations must succeed");
    let app = server::app(pool.clone());

    let live = request(&app, "/health/live").await;
    assert_eq!(live.status(), StatusCode::OK);
    assert!(live.headers().contains_key(&X_REQUEST_ID));
    assert_eq!(response_body(live).await, r#"{"status":"ok"}"#);

    let ready = request(&app, "/health/ready").await;
    assert_eq!(ready.status(), StatusCode::OK);
    assert_eq!(response_body(ready).await, r#"{"status":"ready"}"#);

    pool.close().await;

    let unavailable = request(&app, "/health/ready").await;
    assert_eq!(unavailable.status(), StatusCode::SERVICE_UNAVAILABLE);
    assert!(
        response_body(unavailable)
            .await
            .contains(r#""code":"service_unavailable""#)
    );
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn direct_link_api_validates_persists_and_finds_links() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let public_base_url = Url::parse("https://linkso.su").unwrap();
    let app = server::app_with_links(pool.clone(), public_base_url);

    let created = post_json(
        &app,
        "/api/v1/links",
        json!({
            "target_url": " HTTPS://Example.COM:443/path?q=1#part ",
            "slug": "Stage3Ab",
            "title": "  Example link  "
        }),
    )
    .await;
    assert_eq!(created.status(), StatusCode::CREATED);
    assert!(created.headers().contains_key(&X_REQUEST_ID));
    assert_eq!(
        created.headers().get(header::LOCATION).unwrap(),
        "https://linkso.su/Stage3Ab"
    );
    let created = response_json(created).await;
    assert_eq!(created["slug"], "Stage3Ab");
    assert_eq!(created["short_url"], "https://linkso.su/Stage3Ab");
    assert_eq!(created["target_url"], "https://example.com/path?q=1#part");
    assert_eq!(created["title"], "Example link");
    assert_eq!(created["kind"], "direct");
    assert_eq!(created["status"], "active");
    let id = Uuid::parse_str(created["id"].as_str().unwrap()).unwrap();

    let repository = LinkRepository::new(pool.clone());
    let stored = repository
        .get_by_id(id)
        .await
        .expect("stored link lookup must succeed")
        .expect("created link must exist");
    assert_eq!(stored.slug().as_str(), "Stage3Ab");
    assert_eq!(stored.owner_id(), None);
    assert_eq!(stored.target_url(), "https://example.com/path?q=1#part");
    assert_eq!(stored.title(), Some("Example link"));

    let slug = Slug::parse("Stage3Ab").unwrap();
    assert!(
        repository
            .find_active_by_slug(&slug)
            .await
            .unwrap()
            .is_some()
    );

    sqlx::query("UPDATE links SET status = 'disabled' WHERE id = $1")
        .bind(id)
        .execute(&pool)
        .await
        .unwrap();
    assert!(
        repository
            .find_active_by_slug(&slug)
            .await
            .unwrap()
            .is_none()
    );

    sqlx::query("UPDATE links SET status = 'active', expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1")
        .bind(id)
        .execute(&pool)
        .await
        .unwrap();
    assert!(
        repository
            .find_active_by_slug(&slug)
            .await
            .unwrap()
            .is_none()
    );

    let duplicate = post_json(
        &app,
        "/api/v1/links",
        json!({"target_url": "https://example.org", "slug": "Stage3Ab"}),
    )
    .await;
    assert_api_error(duplicate, StatusCode::CONFLICT, "slug_taken", "slug").await;

    for (payload, code, field) in [
        (
            json!({"target_url": "https://example.org", "slug": "API"}),
            "reserved_slug",
            "slug",
        ),
        (
            json!({"target_url": "https://app.linkso.su/path"}),
            "linkso_target_not_allowed",
            "target_url",
        ),
        (
            json!({"target_url": "ftp://example.org/file"}),
            "invalid_target_url",
            "target_url",
        ),
    ] {
        let response = post_json(&app, "/api/v1/links", payload).await;
        assert_api_error(response, StatusCode::UNPROCESSABLE_ENTITY, code, field).await;
    }

    let generated = post_json(
        &app,
        "/api/v1/links",
        json!({"target_url": "https://example.net/generated"}),
    )
    .await;
    assert_eq!(generated.status(), StatusCode::CREATED);
    let generated = response_json(generated).await;
    let generated_slug = generated["slug"].as_str().unwrap();
    assert_eq!(generated_slug.len(), 8);
    assert!(
        generated_slug
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric())
    );

    let unique_index_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'links' AND indexname = 'links_slug_unique'",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(unique_index_count, 1);

    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn link_creation_rate_limit_is_scoped_persistent_concurrent_and_recovers() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let app = server::app(pool.clone());

    for index in 0..ANONYMOUS_CREATION_LIMIT {
        let response = post_json(
            &app,
            "/api/v1/links",
            json!({"target_url": format!("https://example.com/anonymous/{index}")}),
        )
        .await;
        assert_eq!(response.status(), StatusCode::CREATED);
    }
    let limited = post_json(
        &app,
        "/api/v1/links",
        json!({"target_url": "https://example.com/anonymous/limited"}),
    )
    .await;
    assert_eq!(limited.status(), StatusCode::TOO_MANY_REQUESTS);
    assert!(limited.headers().contains_key(header::RETRY_AFTER));
    let limited_body = response_json(limited).await;
    assert_eq!(limited_body["error"]["code"], "link_creation_rate_limited");
    assert!(
        limited_body["error"]["retry_after_seconds"]
            .as_u64()
            .unwrap()
            > 0
    );
    assert!(!limited_body.to_string().contains("127.0.0.1"));

    let restarted_app = server::app(pool.clone());
    let still_limited = post_json(
        &restarted_app,
        "/api/v1/links",
        json!({"target_url": "https://example.com/anonymous/restarted"}),
    )
    .await;
    assert_eq!(still_limited.status(), StatusCode::TOO_MANY_REQUESTS);

    sqlx::query(
        "UPDATE link_creation_rate_limits SET window_started_at = NOW() - INTERVAL '11 minutes' WHERE scope = 'anonymous'",
    )
    .execute(&pool)
    .await
    .unwrap();
    let recovered = post_json(
        &restarted_app,
        "/api/v1/links",
        json!({"target_url": "https://example.com/anonymous/recovered"}),
    )
    .await;
    assert_eq!(recovered.status(), StatusCode::CREATED);

    clear_links(&pool).await;
    let mut anonymous_tasks = JoinSet::new();
    for index in 0..(ANONYMOUS_CREATION_LIMIT + 4) {
        let app = server::app(pool.clone());
        anonymous_tasks.spawn(async move {
            post_json(
                &app,
                "/api/v1/links",
                json!({"target_url": format!("https://example.com/concurrent/{index}")}),
            )
            .await
            .status()
        });
    }
    let mut created_count = 0;
    let mut limited_count = 0;
    while let Some(result) = anonymous_tasks.join_next().await {
        match result.unwrap() {
            StatusCode::CREATED => created_count += 1,
            StatusCode::TOO_MANY_REQUESTS => limited_count += 1,
            status => panic!("unexpected concurrent creation status: {status}"),
        }
    }
    assert_eq!(created_count, ANONYMOUS_CREATION_LIMIT);
    assert_eq!(limited_count, 4);

    let (_, owner_cookie) = register_verified_user(
        &server::app(pool.clone()),
        "creation-limit@example.com",
        "correct horse battery staple",
    )
    .await;
    let authenticated_app =
        server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    for index in 0..AUTHENTICATED_CREATION_LIMIT {
        let response = request_with_cookie(
            &authenticated_app,
            Method::POST,
            "/api/v1/links",
            Some(json!({"target_url": format!("https://example.com/owner/{index}")})),
            &owner_cookie,
        )
        .await;
        assert_eq!(response.status(), StatusCode::CREATED);
    }
    let owner_limited = request_with_cookie(
        &authenticated_app,
        Method::POST,
        "/api/v1/links",
        Some(json!({"target_url": "https://example.com/owner/limited"})),
        &owner_cookie,
    )
    .await;
    assert_eq!(owner_limited.status(), StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(
        response_json(owner_limited).await["error"]["code"],
        "link_creation_rate_limited"
    );

    let rate_limit_rows: Vec<(String, String)> =
        sqlx::query_as("SELECT scope, key_hash FROM link_creation_rate_limits ORDER BY scope")
            .fetch_all(&pool)
            .await
            .unwrap();
    assert_eq!(
        rate_limit_rows
            .iter()
            .map(|(scope, _)| scope.as_str())
            .collect::<Vec<_>>(),
        ["anonymous", "authenticated"]
    );
    assert!(rate_limit_rows.iter().all(|(_, key_hash)| {
        key_hash.len() == 64
            && key_hash.bytes().all(|byte| byte.is_ascii_hexdigit())
            && !key_hash.contains("127.0.0.1")
            && !key_hash.contains("creation-limit")
    }));
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn password_link_api_hashes_the_secret_before_persistence() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let plain_password = "correct horse battery staple";

    let created = post_json(
        &app,
        "/api/v1/links",
        json!({
            "target_url": "https://example.com/private",
            "kind": "password",
            "slug": "Private42",
            "password": plain_password
        }),
    )
    .await;
    assert_eq!(created.status(), StatusCode::CREATED);
    let created = response_json(created).await;
    assert_eq!(created["kind"], "password");
    assert!(created.get("password").is_none());
    assert!(created.get("password_hash").is_none());
    let id = Uuid::parse_str(created["id"].as_str().unwrap()).unwrap();

    let stored_hash: String = sqlx::query_scalar("SELECT password_hash FROM links WHERE id = $1")
        .bind(id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(stored_hash.starts_with("$argon2id$v=19$"));
    assert!(!stored_hash.contains(plain_password));
    let parsed_hash = PasswordHash::new(&stored_hash).unwrap();
    assert!(
        Argon2::default()
            .verify_password(plain_password.as_bytes(), &parsed_hash)
            .is_ok()
    );

    for (payload, code) in [
        (
            json!({"target_url": "https://example.com", "kind": "password"}),
            "password_required",
        ),
        (
            json!({"target_url": "https://example.com", "kind": "password", "password": "short"}),
            "invalid_password",
        ),
        (
            json!({"target_url": "https://example.com", "kind": "direct", "password": plain_password}),
            "invalid_password",
        ),
    ] {
        let response = post_json(&app, "/api/v1/links", payload).await;
        assert_api_error(response, StatusCode::UNPROCESSABLE_ENTITY, code, "password").await;
    }

    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn password_flow_hides_target_limits_attempts_and_consumes_ticket_once() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());

    let created = post_json(
        &app,
        "/api/v1/links",
        json!({
            "target_url": "https://example.com/private?token=server-only",
            "kind": "password",
            "slug": "Protected42",
            "password": "correct password"
        }),
    )
    .await;
    assert_eq!(created.status(), StatusCode::CREATED);
    let link_id = Uuid::parse_str(response_json(created).await["id"].as_str().unwrap()).unwrap();

    let public_redirect = request(&app, "/Protected42").await;
    assert_eq!(public_redirect.status(), StatusCode::TEMPORARY_REDIRECT);
    assert_eq!(
        public_redirect.headers().get(header::LOCATION).unwrap(),
        "https://linkso.su/app/password/Protected42"
    );

    let locked_session = post_json(
        &app,
        "/api/v1/password-links/Protected42/sessions",
        json!({}),
    )
    .await;
    assert_eq!(locked_session.status(), StatusCode::OK);
    let locked_session_body = response_json(locked_session).await;
    assert!(locked_session_body.get("target_url").is_none());
    assert_eq!(locked_session_body["max_attempts"], 5);
    let locked_session_id = locked_session_body["session_id"].as_str().unwrap();

    for attempt in 1..=5 {
        let wrong = post_json(
            &app,
            "/api/v1/password-links/Protected42/verify",
            json!({"session_id": locked_session_id, "password": "wrong password"}),
        )
        .await;
        if attempt < 5 {
            assert_api_error(
                wrong,
                StatusCode::UNAUTHORIZED,
                "password_incorrect",
                "password",
            )
            .await;
        } else {
            assert_eq!(wrong.status(), StatusCode::TOO_MANY_REQUESTS);
            assert_eq!(wrong.headers().get(header::RETRY_AFTER).unwrap(), "30");
            let body = response_json(wrong).await;
            assert_eq!(body["error"]["code"], "password_temporarily_locked");
            assert_eq!(body["error"]["retry_after_seconds"], 30);
            assert!(body.to_string().find("server-only").is_none());
        }
    }

    let successful_session = post_json(
        &app,
        "/api/v1/password-links/Protected42/sessions",
        json!({}),
    )
    .await;
    let successful_session_body = response_json(successful_session).await;
    let successful_session_id = successful_session_body["session_id"].as_str().unwrap();
    let cannot_bypass_lock = post_json(
        &app,
        "/api/v1/password-links/Protected42/verify",
        json!({"session_id": successful_session_id, "password": "correct password"}),
    )
    .await;
    assert_eq!(cannot_bypass_lock.status(), StatusCode::TOO_MANY_REQUESTS);

    sqlx::query(
        "UPDATE password_link_sessions SET blocked_until = NOW() - INTERVAL '1 second' WHERE link_id = $1",
    )
    .bind(link_id)
    .execute(&pool)
    .await
    .unwrap();
    let verified = post_json(
        &app,
        "/api/v1/password-links/Protected42/verify",
        json!({"session_id": successful_session_id, "password": "correct password"}),
    )
    .await;
    assert_eq!(verified.status(), StatusCode::OK);
    let verified_body = response_json(verified).await;
    assert!(verified_body.get("target_url").is_none());
    assert!(verified_body.to_string().find("server-only").is_none());
    let redirect_url = Url::parse(verified_body["redirect_url"].as_str().unwrap()).unwrap();

    let replayed_verification = post_json(
        &app,
        "/api/v1/password-links/Protected42/verify",
        json!({"session_id": successful_session_id, "password": "correct password"}),
    )
    .await;
    assert_eq!(replayed_verification.status(), StatusCode::NOT_FOUND);

    let ticket_path = redirect_url.path().to_owned();
    let mut consumers = JoinSet::new();
    for _ in 0..2 {
        let app = app.clone();
        let ticket_path = ticket_path.clone();
        consumers.spawn(async move { request(&app, &ticket_path).await });
    }
    let mut responses = Vec::new();
    while let Some(response) = consumers.join_next().await {
        responses.push(response.unwrap());
    }
    assert_eq!(
        responses
            .iter()
            .filter(|response| response.status() == StatusCode::TEMPORARY_REDIRECT)
            .count(),
        1
    );
    assert_eq!(
        responses
            .iter()
            .filter(|response| response.status() == StatusCode::NOT_FOUND)
            .count(),
        1
    );
    let consumed = responses
        .into_iter()
        .find(|response| response.status() == StatusCode::TEMPORARY_REDIRECT)
        .unwrap();
    assert_eq!(
        consumed.headers().get(header::LOCATION).unwrap(),
        "https://example.com/private?token=server-only"
    );
    assert_eq!(
        consumed.headers().get(header::CACHE_CONTROL).unwrap(),
        "no-store"
    );
    assert_eq!(redirect_count(&pool, link_id).await, 1);

    assert_eq!(
        request(&app, &ticket_path).await.status(),
        StatusCode::NOT_FOUND
    );
    assert_eq!(redirect_count(&pool, link_id).await, 1);

    assert_eq!(
        analytics_event_count(&pool, link_id, "password_prompt_view").await,
        2
    );
    assert_eq!(
        analytics_event_count(&pool, link_id, "password_rejected").await,
        6
    );
    assert_eq!(
        analytics_event_count(&pool, link_id, "password_unlocked").await,
        1
    );
    assert_eq!(
        analytics_event_count(&pool, link_id, "password_redirect").await,
        1
    );

    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn admin_campaign_api_validates_manages_and_selects_active_campaigns() {
    const ADMIN_TOKEN: &str = "integration-admin-token-with-at-least-32-bytes";
    let pool = migrated_test_database().await;
    clear_campaigns(&pool).await;
    let app = server::app_with_admin(
        pool.clone(),
        Url::parse("https://linkso.su").unwrap(),
        BootstrapAdminToken::parse(ADMIN_TOKEN.into()).unwrap(),
    );
    let now = chrono::Utc::now();

    let unauthorized = post_json(
        &app,
        "/api/v1/admin/ad-campaigns",
        campaign_payload(
            "Unauthorized",
            "Body",
            now - chrono::Duration::minutes(5),
            now + chrono::Duration::minutes(5),
        ),
    )
    .await;
    assert_eq!(unauthorized.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(
        unauthorized
            .headers()
            .get(header::WWW_AUTHENTICATE)
            .unwrap(),
        "Bearer realm=\"linkso-admin\""
    );
    assert_eq!(
        response_json(unauthorized).await["error"]["code"],
        "admin_authentication_required"
    );

    for (payload, field) in [
        (
            campaign_payload(
                "<script>alert(1)</script>",
                "Body",
                now,
                now + chrono::Duration::minutes(5),
            ),
            "title",
        ),
        (
            json!({
                "title": "Unsafe URL",
                "body": "Body",
                "image_url": "javascript:alert(1)",
                "advertiser_url": "https://advertiser.example",
                "starts_at": now.to_rfc3339(),
                "ends_at": (now + chrono::Duration::minutes(5)).to_rfc3339()
            }),
            "image_url",
        ),
        (
            campaign_payload(
                "Invalid period",
                "Body",
                now + chrono::Duration::minutes(5),
                now,
            ),
            "ends_at",
        ),
    ] {
        let response = admin_json_request(
            &app,
            Method::POST,
            "/api/v1/admin/ad-campaigns",
            Some(payload),
            ADMIN_TOKEN,
        )
        .await;
        assert_eq!(response.status(), StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(response_json(response).await["error"]["field"], field);
    }

    let older = create_campaign(
        &app,
        ADMIN_TOKEN,
        campaign_payload(
            "Older campaign",
            "Older body",
            now - chrono::Duration::minutes(20),
            now + chrono::Duration::minutes(20),
        ),
    )
    .await;
    let newer = create_campaign(
        &app,
        ADMIN_TOKEN,
        campaign_payload(
            "Newer campaign",
            "Newer body",
            now - chrono::Duration::minutes(10),
            now + chrono::Duration::minutes(10),
        ),
    )
    .await;
    let future = create_campaign(
        &app,
        ADMIN_TOKEN,
        campaign_payload(
            "Future campaign",
            "Future body",
            now + chrono::Duration::minutes(10),
            now + chrono::Duration::minutes(20),
        ),
    )
    .await;
    assert!(!older["is_active"].as_bool().unwrap());

    for id in [&older["id"], &newer["id"], &future["id"]] {
        let response = admin_json_request(
            &app,
            Method::POST,
            &format!("/api/v1/admin/ad-campaigns/{}/enable", id.as_str().unwrap()),
            None,
            ADMIN_TOKEN,
        )
        .await;
        assert_eq!(response.status(), StatusCode::OK);
        assert!(
            response_json(response).await["is_active"]
                .as_bool()
                .unwrap()
        );
    }

    let updated = admin_json_request(
        &app,
        Method::PUT,
        &format!(
            "/api/v1/admin/ad-campaigns/{}",
            newer["id"].as_str().unwrap()
        ),
        Some(json!({
            "title": "Updated campaign",
            "body": "Safe plain text\nSecond line",
            "image_url": "https://cdn.example/ad.png#ignored",
            "advertiser_url": "https://advertiser.example/offer?source=linkso",
            "starts_at": (now - chrono::Duration::minutes(5)).to_rfc3339(),
            "ends_at": (now + chrono::Duration::minutes(10)).to_rfc3339()
        })),
        ADMIN_TOKEN,
    )
    .await;
    assert_eq!(updated.status(), StatusCode::OK);
    let updated = response_json(updated).await;
    assert_eq!(updated["title"], "Updated campaign");
    assert_eq!(updated["image_url"], "https://cdn.example/ad.png");
    assert!(updated["is_active"].as_bool().unwrap());

    let active = request(&app, "/api/v1/ad-campaigns/active").await;
    assert_eq!(active.status(), StatusCode::OK);
    let active = response_json(active).await;
    assert_eq!(active["id"], newer["id"]);
    assert_eq!(active["title"], "Updated campaign");
    assert!(active.get("is_active").is_none());
    assert!(active.get("created_at").is_none());

    let disabled = admin_json_request(
        &app,
        Method::POST,
        &format!(
            "/api/v1/admin/ad-campaigns/{}/disable",
            newer["id"].as_str().unwrap()
        ),
        None,
        ADMIN_TOKEN,
    )
    .await;
    assert_eq!(disabled.status(), StatusCode::OK);
    assert!(
        !response_json(disabled).await["is_active"]
            .as_bool()
            .unwrap()
    );

    let fallback = response_json(request(&app, "/api/v1/ad-campaigns/active").await).await;
    assert_eq!(fallback["id"], older["id"]);
    assert_ne!(fallback["id"], future["id"]);

    let stored_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM ad_campaigns")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(stored_count, 3);
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn advertising_flow_enforces_timer_and_consumes_each_session_and_ticket_once() {
    const ADMIN_TOKEN: &str = "advertising-flow-admin-token-with-32-bytes";
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_campaigns(&pool).await;
    let app = server::app_with_admin(
        pool.clone(),
        Url::parse("https://linkso.su").unwrap(),
        BootstrapAdminToken::parse(ADMIN_TOKEN.into()).unwrap(),
    );
    let now = chrono::Utc::now();
    let campaign = create_campaign(
        &app,
        ADMIN_TOKEN,
        campaign_payload(
            "Advertising flow",
            "Wait five seconds to continue",
            now - chrono::Duration::minutes(1),
            now + chrono::Duration::minutes(10),
        ),
    )
    .await;
    let campaign_id = campaign["id"].as_str().unwrap();
    assert_eq!(
        admin_json_request(
            &app,
            Method::POST,
            &format!("/api/v1/admin/ad-campaigns/{campaign_id}/enable"),
            None,
            ADMIN_TOKEN,
        )
        .await
        .status(),
        StatusCode::OK
    );

    let created = post_json(
        &app,
        "/api/v1/links",
        json!({
            "target_url": "https://example.com/after-ad?private=target",
            "kind": "advertising",
            "slug": "AdFlow42"
        }),
    )
    .await;
    assert_eq!(created.status(), StatusCode::CREATED);
    let link_id = Uuid::parse_str(response_json(created).await["id"].as_str().unwrap()).unwrap();

    let public_redirect = request(&app, "/AdFlow42").await;
    assert_eq!(public_redirect.status(), StatusCode::TEMPORARY_REDIRECT);
    assert_eq!(
        public_redirect.headers().get(header::LOCATION).unwrap(),
        "https://linkso.su/app/advertising/AdFlow42"
    );

    let started = post_json(
        &app,
        "/api/v1/advertising-links/AdFlow42/sessions",
        json!({}),
    )
    .await;
    assert_eq!(started.status(), StatusCode::OK);
    let started = response_json(started).await;
    assert!(started.get("target_url").is_none());
    assert!(started.to_string().find("private=target").is_none());
    assert_eq!(started["campaign"]["title"], "Advertising flow");
    let session_id = started["session_id"].as_str().unwrap();
    let continue_path =
        format!("/api/v1/advertising-links/AdFlow42/sessions/{session_id}/continue");

    let premature = post_json(&app, &continue_path, json!({})).await;
    assert_eq!(premature.status(), StatusCode::TOO_EARLY);
    assert!(premature.headers().contains_key(header::RETRY_AFTER));
    let premature = response_json(premature).await;
    assert_eq!(premature["error"]["code"], "advertising_timer_not_finished");
    assert!(premature["error"]["retry_after_seconds"].as_u64().unwrap() >= 1);
    assert!(premature.to_string().find("private=target").is_none());

    sqlx::query(
        "UPDATE ad_sessions SET created_at = NOW() - INTERVAL '10 seconds', unlocks_at = NOW() - INTERVAL '1 second' WHERE id = $1",
    )
        .bind(Uuid::parse_str(session_id).unwrap())
        .execute(&pool)
        .await
        .unwrap();
    let continued = post_json(&app, &continue_path, json!({})).await;
    assert_eq!(continued.status(), StatusCode::OK);
    let continued = response_json(continued).await;
    assert!(continued.get("target_url").is_none());
    assert!(continued.to_string().find("private=target").is_none());
    let redirect_url = Url::parse(continued["redirect_url"].as_str().unwrap()).unwrap();

    assert_eq!(
        post_json(&app, &continue_path, json!({})).await.status(),
        StatusCode::NOT_FOUND
    );
    let ticket_path = redirect_url.path().to_owned();
    let mut consumers = JoinSet::new();
    for _ in 0..2 {
        let app = app.clone();
        let ticket_path = ticket_path.clone();
        consumers.spawn(async move { request(&app, &ticket_path).await });
    }
    let mut responses = Vec::new();
    while let Some(response) = consumers.join_next().await {
        responses.push(response.unwrap());
    }
    assert_eq!(
        responses
            .iter()
            .filter(|response| response.status() == StatusCode::TEMPORARY_REDIRECT)
            .count(),
        1
    );
    assert_eq!(
        responses
            .iter()
            .filter(|response| response.status() == StatusCode::NOT_FOUND)
            .count(),
        1
    );
    let consumed = responses
        .into_iter()
        .find(|response| response.status() == StatusCode::TEMPORARY_REDIRECT)
        .unwrap();
    assert_eq!(
        consumed.headers().get(header::LOCATION).unwrap(),
        "https://example.com/after-ad?private=target"
    );
    assert_eq!(redirect_count(&pool, link_id).await, 1);

    for event_type in [
        "advertising_impression",
        "advertising_timer_complete",
        "advertising_redirect",
    ] {
        assert_eq!(analytics_event_count(&pool, link_id, event_type).await, 1);
    }
    assert_eq!(
        request(&app, &ticket_path).await.status(),
        StatusCode::NOT_FOUND
    );
    assert_eq!(redirect_count(&pool, link_id).await, 1);

    let disabled = admin_json_request(
        &app,
        Method::POST,
        &format!("/api/v1/admin/ad-campaigns/{campaign_id}/disable"),
        None,
        ADMIN_TOKEN,
    )
    .await;
    assert_eq!(disabled.status(), StatusCode::OK);
    let placeholder = post_json(
        &app,
        "/api/v1/advertising-links/AdFlow42/sessions",
        json!({}),
    )
    .await;
    assert_eq!(placeholder.status(), StatusCode::OK);
    let placeholder = response_json(placeholder).await;
    assert!(placeholder["campaign"].is_null());
    let placeholder_session_id =
        Uuid::parse_str(placeholder["session_id"].as_str().unwrap()).unwrap();
    let placeholder_campaign_id: Option<Uuid> =
        sqlx::query_scalar("SELECT campaign_id FROM ad_sessions WHERE id = $1")
            .bind(placeholder_session_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert!(placeholder_campaign_id.is_none());
    sqlx::query(
        "UPDATE ad_sessions SET created_at = NOW() - INTERVAL '10 seconds', unlocks_at = NOW() - INTERVAL '1 second' WHERE id = $1",
    )
    .bind(placeholder_session_id)
    .execute(&pool)
    .await
    .unwrap();
    let placeholder_continued = post_json(
        &app,
        &format!("/api/v1/advertising-links/AdFlow42/sessions/{placeholder_session_id}/continue"),
        json!({}),
    )
    .await;
    assert_eq!(placeholder_continued.status(), StatusCode::OK);
    assert!(response_json(placeholder_continued).await["redirect_url"].is_string());
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn user_and_session_schema_enforces_unique_identity_and_hashed_sessions() {
    let pool = migrated_test_database().await;
    sqlx::query("TRUNCATE TABLE users CASCADE")
        .execute(&pool)
        .await
        .unwrap();
    let user_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO users (id, email, display_name, password_hash)
        VALUES ($1, $2, $3, $4)
        "#,
    )
    .bind(user_id)
    .bind("person@example.com")
    .bind("Person")
    .bind("$argon2id$v=19$placeholder-hash")
    .execute(&pool)
    .await
    .unwrap();
    let duplicate = sqlx::query("INSERT INTO users (id, email, password_hash) VALUES ($1, $2, $3)")
        .bind(Uuid::new_v4())
        .bind("PERSON@example.com")
        .bind("$argon2id$v=19$another-placeholder")
        .execute(&pool)
        .await;
    assert!(duplicate.is_err());

    let session_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO user_sessions (id, user_id, token_hash, expires_at)
        VALUES ($1, $2, $3, NOW() + INTERVAL '1 day')
        "#,
    )
    .bind(session_id)
    .bind(user_id)
    .bind("a".repeat(64))
    .execute(&pool)
    .await
    .unwrap();
    let short_hash = sqlx::query(
        r#"
        INSERT INTO user_sessions (id, user_id, token_hash, expires_at)
        VALUES ($1, $2, $3, NOW() + INTERVAL '1 day')
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(user_id)
    .bind("not-a-hash")
    .execute(&pool)
    .await;
    assert!(short_hash.is_err());

    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(user_id)
        .execute(&pool)
        .await
        .unwrap();
    let sessions: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM user_sessions WHERE id = $1")
        .bind(session_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(sessions, 0);
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn registration_api_normalizes_hashes_and_rejects_duplicate_email() {
    let pool = migrated_test_database().await;
    clear_users(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let plain_password = "correct horse battery staple";

    let created = post_json(
        &app,
        "/api/v1/auth/register",
        json!({
            "email": "  Person+News@Example.COM  ",
            "password": plain_password
        }),
    )
    .await;
    assert_eq!(created.status(), StatusCode::CREATED);
    assert_eq!(
        created.headers().get(header::CACHE_CONTROL).unwrap(),
        "no-store"
    );
    assert!(!created.headers().contains_key(header::SET_COOKIE));
    assert!(created.headers().contains_key(&X_REQUEST_ID));
    let created = response_json(created).await;
    assert_eq!(created["user"]["email"], "person+news@example.com");
    assert_eq!(created["user"]["status"], "pending");
    assert_eq!(created["user"]["email_verified"], false);
    assert!(created["user"]["created_at"].as_str().is_some());
    assert!(created["development_verification_token"].as_str().is_some());
    assert!(created.get("password").is_none());
    assert!(created.get("password_hash").is_none());
    assert!(created.get("session").is_none());
    let id = Uuid::parse_str(created["user"]["id"].as_str().unwrap()).unwrap();

    let (stored_email, stored_hash, stored_status): (String, String, String) =
        sqlx::query_as("SELECT email, password_hash, status FROM users WHERE id = $1")
            .bind(id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(stored_email, "person+news@example.com");
    assert_eq!(stored_status, "pending");
    assert!(stored_hash.starts_with("$argon2id$v=19$"));
    assert!(!stored_hash.contains(plain_password));
    let parsed_hash = PasswordHash::new(&stored_hash).unwrap();
    assert!(
        Argon2::default()
            .verify_password(plain_password.as_bytes(), &parsed_hash)
            .is_ok()
    );
    let session_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM user_sessions")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(session_count, 0);

    let duplicate = post_json(
        &app,
        "/api/v1/auth/register",
        json!({
            "email": "PERSON+NEWS@example.com",
            "password": "another secure password"
        }),
    )
    .await;
    assert_api_error(duplicate, StatusCode::CONFLICT, "email_taken", "email").await;

    for (payload, code, field) in [
        (
            json!({"email": "not-an-email", "password": plain_password}),
            "invalid_email",
            "email",
        ),
        (
            json!({"email": "new@example.com", "password": "too short"}),
            "invalid_password",
            "password",
        ),
    ] {
        let response = post_json(&app, "/api/v1/auth/register", payload).await;
        assert_api_error(response, StatusCode::UNPROCESSABLE_ENTITY, code, field).await;
    }

    let unknown_field = post_json(
        &app,
        "/api/v1/auth/register",
        json!({
            "email": "new@example.com",
            "password": plain_password,
            "role": "administrator"
        }),
    )
    .await;
    assert_public_error(
        unknown_field,
        StatusCode::UNPROCESSABLE_ENTITY,
        "invalid_json",
    )
    .await;

    let user_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(user_count, 1);
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn auth_lifecycle_verifies_logs_in_revokes_resets_and_rate_limits() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let email = "auth-flow@example.com";
    let old_password = "correct horse battery staple";
    let new_password = "new correct horse battery staple";

    let registered = post_json(
        &app,
        "/api/v1/auth/register",
        json!({"email": email, "password": old_password}),
    )
    .await;
    assert_eq!(registered.status(), StatusCode::CREATED);
    let registered = response_json(registered).await;
    let user_id = Uuid::parse_str(registered["user"]["id"].as_str().unwrap()).unwrap();
    let verification_token = registered["development_verification_token"]
        .as_str()
        .unwrap()
        .to_owned();

    let pending_login = post_json(
        &app,
        "/api/v1/auth/login",
        json!({"email": email, "password": old_password}),
    )
    .await;
    assert_api_error(
        pending_login,
        StatusCode::FORBIDDEN,
        "email_not_verified",
        "email",
    )
    .await;

    let verified = post_json(
        &app,
        "/api/v1/auth/verify-email",
        json!({"token": verification_token}),
    )
    .await;
    assert_eq!(verified.status(), StatusCode::OK);
    let verified = response_json(verified).await;
    assert_eq!(verified["status"], "active");
    assert_eq!(verified["email_verified"], true);

    let replay = post_json(
        &app,
        "/api/v1/auth/verify-email",
        json!({"token": verification_token}),
    )
    .await;
    assert_api_error(
        replay,
        StatusCode::UNPROCESSABLE_ENTITY,
        "verification_token_invalid",
        "token",
    )
    .await;

    let login = post_json(
        &app,
        "/api/v1/auth/login",
        json!({"email": email, "password": old_password}),
    )
    .await;
    assert_eq!(login.status(), StatusCode::OK);
    let first_cookie = response_cookie(&login);
    assert!(
        login
            .headers()
            .get(header::SET_COOKIE)
            .unwrap()
            .to_str()
            .unwrap()
            .contains("HttpOnly")
    );
    assert!(
        login
            .headers()
            .get(header::SET_COOKIE)
            .unwrap()
            .to_str()
            .unwrap()
            .contains("SameSite=Lax")
    );
    let current = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/auth/session",
        None,
        &first_cookie,
    )
    .await;
    assert_eq!(current.status(), StatusCode::OK);
    assert_eq!(response_json(current).await["email"], email);

    let profile =
        request_with_cookie(&app, Method::GET, "/api/v1/me/profile", None, &first_cookie).await;
    assert_eq!(profile.status(), StatusCode::OK);
    assert_eq!(profile.headers()[header::CACHE_CONTROL], "no-store");
    let profile = response_json(profile).await;
    assert_eq!(profile["id"], user_id.to_string());
    assert_eq!(profile["email"], email);
    assert_eq!(profile["status"], "active");
    assert_eq!(profile["email_verified"], true);

    let anonymous_profile = request(&app, "/api/v1/me/profile").await;
    assert_public_error(
        anonymous_profile,
        StatusCode::UNAUTHORIZED,
        "authentication_required",
    )
    .await;

    let owned_link = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.com/owned",
            "slug": "OwnedByUser"
        })),
        &first_cookie,
    )
    .await;
    assert_eq!(owned_link.status(), StatusCode::CREATED);
    let owned_link = response_json(owned_link).await;
    assert_eq!(owned_link["owner_id"], user_id.to_string());
    let stored_owner_id: Option<Uuid> =
        sqlx::query_scalar("SELECT owner_id FROM links WHERE slug = 'OwnedByUser'")
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(stored_owner_id, Some(user_id));

    let second_login = post_json(
        &app,
        "/api/v1/auth/login",
        json!({"email": email, "password": old_password}),
    )
    .await;
    let second_cookie = response_cookie(&second_login);
    assert_ne!(first_cookie, second_cookie);
    let fixation_login = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/auth/login",
        Some(json!({"email": email, "password": old_password})),
        "linkso_session=attacker-controlled",
    )
    .await;
    assert_eq!(fixation_login.status(), StatusCode::OK);
    assert_ne!(
        response_cookie(&fixation_login),
        "linkso_session=attacker-controlled"
    );
    let logout_all = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/auth/logout-all",
        None,
        &first_cookie,
    )
    .await;
    assert_eq!(logout_all.status(), StatusCode::NO_CONTENT);
    for cookie in [&first_cookie, &second_cookie] {
        let revoked =
            request_with_cookie(&app, Method::GET, "/api/v1/auth/session", None, cookie).await;
        assert_eq!(revoked.status(), StatusCode::UNAUTHORIZED);
    }

    let login_before_reset = post_json(
        &app,
        "/api/v1/auth/login",
        json!({"email": email, "password": old_password}),
    )
    .await;
    let cookie_before_reset = response_cookie(&login_before_reset);
    let reset = post_json(&app, "/api/v1/auth/password-reset", json!({"email": email})).await;
    assert_eq!(reset.status(), StatusCode::ACCEPTED);
    let reset_token = response_json(reset).await["development_reset_token"]
        .as_str()
        .unwrap()
        .to_owned();
    let confirmed = post_json(
        &app,
        "/api/v1/auth/password-reset/confirm",
        json!({"token": reset_token, "password": new_password}),
    )
    .await;
    assert_eq!(confirmed.status(), StatusCode::NO_CONTENT);
    let revoked_by_reset = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/auth/session",
        None,
        &cookie_before_reset,
    )
    .await;
    assert_eq!(revoked_by_reset.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(
        post_json(
            &app,
            "/api/v1/auth/login",
            json!({"email": email, "password": old_password}),
        )
        .await
        .status(),
        StatusCode::UNAUTHORIZED
    );
    let new_login = post_json(
        &app,
        "/api/v1/auth/login",
        json!({"email": email, "password": new_password}),
    )
    .await;
    assert_eq!(new_login.status(), StatusCode::OK);

    for attempt in 1..=5 {
        let wrong = post_json(
            &app,
            "/api/v1/auth/login",
            json!({"email": email, "password": "wrong secure password"}),
        )
        .await;
        if attempt < 5 {
            assert_eq!(wrong.status(), StatusCode::UNAUTHORIZED);
        } else {
            assert_eq!(wrong.status(), StatusCode::TOO_MANY_REQUESTS);
            assert!(wrong.headers().contains_key(header::RETRY_AFTER));
            assert_eq!(
                response_json(wrong).await["error"]["code"],
                "login_temporarily_limited"
            );
        }
    }

    for attempt in 1..=3 {
        let limited = post_json(
            &app,
            "/api/v1/auth/password-reset",
            json!({"email": "unknown-limit@example.com"}),
        )
        .await;
        if attempt < 3 {
            assert_eq!(limited.status(), StatusCode::ACCEPTED);
            assert!(response_json(limited).await["development_reset_token"].is_null());
        } else {
            assert_eq!(limited.status(), StatusCode::TOO_MANY_REQUESTS);
            assert_eq!(
                response_json(limited).await["error"]["code"],
                "password_reset_temporarily_limited"
            );
        }
    }

    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn mobile_auth_uses_a_bearer_session_without_web_cookie_or_csrf_origin() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let email = "mobile-auth@example.com";
    let password = "correct horse battery staple";
    let (user_id, _) = register_verified_user(&app, email, password).await;

    let login = post_json(
        &app,
        "/api/v1/mobile/auth/login",
        json!({"email": email, "password": password}),
    )
    .await;
    assert_eq!(login.status(), StatusCode::OK);
    assert!(!login.headers().contains_key(header::SET_COOKIE));
    assert_eq!(login.headers()[header::CACHE_CONTROL], "no-store");
    let login = response_json(login).await;
    assert_eq!(login["user"]["id"], user_id.to_string());
    assert!(login["expires_at"].as_str().is_some());
    let token = login["session_token"].as_str().unwrap();

    let current = request_with_bearer(&app, Method::GET, "/api/v1/auth/session", None, token).await;
    assert_eq!(current.status(), StatusCode::OK);
    assert_eq!(response_json(current).await["email"], email);

    let link = request_with_bearer(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({"target_url": "https://example.com/mobile"})),
        token,
    )
    .await;
    assert_eq!(link.status(), StatusCode::CREATED);
    assert_eq!(response_json(link).await["owner_id"], user_id.to_string());

    let logout = request_with_bearer(&app, Method::POST, "/api/v1/auth/logout", None, token).await;
    assert_eq!(logout.status(), StatusCode::NO_CONTENT);
    let revoked = request_with_bearer(&app, Method::GET, "/api/v1/auth/session", None, token).await;
    assert_eq!(revoked.status(), StatusCode::UNAUTHORIZED);

    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn account_settings_manage_profile_security_sessions_and_deletion() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let password = "correct horse battery staple";
    let new_password = "new correct horse battery staple";
    let (user_id, current_cookie) =
        register_verified_user(&app, "settings@example.com", password).await;
    let (_, _) = register_verified_user(&app, "taken@example.com", password).await;
    let second_login = post_json(
        &app,
        "/api/v1/auth/login",
        json!({"email": "settings@example.com", "password": password}),
    )
    .await;
    let second_cookie = response_cookie(&second_login);

    let profile = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/me/profile",
        None,
        &current_cookie,
    )
    .await;
    let profile = response_json(profile).await;
    assert_eq!(profile["display_name"], Value::Null);
    assert!(profile.get("locale").is_none());
    assert!(profile.get("theme").is_none());
    assert_eq!(profile["timezone"], "UTC");

    let named = request_with_cookie(
        &app,
        Method::PUT,
        "/api/v1/me/profile",
        Some(json!({"display_name": "  Link Owner  "})),
        &current_cookie,
    )
    .await;
    assert_eq!(response_json(named).await["display_name"], "Link Owner");
    let preferences = request_with_cookie(
        &app,
        Method::PUT,
        "/api/v1/me/preferences",
        Some(json!({
            "timezone": "Europe/Moscow"
        })),
        &current_cookie,
    )
    .await;
    let preferences = response_json(preferences).await;
    assert!(preferences.get("locale").is_none());
    assert!(preferences.get("theme").is_none());
    assert_eq!(preferences["timezone"], "Europe/Moscow");
    let invalid_preferences = request_with_cookie(
        &app,
        Method::PUT,
        "/api/v1/me/preferences",
        Some(json!({"timezone": "Unknown/Zone"})),
        &current_cookie,
    )
    .await;
    assert_public_error(
        invalid_preferences,
        StatusCode::UNPROCESSABLE_ENTITY,
        "invalid_preferences",
    )
    .await;

    let sessions = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/me/sessions",
        None,
        &current_cookie,
    )
    .await;
    let sessions = response_json(sessions).await;
    assert_eq!(sessions.as_array().unwrap().len(), 2);
    let current_session_id = sessions
        .as_array()
        .unwrap()
        .iter()
        .find(|session| session["is_current"] == true)
        .unwrap()["id"]
        .as_str()
        .unwrap();
    let current_revoke = request_with_cookie(
        &app,
        Method::DELETE,
        &format!("/api/v1/me/sessions/{current_session_id}"),
        None,
        &current_cookie,
    )
    .await;
    assert_public_error(current_revoke, StatusCode::CONFLICT, "current_session").await;

    let wrong_password = request_with_cookie(
        &app,
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({
            "current_password": "wrong current password",
            "new_password": new_password
        })),
        &current_cookie,
    )
    .await;
    assert_api_error(
        wrong_password,
        StatusCode::UNAUTHORIZED,
        "current_password_invalid",
        "current_password",
    )
    .await;
    let changed_password = request_with_cookie(
        &app,
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({"current_password": password, "new_password": new_password})),
        &current_cookie,
    )
    .await;
    assert_eq!(changed_password.status(), StatusCode::NO_CONTENT);
    let revoked_second = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/me/profile",
        None,
        &second_cookie,
    )
    .await;
    assert_public_error(
        revoked_second,
        StatusCode::UNAUTHORIZED,
        "authentication_required",
    )
    .await;

    let taken_email = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/me/email-change",
        Some(json!({"email": "taken@example.com", "current_password": new_password})),
        &current_cookie,
    )
    .await;
    assert_api_error(taken_email, StatusCode::CONFLICT, "email_taken", "email").await;
    let requested_email = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/me/email-change",
        Some(json!({"email": "changed@example.com", "current_password": new_password})),
        &current_cookie,
    )
    .await;
    assert_eq!(requested_email.status(), StatusCode::ACCEPTED);
    let email_token = response_json(requested_email).await["development_confirmation_token"]
        .as_str()
        .unwrap()
        .to_owned();
    let confirmed_email = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/me/email-change/confirm",
        Some(json!({"token": email_token})),
        &current_cookie,
    )
    .await;
    assert_eq!(
        response_json(confirmed_email).await["email"],
        "changed@example.com"
    );

    let owned_link = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.com/settings-owned",
            "slug": "SettingsOwned",
            "tags": ["Private"]
        })),
        &current_cookie,
    )
    .await;
    assert_eq!(owned_link.status(), StatusCode::CREATED);
    let invalid_delete = request_with_cookie(
        &app,
        Method::DELETE,
        "/api/v1/me/profile",
        Some(json!({"current_password": new_password, "confirmation": "delete"})),
        &current_cookie,
    )
    .await;
    assert_api_error(
        invalid_delete,
        StatusCode::UNPROCESSABLE_ENTITY,
        "deletion_confirmation_invalid",
        "confirmation",
    )
    .await;
    let deleted = request_with_cookie(
        &app,
        Method::DELETE,
        "/api/v1/me/profile",
        Some(json!({"current_password": new_password, "confirmation": "DELETE"})),
        &current_cookie,
    )
    .await;
    assert_eq!(deleted.status(), StatusCode::NO_CONTENT);
    assert!(deleted.headers().contains_key(header::SET_COOKIE));
    assert_public_error(
        request(&app, "/SettingsOwned").await,
        StatusCode::NOT_FOUND,
        "not_found",
    )
    .await;
    let deleted_user: (String, String, Option<chrono::DateTime<chrono::Utc>>) =
        sqlx::query_as("SELECT email, status, deleted_at FROM users WHERE id = $1")
            .bind(user_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert!(deleted_user.0.starts_with("deleted-"));
    assert_eq!(deleted_user.1, "disabled");
    assert!(deleted_user.2.is_some());
    let deleted_link: (String, Option<chrono::DateTime<chrono::Utc>>) =
        sqlx::query_as("SELECT status, deleted_at FROM links WHERE slug = 'SettingsOwned'")
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(deleted_link.0, "disabled");
    assert!(deleted_link.1.is_some());
    let audited_actions: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM security_audit_log
        WHERE actor_type = 'user' AND actor_id = $1
          AND action IN (
              'account.email_change_requested',
              'account.email_changed',
              'account.password_changed',
              'account.deleted'
          )
        "#,
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(audited_actions, 4);
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn owned_links_api_isolates_lists_filters_updates_and_soft_deletes() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let (owner_id, owner_cookie) =
        register_verified_user(&app, "owner@example.com", "correct horse battery staple").await;
    let (_, other_cookie) =
        register_verified_user(&app, "other@example.com", "correct horse battery staple").await;

    let anonymous = request(&app, "/api/v1/me/links").await;
    assert_public_error(
        anonymous,
        StatusCode::UNAUTHORIZED,
        "authentication_required",
    )
    .await;

    let first = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.com/alpha",
            "slug": "OwnedAlpha",
            "title": "Alpha report"
        })),
        &owner_cookie,
    )
    .await;
    assert_eq!(first.status(), StatusCode::CREATED);
    let first = response_json(first).await;
    let first_id = Uuid::parse_str(first["id"].as_str().unwrap()).unwrap();

    let second = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.com/private",
            "slug": "OwnedSecret",
            "title": "Private notes",
            "kind": "password",
            "password": "secret password"
        })),
        &owner_cookie,
    )
    .await;
    let second_id = Uuid::parse_str(response_json(second).await["id"].as_str().unwrap()).unwrap();

    let third = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.com/ad",
            "slug": "OwnedAdvert",
            "title": "Campaign landing",
            "kind": "advertising"
        })),
        &owner_cookie,
    )
    .await;
    let third_id = Uuid::parse_str(response_json(third).await["id"].as_str().unwrap()).unwrap();

    let foreign = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.org/foreign",
            "slug": "ForeignLink",
            "title": "Alpha from another owner"
        })),
        &other_cookie,
    )
    .await;
    let foreign_id = response_json(foreign).await["id"]
        .as_str()
        .unwrap()
        .to_owned();

    sqlx::query(
        "UPDATE links SET redirect_count = CASE id WHEN $1 THEN 30 WHEN $2 THEN 10 ELSE 20 END WHERE owner_id = $3",
    )
    .bind(first_id)
    .bind(second_id)
    .bind(owner_id)
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query("UPDATE links SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1")
        .bind(third_id)
        .execute(&pool)
        .await
        .unwrap();

    let list = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/me/links?page=1&page_size=2&sort=redirect_count&direction=asc",
        None,
        &owner_cookie,
    )
    .await;
    assert_eq!(list.status(), StatusCode::OK);
    assert_eq!(
        list.headers().get(header::CACHE_CONTROL).unwrap(),
        "no-store"
    );
    let list = response_json(list).await;
    assert_eq!(list["pagination"]["total_items"], 3);
    assert_eq!(list["pagination"]["total_pages"], 2);
    assert_eq!(list["items"].as_array().unwrap().len(), 2);
    assert_eq!(list["items"][0]["id"], second_id.to_string());
    assert!(list.to_string().find("ForeignLink").is_none());

    for (suffix, expected_id) in [
        ("query=Alpha", first_id),
        ("kind=password", second_id),
        ("expiration=expired", third_id),
    ] {
        let filtered = request_with_cookie(
            &app,
            Method::GET,
            &format!("/api/v1/me/links?{suffix}"),
            None,
            &owner_cookie,
        )
        .await;
        let filtered = response_json(filtered).await;
        assert_eq!(filtered["pagination"]["total_items"], 1);
        assert_eq!(filtered["items"][0]["id"], expected_id.to_string());
    }

    let detail = request_with_cookie(
        &app,
        Method::GET,
        &format!("/api/v1/me/links/{first_id}"),
        None,
        &owner_cookie,
    )
    .await;
    assert_eq!(detail.status(), StatusCode::OK);
    assert_eq!(response_json(detail).await["redirect_count"], 30);

    let foreign_detail = request_with_cookie(
        &app,
        Method::GET,
        &format!("/api/v1/me/links/{foreign_id}"),
        None,
        &owner_cookie,
    )
    .await;
    assert_public_error(foreign_detail, StatusCode::NOT_FOUND, "not_found").await;

    let password_without_secret = request_with_cookie(
        &app,
        Method::PUT,
        &format!("/api/v1/me/links/{first_id}"),
        Some(json!({
            "target_url": "https://example.com/alpha",
            "slug": "OwnedAlpha",
            "title": "Alpha report",
            "kind": "password"
        })),
        &owner_cookie,
    )
    .await;
    assert_api_error(
        password_without_secret,
        StatusCode::UNPROCESSABLE_ENTITY,
        "password_required",
        "password",
    )
    .await;

    let updated = request_with_cookie(
        &app,
        Method::PUT,
        &format!("/api/v1/me/links/{first_id}"),
        Some(json!({
            "target_url": "https://example.net/updated",
            "slug": "OwnedUpdated",
            "title": "Updated title",
            "kind": "advertising"
        })),
        &owner_cookie,
    )
    .await;
    assert_eq!(updated.status(), StatusCode::OK);
    let updated = response_json(updated).await;
    assert_eq!(updated["slug"], "OwnedUpdated");
    assert_eq!(updated["kind"], "advertising");

    let disabled = request_with_cookie(
        &app,
        Method::POST,
        &format!("/api/v1/me/links/{first_id}/disable"),
        None,
        &owner_cookie,
    )
    .await;
    assert_eq!(response_json(disabled).await["status"], "disabled");
    let disabled_filter = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/me/links?status=disabled",
        None,
        &owner_cookie,
    )
    .await;
    assert_eq!(
        response_json(disabled_filter).await["pagination"]["total_items"],
        1
    );

    let enabled = request_with_cookie(
        &app,
        Method::POST,
        &format!("/api/v1/me/links/{first_id}/enable"),
        None,
        &owner_cookie,
    )
    .await;
    assert_eq!(response_json(enabled).await["status"], "active");

    for (method, suffix) in [
        (Method::PUT, ""),
        (Method::POST, "/disable"),
        (Method::DELETE, ""),
    ] {
        let payload = (method == Method::PUT).then(|| {
            json!({
                "target_url": "https://example.org/nope",
                "slug": "NoAccess",
                "kind": "direct"
            })
        });
        let denied = request_with_cookie(
            &app,
            method,
            &format!("/api/v1/me/links/{foreign_id}{suffix}"),
            payload,
            &owner_cookie,
        )
        .await;
        assert_public_error(denied, StatusCode::NOT_FOUND, "not_found").await;
    }

    let deleted = request_with_cookie(
        &app,
        Method::DELETE,
        &format!("/api/v1/me/links/{first_id}"),
        None,
        &owner_cookie,
    )
    .await;
    assert_eq!(deleted.status(), StatusCode::NO_CONTENT);
    let deleted_at: Option<chrono::DateTime<chrono::Utc>> =
        sqlx::query_scalar("SELECT deleted_at FROM links WHERE id = $1")
            .bind(first_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert!(deleted_at.is_some());
    let deleted_detail = request_with_cookie(
        &app,
        Method::GET,
        &format!("/api/v1/me/links/{first_id}"),
        None,
        &owner_cookie,
    )
    .await;
    assert_public_error(deleted_detail, StatusCode::NOT_FOUND, "not_found").await;

    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn link_tags_are_normalized_owner_scoped_filtered_and_cleaned_up() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let (_, owner_cookie) = register_verified_user(
        &app,
        "tags-owner@example.com",
        "correct horse battery staple",
    )
    .await;
    let (_, other_cookie) = register_verified_user(
        &app,
        "tags-other@example.com",
        "correct horse battery staple",
    )
    .await;

    let anonymous = post_json(
        &app,
        "/api/v1/links",
        json!({
            "target_url": "https://example.com/anonymous",
            "slug": "AnonymousTags",
            "tags": ["Work"]
        }),
    )
    .await;
    assert_public_error(
        anonymous,
        StatusCode::UNAUTHORIZED,
        "authentication_required",
    )
    .await;

    let created = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.com/tagged",
            "slug": "TaggedLink",
            "title": "Tagged",
            "tags": ["  Work  ", "work", "Product   Launch"]
        })),
        &owner_cookie,
    )
    .await;
    assert_eq!(created.status(), StatusCode::CREATED);
    let created = response_json(created).await;
    assert_eq!(created["tags"], json!(["Work", "Product Launch"]));
    let link_id = created["id"].as_str().unwrap();

    let other = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.org/tagged",
            "slug": "OtherTagged",
            "tags": ["Work"]
        })),
        &other_cookie,
    )
    .await;
    assert_eq!(other.status(), StatusCode::CREATED);

    let tags = request_with_cookie(&app, Method::GET, "/api/v1/me/tags", None, &owner_cookie).await;
    assert_eq!(tags.status(), StatusCode::OK);
    assert_eq!(
        response_json(tags).await,
        json!([
            {"name": "Product Launch", "link_count": 1},
            {"name": "Work", "link_count": 1}
        ])
    );

    let filtered = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/me/links?tag=%20WORK%20",
        None,
        &owner_cookie,
    )
    .await;
    let filtered = response_json(filtered).await;
    assert_eq!(filtered["pagination"]["total_items"], 1);
    assert_eq!(filtered["items"][0]["id"], link_id);
    assert_eq!(
        filtered["items"][0]["tags"],
        json!(["Work", "Product Launch"])
    );

    let too_many = request_with_cookie(
        &app,
        Method::PUT,
        &format!("/api/v1/me/links/{link_id}"),
        Some(json!({
            "target_url": "https://example.com/tagged",
            "slug": "TaggedLink",
            "title": "Tagged",
            "kind": "direct",
            "tags": (0..11).map(|index| format!("tag {index}")).collect::<Vec<_>>()
        })),
        &owner_cookie,
    )
    .await;
    assert_api_error(
        too_many,
        StatusCode::UNPROCESSABLE_ENTITY,
        "too_many_tags",
        "tags",
    )
    .await;

    let updated = request_with_cookie(
        &app,
        Method::PUT,
        &format!("/api/v1/me/links/{link_id}"),
        Some(json!({
            "target_url": "https://example.com/tagged",
            "slug": "TaggedLink",
            "title": "Tagged",
            "kind": "direct",
            "tags": ["Archive"]
        })),
        &owner_cookie,
    )
    .await;
    assert_eq!(response_json(updated).await["tags"], json!(["Archive"]));

    let tags = request_with_cookie(&app, Method::GET, "/api/v1/me/tags", None, &owner_cookie).await;
    assert_eq!(
        response_json(tags).await,
        json!([{"name": "Archive", "link_count": 1}])
    );
    let owner_tag_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM tags t JOIN users u ON u.id = t.owner_id WHERE u.email = $1",
    )
    .bind("tags-owner@example.com")
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(owner_tag_count, 1);

    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn direct_redirect_handles_active_and_unavailable_links() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());

    let active_id = create_direct_link(
        &app,
        "RedirectOk",
        "https://example.com/destination?q=1#part",
    )
    .await;
    let expired_id =
        create_direct_link(&app, "RedirectExpired", "https://example.com/expired").await;
    let disabled_id =
        create_direct_link(&app, "RedirectDisabled", "https://example.com/disabled").await;
    let blocked_id =
        create_direct_link(&app, "RedirectBlocked", "https://example.com/blocked").await;
    let deleted_id =
        create_direct_link(&app, "RedirectDeleted", "https://example.com/deleted").await;

    sqlx::query("UPDATE links SET expires_at = NOW() - INTERVAL '1 minute' WHERE id = $1")
        .bind(expired_id)
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("UPDATE links SET status = 'disabled' WHERE id = $1")
        .bind(disabled_id)
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query(
        "UPDATE links SET status = 'blocked', blocked_reason = 'Test block', blocked_at = NOW(), blocked_by = 'system' WHERE id = $1",
    )
        .bind(blocked_id)
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("UPDATE links SET deleted_at = NOW() WHERE id = $1")
        .bind(deleted_id)
        .execute(&pool)
        .await
        .unwrap();

    let active = request(&app, "/RedirectOk").await;
    assert_eq!(active.status(), StatusCode::TEMPORARY_REDIRECT);
    assert!(active.headers().contains_key(&X_REQUEST_ID));
    assert_eq!(
        active.headers().get(header::LOCATION).unwrap(),
        "https://example.com/destination?q=1#part"
    );
    assert_eq!(
        active.headers().get(header::CACHE_CONTROL).unwrap(),
        "no-store"
    );
    assert_eq!(response_body(active).await, "");

    assert_public_error(
        request(&app, "/RedirectExpired").await,
        StatusCode::GONE,
        "link_expired",
    )
    .await;
    assert_public_error(
        request(&app, "/RedirectDisabled").await,
        StatusCode::GONE,
        "link_disabled",
    )
    .await;
    assert_public_error(
        request(&app, "/RedirectBlocked").await,
        StatusCode::FORBIDDEN,
        "link_blocked",
    )
    .await;
    assert_public_error(
        request(&app, "/RedirectDeleted").await,
        StatusCode::NOT_FOUND,
        "not_found",
    )
    .await;
    assert_public_error(
        request(&app, "/UnknownSlug").await,
        StatusCode::NOT_FOUND,
        "not_found",
    )
    .await;

    for (slug, path) in [
        ("RedirectExpired", "/errors/expired"),
        ("RedirectDisabled", "/errors/disabled"),
        ("RedirectBlocked", "/errors/blocked"),
        ("UnknownSlug", "/errors/not-found"),
    ] {
        let response = request_html(&app, &format!("/{slug}")).await;
        assert_eq!(response.status(), StatusCode::TEMPORARY_REDIRECT);
        assert_eq!(
            response
                .headers()
                .get(header::LOCATION)
                .unwrap()
                .to_str()
                .unwrap(),
            format!("https://linkso.su{path}")
        );
        assert_eq!(
            response.headers().get(header::CACHE_CONTROL).unwrap(),
            "no-store"
        );
    }
    assert_public_error(
        request(&app, "/bad.slug").await,
        StatusCode::NOT_FOUND,
        "not_found",
    )
    .await;

    flush_analytics(&pool).await;
    assert_eq!(redirect_count(&pool, active_id).await, 1);
    let total_redirect_count: i64 =
        sqlx::query_scalar("SELECT COALESCE(SUM(redirect_count), 0)::BIGINT FROM links")
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(total_redirect_count, 1);
    assert_eq!(
        analytics_event_count(&pool, active_id, "direct_redirect").await,
        1
    );
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn analytics_aggregates_human_and_bot_events_exactly_once() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let link_id =
        create_direct_link(&app, "AnalyticsAggregate", "https://example.com/analytics").await;
    let analytics = AnalyticsRepository::new(pool.clone());
    analytics
        .record(link_id, AnalyticsEventType::DirectRedirect, false)
        .await
        .unwrap();
    analytics
        .record(link_id, AnalyticsEventType::DirectRedirect, true)
        .await
        .unwrap();

    assert_eq!(analytics.aggregate_pending(100).await.unwrap(), 2);
    assert_eq!(analytics.aggregate_pending(100).await.unwrap(), 0);
    assert_eq!(analytics.delete_expired_raw_events().await.unwrap(), 0);
    let (human_count, bot_count): (i64, i64) = sqlx::query_as(
        r#"
        SELECT human_count, bot_count
        FROM link_daily_analytics
        WHERE link_id = $1 AND day = CURRENT_DATE AND event_type = 'direct_redirect'
        "#,
    )
    .bind(link_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!((human_count, bot_count), (1, 1));
    let aggregated_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM link_analytics_events WHERE link_id = $1 AND aggregated_at IS NOT NULL",
    )
    .bind(link_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(aggregated_count, 2);
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn analytics_api_is_owner_scoped_and_returns_aggregated_periods() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    clear_users(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let (_, owner_cookie) = register_verified_user(
        &app,
        "analytics-owner@example.com",
        "correct horse battery staple",
    )
    .await;
    let (_, other_cookie) = register_verified_user(
        &app,
        "analytics-other@example.com",
        "correct horse battery staple",
    )
    .await;

    let direct = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.com/direct",
            "slug": "AnalyticsOwnerDirect",
            "title": "Owner direct"
        })),
        &owner_cookie,
    )
    .await;
    let direct_id = Uuid::parse_str(response_json(direct).await["id"].as_str().unwrap()).unwrap();
    let advertising = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.com/advertising",
            "slug": "AnalyticsOwnerAdvertising",
            "title": "Owner advertising",
            "kind": "advertising"
        })),
        &owner_cookie,
    )
    .await;
    let advertising_id =
        Uuid::parse_str(response_json(advertising).await["id"].as_str().unwrap()).unwrap();
    let foreign = request_with_cookie(
        &app,
        Method::POST,
        "/api/v1/links",
        Some(json!({
            "target_url": "https://example.org/foreign",
            "slug": "AnalyticsForeignDirect"
        })),
        &other_cookie,
    )
    .await;
    let foreign_id = Uuid::parse_str(response_json(foreign).await["id"].as_str().unwrap()).unwrap();

    let analytics = AnalyticsRepository::new(pool.clone());
    for _ in 0..2 {
        analytics
            .record(direct_id, AnalyticsEventType::DirectRedirect, false)
            .await
            .unwrap();
    }
    analytics
        .record(direct_id, AnalyticsEventType::DirectRedirect, true)
        .await
        .unwrap();
    for _ in 0..5 {
        analytics
            .record(
                advertising_id,
                AnalyticsEventType::AdvertisingImpression,
                false,
            )
            .await
            .unwrap();
    }
    for _ in 0..3 {
        analytics
            .record(
                advertising_id,
                AnalyticsEventType::AdvertisingTimerComplete,
                false,
            )
            .await
            .unwrap();
    }
    for _ in 0..2 {
        analytics
            .record(
                advertising_id,
                AnalyticsEventType::AdvertisingRedirect,
                false,
            )
            .await
            .unwrap();
    }
    analytics
        .record(
            advertising_id,
            AnalyticsEventType::AdvertisingRedirect,
            true,
        )
        .await
        .unwrap();
    for _ in 0..10 {
        analytics
            .record(foreign_id, AnalyticsEventType::DirectRedirect, false)
            .await
            .unwrap();
    }
    assert_eq!(analytics.aggregate_pending(100).await.unwrap(), 24);

    let anonymous = request(&app, "/api/v1/me/analytics?days=7").await;
    assert_public_error(
        anonymous,
        StatusCode::UNAUTHORIZED,
        "authentication_required",
    )
    .await;
    let invalid = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/me/analytics?days=8",
        None,
        &owner_cookie,
    )
    .await;
    assert_public_error(invalid, StatusCode::UNPROCESSABLE_ENTITY, "invalid_query").await;

    let dashboard = request_with_cookie(
        &app,
        Method::GET,
        "/api/v1/me/analytics?days=7",
        None,
        &owner_cookie,
    )
    .await;
    assert_eq!(dashboard.status(), StatusCode::OK);
    assert_eq!(dashboard.headers()[header::CACHE_CONTROL], "no-store");
    let dashboard = response_json(dashboard).await;
    assert_eq!(dashboard["period"]["days"], 7);
    assert_eq!(dashboard["summary"]["links"], 2);
    assert_eq!(dashboard["summary"]["human_redirects"], 4);
    assert_eq!(dashboard["summary"]["bot_redirects"], 2);
    assert_eq!(dashboard["series"].as_array().unwrap().len(), 7);
    assert_eq!(dashboard["series"][6]["human_redirects"], 4);
    assert_eq!(dashboard["series"][6]["bot_redirects"], 2);
    assert_eq!(dashboard["advertising_funnel"]["impressions"], 5);
    assert_eq!(dashboard["advertising_funnel"]["timer_completions"], 3);
    assert_eq!(dashboard["advertising_funnel"]["redirects"], 2);

    let link = request_with_cookie(
        &app,
        Method::GET,
        &format!("/api/v1/me/links/{advertising_id}/analytics?days=30"),
        None,
        &owner_cookie,
    )
    .await;
    let link = response_json(link).await;
    assert_eq!(link["link"]["id"], advertising_id.to_string());
    assert_eq!(link["link"]["kind"], "advertising");
    assert_eq!(link["summary"]["links"], 1);
    assert_eq!(link["summary"]["human_redirects"], 2);
    assert_eq!(link["summary"]["bot_redirects"], 1);
    assert_eq!(link["advertising_funnel"]["impressions"], 5);

    let foreign = request_with_cookie(
        &app,
        Method::GET,
        &format!("/api/v1/me/links/{foreign_id}/analytics?days=30"),
        None,
        &owner_cookie,
    )
    .await;
    assert_public_error(foreign, StatusCode::NOT_FOUND, "not_found").await;
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn redirect_path_handles_concurrent_smoke_load() {
    const REQUEST_COUNT: i64 = 200;
    const DIRECT_LIMIT: i64 = 300;

    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let app = server::app_with_links(pool.clone(), Url::parse("https://linkso.su").unwrap());
    let id = create_direct_link(&app, "RedirectLoad", "https://example.com/load").await;
    let mut requests = JoinSet::new();

    for _ in 0..REQUEST_COUNT {
        let app = app.clone();
        requests.spawn(async move { request(&app, "/RedirectLoad").await });
    }

    let mut completed = 0;
    while let Some(result) = requests.join_next().await {
        let response = result.expect("redirect smoke task must complete");
        assert_eq!(response.status(), StatusCode::TEMPORARY_REDIRECT);
        assert_eq!(
            response.headers().get(header::LOCATION).unwrap(),
            "https://example.com/load"
        );
        completed += 1;
    }

    assert_eq!(completed, REQUEST_COUNT);
    for _ in REQUEST_COUNT..DIRECT_LIMIT {
        assert_eq!(
            request(&app, "/RedirectLoad").await.status(),
            StatusCode::TEMPORARY_REDIRECT
        );
    }
    let limited = request(&app, "/RedirectLoad").await;
    assert_eq!(limited.status(), StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(
        response_json(limited).await["error"]["code"],
        "public_endpoint_rate_limited"
    );
    flush_analytics(&pool).await;
    assert_eq!(redirect_count(&pool, id).await, DIRECT_LIMIT);
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn generated_slug_retries_after_a_database_collision() {
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let repository = LinkRepository::new(pool.clone());
    let public_base_url = Url::parse("https://linkso.su").unwrap();
    let target = || TargetUrl::parse("https://example.com", &public_base_url).unwrap();
    let collision = Slug::parse("Collision1").unwrap();
    let fresh = Slug::parse("FreshSlug1").unwrap();

    let first = CreateDirectLink::new(target(), Some(collision.clone()), None, None).unwrap();
    repository.create_anonymous_direct(first).await.unwrap();

    let generator = SequenceSlugGenerator::new([collision, fresh.clone()]);
    let second = CreateDirectLink::new(target(), None, None, None).unwrap();
    let created = repository
        .create_anonymous_direct_with_generator(second, &generator)
        .await
        .expect("a collision must be retried with the next generated slug");

    assert_eq!(created.slug(), &fresh);
    let link_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM links")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(link_count, 2);

    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn reports_can_be_reviewed_and_links_can_be_blocked_and_unblocked() {
    const ADMIN_TOKEN: &str = "moderation-admin-token-with-at-least-32-bytes";
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let app = server::app_with_admin(
        pool.clone(),
        Url::parse("http://localhost:8080").unwrap(),
        BootstrapAdminToken::parse(ADMIN_TOKEN.into()).unwrap(),
    );
    let link_id = create_direct_link(&app, "Reported1", "https://example.com/reported").await;

    let reported = post_json(
        &app,
        "/api/v1/links/Reported1/reports",
        json!({"reason": "phishing", "details": "Imitates a login form"}),
    )
    .await;
    assert_eq!(reported.status(), StatusCode::ACCEPTED);

    let reports = admin_json_request(
        &app,
        Method::GET,
        "/api/v1/admin/link-reports",
        None,
        ADMIN_TOKEN,
    )
    .await;
    assert_eq!(reports.status(), StatusCode::OK);
    let reports = response_json(reports).await;
    assert_eq!(reports.as_array().unwrap().len(), 1);
    assert_eq!(reports[0]["link_id"], link_id.to_string());

    let blocked = admin_json_request(
        &app,
        Method::POST,
        &format!("/api/v1/admin/links/{link_id}/block"),
        Some(json!({"reason": "Confirmed phishing"})),
        ADMIN_TOKEN,
    )
    .await;
    assert_eq!(blocked.status(), StatusCode::NO_CONTENT);
    assert_eq!(
        request(&app, "/Reported1").await.status(),
        StatusCode::FORBIDDEN
    );
    let stored_reason: Option<String> =
        sqlx::query_scalar("SELECT blocked_reason FROM links WHERE id = $1")
            .bind(link_id)
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(stored_reason.as_deref(), Some("Confirmed phishing"));

    let audit_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM security_audit_log WHERE action = 'link.blocked' AND target_id = $1",
    )
    .bind(link_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(audit_count, 1);

    let unblocked = admin_json_request(
        &app,
        Method::POST,
        &format!("/api/v1/admin/links/{link_id}/unblock"),
        None,
        ADMIN_TOKEN,
    )
    .await;
    assert_eq!(unblocked.status(), StatusCode::NO_CONTENT);
    assert_eq!(
        request(&app, "/Reported1").await.status(),
        StatusCode::TEMPORARY_REDIRECT
    );
    pool.close().await;
}

#[tokio::test]
#[ignore = "requires an explicitly prepared linkso_test PostgreSQL database"]
async fn metrics_are_admin_protected_bounded_and_cover_redirects() {
    const ADMIN_TOKEN: &str = "metrics-admin-token-with-at-least-32-bytes";
    let pool = migrated_test_database().await;
    clear_links(&pool).await;
    let app = server::app_with_admin(
        pool.clone(),
        Url::parse("http://localhost:8080").unwrap(),
        BootstrapAdminToken::parse(ADMIN_TOKEN.into()).unwrap(),
    );
    create_direct_link(&app, "MetricsSecretSlug", "https://example.com/metrics").await;
    assert_eq!(
        request(&app, "/MetricsSecretSlug").await.status(),
        StatusCode::TEMPORARY_REDIRECT
    );
    assert_eq!(
        request(&app, "/UnknownMetricSlug").await.status(),
        StatusCode::NOT_FOUND
    );

    let denied = request(&app, "/internal/metrics").await;
    assert_eq!(denied.status(), StatusCode::UNAUTHORIZED);
    let metrics =
        admin_json_request(&app, Method::GET, "/internal/metrics", None, ADMIN_TOKEN).await;
    assert_eq!(metrics.status(), StatusCode::OK);
    assert_eq!(
        metrics.headers()[header::CONTENT_TYPE],
        "text/plain; version=0.0.4; charset=utf-8"
    );
    let metrics = response_body(metrics).await;
    assert!(metrics.contains("route=\"short_link\""));
    assert!(metrics.contains("status=\"3xx\""));
    assert!(metrics.contains("status=\"4xx\""));
    assert!(metrics.contains("linkso_redirects_total{flow=\"direct\"} 1"));
    assert!(!metrics.contains("MetricsSecretSlug"));
    assert!(!metrics.contains("UnknownMetricSlug"));
    assert!(!metrics.contains("example.com"));
    pool.close().await;
}

struct SequenceSlugGenerator {
    slugs: Mutex<VecDeque<Slug>>,
}

impl SequenceSlugGenerator {
    fn new(slugs: impl IntoIterator<Item = Slug>) -> Self {
        Self {
            slugs: Mutex::new(slugs.into_iter().collect()),
        }
    }
}

impl SlugGenerator for SequenceSlugGenerator {
    fn generate(&self) -> Result<Slug, SlugGenerationError> {
        self.slugs
            .lock()
            .unwrap()
            .pop_front()
            .ok_or(SlugGenerationError)
    }
}

async fn migrated_test_database() -> PgPool {
    let pool = connect_test_database().await;
    database::migrate(&pool)
        .await
        .expect("test database migrations must succeed");
    pool
}

async fn clear_links(pool: &PgPool) {
    sqlx::query(
        "TRUNCATE TABLE links, link_creation_rate_limits, public_request_rate_limits, security_audit_log CASCADE",
    )
        .execute(pool)
        .await
        .expect("test links must be cleared");
}

async fn clear_campaigns(pool: &PgPool) {
    sqlx::query("TRUNCATE TABLE ad_campaigns CASCADE")
        .execute(pool)
        .await
        .expect("test advertising campaigns must be cleared");
}

async fn clear_users(pool: &PgPool) {
    sqlx::query("TRUNCATE TABLE users, auth_rate_limits CASCADE")
        .execute(pool)
        .await
        .expect("test users must be cleared");
}

async fn redirect_count(pool: &PgPool, id: Uuid) -> i64 {
    sqlx::query_scalar("SELECT redirect_count FROM links WHERE id = $1")
        .bind(id)
        .fetch_one(pool)
        .await
        .expect("redirect count query must succeed")
}

async fn analytics_event_count(pool: &PgPool, link_id: Uuid, event_type: &str) -> i64 {
    sqlx::query_scalar(
        "SELECT COUNT(*) FROM link_analytics_events WHERE link_id = $1 AND event_type = $2",
    )
    .bind(link_id)
    .bind(event_type)
    .fetch_one(pool)
    .await
    .expect("analytics event count query must succeed")
}

async fn flush_analytics(pool: &PgPool) {
    AnalyticsRepository::new(pool.clone())
        .aggregate_pending(1_000)
        .await
        .expect("pending analytics must aggregate");
}

async fn connect_test_database() -> PgPool {
    let database_url = load_test_database_url();
    validate_test_database_url(&database_url);

    PgPoolOptions::new()
        .max_connections(2)
        .acquire_timeout(Duration::from_secs(5))
        .connect(&database_url)
        .await
        .expect("linkso_test must be reachable; run the preparation command first")
}

fn load_test_database_url() -> String {
    if let Ok(value) = env::var(TEST_DATABASE_URL)
        && !value.trim().is_empty()
    {
        return value;
    }

    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(".env.test");
    let values: HashMap<String, String> = dotenvy::from_path_iter(&path)
        .unwrap_or_else(|_| {
            panic!(
                "{} is missing; run the test database preparation command",
                path.display()
            )
        })
        .filter_map(Result::ok)
        .collect();

    values.get(TEST_DATABASE_URL).cloned().unwrap_or_else(|| {
        panic!(
            "{TEST_DATABASE_URL} is missing from {}; copy .env.test.example",
            path.display()
        )
    })
}

fn validate_test_database_url(database_url: &str) {
    let url = Url::parse(database_url).expect("test database URL must be valid");
    assert!(
        matches!(url.scheme(), "postgres" | "postgresql"),
        "test database URL must use PostgreSQL"
    );

    let database_name = url.path().trim_matches('/');
    assert_ne!(
        database_name, "linkso",
        "refusing to run integration tests against the development database"
    );
    assert_eq!(
        database_name, TEST_DATABASE_NAME,
        "integration tests may only use the linkso_test database"
    );
}

async fn request(app: &axum::Router, uri: &str) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(uri)
                .body(Body::empty())
                .expect("integration request must be valid"),
        )
        .await
        .expect("Router must return an integration response")
}

async fn request_html(app: &axum::Router, uri: &str) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(uri)
                .header(header::ACCEPT, "text/html,application/xhtml+xml")
                .body(Body::empty())
                .expect("integration HTML request must be valid"),
        )
        .await
        .expect("Router must return an integration HTML response")
}

async fn post_json(app: &axum::Router, uri: &str, payload: Value) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(uri)
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(payload.to_string()))
                .expect("integration request must be valid"),
        )
        .await
        .expect("Router must return an integration response")
}

async fn request_with_cookie(
    app: &axum::Router,
    method: Method,
    uri: &str,
    payload: Option<Value>,
    cookie: &str,
) -> axum::response::Response {
    let mut request = Request::builder()
        .method(method.clone())
        .uri(uri)
        .header(header::COOKIE, cookie);
    if matches!(
        method,
        Method::POST | Method::PUT | Method::PATCH | Method::DELETE
    ) {
        request = request.header(header::ORIGIN, "https://linkso.su");
    }
    let body = if let Some(payload) = payload {
        request = request.header(header::CONTENT_TYPE, "application/json");
        Body::from(payload.to_string())
    } else {
        Body::empty()
    };
    app.clone()
        .oneshot(request.body(body).expect("auth request must be valid"))
        .await
        .expect("Router must return an auth integration response")
}

async fn request_with_bearer(
    app: &axum::Router,
    method: Method,
    uri: &str,
    payload: Option<Value>,
    token: &str,
) -> axum::response::Response {
    let mut request = Request::builder()
        .method(method)
        .uri(uri)
        .header(header::AUTHORIZATION, format!("Bearer {token}"));
    let body = if let Some(payload) = payload {
        request = request.header(header::CONTENT_TYPE, "application/json");
        Body::from(payload.to_string())
    } else {
        Body::empty()
    };
    app.clone()
        .oneshot(
            request
                .body(body)
                .expect("mobile auth request must be valid"),
        )
        .await
        .expect("Router must return a mobile auth integration response")
}

fn response_cookie(response: &axum::response::Response) -> String {
    response
        .headers()
        .get(header::SET_COOKIE)
        .expect("login response must set a cookie")
        .to_str()
        .expect("session cookie must be ASCII")
        .split(';')
        .next()
        .expect("session cookie must contain a name-value pair")
        .to_owned()
}

async fn register_verified_user(app: &axum::Router, email: &str, password: &str) -> (Uuid, String) {
    let registered = post_json(
        app,
        "/api/v1/auth/register",
        json!({"email": email, "password": password}),
    )
    .await;
    assert_eq!(registered.status(), StatusCode::CREATED);
    let registered = response_json(registered).await;
    let user_id = Uuid::parse_str(registered["user"]["id"].as_str().unwrap()).unwrap();
    let token = registered["development_verification_token"]
        .as_str()
        .unwrap();
    let verified = post_json(app, "/api/v1/auth/verify-email", json!({"token": token})).await;
    assert_eq!(verified.status(), StatusCode::OK);
    let login = post_json(
        app,
        "/api/v1/auth/login",
        json!({"email": email, "password": password}),
    )
    .await;
    assert_eq!(login.status(), StatusCode::OK);
    (user_id, response_cookie(&login))
}

async fn admin_json_request(
    app: &axum::Router,
    method: Method,
    uri: &str,
    payload: Option<Value>,
    admin_token: &str,
) -> axum::response::Response {
    let mut request = Request::builder()
        .method(method)
        .uri(uri)
        .header(header::AUTHORIZATION, format!("Bearer {admin_token}"));
    let body = if let Some(payload) = payload {
        request = request.header(header::CONTENT_TYPE, "application/json");
        Body::from(payload.to_string())
    } else {
        Body::empty()
    };
    app.clone()
        .oneshot(request.body(body).expect("admin request must be valid"))
        .await
        .expect("Router must return an admin integration response")
}

fn campaign_payload(
    title: &str,
    body: &str,
    starts_at: chrono::DateTime<chrono::Utc>,
    ends_at: chrono::DateTime<chrono::Utc>,
) -> Value {
    json!({
        "title": title,
        "body": body,
        "image_url": null,
        "advertiser_url": "https://advertiser.example/offer",
        "starts_at": starts_at.to_rfc3339(),
        "ends_at": ends_at.to_rfc3339()
    })
}

async fn create_campaign(app: &axum::Router, admin_token: &str, payload: Value) -> Value {
    let response = admin_json_request(
        app,
        Method::POST,
        "/api/v1/admin/ad-campaigns",
        Some(payload),
        admin_token,
    )
    .await;
    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await
}

async fn create_direct_link(app: &axum::Router, slug: &str, target_url: &str) -> Uuid {
    let response = post_json(
        app,
        "/api/v1/links",
        json!({"target_url": target_url, "slug": slug}),
    )
    .await;
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    Uuid::parse_str(body["id"].as_str().unwrap()).unwrap()
}

async fn response_json(response: axum::response::Response) -> Value {
    serde_json::from_str(&response_body(response).await)
        .expect("integration response must contain valid JSON")
}

async fn assert_api_error(
    response: axum::response::Response,
    status: StatusCode,
    code: &str,
    field: &str,
) {
    assert_eq!(response.status(), status);
    assert!(response.headers().contains_key(&X_REQUEST_ID));
    let body = response_json(response).await;
    assert_eq!(body["error"]["code"], code);
    assert_eq!(body["error"]["field"], field);
    assert!(body["error"]["request_id"].as_str().is_some());
}

async fn assert_public_error(response: axum::response::Response, status: StatusCode, code: &str) {
    assert_eq!(response.status(), status);
    assert!(response.headers().contains_key(&X_REQUEST_ID));
    let body = response_json(response).await;
    assert_eq!(body["error"]["code"], code);
    assert!(body["error"]["field"].is_null());
    assert!(body["error"]["request_id"].as_str().is_some());
}

async fn response_body(response: axum::response::Response) -> String {
    let body = to_bytes(response.into_body(), 64 * 1024)
        .await
        .expect("integration response body must be readable");
    String::from_utf8(body.to_vec()).expect("integration response must be UTF-8")
}

#[cfg(test)]
mod validation_tests {
    use super::validate_test_database_url;

    #[test]
    #[should_panic(expected = "refusing to run integration tests against the development database")]
    fn rejects_development_database() {
        validate_test_database_url("postgres://linkso:password@localhost/linkso");
    }

    #[test]
    #[should_panic(expected = "integration tests may only use the linkso_test database")]
    fn rejects_other_database_name() {
        validate_test_database_url("postgres://linkso:password@localhost/postgres");
    }
}
