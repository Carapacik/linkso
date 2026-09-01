import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/my_links/data/my_link.dart';
import 'package:linkso_client/src/features/my_links/data/my_links_service.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';

void main() {
  test('lists owned links with pagination, search, filters and sorting', () async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/me/links');
        expect(request.url.queryParameters, {
          'page': '2',
          'page_size': '10',
          'query': 'alpha',
          'kind': 'password',
          'status': 'disabled',
          'expiration': 'never',
          'sort': 'redirect_count',
          'direction': 'asc',
          'tag': 'Work',
        });
        return http.Response(
          jsonEncode({
            'items': [_linkJson()],
            'pagination': {'page': 2, 'page_size': 10, 'total_items': 11, 'total_pages': 2},
          }),
          200,
        );
      }),
    );

    final MyLinksResult result = await MyLinksService(apiClient: apiClient).list(
      page: 2,
      pageSize: 10,
      query: ' alpha ',
      kind: LinkKind.password,
      status: MyLinkStatus.disabled,
      expiration: MyLinksExpirationFilter.never,
      sort: MyLinksSort.redirectCount,
      direction: SortDirection.ascending,
      tag: ' Work ',
    );

    expect(result.totalItems, 11);
    expect(result.items.single.slug, 'OwnedAlpha');
    expect(result.items.single.redirectCount, 30);
    expect(result.items.single.tags, ['Work']);
  });

  test('lists the owner tag summaries', () async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/me/tags');
        return http.Response(
          jsonEncode([
            {'name': 'Work', 'link_count': 2},
          ]),
          200,
        );
      }),
    );
    addTearDown(apiClient.close);

    final List<MyTagSummary> tags = await MyLinksService(apiClient: apiClient).listTags();
    expect(tags.single.name, 'Work');
    expect(tags.single.linkCount, 2);
  });

  test('uses owner-scoped detail, update, status and delete endpoints', () async {
    final requests = <http.Request>[];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return http.Response(jsonEncode(_linkJson()), 200);
      }),
    );
    final service = MyLinksService(apiClient: apiClient);

    await service.get('link-id');
    await service.update(
      id: 'link-id',
      targetUrl: 'https://example.net/new',
      slug: 'UpdatedSlug',
      kind: LinkKind.advertising,
      title: 'Updated',
      tags: const ['Archive'],
    );
    await service.setEnabled('link-id', enabled: false);
    await service.delete('link-id');

    expect(requests.map((request) => '${request.method} ${request.url.path}'), [
      'GET /api/v1/me/links/link-id',
      'PUT /api/v1/me/links/link-id',
      'POST /api/v1/me/links/link-id/disable',
      'DELETE /api/v1/me/links/link-id',
    ]);
    expect(jsonDecode(requests[1].body), {
      'target_url': 'https://example.net/new',
      'slug': 'UpdatedSlug',
      'kind': 'advertising',
      'title': 'Updated',
      'expires_at': null,
      'tags': ['Archive'],
    });
  });
}

Map<String, Object?> _linkJson() => {
  'id': 'link-id',
  'slug': 'OwnedAlpha',
  'short_url': 'https://linkso.su/OwnedAlpha',
  'target_url': 'https://example.com/alpha',
  'title': 'Alpha report',
  'kind': 'direct',
  'status': 'active',
  'expires_at': null,
  'created_at': '2026-08-29T12:00:00Z',
  'updated_at': '2026-08-29T12:00:00Z',
  'redirect_count': 30,
  'tags': ['Work'],
};
