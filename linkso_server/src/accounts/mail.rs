use std::{fmt, future::Future, pin::Pin, sync::Arc, time::Duration};

use lettre::{
    AsyncSmtpTransport, AsyncTransport, Message, Tokio1Executor,
    message::{Mailbox, MultiPart, SinglePart},
    transport::smtp::authentication::Credentials,
};
use tokio::{sync::mpsc, task::JoinHandle};
use url::Url;

use crate::config::{ConfigError, Environment};

const QUEUE_CAPACITY: usize = 64;
const ATTEMPTS: usize = 3;

#[derive(Clone)]
pub struct MailConfig {
    host: String,
    port: u16,
    security: String,
    username: Option<String>,
    password: Option<String>,
    sender: Mailbox,
    timeout: Duration,
}

impl fmt::Debug for MailConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("MailConfig([REDACTED])")
    }
}

impl MailConfig {
    pub(crate) fn from_lookup(
        lookup: &impl Fn(&str) -> Option<String>,
        environment: Environment,
    ) -> Result<Self, ConfigError> {
        let production = environment == Environment::Production;
        let value = |name: &'static str, default: &str| {
            lookup(name)
                .filter(|v| !v.trim().is_empty())
                .or_else(|| (!production).then(|| default.to_owned()))
                .ok_or(ConfigError::Missing { name })
        };
        let host = value("LINKSO_SMTP_HOST", "127.0.0.1")?;
        if url::Host::parse(&host).is_err() || host.contains(['/', '@', ':', ' ', '\n', '\r']) {
            return Err(ConfigError::invalid(
                "LINKSO_SMTP_HOST",
                "expected a hostname or IPv4 address",
            ));
        }
        let port = value("LINKSO_SMTP_PORT", "1025")?
            .parse::<u16>()
            .ok()
            .filter(|v| *v != 0)
            .ok_or_else(|| {
                ConfigError::invalid("LINKSO_SMTP_PORT", "expected a port between 1 and 65535")
            })?;
        let security = value("LINKSO_SMTP_SECURITY", "none")?;
        if !matches!(security.as_str(), "none" | "starttls" | "tls")
            || (security == "none"
                && (production || !matches!(host.as_str(), "127.0.0.1" | "localhost" | "mailpit")))
        {
            return Err(ConfigError::invalid(
                "LINKSO_SMTP_SECURITY",
                "use starttls or tls; none is allowed only for local Mailpit",
            ));
        }
        let username = lookup("LINKSO_SMTP_USERNAME").filter(|v| !v.is_empty());
        let password = lookup("LINKSO_SMTP_PASSWORD").filter(|v| !v.is_empty());
        if production
            && [
                &host,
                username.as_deref().unwrap_or(""),
                password.as_deref().unwrap_or(""),
            ]
            .iter()
            .any(|v| v.contains("CHANGE_ME"))
        {
            return Err(ConfigError::invalid(
                "LINKSO_SMTP_HOST",
                "replace all production SMTP placeholders",
            ));
        }
        if username.is_some() != password.is_some() || (production && username.is_none()) {
            return Err(ConfigError::invalid(
                "LINKSO_SMTP_USERNAME",
                "SMTP username and password must be supplied together; production requires authentication",
            ));
        }
        if security == "none" && username.is_some() {
            return Err(ConfigError::invalid(
                "LINKSO_SMTP_SECURITY",
                "credentials require encrypted SMTP",
            ));
        }
        let sender = value("LINKSO_MAIL_FROM", "LinkSo <noreply@linkso.test>")?
            .parse::<Mailbox>()
            .map_err(|_| ConfigError::invalid("LINKSO_MAIL_FROM", "expected a sender mailbox"))?;
        let timeout = lookup("LINKSO_SMTP_TIMEOUT_SECONDS")
            .unwrap_or_else(|| "10".into())
            .parse::<u64>()
            .ok()
            .filter(|v| (1..=30).contains(v))
            .ok_or_else(|| {
                ConfigError::invalid("LINKSO_SMTP_TIMEOUT_SECONDS", "expected 1 to 30 seconds")
            })?;
        Ok(Self {
            host,
            port,
            security,
            username,
            password,
            sender,
            timeout: Duration::from_secs(timeout),
        })
    }

    pub fn start(&self, public_url: &Url) -> Result<(MailService, JoinHandle<()>), MailError> {
        let builder = match self.security.as_str() {
            "starttls" => AsyncSmtpTransport::<Tokio1Executor>::starttls_relay(&self.host)
                .map_err(|_| MailError)?,
            "tls" => {
                AsyncSmtpTransport::<Tokio1Executor>::relay(&self.host).map_err(|_| MailError)?
            }
            _ => AsyncSmtpTransport::<Tokio1Executor>::builder_dangerous(&self.host),
        };
        let mut builder = builder.port(self.port).timeout(Some(self.timeout));
        if let (Some(username), Some(password)) = (&self.username, &self.password) {
            builder = builder.credentials(Credentials::new(username.clone(), password.clone()));
        }
        Ok(MailService::start(
            Arc::new(SmtpDelivery(builder.build())),
            self.sender.clone(),
            public_url.clone(),
            self.timeout,
        ))
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MailKind {
    Verification,
    PasswordReset,
    EmailChange,
}

impl MailKind {
    fn content(self) -> (&'static str, &'static str, &'static str) {
        match self {
            Self::Verification => (
                "Verify your LinkSo email",
                "/app/auth/verify-email",
                "24 hours",
            ),
            Self::PasswordReset => (
                "Reset your LinkSo password",
                "/app/auth/password-reset",
                "30 minutes",
            ),
            Self::EmailChange => ("Confirm your new LinkSo email", "/app/settings", "24 hours"),
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct MailError;
impl fmt::Display for MailError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("email delivery unavailable")
    }
}
impl std::error::Error for MailError {}

/// Adapters must never log the message, recipient, SMTP response or credentials.
pub trait MailDelivery: Send + Sync {
    fn send<'a>(
        &'a self,
        message: &'a Message,
    ) -> Pin<Box<dyn Future<Output = Result<(), MailError>> + Send + 'a>>;
}

struct SmtpDelivery(AsyncSmtpTransport<Tokio1Executor>);
impl MailDelivery for SmtpDelivery {
    fn send<'a>(
        &'a self,
        message: &'a Message,
    ) -> Pin<Box<dyn Future<Output = Result<(), MailError>> + Send + 'a>> {
        Box::pin(async {
            self.0
                .send(message.clone())
                .await
                .map(|_| ())
                .map_err(|_| MailError)
        })
    }
}

struct QueuedMail {
    kind: MailKind,
    message: Message,
}

#[derive(Clone)]
pub struct MailService {
    queue: mpsc::Sender<QueuedMail>,
    sender: Mailbox,
    public_url: Url,
}

impl MailService {
    pub fn start(
        delivery: Arc<dyn MailDelivery>,
        sender: Mailbox,
        public_url: Url,
        timeout: Duration,
    ) -> (Self, JoinHandle<()>) {
        let (queue, mut receiver) = mpsc::channel::<QueuedMail>(QUEUE_CAPACITY);
        let worker = tokio::spawn(async move {
            while let Some(mail) = receiver.recv().await {
                if deliver_with_retry(
                    delivery.as_ref(),
                    &mail.message,
                    timeout,
                    Duration::from_secs(1),
                )
                .await
                .is_err()
                {
                    tracing::error!(kind = ?mail.kind, attempts = ATTEMPTS, "email delivery exhausted; user can request a new message");
                } else {
                    tracing::info!(kind = ?mail.kind, "email accepted by SMTP");
                }
            }
        });
        (
            Self {
                queue,
                sender,
                public_url,
            },
            worker,
        )
    }

    pub fn enqueue(&self, kind: MailKind, recipient: &str, token: &str) -> Result<(), MailError> {
        let message = message(&self.sender, &self.public_url, kind, recipient, token)?;
        self.queue
            .try_send(QueuedMail { kind, message })
            .map_err(|_| MailError)
    }
}

async fn deliver_with_retry(
    delivery: &dyn MailDelivery,
    message: &Message,
    timeout: Duration,
    backoff: Duration,
) -> Result<(), MailError> {
    for attempt in 0..ATTEMPTS {
        if matches!(
            tokio::time::timeout(timeout, delivery.send(message)).await,
            Ok(Ok(()))
        ) {
            return Ok(());
        }
        if attempt + 1 < ATTEMPTS {
            tokio::time::sleep(backoff * (1 << attempt)).await;
        }
    }
    Err(MailError)
}

fn message(
    sender: &Mailbox,
    base: &Url,
    kind: MailKind,
    recipient: &str,
    token: &str,
) -> Result<Message, MailError> {
    let (subject, path, lifetime) = kind.content();
    let mut url = base.join(path).map_err(|_| MailError)?;
    // Fragments are read by Flutter, never transmitted in HTTP request URLs.
    let parameter = if kind == MailKind::EmailChange {
        "email_token"
    } else {
        "token"
    };
    let fragment = url::form_urlencoded::Serializer::new(String::new())
        .append_pair(parameter, token)
        .finish();
    url.set_fragment(Some(&fragment));
    let note = if kind == MailKind::EmailChange {
        "Sign in to the account that requested this change before confirming. "
    } else {
        ""
    };
    let text = format!(
        "{subject}\n\nOpen this link to continue:\n{url}\n\n{note}This single-use link expires in {lifetime}. If you did not request it, ignore this email.\n\nLinkSo"
    );
    let html = format!(
        "<!doctype html><html lang=\"en\"><body><h1>{subject}</h1><p><a href=\"{}\">Continue in LinkSo</a></p><p>{note}This single-use link expires in {lifetime}.</p><p>If you did not request it, ignore this email.</p><p>LinkSo</p></body></html>",
        url.as_str()
            .replace('&', "&amp;")
            .replace('"', "&quot;")
            .replace('<', "&lt;")
    );
    Message::builder()
        .from(sender.clone())
        .to(recipient.parse().map_err(|_| MailError)?)
        .subject(subject)
        .multipart(
            MultiPart::alternative()
                .singlepart(SinglePart::plain(text))
                .singlepart(SinglePart::html(html)),
        )
        .map_err(|_| MailError)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct Fake {
        attempts: AtomicUsize,
        failures: usize,
        hang: bool,
    }
    impl MailDelivery for Fake {
        fn send<'a>(
            &'a self,
            _: &'a Message,
        ) -> Pin<Box<dyn Future<Output = Result<(), MailError>> + Send + 'a>> {
            Box::pin(async {
                let attempt = self.attempts.fetch_add(1, Ordering::SeqCst);
                if self.hang {
                    std::future::pending::<()>().await;
                }
                if attempt < self.failures {
                    Err(MailError)
                } else {
                    Ok(())
                }
            })
        }
    }
    fn sample() -> Message {
        message(
            &"LinkSo <noreply@linkso.test>".parse().unwrap(),
            &Url::parse("http://localhost:8088").unwrap(),
            MailKind::Verification,
            "recipient@example.test",
            "secret-token",
        )
        .unwrap()
    }
    #[test]
    fn validates_production_smtp_and_redacts_all_credentials() {
        use std::collections::HashMap;
        let valid = HashMap::from([
            ("LINKSO_SMTP_HOST", "smtp.example.test"),
            ("LINKSO_SMTP_PORT", "587"),
            ("LINKSO_SMTP_SECURITY", "starttls"),
            ("LINKSO_MAIL_FROM", "LinkSo <noreply@example.test>"),
            ("LINKSO_SMTP_USERNAME", "private-user"),
            ("LINKSO_SMTP_PASSWORD", "private-password"),
        ]);
        let load = |values: &HashMap<&str, &str>| {
            MailConfig::from_lookup(
                &|k| values.get(k).map(|v| (*v).into()),
                Environment::Production,
            )
        };
        assert_eq!(
            format!("{:?}", load(&valid).unwrap()),
            "MailConfig([REDACTED])"
        );
        for key in valid.keys() {
            let mut values = valid.clone();
            values.remove(key);
            assert!(load(&values).is_err(), "missing {key} must fail");
        }
        for (key, value) in [
            ("LINKSO_SMTP_SECURITY", "none"),
            ("LINKSO_SMTP_PORT", "0"),
            ("LINKSO_SMTP_TIMEOUT_SECONDS", "31"),
            ("LINKSO_MAIL_FROM", "not an email"),
            (
                "LINKSO_SMTP_HOST",
                "smtp://private-user:private-password@example.test",
            ),
            ("LINKSO_SMTP_PASSWORD", "CHANGE_ME"),
        ] {
            let mut values = valid.clone();
            values.insert(key, value);
            let error = load(&values).unwrap_err();
            assert!(!format!("{error:?}").contains("private-password"));
        }
        let insecure = HashMap::from([("LINKSO_SMTP_HOST", "smtp.example.test")]);
        assert!(
            MailConfig::from_lookup(
                &|k| insecure.get(k).map(|v| (*v).into()),
                Environment::Development
            )
            .is_err()
        );
    }
    #[tokio::test]
    async fn retries_transient_failures_and_bounds_failure_and_timeout() {
        for (failures, hang, expected, succeeds) in [
            (0, false, 1, true),
            (2, false, 3, true),
            (9, false, 3, false),
            (0, true, 3, false),
        ] {
            let fake = Fake {
                attempts: AtomicUsize::new(0),
                failures,
                hang,
            };
            let result =
                deliver_with_retry(&fake, &sample(), Duration::from_millis(2), Duration::ZERO)
                    .await;
            assert_eq!(result.is_ok(), succeeds);
            assert_eq!(fake.attempts.load(Ordering::SeqCst), expected);
        }
    }
    #[test]
    fn templates_use_fragment_tokens_and_have_text_and_html() {
        for kind in [
            MailKind::Verification,
            MailKind::PasswordReset,
            MailKind::EmailChange,
        ] {
            let mail = message(
                &"noreply@linkso.test".parse().unwrap(),
                &Url::parse("https://example.test").unwrap(),
                kind,
                "recipient@example.test",
                "secret-token",
            )
            .unwrap();
            let formatted = String::from_utf8(mail.formatted()).unwrap();
            assert!(formatted.contains("text/plain"));
            assert!(formatted.contains("text/html"));
            assert!(formatted.contains("#"));
            assert!(!formatted.contains("?token"));
            assert!(formatted.contains(kind.content().0));
        }
    }
    #[tokio::test]
    async fn queue_is_bounded_and_closed_worker_rejects_mail() {
        let (service, worker) = MailService::start(
            Arc::new(Fake {
                attempts: AtomicUsize::new(0),
                failures: 0,
                hang: true,
            }),
            "noreply@linkso.test".parse().unwrap(),
            Url::parse("http://localhost:8088").unwrap(),
            Duration::from_secs(1),
        );
        for _ in 0..QUEUE_CAPACITY {
            service
                .enqueue(MailKind::Verification, "a@example.test", "token")
                .unwrap();
        }
        assert!(
            service
                .enqueue(MailKind::Verification, "a@example.test", "token")
                .is_err()
        );
        worker.abort();
        let _ = worker.await;
        assert!(
            service
                .enqueue(MailKind::Verification, "a@example.test", "token")
                .is_err()
        );
    }
}
