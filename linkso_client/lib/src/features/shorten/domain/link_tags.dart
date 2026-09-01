const maximumTagsPerLink = 10;
const maximumTagNameLength = 32;

enum LinkTagsValidationError() {
  empty,
  tooLong,
  tooMany,
}

List<String> parseLinkTags(String value) {
  final tags = <String>[];
  final normalized = <String>{};
  for (final String rawTag in value.split(RegExp('[,\n]'))) {
    final String tag = rawTag.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).join(' ');
    if (tag.isEmpty) {
      continue;
    }
    if (normalized.add(tag.toLowerCase())) {
      tags.add(tag);
    }
  }
  return tags;
}

LinkTagsValidationError? validateLinkTags(String value) {
  final List<String> tags = parseLinkTags(value);
  if (tags.any((tag) => tag.runes.length > maximumTagNameLength)) {
    return LinkTagsValidationError.tooLong;
  }
  if (tags.length > maximumTagsPerLink) {
    return LinkTagsValidationError.tooMany;
  }
  return null;
}
