const maximumLinkTitleLength = 120;
const minimumCustomSlugLength = 3;
const maximumCustomSlugLength = 64;
const minimumLinkPasswordLength = 8;
const maximumLinkPasswordLength = 128;

const reservedSlugs = {'ad', 'admin', 'api', 'auth', 'go', 'health', 'p', 'settings'};

enum TitleValidationError() {
  tooLong,
}

enum SlugValidationError() {
  tooShort,
  tooLong,
  invalidFormat,
  reserved,
}

enum PasswordValidationError() {
  required,
  tooShort,
  tooLong,
}

enum ExpirationValidationError() {
  notFuture,
}

TitleValidationError? validateLinkTitle(String value) {
  if (value.trim().length > maximumLinkTitleLength) {
    return TitleValidationError.tooLong;
  }
  return null;
}

SlugValidationError? validateCustomSlug(String value) {
  final String slug = value.trim();
  if (slug.isEmpty) {
    return null;
  }
  if (slug.length < minimumCustomSlugLength) {
    return SlugValidationError.tooShort;
  }
  if (slug.length > maximumCustomSlugLength) {
    return SlugValidationError.tooLong;
  }
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*[A-Za-z0-9]$').hasMatch(slug)) {
    return SlugValidationError.invalidFormat;
  }
  if (reservedSlugs.contains(slug.toLowerCase())) {
    return SlugValidationError.reserved;
  }
  return null;
}

PasswordValidationError? validateLinkPassword(String value) {
  if (value.isEmpty) {
    return PasswordValidationError.required;
  }
  if (value.length < minimumLinkPasswordLength) {
    return PasswordValidationError.tooShort;
  }
  if (value.length > maximumLinkPasswordLength) {
    return PasswordValidationError.tooLong;
  }
  return null;
}

ExpirationValidationError? validateExpiration(DateTime? value, DateTime now) {
  if (value != null && !value.isAfter(now)) {
    return ExpirationValidationError.notFuture;
  }
  return null;
}
