import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/shorten/presentation/linkso_qr_code.dart';
import 'package:linkso_client/src/l10n/generated/app_localizations_ru.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows all direct fields and localized validation', (tester) async {
    final LinkSoApiClient apiClient = _unusedApiClient();
    addTearDown(apiClient.close);
    await tester.pumpWidget(LinkSoApp(locale: const Locale('ru'), initialLocation: shortenPath, apiClient: apiClient));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('target-url-field')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('link-title-field')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('custom-slug-field')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('link-tags-field')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('expiration-picker-button')), findsOneWidget);
    final localizations = AppLocalizationsRu();
    expect(find.text(localizations.targetUrlLabel), findsOneWidget);
    expect(find.text(localizations.linkModeLabel), findsOneWidget);

    final Finder createButton = find.byKey(const ValueKey<String>('create-link-button'));
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(find.text(localizations.targetUrlRequired), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('target-url-field')), 'ftp://example.com/file');
    await tester.pumpAndSettle();
    expect(find.text(localizations.targetUrlUnsupportedScheme), findsOneWidget);
  });

  testWidgets('switches between three exclusive modes', (tester) async {
    final LinkSoApiClient apiClient = _unusedApiClient();
    addTearDown(apiClient.close);
    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: shortenPath, apiClient: apiClient));
    await tester.pumpAndSettle();

    expect(find.text('Immediately redirects to the target website.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('link-password-field')), findsNothing);

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('link-password-field')), findsOneWidget);
    expect(find.text('Requires a password before the redirect.'), findsOneWidget);
    expect(find.textContaining('Creation for this type'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey<String>('create-link-button'))).onPressed, isNotNull);

    await tester.tap(find.text('Advertising'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('link-password-field')), findsNothing);
    expect(find.textContaining('enables Continue after 5 seconds'), findsOneWidget);
    expect(find.textContaining('Creation for this type'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey<String>('create-link-button'))).onPressed, isNotNull);
  });

  testWidgets('opens the localized expiration picker', (tester) async {
    final LinkSoApiClient apiClient = _unusedApiClient();
    addTearDown(apiClient.close);
    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: shortenPath, apiClient: apiClient));
    await tester.pumpAndSettle();

    final Finder pickerButton = find.byKey(const ValueKey<String>('expiration-picker-button'));
    await tester.ensureVisible(pickerButton);
    await tester.tap(pickerButton);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('creates a direct link and shows copyable QR result', (tester) async {
    final response = Completer<http.Response>();
    late Map<String, Object?> requestBody;
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) {
        requestBody = (jsonDecode(request.body) as Map).cast<String, Object?>();
        return response.future;
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: shortenPath, apiClient: apiClient));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey<String>('target-url-field')), 'https://example.com/article');
    await tester.enterText(find.byKey(const ValueKey<String>('link-title-field')), 'Team article');
    await tester.enterText(find.byKey(const ValueKey<String>('custom-slug-field')), 'team-link');
    await tester.enterText(find.byKey(const ValueKey<String>('link-tags-field')), ' Work, work, Product   Launch ');
    final Finder createButton = find.byKey(const ValueKey<String>('create-link-button'));
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();

    expect(find.text('Creating…'), findsOneWidget);
    response.complete(
      http.Response(
        jsonEncode({
          'id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
          'slug': 'team-link',
          'short_url': 'https://linkso.su/team-link',
          'target_url': 'https://example.com/article',
          'title': 'Team article',
          'kind': 'direct',
          'expires_at': null,
          'tags': ['Work', 'Product Launch'],
        }),
        201,
      ),
    );
    await tester.pumpAndSettle();

    expect(requestBody, {
      'target_url': 'https://example.com/article',
      'kind': 'direct',
      'title': 'Team article',
      'slug': 'team-link',
      'tags': ['Work', 'Product Launch'],
    });
    expect(find.byKey(const ValueKey<String>('created-link-result')), findsOneWidget);
    expect(find.text('https://linkso.su/team-link'), findsOneWidget);
    expect(find.byType(LinkSoQrCode), findsOneWidget);

    expect(find.byKey(const ValueKey<String>('copy-link-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('create-another-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('shorten-page')), findsOneWidget);
  });

  testWidgets('maps server field errors and request IDs', (tester) async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"slug_taken","message":"taken","field":"slug","request_id":"request-42"}}',
          409,
        ),
      ),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: shortenPath, apiClient: apiClient));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey<String>('target-url-field')), 'https://example.com');
    await tester.enterText(find.byKey(const ValueKey<String>('custom-slug-field')), 'team-link');
    final Finder createButton = find.byKey(const ValueKey<String>('create-link-button'));
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('This slug is already in use'), findsOneWidget);
    expect(find.text('Request reference: request-42'), findsOneWidget);
  });

  testWidgets('shows a localized network error', (tester) async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: shortenPath, apiClient: apiClient));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey<String>('target-url-field')), 'https://example.com');
    final Finder createButton = find.byKey(const ValueKey<String>('create-link-button'));
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(find.text('The server is unavailable. Check your connection and try again.'), findsOneWidget);
  });

  for (final language in ['en', 'ru']) {
    testWidgets('unblocks submission after a timeout in $language and ignores a late response', (tester) async {
      final response = Completer<http.Response>();
      var sends = 0;
      final apiClient = LinkSoApiClient(
        baseUri: Uri.parse('https://linkso.su/'),
        requestTimeout: const Duration(seconds: 1),
        client: MockClient((_) {
          sends++;
          return response.future;
        }),
      );
      addTearDown(apiClient.close);
      await tester.pumpWidget(LinkSoApp(locale: Locale(language), initialLocation: shortenPath, apiClient: apiClient));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('target-url-field')), 'https://example.com');
      final Finder createButton = find.byKey(const ValueKey<String>('create-link-button'));
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final String message = language == 'ru'
          ? AppLocalizationsRu().requestTimeoutError
          : 'The request timed out. Check your connection and whether the operation completed before trying again.';
      expect(find.text(message), findsOneWidget);
      expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
      expect(sends, 1);

      response.complete(http.Response('{}', 201));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('created-link-result')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

LinkSoApiClient _unusedApiClient() {
  return LinkSoApiClient(
    baseUri: Uri.parse('https://linkso.su/'),
    client: MockClient((_) async => throw StateError('Unexpected API request')),
  );
}
