import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows the real owner profile and keeps the legacy account route working', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);
    final List<String> requests = [];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request.url.path);
        if (request.url.path == '/api/v1/me/sessions') {
          return http.Response('[]', 200);
        }
        return http.Response(jsonEncode(_profileJson()), 200);
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      LinkSoApp(locale: const Locale('en'), initialLocation: legacyAccountPath, apiClient: apiClient),
    );
    await tester.pumpAndSettle();

    expect(requests, ['/api/v1/auth/session', '/api/v1/me/profile', '/api/v1/me/sessions']);
    expect(find.byKey(const ValueKey<String>('settings-page')), findsOneWidget);
    expect(find.text('person@example.com'), findsWidgets);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('01991a6c-b267-7a11-9b26-9cdd65e44071'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('requires explicit confirmation and deletes the account', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    final List<http.Request> requests = [];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/me/sessions') {
          return http.Response('[]', 200);
        }
        if (request.method == 'DELETE' || request.url.path == '/api/v1/auth/logout') {
          return http.Response('', 204);
        }
        return http.Response(jsonEncode(_profileJson()), 200);
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: accountPath, apiClient: apiClient));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('delete-account')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey<String>('delete-account')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('delete-account-password')), 'current secure password');
    await tester.enterText(find.byKey(const ValueKey<String>('delete-account-confirmation')), 'DELETE');
    await tester.tap(find.byKey(const ValueKey<String>('confirm-delete-account')));
    await tester.pumpAndSettle();

    final http.Request deleteRequest = requests.singleWhere(
      (request) => request.method == 'DELETE' && request.url.path == '/api/v1/me/profile',
    );
    expect(jsonDecode(deleteRequest.body), {'current_password': 'current secure password', 'confirmation': 'DELETE'});
    expect(
      requests.where((request) => request.method == 'POST' && request.url.path == '/api/v1/auth/logout'),
      hasLength(1),
    );
    expect(find.byKey(const ValueKey<String>('shorten-page')), findsOneWidget);
  });
}

Map<String, Object?> _profileJson() => {
  'id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
  'email': 'person@example.com',
  'display_name': 'Person',
  'status': 'active',
  'email_verified': true,
  'created_at': '2026-08-29T12:00:00Z',
  'timezone': 'UTC',
};
