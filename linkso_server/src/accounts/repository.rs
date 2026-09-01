use std::{error::Error, fmt, str::FromStr};

use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use super::{Email, UserPasswordHash};

#[derive(Debug)]
pub struct RegisterUser {
    email: Email,
    password_hash: UserPasswordHash,
}

impl RegisterUser {
    pub fn new(email: Email, password_hash: UserPasswordHash) -> Self {
        Self {
            email,
            password_hash,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum UserStatus {
    Pending,
    Active,
    Disabled,
}

impl FromStr for UserStatus {
    type Err = CorruptUserRecord;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "pending" => Ok(Self::Pending),
            "active" => Ok(Self::Active),
            "disabled" => Ok(Self::Disabled),
            _ => Err(CorruptUserRecord),
        }
    }
}

#[derive(Clone, Debug)]
pub struct UserRecord {
    id: Uuid,
    email: String,
    status: UserStatus,
    email_verified_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
}

impl UserRecord {
    pub(crate) fn from_stored(
        id: Uuid,
        email: String,
        status: String,
        email_verified_at: Option<DateTime<Utc>>,
        created_at: DateTime<Utc>,
    ) -> Result<Self, CorruptUserRecord> {
        Ok(Self {
            id,
            email,
            status: status.parse()?,
            email_verified_at,
            created_at,
        })
    }

    pub fn id(&self) -> Uuid {
        self.id
    }

    pub fn email(&self) -> &str {
        &self.email
    }

    pub fn status(&self) -> UserStatus {
        self.status
    }

    pub fn email_verified_at(&self) -> Option<DateTime<Utc>> {
        self.email_verified_at
    }

    pub fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }
}

#[derive(Clone)]
pub struct AccountRepository {
    pool: PgPool,
}

impl AccountRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn register(
        &self,
        input: RegisterUser,
    ) -> Result<UserRecord, AccountRepositoryError> {
        let row = sqlx::query_as::<_, UserRow>(
            r#"
            INSERT INTO users (id, email, password_hash)
            VALUES ($1, $2, $3)
            RETURNING id, email, status, email_verified_at, created_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.email.as_str())
        .bind(input.password_hash.as_str())
        .fetch_one(&self.pool)
        .await
        .map_err(AccountRepositoryError::from_database)?;

        UserRecord::try_from(row).map_err(AccountRepositoryError::CorruptData)
    }
}

#[derive(FromRow)]
struct UserRow {
    id: Uuid,
    email: String,
    status: String,
    email_verified_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
}

impl TryFrom<UserRow> for UserRecord {
    type Error = CorruptUserRecord;

    fn try_from(row: UserRow) -> Result<Self, Self::Error> {
        Self::from_stored(
            row.id,
            row.email,
            row.status,
            row.email_verified_at,
            row.created_at,
        )
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct CorruptUserRecord;

impl fmt::Display for CorruptUserRecord {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("stored user record is invalid")
    }
}

impl Error for CorruptUserRecord {}

pub enum AccountRepositoryError {
    EmailTaken,
    Database(sqlx::Error),
    CorruptData(CorruptUserRecord),
}

impl AccountRepositoryError {
    fn from_database(error: sqlx::Error) -> Self {
        if is_email_conflict(&error) {
            Self::EmailTaken
        } else {
            Self::Database(error)
        }
    }
}

impl fmt::Debug for AccountRepositoryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for AccountRepositoryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::EmailTaken => "account email is already registered",
            Self::Database(_) => "account database operation failed",
            Self::CorruptData(_) => "stored account data is invalid",
        })
    }
}

impl Error for AccountRepositoryError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Database(error) => Some(error),
            Self::CorruptData(error) => Some(error),
            Self::EmailTaken => None,
        }
    }
}

fn is_email_conflict(error: &sqlx::Error) -> bool {
    error.as_database_error().is_some_and(|database_error| {
        database_error.code().as_deref() == Some("23505")
            && database_error.constraint() == Some("users_email_unique")
    })
}
