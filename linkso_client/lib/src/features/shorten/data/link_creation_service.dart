import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/shorten/data/created_link.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';

final class LinkCreationService({required final LinkSoApiClient apiClient}) {
  Future<CreatedLink> create({
    required String targetUrl,
    required LinkKind kind,
    String? title,
    String? slug,
    DateTime? expiresAt,
    String? password,
    List<String> tags = const [],
  }) async {
    final body = <String, Object?>{
      'target_url': targetUrl.trim(),
      'kind': kind.apiValue,
      if (title?.trim().isNotEmpty ?? false) 'title': title!.trim(),
      if (slug?.trim().isNotEmpty ?? false) 'slug': slug!.trim(),
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
      if (password case final String password) 'password': password,
      if (tags.isNotEmpty) 'tags': tags,
    };
    final Map<String, Object?> response = await apiClient.postJson(path: '/api/v1/links', body: body);
    return CreatedLink.fromJson(response);
  }
}
