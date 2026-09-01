import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:material_ui/material_ui.dart';

const _user =
    '{"id":"01991a6c-b267-7a11-9b26-9cdd65e44071","email":"person@example.test","status":"active","email_verified":true,"created_at":"2026-08-29T12:00:00Z","timezone":"UTC"}';

void main() {
  test('email fragments decode safely without hash-based routing', () {
    expect(emailLinkParameter(Uri.parse('$verifyEmailPath#token=secret'), 'token'), 'secret');
    expect(emailLinkParameter(Uri.parse('$verifyEmailPath#token=%FF'), 'token'), isNull);
  });

  testWidgets('verification link confirms without manually entering a token', (tester) async {
    final requests = <http.Request>[];
    final api = LinkSoApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(_user, 200);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(LinkSoApp(apiClient: api, initialLocation: '$verifyEmailPath#token=verification-secret'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Verify email'));
    await tester.pumpAndSettle();
    final http.Request request = requests.singleWhere((r) => r.url.path == '/api/v1/auth/verify-email');
    expect(jsonDecode(request.body), {'token': 'verification-secret'});
    expect(request.url.hasQuery, isFalse);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('password reset link opens the new-password form immediately', (tester) async {
    final requests = <http.Request>[];
    final api = LinkSoApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(LinkSoApp(apiClient: api, initialLocation: '$passwordResetPath#token=reset-secret'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth-email-field')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey<String>('auth-password-field')),
      'new correct horse battery staple',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(jsonDecode(requests.single.body), {'token': 'reset-secret', 'password': 'new correct horse battery staple'});
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('verification resend uses a generic response and renders rate limits', (tester) async {
    var limited = false;
    final api = LinkSoApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/verification-resend');
        expect(jsonDecode(request.body), {'email': 'person@example.test'});
        return limited
            ? http.Response('{"error":{"code":"email_temporarily_limited","message":"Too many email requests"}}', 429)
            : http.Response('{"accepted":true}', 202);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(LinkSoApp(apiClient: api, initialLocation: resendVerificationPath));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('auth-email-field')), 'person@example.test');
    await tester.tap(find.byKey(const ValueKey<String>('verification-resend-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('If this address belongs to an unverified account'), findsOneWidget);
    limited = true;
    await tester.tap(find.byKey(const ValueKey<String>('verification-resend-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Too many'), findsOneWidget);
  });

  testWidgets('email change survives login and confirms from its email link', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);
    final requests = <http.Request>[];
    final api = LinkSoApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/auth/session') {
          return http.Response('{"error":{"code":"authentication_required","message":"Sign in"}}', 401);
        }
        if (request.url.path == '/api/v1/me/sessions') {
          return http.Response('[]', 200);
        }
        return http.Response(_user, 200);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(LinkSoApp(apiClient: api, initialLocation: '$accountPath#email_token=change-secret'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('login-page')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey<String>('auth-email-field')), 'person@example.test');
    await tester.enterText(find.byKey(const ValueKey<String>('auth-password-field')), 'correct horse battery staple');
    await tester.tap(find.byKey(const ValueKey<String>('login-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('confirm-email-link')));
    await tester.pumpAndSettle();
    expect(jsonDecode(requests.singleWhere((r) => r.url.path == '/api/v1/me/email-change/confirm').body), {
      'token': 'change-secret',
    });
    expect(find.byKey(const ValueKey<String>('confirm-email-link')), findsNothing);
    expect(requests.every((r) => !r.url.hasQuery && !r.url.hasFragment), isTrue);
  });
}
