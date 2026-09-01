import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/password_link/data/password_link_service.dart';

void main() {
  test('starts a session and verifies it without receiving a target URL', () async {
    final requests = <http.Request>[];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/sessions')) {
          return http.Response(
            '{"session_id":"01991a6c-b267-7a11-9b26-9cdd65e44071","expires_at":"2026-08-28T12:10:00Z","max_attempts":5}',
            200,
          );
        }
        return http.Response(
          '{"redirect_url":"https://linkso.su/api/v1/password-links/tickets/01991a6c-b267-7a11-9b26-9cdd65e44072","expires_at":"2026-08-28T12:01:00Z"}',
          200,
        );
      }),
    );
    addTearDown(apiClient.close);
    final service = PasswordLinkService(apiClient: apiClient);

    final PasswordLinkSession session = await service.start('Private42');
    final PasswordLinkTicket ticket = await service.verify(
      slug: 'Private42',
      sessionId: session.id,
      password: 'secret pass',
    );

    expect(session.maxAttempts, 5);
    expect(ticket.redirectUri.path, contains('/tickets/'));
    expect(requests.map((request) => request.url.path), [
      '/api/v1/password-links/Private42/sessions',
      '/api/v1/password-links/Private42/verify',
    ]);
    expect(jsonDecode(requests.last.body), {
      'session_id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
      'password': 'secret pass',
    });
  });

  test('rejects a response that leaks the target before ticket consumption', () async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient(
        (_) async => http.Response(
          '{"session_id":"id","expires_at":"2026-08-28T12:10:00Z","max_attempts":5,"target_url":"https://secret.example"}',
          200,
        ),
      ),
    );
    addTearDown(apiClient.close);

    await expectLater(
      PasswordLinkService(apiClient: apiClient).start('Private42'),
      throwsA(same(invalidResponseApiFailure)),
    );
  });
}
