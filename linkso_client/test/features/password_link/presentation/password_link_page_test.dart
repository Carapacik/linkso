import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('exposes password controls to keyboard and assistive technology', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((_) async => _sessionResponse()),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(
      LinkSoApp(locale: const Locale('en'), initialLocation: '/app/password/Accessible42', apiClient: apiClient),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Password')), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('access-password-field')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    semantics.dispose();
  });

  testWidgets('shows wrong password and temporary lock states', (tester) async {
    var verifyCount = 0;
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/sessions')) {
          return _sessionResponse();
        }
        verifyCount++;
        if (verifyCount == 1) {
          return http.Response(
            '{"error":{"code":"password_incorrect","message":"wrong","field":"password","request_id":"r1"}}',
            401,
          );
        }
        return http.Response(
          '{"error":{"code":"password_temporarily_locked","message":"locked","field":"password","retry_after_seconds":30,"request_id":"r2"}}',
          429,
          headers: {'retry-after': '30'},
        );
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(
      LinkSoApp(locale: const Locale('en'), initialLocation: '/app/password/Private42', apiClient: apiClient),
    );
    await tester.pumpAndSettle();

    final Finder passwordField = find.byKey(const ValueKey<String>('access-password-field'));
    final Finder submit = find.byKey(const ValueKey<String>('verify-password-button'));
    await tester.enterText(passwordField, 'wrong password');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('The password is incorrect'), findsOneWidget);

    await tester.enterText(passwordField, 'still wrong');
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Too many attempts. Try again in 30 seconds.'), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('successful password flow navigates only to the server ticket', (tester) async {
    final Uri ticketUri = Uri.parse(
      'https://linkso.su/api/v1/password-links/tickets/01991a6c-b267-7a11-9b26-9cdd65e44072',
    );
    Uri? redirectedTo;
    final responses = <String>[];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        responses.add(request.body);
        if (request.url.path.endsWith('/sessions')) {
          return _sessionResponse();
        }
        return http.Response(
          jsonEncode({'redirect_url': ticketUri.toString(), 'expires_at': '2026-08-28T12:01:00Z'}),
          200,
        );
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(
      LinkSoApp(
        locale: const Locale('en'),
        initialLocation: '/app/password/Private42',
        apiClient: apiClient,
        redirect: (uri) async => redirectedTo = uri,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('destination stays hidden'), findsOneWidget);
    expect(find.textContaining('secret.example'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey<String>('access-password-field')), 'correct password');
    await tester.tap(find.byKey(const ValueKey<String>('verify-password-button')));
    await tester.pumpAndSettle();

    expect(redirectedTo, ticketUri);
    expect(redirectedTo.toString(), isNot(contains('secret.example')));
    expect(responses.last, contains('correct password'));
  });
}

http.Response _sessionResponse() => http.Response(
  '{"session_id":"01991a6c-b267-7a11-9b26-9cdd65e44071","expires_at":"2026-08-28T12:10:00Z","max_attempts":5}',
  200,
);
