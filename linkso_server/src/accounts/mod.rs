mod auth_flow;
mod email;
mod password;
mod repository;
mod settings;
mod token;

pub mod http;
pub mod mail;

pub use auth_flow::{
    AccountCredentials, AuthRateLimitKind, AuthRepository, AuthRepositoryError,
    EMAIL_VERIFICATION_LIFETIME_HOURS, PASSWORD_RESET_LIFETIME_MINUTES, USER_SESSION_LIFETIME_DAYS,
    UserSession,
};

pub use email::{
    Email, EmailError, MAX_EMAIL_DOMAIN_LENGTH, MAX_EMAIL_LENGTH, MAX_EMAIL_LOCAL_PART_LENGTH,
};
pub use password::{
    MAX_USER_PASSWORD_LENGTH, MIN_USER_PASSWORD_LENGTH, UserPassword, UserPasswordError,
    UserPasswordHash, UserPasswordHashError, UserPasswordVerifyError, hash_user_password,
    verify_user_password,
};
pub use repository::{
    AccountRepository, AccountRepositoryError, CorruptUserRecord, RegisterUser, UserRecord,
    UserStatus,
};
pub use settings::{
    AccountProfile, ActiveSession, SUPPORTED_TIMEZONES, SettingsError, SettingsRepository,
};
pub use token::{AuthToken, AuthTokenCodec, AuthTokenCodecError};
