import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders a table on wide screens and cards on narrow screens', (tester) async {
    for (final ({Size size, String key}) value in [
      (size: const Size(1200, 900), key: 'my-links-table'),
      (size: const Size(600, 900), key: 'my-links-cards'),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = value.size;
      final LinkSoApiClient apiClient = _apiClient();
      await tester.pumpWidget(
        LinkSoApp(key: UniqueKey(), locale: const Locale('en'), initialLocation: '/app/links', apiClient: apiClient),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>(value.key)), findsOneWidget);
      expect(find.text('Alpha report'), findsOneWidget);
      expect(find.text('https://linkso.su/OwnedAlpha'), findsOneWidget);
      apiClient.close();
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('asks for confirmation before disabling a link', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 900);
    addTearDown(tester.view.reset);
    var disableCalls = 0;
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/session') {
          return http.Response(jsonEncode(_userJson()), 200);
        }
        if (request.url.path == '/api/v1/me/tags') {
          return http.Response(jsonEncode(_tagsJson()), 200);
        }
        if (request.url.path.endsWith('/disable')) {
          disableCalls += 1;
          return http.Response(jsonEncode({..._linkJson(), 'status': 'disabled'}), 200);
        }
        return http.Response(jsonEncode(_listJson()), 200);
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: '/app/links', apiClient: apiClient));
    await tester.pumpAndSettle();

    final Finder disableButton = find.byTooltip('Disable');
    await tester.ensureVisible(disableButton);
    await tester.pumpAndSettle();
    await tester.tap(disableButton);
    await tester.pumpAndSettle();
    expect(find.text('Disable this link?'), findsOneWidget);
    expect(disableCalls, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Disable'));
    await tester.pumpAndSettle();
    expect(disableCalls, 1);
  });

  testWidgets('loads and saves the edit form through owner-scoped endpoints', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);
    Map<String, Object?>? updateBody;
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/session') {
          return http.Response(jsonEncode(_userJson()), 200);
        }
        if (request.url.path == '/api/v1/me/tags') {
          return http.Response(jsonEncode(_tagsJson()), 200);
        }
        if (request.method == 'PUT') {
          updateBody = (jsonDecode(request.body) as Map).cast<String, Object?>();
          return http.Response(jsonEncode({..._linkJson(), 'title': updateBody!['title']}), 200);
        }
        if (request.url.path == '/api/v1/me/links/link-id') {
          return http.Response(jsonEncode(_linkJson()), 200);
        }
        return http.Response(jsonEncode(_listJson()), 200);
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(
      LinkSoApp(locale: const Locale('en'), initialLocation: '/app/links/link-id/edit', apiClient: apiClient),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('edit-link-page')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey<String>('edit-title-field')), 'Updated title');
    await tester.enterText(find.byKey(const ValueKey<String>('edit-tags-field')), 'Archive, Team');
    tester.testTextInput.hide();
    await tester.tap(find.byKey(const ValueKey<String>('save-link-button')));
    await tester.pumpAndSettle();

    expect(updateBody?['title'], 'Updated title');
    expect(updateBody?['tags'], ['Archive', 'Team']);
    expect(find.byKey(const ValueKey<String>('my-links-page')), findsOneWidget);
  });
}

LinkSoApiClient _apiClient() => LinkSoApiClient(
  baseUri: Uri.parse('https://linkso.su/'),
  client: MockClient((request) async {
    if (request.url.path == '/api/v1/auth/session') {
      return http.Response(jsonEncode(_userJson()), 200);
    }
    if (request.url.path == '/api/v1/me/tags') {
      return http.Response(jsonEncode(_tagsJson()), 200);
    }
    return http.Response(jsonEncode(_listJson()), 200);
  }),
);

Map<String, Object?> _userJson() => {
  'id': 'user-id',
  'email': 'owner@example.com',
  'email_verified': true,
  'created_at': '2026-08-29T10:00:00Z',
};

Map<String, Object?> _listJson() => {
  'items': [_linkJson()],
  'pagination': {'page': 1, 'page_size': 20, 'total_items': 1, 'total_pages': 1},
};

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

List<Map<String, Object?>> _tagsJson() => [
  {'name': 'Work', 'link_count': 1},
];
