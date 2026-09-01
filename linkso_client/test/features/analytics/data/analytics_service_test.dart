import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/analytics/data/analytics_models.dart';
import 'package:linkso_client/src/features/analytics/data/analytics_service.dart';

void main() {
  test('loads dashboard and one-link analytics with the selected period', () async {
    final List<Uri> requests = [];
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient((request) async {
        requests.add(request.url);
        return http.Response(jsonEncode(_reportJson(withLink: request.url.path.contains('/links/'))), 200);
      }),
    );
    addTearDown(apiClient.close);
    final service = AnalyticsService(apiClient: apiClient);

    final AnalyticsReport dashboard = await service.dashboard(days: 7);
    final AnalyticsReport link = await service.link(id: 'link/id', days: 90);

    expect(requests[0].path, '/api/v1/me/analytics');
    expect(requests[0].queryParameters['days'], '7');
    expect(requests[1].path, '/api/v1/me/links/link%2Fid/analytics');
    expect(requests[1].queryParameters['days'], '90');
    expect(dashboard.summary.humanRedirects, 42);
    expect(dashboard.funnel.timerCompletions, 8);
    expect(dashboard.link, isNull);
    expect(link.link?.slug, 'RealLink');
  });
}

Map<String, Object?> _reportJson({required bool withLink}) => {
  if (withLink) 'link': {'id': 'link-id', 'slug': 'RealLink', 'title': 'Real report', 'kind': 'advertising'},
  'period': {'days': 7, 'from': '2026-08-23', 'to': '2026-08-29'},
  'summary': {'links': 3, 'human_redirects': 42, 'bot_redirects': 4},
  'series': [
    {'day': '2026-08-29', 'human_redirects': 42, 'bot_redirects': 4},
  ],
  'advertising_funnel': {'impressions': 10, 'timer_completions': 8, 'redirects': 6},
};
