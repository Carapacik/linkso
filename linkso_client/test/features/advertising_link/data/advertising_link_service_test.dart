import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/advertising_link/data/advertising_link_service.dart';

void main() {
  test('starts and continues an advertising session without receiving the target URL', () async {
    final requests = <http.Request>[];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/sessions')) {
          return http.Response(
            jsonEncode({
              'session_id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
              'unlocks_at': '2026-08-28T12:00:05Z',
              'expires_at': '2026-08-28T12:10:00Z',
              'campaign': {
                'id': '01991a6c-b267-7a11-9b26-9cdd65e44072',
                'title': 'Campaign',
                'body': 'Campaign body',
                'image_url': 'https://cdn.example/ad.png',
                'advertiser_url': 'https://advertiser.example/offer',
                'ends_at': '2026-08-28T13:00:00Z',
              },
            }),
            200,
          );
        }
        return http.Response(
          '{"redirect_url":"https://linkso.su/api/v1/advertising-links/tickets/01991a6c-b267-7a11-9b26-9cdd65e44073","expires_at":"2026-08-28T12:01:00Z"}',
          200,
        );
      }),
    );
    addTearDown(apiClient.close);
    final service = AdvertisingLinkService(apiClient: apiClient);

    final AdvertisingSession session = await service.start('AdFlow42');
    final AdvertisingTicket ticket = await service.continueSession(slug: 'AdFlow42', sessionId: session.id);

    final AdvertisingCampaign? campaign = session.campaign;
    expect(campaign, isNotNull);
    expect(campaign!.title, 'Campaign');
    expect(campaign.imageUri, Uri.parse('https://cdn.example/ad.png'));
    expect(ticket.redirectUri.path, contains('/advertising-links/tickets/'));
    expect(requests.map((request) => request.url.path), [
      '/api/v1/advertising-links/AdFlow42/sessions',
      '/api/v1/advertising-links/AdFlow42/sessions/01991a6c-b267-7a11-9b26-9cdd65e44071/continue',
    ]);
  });

  test('accepts a session without an active campaign', () async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient(
        (_) async => http.Response(
          '{"session_id":"01991a6c-b267-7a11-9b26-9cdd65e44071","unlocks_at":"2026-08-28T12:00:05Z","expires_at":"2026-08-28T12:10:00Z","campaign":null}',
          200,
        ),
      ),
    );
    addTearDown(apiClient.close);

    final AdvertisingSession session = await AdvertisingLinkService(apiClient: apiClient).start('AdFlow42');

    expect(session.campaign, isNull);
  });

  test('rejects a nested target URL leak in the session response', () async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient(
        (_) async => http.Response(
          '{"session_id":"id","unlocks_at":"2026-08-28T12:00:05Z","expires_at":"2026-08-28T12:10:00Z","campaign":{"target_url":"https://secret.example"}}',
          200,
        ),
      ),
    );
    addTearDown(apiClient.close);

    await expectLater(
      AdvertisingLinkService(apiClient: apiClient).start('AdFlow42'),
      throwsA(same(invalidResponseApiFailure)),
    );
  });
}
