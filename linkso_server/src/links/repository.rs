use std::{collections::HashMap, error::Error, fmt};

use chrono::{DateTime, Utc};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use super::{
    LinkKind, LinkPasswordHash, LinkStatus, LinkTag, ParseLinkKindError, ParseLinkStatusError,
    SecureSlugGenerator, Slug, SlugGenerationError, SlugGenerator, TargetUrl,
};

pub const MAX_SLUG_ATTEMPTS: usize = 5;
pub const MAX_TITLE_LENGTH: usize = 120;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum OwnedLinkExpiration {
    NotExpired,
    Expired,
    Never,
}

impl OwnedLinkExpiration {
    const fn as_str(self) -> &'static str {
        match self {
            Self::NotExpired => "not_expired",
            Self::Expired => "expired",
            Self::Never => "never",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum OwnedLinkSort {
    CreatedAt,
    RedirectCount,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SortDirection {
    Ascending,
    Descending,
}

#[derive(Debug)]
pub struct OwnedLinkQuery {
    pub page: u32,
    pub page_size: u32,
    pub search: Option<String>,
    pub kind: Option<LinkKind>,
    pub status: Option<LinkStatus>,
    pub expiration: Option<OwnedLinkExpiration>,
    pub tag: Option<String>,
    pub sort: OwnedLinkSort,
    pub direction: SortDirection,
}

#[derive(Debug, Eq, PartialEq)]
pub struct OwnedTagSummary {
    pub name: String,
    pub link_count: i64,
}

#[derive(Debug)]
pub struct OwnedLinkPage {
    pub items: Vec<LinkRecord>,
    pub total_items: i64,
}

#[derive(Debug)]
pub enum PasswordHashUpdate {
    Preserve,
    Replace(LinkPasswordHash),
    Remove,
}

#[derive(Debug)]
pub struct UpdateOwnedLink {
    target_url: TargetUrl,
    slug: Slug,
    title: Option<String>,
    expires_at: Option<DateTime<Utc>>,
    kind: LinkKind,
    password_hash: PasswordHashUpdate,
}

impl UpdateOwnedLink {
    pub fn new(
        target_url: TargetUrl,
        slug: Slug,
        title: Option<String>,
        expires_at: Option<DateTime<Utc>>,
        kind: LinkKind,
        password_hash: PasswordHashUpdate,
    ) -> Result<Self, CreateLinkError> {
        let title = normalize_title(title)?;
        validate_expiration(expires_at)?;
        Ok(Self {
            target_url,
            slug,
            title,
            expires_at,
            kind,
            password_hash,
        })
    }
}

#[derive(Debug)]
pub struct CreateLink {
    target_url: TargetUrl,
    custom_slug: Option<Slug>,
    title: Option<String>,
    expires_at: Option<DateTime<Utc>>,
    kind: LinkKind,
    password_hash: Option<LinkPasswordHash>,
}

impl CreateLink {
    pub fn direct(
        target_url: TargetUrl,
        custom_slug: Option<Slug>,
        title: Option<String>,
        expires_at: Option<DateTime<Utc>>,
    ) -> Result<Self, CreateLinkError> {
        Self::new(
            target_url,
            custom_slug,
            title,
            expires_at,
            LinkKind::Direct,
            None,
        )
    }

    pub fn password(
        target_url: TargetUrl,
        custom_slug: Option<Slug>,
        title: Option<String>,
        expires_at: Option<DateTime<Utc>>,
        password_hash: LinkPasswordHash,
    ) -> Result<Self, CreateLinkError> {
        Self::new(
            target_url,
            custom_slug,
            title,
            expires_at,
            LinkKind::Password,
            Some(password_hash),
        )
    }

    pub fn advertising(
        target_url: TargetUrl,
        custom_slug: Option<Slug>,
        title: Option<String>,
        expires_at: Option<DateTime<Utc>>,
    ) -> Result<Self, CreateLinkError> {
        Self::new(
            target_url,
            custom_slug,
            title,
            expires_at,
            LinkKind::Advertising,
            None,
        )
    }

    fn new(
        target_url: TargetUrl,
        custom_slug: Option<Slug>,
        title: Option<String>,
        expires_at: Option<DateTime<Utc>>,
        kind: LinkKind,
        password_hash: Option<LinkPasswordHash>,
    ) -> Result<Self, CreateLinkError> {
        let title = normalize_title(title)?;
        validate_expiration(expires_at)?;

        Ok(Self {
            target_url,
            custom_slug,
            title,
            expires_at,
            kind,
            password_hash,
        })
    }
}

#[derive(Debug)]
pub struct CreateDirectLink(CreateLink);

impl CreateDirectLink {
    pub fn new(
        target_url: TargetUrl,
        custom_slug: Option<Slug>,
        title: Option<String>,
        expires_at: Option<DateTime<Utc>>,
    ) -> Result<Self, CreateLinkError> {
        CreateLink::direct(target_url, custom_slug, title, expires_at).map(Self)
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CreateLinkError {
    TitleTooLong,
    ExpirationNotFuture,
}

impl fmt::Display for CreateLinkError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let message = match self {
            Self::TitleTooLong => "link title is too long",
            Self::ExpirationNotFuture => "link expiration must be in the future",
        };
        formatter.write_str(message)
    }
}

impl Error for CreateLinkError {}

#[derive(Clone, Debug)]
pub struct LinkRecord {
    id: Uuid,
    slug: Slug,
    owner_id: Option<Uuid>,
    target_url: String,
    title: Option<String>,
    kind: LinkKind,
    status: LinkStatus,
    blocked_reason: Option<String>,
    blocked_at: Option<DateTime<Utc>>,
    blocked_by: Option<String>,
    expires_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    deleted_at: Option<DateTime<Utc>>,
    redirect_count: i64,
}

#[derive(Clone, Debug)]
pub enum PublicLinkResolution {
    Active(Box<LinkRecord>),
    NotFound,
    Expired,
    Disabled,
    Blocked,
}

impl LinkRecord {
    pub fn id(&self) -> Uuid {
        self.id
    }

    pub fn slug(&self) -> &Slug {
        &self.slug
    }

    pub fn owner_id(&self) -> Option<Uuid> {
        self.owner_id
    }

    pub fn target_url(&self) -> &str {
        &self.target_url
    }

    pub fn title(&self) -> Option<&str> {
        self.title.as_deref()
    }

    pub fn kind(&self) -> LinkKind {
        self.kind
    }

    pub fn status(&self) -> LinkStatus {
        self.status
    }

    pub fn blocked_reason(&self) -> Option<&str> {
        self.blocked_reason.as_deref()
    }

    pub fn blocked_at(&self) -> Option<DateTime<Utc>> {
        self.blocked_at
    }

    pub fn blocked_by(&self) -> Option<&str> {
        self.blocked_by.as_deref()
    }

    pub fn expires_at(&self) -> Option<DateTime<Utc>> {
        self.expires_at
    }

    pub fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }

    pub fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }

    pub fn deleted_at(&self) -> Option<DateTime<Utc>> {
        self.deleted_at
    }

    pub fn redirect_count(&self) -> i64 {
        self.redirect_count
    }
}

#[derive(Clone)]
pub struct LinkRepository {
    pool: PgPool,
}

impl LinkRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    pub async fn create_anonymous_direct(
        &self,
        input: CreateDirectLink,
    ) -> Result<LinkRecord, LinkRepositoryError> {
        self.create_anonymous(input.0).await
    }

    pub async fn create_anonymous_direct_with_generator<G>(
        &self,
        input: CreateDirectLink,
        generator: &G,
    ) -> Result<LinkRecord, LinkRepositoryError>
    where
        G: SlugGenerator,
    {
        self.create_anonymous_with_generator(input.0, generator)
            .await
    }

    pub async fn create_anonymous(
        &self,
        input: CreateLink,
    ) -> Result<LinkRecord, LinkRepositoryError> {
        self.create(input, None).await
    }

    pub async fn create(
        &self,
        input: CreateLink,
        owner_id: Option<Uuid>,
    ) -> Result<LinkRecord, LinkRepositoryError> {
        self.create_with_generator(input, owner_id, &SecureSlugGenerator)
            .await
    }

    pub async fn create_anonymous_with_generator<G>(
        &self,
        input: CreateLink,
        generator: &G,
    ) -> Result<LinkRecord, LinkRepositoryError>
    where
        G: SlugGenerator,
    {
        self.create_with_generator(input, None, generator).await
    }

    async fn create_with_generator<G>(
        &self,
        input: CreateLink,
        owner_id: Option<Uuid>,
        generator: &G,
    ) -> Result<LinkRecord, LinkRepositoryError>
    where
        G: SlugGenerator,
    {
        if let Some(custom_slug) = input.custom_slug.clone() {
            return self
                .insert_link(&input, custom_slug, owner_id)
                .await
                .map_err(|error| {
                    if is_slug_conflict(&error) {
                        LinkRepositoryError::SlugTaken
                    } else {
                        LinkRepositoryError::database(error)
                    }
                });
        }

        for _ in 0..MAX_SLUG_ATTEMPTS {
            let slug = generator
                .generate()
                .map_err(LinkRepositoryError::SlugGeneration)?;
            match self.insert_link(&input, slug, owner_id).await {
                Ok(record) => return Ok(record),
                Err(error) if is_slug_conflict(&error) => continue,
                Err(error) => return Err(LinkRepositoryError::database(error)),
            }
        }

        Err(LinkRepositoryError::SlugRetriesExhausted)
    }

    pub async fn get_by_id(&self, id: Uuid) -> Result<Option<LinkRecord>, LinkRepositoryError> {
        let row = sqlx::query_as::<_, LinkRow>(
            r#"
            SELECT id, slug, owner_id, target_url, title, kind, status,
                   blocked_reason, blocked_at, blocked_by,
                   expires_at, created_at, updated_at, deleted_at, redirect_count
            FROM links
            WHERE id = $1
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(LinkRepositoryError::database)?;

        row.map(LinkRecord::try_from)
            .transpose()
            .map_err(LinkRepositoryError::corrupt_data)
    }

    pub async fn get_owned_by_id(
        &self,
        owner_id: Uuid,
        id: Uuid,
    ) -> Result<Option<LinkRecord>, LinkRepositoryError> {
        let row = sqlx::query_as::<_, LinkRow>(
            r#"
            SELECT id, slug, owner_id, target_url, title, kind, status,
                   blocked_reason, blocked_at, blocked_by,
                   expires_at, created_at, updated_at, deleted_at, redirect_count
            FROM links
            WHERE id = $1 AND owner_id = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .bind(owner_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(LinkRepositoryError::database)?;
        row.map(LinkRecord::try_from)
            .transpose()
            .map_err(LinkRepositoryError::corrupt_data)
    }

    pub async fn list_owned(
        &self,
        owner_id: Uuid,
        query: &OwnedLinkQuery,
    ) -> Result<OwnedLinkPage, LinkRepositoryError> {
        let search = query
            .search
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| format!("%{value}%"));
        let kind = query.kind.map(LinkKind::as_str);
        let status = query.status.map(LinkStatus::as_str);
        let expiration = query.expiration.map(OwnedLinkExpiration::as_str);
        let tag = query.tag.as_deref();
        let total_items = sqlx::query_scalar::<_, i64>(
            r#"
            SELECT COUNT(*)
            FROM links
            WHERE owner_id = $1 AND deleted_at IS NULL
              AND ($2::TEXT IS NULL OR kind = $2)
              AND ($3::TEXT IS NULL OR status = $3)
              AND ($4::TEXT IS NULL OR title ILIKE $4 OR slug ILIKE $4 OR target_url ILIKE $4)
              AND ($5::TEXT IS NULL
                   OR ($5 = 'not_expired' AND (expires_at IS NULL OR expires_at > NOW()))
                   OR ($5 = 'expired' AND expires_at <= NOW())
                   OR ($5 = 'never' AND expires_at IS NULL))
              AND ($6::TEXT IS NULL OR EXISTS (
                    SELECT 1
                    FROM link_tags lt
                    JOIN tags t ON t.id = lt.tag_id
                    WHERE lt.link_id = links.id
                      AND t.owner_id = $1
                      AND t.normalized_name = $6
              ))
            "#,
        )
        .bind(owner_id)
        .bind(kind)
        .bind(status)
        .bind(search.as_deref())
        .bind(expiration)
        .bind(tag)
        .fetch_one(&self.pool)
        .await
        .map_err(LinkRepositoryError::database)?;

        let order_by = match (query.sort, query.direction) {
            (OwnedLinkSort::CreatedAt, SortDirection::Ascending) => "created_at ASC, id ASC",
            (OwnedLinkSort::CreatedAt, SortDirection::Descending) => "created_at DESC, id DESC",
            (OwnedLinkSort::RedirectCount, SortDirection::Ascending) => {
                "redirect_count ASC, id ASC"
            }
            (OwnedLinkSort::RedirectCount, SortDirection::Descending) => {
                "redirect_count DESC, id DESC"
            }
        };
        let sql = format!(
            r#"
            SELECT id, slug, owner_id, target_url, title, kind, status,
                   blocked_reason, blocked_at, blocked_by,
                   expires_at, created_at, updated_at, deleted_at, redirect_count
            FROM links
            WHERE owner_id = $1 AND deleted_at IS NULL
              AND ($2::TEXT IS NULL OR kind = $2)
              AND ($3::TEXT IS NULL OR status = $3)
              AND ($4::TEXT IS NULL OR title ILIKE $4 OR slug ILIKE $4 OR target_url ILIKE $4)
              AND ($5::TEXT IS NULL
                   OR ($5 = 'not_expired' AND (expires_at IS NULL OR expires_at > NOW()))
                   OR ($5 = 'expired' AND expires_at <= NOW())
                   OR ($5 = 'never' AND expires_at IS NULL))
              AND ($6::TEXT IS NULL OR EXISTS (
                    SELECT 1
                    FROM link_tags lt
                    JOIN tags t ON t.id = lt.tag_id
                    WHERE lt.link_id = links.id
                      AND t.owner_id = $1
                      AND t.normalized_name = $6
              ))
            ORDER BY {order_by}
            LIMIT $7 OFFSET $8
            "#
        );
        let offset = i64::from(query.page.saturating_sub(1)) * i64::from(query.page_size);
        // `order_by` is selected exclusively from the closed enums above; user input is bound.
        let rows = sqlx::query_as::<_, LinkRow>(sqlx::AssertSqlSafe(sql.as_str()))
            .bind(owner_id)
            .bind(kind)
            .bind(status)
            .bind(search.as_deref())
            .bind(expiration)
            .bind(tag)
            .bind(i64::from(query.page_size))
            .bind(offset)
            .fetch_all(&self.pool)
            .await
            .map_err(LinkRepositoryError::database)?;
        let items = rows
            .into_iter()
            .map(LinkRecord::try_from)
            .collect::<Result<Vec<_>, _>>()
            .map_err(LinkRepositoryError::corrupt_data)?;
        Ok(OwnedLinkPage { items, total_items })
    }

    pub async fn tags_for_owned_links(
        &self,
        owner_id: Uuid,
        link_ids: &[Uuid],
    ) -> Result<HashMap<Uuid, Vec<String>>, LinkRepositoryError> {
        if link_ids.is_empty() {
            return Ok(HashMap::new());
        }
        let rows = sqlx::query_as::<_, LinkTagRow>(
            r#"
            SELECT lt.link_id, t.name
            FROM link_tags lt
            JOIN tags t ON t.id = lt.tag_id
            JOIN links l ON l.id = lt.link_id
            WHERE t.owner_id = $1 AND l.owner_id = $1 AND lt.link_id = ANY($2)
            ORDER BY lt.link_id, lt.position
            "#,
        )
        .bind(owner_id)
        .bind(link_ids)
        .fetch_all(&self.pool)
        .await
        .map_err(LinkRepositoryError::database)?;
        let mut tags = HashMap::<Uuid, Vec<String>>::new();
        for row in rows {
            tags.entry(row.link_id).or_default().push(row.name);
        }
        Ok(tags)
    }

    pub async fn list_owned_tags(
        &self,
        owner_id: Uuid,
    ) -> Result<Vec<OwnedTagSummary>, LinkRepositoryError> {
        sqlx::query_as::<_, OwnedTagSummaryRow>(
            r#"
            SELECT t.name, COUNT(*)::BIGINT AS link_count
            FROM tags t
            JOIN link_tags lt ON lt.tag_id = t.id
            JOIN links l ON l.id = lt.link_id
            WHERE t.owner_id = $1 AND l.owner_id = $1 AND l.deleted_at IS NULL
            GROUP BY t.id, t.name, t.normalized_name
            ORDER BY t.normalized_name, t.id
            "#,
        )
        .bind(owner_id)
        .fetch_all(&self.pool)
        .await
        .map(|rows| {
            rows.into_iter()
                .map(|row| OwnedTagSummary {
                    name: row.name,
                    link_count: row.link_count,
                })
                .collect()
        })
        .map_err(LinkRepositoryError::database)
    }

    pub async fn replace_owned_tags(
        &self,
        owner_id: Uuid,
        link_id: Uuid,
        tags: &[LinkTag],
    ) -> Result<Option<Vec<String>>, LinkRepositoryError> {
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(LinkRepositoryError::database)?;
        let owned = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM links WHERE id = $1 AND owner_id = $2 AND deleted_at IS NULL)",
        )
        .bind(link_id)
        .bind(owner_id)
        .fetch_one(&mut *transaction)
        .await
        .map_err(LinkRepositoryError::database)?;
        if !owned {
            return Ok(None);
        }

        sqlx::query("DELETE FROM link_tags WHERE link_id = $1")
            .bind(link_id)
            .execute(&mut *transaction)
            .await
            .map_err(LinkRepositoryError::database)?;
        for (position, tag) in tags.iter().enumerate() {
            let tag_id = sqlx::query_scalar::<_, Uuid>(
                r#"
                INSERT INTO tags (id, owner_id, name, normalized_name)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (owner_id, normalized_name)
                DO UPDATE SET name = EXCLUDED.name, updated_at = NOW()
                RETURNING id
                "#,
            )
            .bind(Uuid::new_v4())
            .bind(owner_id)
            .bind(tag.name())
            .bind(tag.normalized_name())
            .fetch_one(&mut *transaction)
            .await
            .map_err(LinkRepositoryError::database)?;
            sqlx::query("INSERT INTO link_tags (link_id, tag_id, position) VALUES ($1, $2, $3)")
                .bind(link_id)
                .bind(tag_id)
                .bind(i16::try_from(position).expect("tag limit fits SMALLINT"))
                .execute(&mut *transaction)
                .await
                .map_err(LinkRepositoryError::database)?;
        }
        cleanup_unused_tags(&mut transaction, owner_id).await?;
        transaction
            .commit()
            .await
            .map_err(LinkRepositoryError::database)?;
        Ok(Some(tags.iter().map(|tag| tag.name().to_owned()).collect()))
    }

    pub async fn update_owned(
        &self,
        owner_id: Uuid,
        id: Uuid,
        input: UpdateOwnedLink,
    ) -> Result<Option<LinkRecord>, LinkRepositoryError> {
        let (preserve_password, password_hash) = match input.password_hash {
            PasswordHashUpdate::Preserve => (true, None),
            PasswordHashUpdate::Replace(value) => (false, Some(value)),
            PasswordHashUpdate::Remove => (false, None),
        };
        let row = sqlx::query_as::<_, LinkRow>(
            r#"
            UPDATE links
            SET slug = $3, target_url = $4, title = $5, kind = $6,
                password_hash = CASE WHEN $7 THEN password_hash ELSE $8 END,
                expires_at = $9, updated_at = NOW()
            WHERE id = $1 AND owner_id = $2 AND deleted_at IS NULL
            RETURNING id, slug, owner_id, target_url, title, kind, status,
                      blocked_reason, blocked_at, blocked_by,
                      expires_at, created_at, updated_at, deleted_at, redirect_count
            "#,
        )
        .bind(id)
        .bind(owner_id)
        .bind(input.slug.as_str())
        .bind(input.target_url.as_str())
        .bind(input.title.as_deref())
        .bind(input.kind.as_str())
        .bind(preserve_password)
        .bind(password_hash.as_ref().map(LinkPasswordHash::as_str))
        .bind(input.expires_at)
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| {
            if is_slug_conflict(&error) {
                LinkRepositoryError::SlugTaken
            } else {
                LinkRepositoryError::database(error)
            }
        })?;
        row.map(LinkRecord::try_from)
            .transpose()
            .map_err(LinkRepositoryError::corrupt_data)
    }

    pub async fn set_owned_status(
        &self,
        owner_id: Uuid,
        id: Uuid,
        status: LinkStatus,
    ) -> Result<Option<LinkRecord>, LinkRepositoryError> {
        let row = sqlx::query_as::<_, LinkRow>(
            r#"
            UPDATE links
            SET status = $3, updated_at = NOW()
            WHERE id = $1 AND owner_id = $2 AND deleted_at IS NULL AND status <> 'blocked'
            RETURNING id, slug, owner_id, target_url, title, kind, status,
                      blocked_reason, blocked_at, blocked_by,
                      expires_at, created_at, updated_at, deleted_at, redirect_count
            "#,
        )
        .bind(id)
        .bind(owner_id)
        .bind(status.as_str())
        .fetch_optional(&self.pool)
        .await
        .map_err(LinkRepositoryError::database)?;
        row.map(LinkRecord::try_from)
            .transpose()
            .map_err(LinkRepositoryError::corrupt_data)
    }

    pub async fn soft_delete_owned(
        &self,
        owner_id: Uuid,
        id: Uuid,
    ) -> Result<bool, LinkRepositoryError> {
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(LinkRepositoryError::database)?;
        let result = sqlx::query(
            r#"
            UPDATE links
            SET deleted_at = NOW(), updated_at = NOW()
            WHERE id = $1 AND owner_id = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(id)
        .bind(owner_id)
        .execute(&mut *transaction)
        .await
        .map_err(LinkRepositoryError::database)?;
        if result.rows_affected() == 1 {
            sqlx::query("DELETE FROM link_tags WHERE link_id = $1")
                .bind(id)
                .execute(&mut *transaction)
                .await
                .map_err(LinkRepositoryError::database)?;
            cleanup_unused_tags(&mut transaction, owner_id).await?;
        }
        transaction
            .commit()
            .await
            .map_err(LinkRepositoryError::database)?;
        Ok(result.rows_affected() == 1)
    }

    pub async fn find_active_by_slug(
        &self,
        slug: &Slug,
    ) -> Result<Option<LinkRecord>, LinkRepositoryError> {
        let row = sqlx::query_as::<_, LinkRow>(
            r#"
            SELECT id, slug, owner_id, target_url, title, kind, status,
                   blocked_reason, blocked_at, blocked_by,
                   expires_at, created_at, updated_at, deleted_at, redirect_count
            FROM links
            WHERE slug = $1
              AND status = 'active'
              AND deleted_at IS NULL
              AND (expires_at IS NULL OR expires_at > NOW())
            "#,
        )
        .bind(slug.as_str())
        .fetch_optional(&self.pool)
        .await
        .map_err(LinkRepositoryError::database)?;

        row.map(LinkRecord::try_from)
            .transpose()
            .map_err(LinkRepositoryError::corrupt_data)
    }

    pub async fn resolve_public_by_slug(
        &self,
        slug: &Slug,
    ) -> Result<PublicLinkResolution, LinkRepositoryError> {
        let row = sqlx::query_as::<_, LinkRow>(
            r#"
            SELECT id, slug, owner_id, target_url, title, kind, status,
                   blocked_reason, blocked_at, blocked_by,
                   expires_at, created_at, updated_at, deleted_at, redirect_count
            FROM links
            WHERE slug = $1
            "#,
        )
        .bind(slug.as_str())
        .fetch_optional(&self.pool)
        .await
        .map_err(LinkRepositoryError::database)?;

        let Some(row) = row else {
            return Ok(PublicLinkResolution::NotFound);
        };
        let record = LinkRecord::try_from(row).map_err(LinkRepositoryError::corrupt_data)?;

        if record.deleted_at().is_some() {
            return Ok(PublicLinkResolution::NotFound);
        }
        match record.status() {
            LinkStatus::Disabled => return Ok(PublicLinkResolution::Disabled),
            LinkStatus::Blocked => return Ok(PublicLinkResolution::Blocked),
            LinkStatus::Active => {}
        }
        if record.expires_at().is_some_and(|value| value <= Utc::now()) {
            return Ok(PublicLinkResolution::Expired);
        }

        Ok(PublicLinkResolution::Active(Box::new(record)))
    }

    pub async fn record_direct_redirect(&self, id: Uuid) -> Result<bool, LinkRepositoryError> {
        let result = sqlx::query(
            r#"
            UPDATE links
            SET redirect_count = redirect_count + 1
            WHERE id = $1
              AND kind = 'direct'
              AND status = 'active'
              AND deleted_at IS NULL
              AND (expires_at IS NULL OR expires_at > NOW())
            "#,
        )
        .bind(id)
        .execute(&self.pool)
        .await
        .map_err(LinkRepositoryError::database)?;

        Ok(result.rows_affected() == 1)
    }

    async fn insert_link(
        &self,
        input: &CreateLink,
        slug: Slug,
        owner_id: Option<Uuid>,
    ) -> Result<LinkRecord, sqlx::Error> {
        let row = sqlx::query_as::<_, LinkRow>(
            r#"
            INSERT INTO links (
                id, slug, owner_id, target_url, title, kind, password_hash, status, expires_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING id, slug, owner_id, target_url, title, kind, status,
                      blocked_reason, blocked_at, blocked_by,
                      expires_at, created_at, updated_at, deleted_at, redirect_count
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(slug.as_str())
        .bind(owner_id)
        .bind(input.target_url.as_str())
        .bind(input.title.as_deref())
        .bind(input.kind.as_str())
        .bind(input.password_hash.as_ref().map(LinkPasswordHash::as_str))
        .bind(LinkStatus::Active.as_str())
        .bind(input.expires_at)
        .fetch_one(&self.pool)
        .await?;

        LinkRecord::try_from(row).map_err(|error| sqlx::Error::Decode(Box::new(error)))
    }
}

#[derive(FromRow)]
struct LinkRow {
    id: Uuid,
    slug: String,
    owner_id: Option<Uuid>,
    target_url: String,
    title: Option<String>,
    kind: String,
    status: String,
    blocked_reason: Option<String>,
    blocked_at: Option<DateTime<Utc>>,
    blocked_by: Option<String>,
    expires_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    deleted_at: Option<DateTime<Utc>>,
    redirect_count: i64,
}

#[derive(FromRow)]
struct LinkTagRow {
    link_id: Uuid,
    name: String,
}

#[derive(FromRow)]
struct OwnedTagSummaryRow {
    name: String,
    link_count: i64,
}

async fn cleanup_unused_tags(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    owner_id: Uuid,
) -> Result<(), LinkRepositoryError> {
    sqlx::query(
        r#"
        DELETE FROM tags t
        WHERE t.owner_id = $1
          AND NOT EXISTS (SELECT 1 FROM link_tags lt WHERE lt.tag_id = t.id)
        "#,
    )
    .bind(owner_id)
    .execute(&mut **transaction)
    .await
    .map_err(LinkRepositoryError::database)?;
    Ok(())
}

impl TryFrom<LinkRow> for LinkRecord {
    type Error = StoredLinkError;

    fn try_from(row: LinkRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            slug: Slug::parse(row.slug).map_err(StoredLinkError::Slug)?,
            owner_id: row.owner_id,
            target_url: row.target_url,
            title: row.title,
            kind: row.kind.parse().map_err(StoredLinkError::Kind)?,
            status: row.status.parse().map_err(StoredLinkError::Status)?,
            blocked_reason: row.blocked_reason,
            blocked_at: row.blocked_at,
            blocked_by: row.blocked_by,
            expires_at: row.expires_at,
            created_at: row.created_at,
            updated_at: row.updated_at,
            deleted_at: row.deleted_at,
            redirect_count: row.redirect_count,
        })
    }
}

#[derive(Debug)]
enum StoredLinkError {
    Slug(super::SlugError),
    Kind(ParseLinkKindError),
    Status(ParseLinkStatusError),
}

impl fmt::Display for StoredLinkError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Slug(error) => write!(formatter, "stored link has an invalid slug: {error}"),
            Self::Kind(error) => write!(formatter, "stored link has an invalid kind: {error}"),
            Self::Status(error) => write!(formatter, "stored link has an invalid status: {error}"),
        }
    }
}

impl Error for StoredLinkError {}

pub enum LinkRepositoryError {
    SlugTaken,
    SlugGeneration(SlugGenerationError),
    SlugRetriesExhausted,
    Database(sqlx::Error),
    CorruptData(Box<dyn Error + Send + Sync>),
}

impl LinkRepositoryError {
    fn database(error: sqlx::Error) -> Self {
        Self::Database(error)
    }

    fn corrupt_data(error: StoredLinkError) -> Self {
        Self::CorruptData(Box::new(error))
    }
}

impl fmt::Debug for LinkRepositoryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Display::fmt(self, formatter)
    }
}

impl fmt::Display for LinkRepositoryError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        let message = match self {
            Self::SlugTaken => "slug is already in use",
            Self::SlugGeneration(_) => "failed to generate a link slug",
            Self::SlugRetriesExhausted => "failed to allocate a unique link slug",
            Self::Database(_) => "link database operation failed",
            Self::CorruptData(_) => "stored link data is invalid",
        };
        formatter.write_str(message)
    }
}

impl Error for LinkRepositoryError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::SlugGeneration(error) => Some(error),
            Self::Database(error) => Some(error),
            Self::CorruptData(error) => Some(error.as_ref()),
            Self::SlugTaken | Self::SlugRetriesExhausted => None,
        }
    }
}

fn is_slug_conflict(error: &sqlx::Error) -> bool {
    let sqlx::Error::Database(error) = error else {
        return false;
    };

    error.code().as_deref() == Some("23505") && error.constraint() == Some("links_slug_unique")
}

fn normalize_title(title: Option<String>) -> Result<Option<String>, CreateLinkError> {
    let title = title
        .map(|value| value.trim().to_owned())
        .filter(|value| !value.is_empty());
    if title
        .as_ref()
        .is_some_and(|value| value.chars().count() > MAX_TITLE_LENGTH)
    {
        return Err(CreateLinkError::TitleTooLong);
    }
    Ok(title)
}

fn validate_expiration(expires_at: Option<DateTime<Utc>>) -> Result<(), CreateLinkError> {
    if expires_at.is_some_and(|value| value <= Utc::now()) {
        return Err(CreateLinkError::ExpirationNotFuture);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, Utc};
    use url::Url;

    use super::{CreateDirectLink, CreateLinkError, MAX_TITLE_LENGTH};
    use crate::links::TargetUrl;

    fn target_url() -> TargetUrl {
        TargetUrl::parse(
            "https://example.com",
            &Url::parse("https://linkso.su").unwrap(),
        )
        .unwrap()
    }

    #[test]
    fn trims_title_and_treats_blank_title_as_absent() {
        let with_title =
            CreateDirectLink::new(target_url(), None, Some("  Example  ".into()), None).unwrap();
        assert_eq!(with_title.0.title.as_deref(), Some("Example"));

        let blank = CreateDirectLink::new(target_url(), None, Some("   ".into()), None).unwrap();
        assert_eq!(blank.0.title, None);
    }

    #[test]
    fn rejects_long_title_and_past_expiration() {
        assert!(matches!(
            CreateDirectLink::new(
                target_url(),
                None,
                Some("a".repeat(MAX_TITLE_LENGTH + 1)),
                None,
            ),
            Err(CreateLinkError::TitleTooLong)
        ));
        assert!(matches!(
            CreateDirectLink::new(
                target_url(),
                None,
                None,
                Some(Utc::now() - Duration::seconds(1)),
            ),
            Err(CreateLinkError::ExpirationNotFuture)
        ));
    }
}
