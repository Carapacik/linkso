import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('announces the countdown and exposes the final action', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/sessions')) {
          return _sessionResponse(DateTime.now().toUtc().add(const Duration(seconds: 2)));
        }
        return _ticketResponse(Uri.parse('https://linkso.su/api/v1/advertising-links/tickets/ticket'));
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(
      LinkSoApp(locale: const Locale('en'), initialLocation: '/app/advertising/Accessible42', apiClient: apiClient),
    );
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp('Continue will be available')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('waits for server confirmation and redirects only after the button is pressed', (tester) async {
    Uri? redirectedTo;
    var continueRequests = 0;
    final Uri ticketUri = Uri.parse(
      'https://linkso.su/api/v1/advertising-links/tickets/01991a6c-b267-7a11-9b26-9cdd65e44073',
    );
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/sessions')) {
          return _sessionResponse(DateTime.now().toUtc().add(const Duration(seconds: 2)));
        }
        continueRequests++;
        return _ticketResponse(ticketUri);
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(
      LinkSoApp(
        locale: const Locale('en'),
        initialLocation: '/app/advertising/AdFlow42',
        apiClient: apiClient,
        redirect: (uri) async => redirectedTo = uri,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Campaign title'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('advertising-countdown')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('advertising-continue-button')), findsNothing);
    expect(continueRequests, 0);
    expect(redirectedTo, isNull);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(continueRequests, 1);
    expect(find.byKey(const ValueKey<String>('advertising-continue-button')), findsOneWidget);
    expect(redirectedTo, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('advertising-continue-button')));
    await tester.pump();
    expect(redirectedTo, ticketUri);
    expect(redirectedTo.toString(), isNot(contains('secret.example')));
  });

  testWidgets('uses Retry-After when the server rejects an early client countdown', (tester) async {
    var continueRequests = 0;
    final Uri ticketUri = Uri.parse(
      'https://linkso.su/api/v1/advertising-links/tickets/01991a6c-b267-7a11-9b26-9cdd65e44073',
    );
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/sessions')) {
          return _sessionResponse(DateTime.now().toUtc().subtract(const Duration(seconds: 1)));
        }
        continueRequests++;
        if (continueRequests == 1) {
          return http.Response(
            '{"error":{"code":"advertising_timer_not_finished","message":"early","retry_after_seconds":2,"request_id":"r1"}}',
            425,
            headers: {'retry-after': '2'},
          );
        }
        return _ticketResponse(ticketUri);
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(
      LinkSoApp(locale: const Locale('en'), initialLocation: '/app/advertising/AdFlow42', apiClient: apiClient),
    );
    await tester.pump();
    await tester.pump();

    expect(continueRequests, 1);
    expect(find.text('Continue will be available in 2 seconds'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('advertising-continue-button')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(continueRequests, 2);
    expect(find.byKey(const ValueKey<String>('advertising-continue-button')), findsOneWidget);
  });

  testWidgets('shows a timed placeholder when no campaign is active', (tester) async {
    var continueRequests = 0;
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/sessions')) {
          return _sessionResponse(DateTime.now().toUtc().add(const Duration(seconds: 2)), campaign: false);
        }
        continueRequests++;
        return _ticketResponse(Uri.parse('https://linkso.su/api/v1/advertising-links/tickets/ticket'));
      }),
    );
    addTearDown(apiClient.close);
    await tester.pumpWidget(
      LinkSoApp(locale: const Locale('en'), initialLocation: '/app/advertising/AdFlow42', apiClient: apiClient),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No ads yet'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('advertising-countdown')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(continueRequests, 1);
    expect(find.byKey(const ValueKey<String>('advertising-continue-button')), findsOneWidget);
  });
}

http.Response _sessionResponse(DateTime unlocksAt, {bool campaign = true}) => http.Response(
  jsonEncode({
    'session_id': '01991a6c-b267-7a11-9b26-9cdd65e44071',
    'unlocks_at': unlocksAt.toIso8601String(),
    'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
    'campaign': campaign
        ? {
            'id': '01991a6c-b267-7a11-9b26-9cdd65e44072',
            'title': 'Campaign title',
            'body': 'Campaign body',
            'image_url': null,
            'advertiser_url': 'https://advertiser.example/offer',
            'ends_at': DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
          }
        : null,
  }),
  200,
);

http.Response _ticketResponse(Uri ticketUri) => http.Response(
  jsonEncode({
    'redirect_url': ticketUri.toString(),
    'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 1)).toIso8601String(),
  }),
  200,
);
