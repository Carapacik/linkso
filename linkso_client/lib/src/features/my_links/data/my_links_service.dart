import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/my_links/data/my_link.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';

final class MyLinksService({required final LinkSoApiClient apiClient}) {
  Future<MyLinksResult> list({
    int page = 1,
    int pageSize = 20,
    String? query,
    LinkKind? kind,
    MyLinkStatus? status,
    MyLinksExpirationFilter? expiration,
    MyLinksSort sort = MyLinksSort.createdAt,
    SortDirection direction = SortDirection.descending,
    String? tag,
  }) async {
    final parameters = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (query?.trim().isNotEmpty ?? false) 'query': query!.trim(),
      if (kind != null) 'kind': kind.apiValue,
      if (status != null) 'status': status.name,
      if (expiration != null) 'expiration': _expirationValue(expiration),
      'sort': sort == MyLinksSort.createdAt ? 'created_at' : 'redirect_count',
      'direction': direction == SortDirection.ascending ? 'asc' : 'desc',
      if (tag?.trim().isNotEmpty ?? false) 'tag': tag!.trim(),
    };
    final path = Uri(path: '/api/v1/me/links', queryParameters: parameters).toString();
    final Map<String, Object?> json = await apiClient.getJson(path: path);
    try {
      final rawItems = json['items']! as List<Object?>;
      final Map<String, Object?> pagination = (json['pagination']! as Map).cast<String, Object?>();
      return MyLinksResult(
        items: rawItems.map((item) => MyLink.fromJson((item! as Map).cast<String, Object?>())).toList(),
        page: pagination['page']! as int,
        pageSize: pagination['page_size']! as int,
        totalItems: pagination['total_items']! as int,
        totalPages: pagination['total_pages']! as int,
      );
    } on ApiFailure {
      rethrow;
    } on Object {
      throw invalidResponseApiFailure;
    }
  }

  Future<MyLink> get(String id) async =>
      MyLink.fromJson(await apiClient.getJson(path: '/api/v1/me/links/${Uri.encodeComponent(id)}'));

  Future<List<MyTagSummary>> listTags() async {
    final List<Object?> json = await apiClient.getJsonList(path: '/api/v1/me/tags');
    try {
      return json.map((item) => MyTagSummary.fromJson((item! as Map).cast<String, Object?>())).toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on Object {
      throw invalidResponseApiFailure;
    }
  }

  Future<MyLink> update({
    required String id,
    required String targetUrl,
    required String slug,
    required LinkKind kind,
    String? title,
    DateTime? expiresAt,
    String? password,
    List<String>? tags,
  }) async {
    final Map<String, Object?> json = await apiClient.putJson(
      path: '/api/v1/me/links/${Uri.encodeComponent(id)}',
      body: {
        'target_url': targetUrl.trim(),
        'slug': slug.trim(),
        'kind': kind.apiValue,
        'title': title?.trim().isEmpty ?? true ? null : title!.trim(),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        if (password?.isNotEmpty ?? false) 'password': password,
        'tags': ?tags,
      },
    );
    return MyLink.fromJson(json);
  }

  Future<MyLink> setEnabled(String id, {required bool enabled}) async => MyLink.fromJson(
    await apiClient.postJson(
      path: '/api/v1/me/links/${Uri.encodeComponent(id)}/${enabled ? 'enable' : 'disable'}',
      body: const {},
    ),
  );

  Future<void> delete(String id) => apiClient.deleteEmpty(path: '/api/v1/me/links/${Uri.encodeComponent(id)}');

  String _expirationValue(MyLinksExpirationFilter value) => switch (value) {
    MyLinksExpirationFilter.notExpired => 'not_expired',
    MyLinksExpirationFilter.expired => 'expired',
    MyLinksExpirationFilter.never => 'never',
  };
}
