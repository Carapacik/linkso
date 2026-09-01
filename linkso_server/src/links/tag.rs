use std::{collections::HashSet, error::Error, fmt};

pub const MAX_TAGS_PER_LINK: usize = 10;
pub const MAX_TAG_NAME_LENGTH: usize = 32;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct LinkTag {
    name: String,
    normalized_name: String,
}

impl LinkTag {
    pub fn parse(value: impl AsRef<str>) -> Result<Self, LinkTagError> {
        let name = value
            .as_ref()
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ");
        if name.is_empty() {
            return Err(LinkTagError::Empty);
        }
        if name.chars().count() > MAX_TAG_NAME_LENGTH {
            return Err(LinkTagError::TooLong);
        }
        if name.chars().any(char::is_control) {
            return Err(LinkTagError::InvalidCharacter);
        }
        let normalized_name = name.to_lowercase();
        if normalized_name.chars().count() > MAX_TAG_NAME_LENGTH {
            return Err(LinkTagError::TooLong);
        }
        Ok(Self {
            name,
            normalized_name,
        })
    }

    pub fn parse_many(values: Vec<String>) -> Result<Vec<Self>, LinkTagError> {
        let mut normalized_names = HashSet::new();
        let mut tags = Vec::new();
        for value in values {
            let tag = Self::parse(value)?;
            if normalized_names.insert(tag.normalized_name.clone()) {
                tags.push(tag);
            }
        }
        if tags.len() > MAX_TAGS_PER_LINK {
            return Err(LinkTagError::TooMany);
        }
        Ok(tags)
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn normalized_name(&self) -> &str {
        &self.normalized_name
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LinkTagError {
    Empty,
    TooLong,
    TooMany,
    InvalidCharacter,
}

impl fmt::Display for LinkTagError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Empty => "tag name cannot be empty",
            Self::TooLong => "tag name is too long",
            Self::TooMany => "link has too many tags",
            Self::InvalidCharacter => "tag name contains an invalid character",
        })
    }
}

impl Error for LinkTagError {}

#[cfg(test)]
mod tests {
    use super::{LinkTag, LinkTagError, MAX_TAG_NAME_LENGTH, MAX_TAGS_PER_LINK};

    #[test]
    fn normalizes_spacing_and_case_insensitive_identity() {
        let tag = LinkTag::parse("  Product   Launch  ").unwrap();
        assert_eq!(tag.name(), "Product Launch");
        assert_eq!(tag.normalized_name(), "product launch");
    }

    #[test]
    fn parse_many_deduplicates_normalized_names_in_input_order() {
        let tags = LinkTag::parse_many(vec![
            "Work".to_owned(),
            " work ".to_owned(),
            "Personal".to_owned(),
        ])
        .unwrap();
        assert_eq!(
            tags.iter().map(LinkTag::name).collect::<Vec<_>>(),
            ["Work", "Personal"]
        );
    }

    #[test]
    fn rejects_invalid_names_and_too_many_distinct_tags() {
        assert_eq!(LinkTag::parse("   ").unwrap_err(), LinkTagError::Empty);
        assert_eq!(
            LinkTag::parse("x".repeat(MAX_TAG_NAME_LENGTH + 1)).unwrap_err(),
            LinkTagError::TooLong
        );
        assert_eq!(
            LinkTag::parse_many(
                (0..=MAX_TAGS_PER_LINK)
                    .map(|index| format!("tag {index}"))
                    .collect()
            )
            .unwrap_err(),
            LinkTagError::TooMany
        );
    }
}
