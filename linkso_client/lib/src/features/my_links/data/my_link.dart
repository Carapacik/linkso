import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';

enum MyLinkStatus() {
  active,
  disabled,
  blocked,
}

final class const MyLink({
  required final String id,
  required final String slug,
  required final Uri shortUrl,
  required final Uri targetUrl,
  required final LinkKind kind,
  required final MyLinkStatus status,
  required final DateTime createdAt,
  required final DateTime updatedAt,
  required final int redirectCount,
  final List<String> tags = const [],
  final String? title,
  final DateTime? expiresAt,
}) {
  factory fromJson(Map<String, Object?> json) {
    try {
      final Uri shortUrl = Uri.parse(json['short_url']! as String);
      final Uri targetUrl = Uri.parse(json['target_url']! as String);
      final LinkKind kind = LinkKind.values.singleWhere((value) => value.apiValue == json['kind']);
      final MyLinkStatus status = MyLinkStatus.values.singleWhere((value) => value.name == json['status']);
      final Object? rawExpiration = json['expires_at'];
      final DateTime? expiresAt = rawExpiration is String ? DateTime.parse(rawExpiration) : null;
      final Object? rawTags = json['tags'];
      final List<String> tags = rawTags == null ? const [] : (rawTags as List<Object?>).cast<String>();
      if (!shortUrl.hasAuthority || !targetUrl.hasAuthority || (rawExpiration != null && expiresAt == null)) {
        throw invalidResponseApiFailure;
      }
      return MyLink(
        id: json['id']! as String,
        slug: json['slug']! as String,
        shortUrl: shortUrl,
        targetUrl: targetUrl,
        title: json['title'] as String?,
        kind: kind,
        status: status,
        expiresAt: expiresAt,
        createdAt: DateTime.parse(json['created_at']! as String),
        updatedAt: DateTime.parse(json['updated_at']! as String),
        redirectCount: json['redirect_count']! as int,
        tags: tags,
      );
    } on ApiFailure {
      rethrow;
    } on Object {
      throw invalidResponseApiFailure;
    }
  }
}

final class const MyTagSummary({required final String name, required final int linkCount}) {
  factory fromJson(Map<String, Object?> json) {
    try {
      return MyTagSummary(name: json['name']! as String, linkCount: json['link_count']! as int);
    } on Object {
      throw invalidResponseApiFailure;
    }
  }
}

final class const MyLinksResult({
  required final List<MyLink> items,
  required final int page,
  required final int pageSize,
  required final int totalItems,
  required final int totalPages,
});

enum MyLinksExpirationFilter() {
  notExpired,
  expired,
  never,
}

enum MyLinksSort() {
  createdAt,
  redirectCount,
}

enum SortDirection() {
  ascending,
  descending,
}
