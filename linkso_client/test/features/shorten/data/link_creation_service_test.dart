import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/shorten/data/created_link.dart';
import 'package:linkso_client/src/features/shorten/data/link_creation_service.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';

void main() {
  test('sends the complete creation contract and parses the result', () async {
    final httpClient = MockClient((request) async {
      expect(request.url, Uri.parse('https://linkso.su/api/v1/links'));
      expect(jsonDecode(request.body), {
        'target_url': 'https://example.com/article',
        'kind': 'password',
        'title': 'Team article',
        'slug': 'team-link',
        'expires_at': '2026-09-01T09:30:00.000Z',
        'password': 'secret-pass',
        'tags': ['Work', 'Product Launch'],
      });
      return http.Response(
        jsonEncode({
          'id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
          'slug': 'team-link',
          'short_url': 'https://linkso.su/team-link',
          'target_url': 'https://example.com/article',
          'title': 'Team article',
          'kind': 'password',
          'expires_at': '2026-09-01T09:30:00Z',
          'tags': ['Work', 'Product Launch'],
        }),
        201,
      );
    });
    final apiClient = LinkSoApiClient(baseUri: Uri.parse('https://linkso.su/'), client: httpClient);
    final service = LinkCreationService(apiClient: apiClient);

    final CreatedLink link = await service.create(
      targetUrl: ' https://example.com/article ',
      kind: LinkKind.password,
      title: ' Team article ',
      slug: ' team-link ',
      expiresAt: DateTime.utc(2026, 9, 1, 9, 30),
      password: 'secret-pass',
      tags: const ['Work', 'Product Launch'],
    );

    expect(link.slug, 'team-link');
    expect(link.shortUrl, Uri.parse('https://linkso.su/team-link'));
    expect(link.kind, LinkKind.password);
    expect(link.expiresAt, DateTime.utc(2026, 9, 1, 9, 30));
    expect(link.tags, ['Work', 'Product Launch']);
    apiClient.close();
  });

  test('rejects an incomplete success response', () async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((_) async => http.Response('{"slug":"missing-fields"}', 201)),
    );
    final service = LinkCreationService(apiClient: apiClient);

    await expectLater(
      service.create(targetUrl: 'https://example.com', kind: LinkKind.direct),
      throwsA(isA<ApiFailure>().having((error) => error.code, 'code', 'invalid_response')),
    );
    apiClient.close();
  });

  test('creates an advertising link without a password field', () async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {'target_url': 'https://example.com/advertised', 'kind': 'advertising'});
        return http.Response(
          jsonEncode({
            'id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
            'slug': 'AdFlow42',
            'short_url': 'https://linkso.su/AdFlow42',
            'target_url': 'https://example.com/advertised',
            'title': null,
            'kind': 'advertising',
            'expires_at': null,
          }),
          201,
        );
      }),
    );
    addTearDown(apiClient.close);

    final CreatedLink link = await LinkCreationService(apiClient: apiClient)
        .create(targetUrl: 'https://example.com/advertised', kind: LinkKind.advertising);
    expect(link.kind, LinkKind.advertising);
  });
}
