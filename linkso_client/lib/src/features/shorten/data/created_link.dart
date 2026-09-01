import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';

final class const CreatedLink({
  required final String id,
  required final String slug,
  required final Uri shortUrl,
  required final Uri targetUrl,
  required final LinkKind kind,
  final List<String> tags = const [],
  final String? title,
  final DateTime? expiresAt,
}) {
  factory fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final slug = json['slug'] as String?;
    final Uri? shortUrl = Uri.tryParse(json['short_url'] as String? ?? '');
    final Uri? targetUrl = Uri.tryParse(json['target_url'] as String? ?? '');
    final LinkKind? kind = LinkKind.values.where((value) => value.apiValue == json['kind']).firstOrNull;
    final Object? rawExpiresAt = json['expires_at'];
    final Object? rawTags = json['tags'];
    final DateTime? expiresAt = rawExpiresAt is String ? DateTime.tryParse(rawExpiresAt) : null;

    if (id == null || slug == null || shortUrl == null || !shortUrl.hasAuthority || targetUrl == null || kind == null) {
      throw invalidResponseApiFailure;
    }
    if (rawExpiresAt != null && expiresAt == null) {
      throw invalidResponseApiFailure;
    }
    final List<String> tags;
    try {
      tags = rawTags == null ? const [] : (rawTags as List<Object?>).cast<String>();
    } on Object {
      throw invalidResponseApiFailure;
    }

    return CreatedLink(
      id: id,
      slug: slug,
      shortUrl: shortUrl,
      targetUrl: targetUrl,
      kind: kind,
      title: json['title'] as String?,
      expiresAt: expiresAt,
      tags: tags,
    );
  }
}
