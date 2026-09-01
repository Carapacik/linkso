const maximumTargetUrlLength = 2048;

enum TargetUrlValidationError() {
  required,
  tooLong,
  invalid,
  unsupportedScheme,
}

TargetUrlValidationError? validateTargetUrl(String value) {
  final String normalizedValue = value.trim();
  if (normalizedValue.isEmpty) {
    return TargetUrlValidationError.required;
  }
  if (normalizedValue.length > maximumTargetUrlLength) {
    return TargetUrlValidationError.tooLong;
  }

  final Uri? uri = Uri.tryParse(normalizedValue);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
    return TargetUrlValidationError.invalid;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return TargetUrlValidationError.unsupportedScheme;
  }

  return null;
}
