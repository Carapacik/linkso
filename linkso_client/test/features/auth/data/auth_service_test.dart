import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/auth/session_token_store.dart';
import 'package:linkso_client/src/features/auth/data/auth_service.dart';

void main() {
  test('registration, verification, login and session use the auth API contract', () async {
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      final Map<String, Object?> user = {
        'id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
        'email': 'person@example.com',
        'email_verified': request.url.path != '/api/v1/auth/register',
        'created_at': '2026-08-29T12:00:00Z',
      };
      return switch (request.url.path) {
        '/api/v1/auth/register' => http.Response(
          jsonEncode({'user': user, 'development_verification_token': 'verify-token'}),
          201,
        ),
        '/api/v1/auth/verify-email' ||
        '/api/v1/auth/login' ||
        '/api/v1/auth/session' => http.Response(jsonEncode(user), 200),
        _ => http.Response('', 404),
      };
    });
    final apiClient = LinkSoApiClient(baseUri: Uri.parse('https://linkso.su/'), client: httpClient);
    final service = AuthService(apiClient: apiClient);

    final RegistrationResult registration = await service.register(
      email: 'person@example.com',
      password: 'secure password',
    );
    expect(registration.user.emailVerified, isFalse);
    expect(registration.developmentVerificationToken, 'verify-token');
    expect((jsonDecode(requests.first.body) as Map)['password'], 'secure password');

    expect((await service.verifyEmail('verify-token')).emailVerified, isTrue);
    expect((await service.login(email: 'person@example.com', password: 'secure password')).email, 'person@example.com');
    expect((await service.currentSession()).id, '01991a6c-b267-7a11-9b26-9cdd65e44071');
    expect(requests.last.method, 'GET');
  });

  test('password reset and logout accept bodyless success responses', () async {
    final requests = <http.Request>[];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/auth/password-reset') {
          return http.Response('{"accepted":true,"development_reset_token":"reset-token"}', 202);
        }
        return http.Response('', 204);
      }),
    );
    final service = AuthService(apiClient: apiClient);

    final PasswordResetRequestResult reset = await service.requestPasswordReset('person@example.com');
    expect(reset.developmentResetToken, 'reset-token');
    await service.confirmPasswordReset(token: 'reset-token', password: 'new secure password');
    await service.logout();
    await service.logoutAll();

    expect(requests.map((request) => request.url.path), [
      '/api/v1/auth/password-reset',
      '/api/v1/auth/password-reset/confirm',
      '/api/v1/auth/logout',
      '/api/v1/auth/logout-all',
    ]);
  });

  test('native login stores the bearer session and uses the mobile endpoint', () async {
    final requests = <http.Request>[];
    final tokenStore = MemorySessionTokenStore();
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/mobile/auth/login') {
          return http.Response(
            '{"user":{"id":"01991a6c-b267-7a11-9b26-9cdd65e44071","email":"person@example.com",'
            '"email_verified":true,"created_at":"2026-08-29T12:00:00Z"},'
            '"session_token":"native-session","expires_at":"2026-09-29T12:00:00Z"}',
            200,
          );
        }
        return http.Response(
          '{"id":"01991a6c-b267-7a11-9b26-9cdd65e44071","email":"person@example.com",'
          '"email_verified":true,"created_at":"2026-08-29T12:00:00Z"}',
          200,
        );
      }),
      sessionTokenStore: tokenStore,
      usesBearerSession: true,
    );
    final service = AuthService(apiClient: apiClient);

    await service.login(email: 'person@example.com', password: 'secure password');
    await service.currentSession();

    expect(requests.first.url.path, '/api/v1/mobile/auth/login');
    expect(await tokenStore.read(), 'native-session');
    expect(requests.last.headers['authorization'], 'Bearer native-session');
  });
}
