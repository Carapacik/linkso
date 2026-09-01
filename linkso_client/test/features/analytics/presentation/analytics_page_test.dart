import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders only server analytics and reloads the selected period', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1200);
    addTearDown(tester.view.reset);
    final List<String> requestedPeriods = [];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/session') {
          return http.Response(jsonEncode(_userJson()), 200);
        }
        requestedPeriods.add(request.url.queryParameters['days']!);
        return http.Response(jsonEncode(_reportJson(int.parse(request.url.queryParameters['days']!))), 200);
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      LinkSoApp(locale: const Locale('en'), initialLocation: '/app/analytics', apiClient: apiClient),
    );
    await tester.pumpAndSettle();

    expect(requestedPeriods, ['30']);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('314'), findsOneWidget);
    expect(find.text('159'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('999'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('analytics-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7').last);
    await tester.pumpAndSettle();
    expect(requestedPeriods, ['30', '7']);
  });

  testWidgets('loads owner-scoped analytics for one link', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1200);
    addTearDown(tester.view.reset);
    Uri? analyticsRequest;
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/session') {
          return http.Response(jsonEncode(_userJson()), 200);
        }
        analyticsRequest = request.url;
        return http.Response(jsonEncode({..._reportJson(30), 'link': _linkJson()}), 200);
      }),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      LinkSoApp(
        locale: const Locale('en'),
        initialLocation: '/app/links/01991a6c-b267-7a11-9b26-9cdd65e44073/analytics',
        apiClient: apiClient,
      ),
    );
    await tester.pumpAndSettle();

    expect(analyticsRequest?.path, '/api/v1/me/links/01991a6c-b267-7a11-9b26-9cdd65e44073/analytics');
    expect(find.text('Analytics: Campaign link'), findsOneWidget);
  });
}

Map<String, Object?> _userJson() => {
  'id': 'user-id',
  'email': 'owner@example.com',
  'email_verified': true,
  'created_at': '2026-08-29T10:00:00Z',
};

Map<String, Object?> _linkJson() => {
  'id': '01991a6c-b267-7a11-9b26-9cdd65e44073',
  'slug': 'CampaignLink',
  'title': 'Campaign link',
  'kind': 'advertising',
};

Map<String, Object?> _reportJson(int days) => {
  'period': {'days': days, 'from': '2026-08-01', 'to': '2026-08-29'},
  'summary': {'links': 3, 'human_redirects': 314, 'bot_redirects': 26},
  'series': [
    for (int index = 0; index < days; index++)
      {'day': '2026-08-${(index % 29 + 1).toString().padLeft(2, '0')}', 'human_redirects': index, 'bot_redirects': 1},
  ],
  'advertising_funnel': {'impressions': 200, 'timer_completions': 159, 'redirects': 120},
};
