import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';

void main() {
  test('loads the authenticated profile from the owner-scoped endpoint', () async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/me/profile');
        return http.Response(jsonEncode(_profileJson()), 200);
      }),
    );
    addTearDown(apiClient.close);

    final UserProfile profile = await ProfileService(apiClient: apiClient).getProfile();

    expect(profile.id, '01991a6c-b267-7a11-9b26-9cdd65e44071');
    expect(profile.email, 'person@example.com');
    expect(profile.status, 'active');
    expect(profile.emailVerified, isTrue);
    expect(profile.createdAt, DateTime.utc(2026, 8, 29, 12));
    expect(profile.timezone, 'UTC');
  });

  test('uses settings security, preferences, sessions and deletion endpoints', () async {
    final List<http.Request> requests = [];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/me/sessions' && request.method == 'GET') {
          return http.Response(jsonEncode([_sessionJson()]), 200);
        }
        if (request.url.path == '/api/v1/me/email-change') {
          return http.Response(jsonEncode({'accepted': true, 'development_confirmation_token': 'email-token'}), 202);
        }
        if (request.method == 'PUT' || request.url.path.endsWith('/confirm')) {
          return http.Response(jsonEncode(_profileJson()), 200);
        }
        return http.Response('', 204);
      }),
    );
    addTearDown(apiClient.close);
    final service = ProfileService(apiClient: apiClient);

    await service.updateDisplayName('Person');
    await service.updateTimezone('Europe/Moscow');
    final EmailChangeRequestResult emailChange = await service.requestEmailChange(
      email: 'new@example.com',
      currentPassword: 'current password',
    );
    await service.confirmEmailChange('email-token');
    await service.changePassword(currentPassword: 'current password', newPassword: 'new secure password');
    final List<AccountSession> sessions = await service.listSessions();
    await service.revokeSession('session-id');
    await service.deleteAccount(currentPassword: 'new secure password', confirmation: 'DELETE');

    expect(emailChange.developmentConfirmationToken, 'email-token');
    expect(sessions.single.isCurrent, isTrue);
    expect(requests.map((request) => '${request.method} ${request.url.path}'), [
      'PUT /api/v1/me/profile',
      'PUT /api/v1/me/preferences',
      'POST /api/v1/me/email-change',
      'POST /api/v1/me/email-change/confirm',
      'PUT /api/v1/me/password',
      'GET /api/v1/me/sessions',
      'DELETE /api/v1/me/sessions/session-id',
      'DELETE /api/v1/me/profile',
    ]);
    expect(jsonDecode(requests[1].body), {'timezone': 'Europe/Moscow'});
    expect(jsonDecode(requests.last.body), {'current_password': 'new secure password', 'confirmation': 'DELETE'});
  });
}

Map<String, Object?> _profileJson() => {
  'id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
  'email': 'person@example.com',
  'display_name': null,
  'status': 'active',
  'email_verified': true,
  'created_at': '2026-08-29T12:00:00Z',
  'timezone': 'UTC',
};

Map<String, Object?> _sessionJson() => {
  'id': 'session-id',
  'created_at': '2026-08-29T12:00:00Z',
  'last_seen_at': '2026-08-29T12:01:00Z',
  'expires_at': '2026-09-29T12:00:00Z',
  'is_current': true,
};
