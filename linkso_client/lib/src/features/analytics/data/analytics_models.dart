import 'package:linkso_client/src/core/api/api_failure.dart';

final class const AnalyticsPeriod({required final int days, required final DateTime from, required final DateTime to}) {
  factory fromJson(Map<String, Object?> json) => AnalyticsPeriod(
    days: json['days']! as int,
    from: DateTime.parse(json['from']! as String),
    to: DateTime.parse(json['to']! as String),
  );
}

final class const AnalyticsSummary({
  required final int links,
  required final int humanRedirects,
  required final int botRedirects,
}) {
  factory fromJson(Map<String, Object?> json) => AnalyticsSummary(
    links: json['links']! as int,
    humanRedirects: json['human_redirects']! as int,
    botRedirects: json['bot_redirects']! as int,
  );
}

final class const DailyRedirects({
  required final DateTime day,
  required final int humanRedirects,
  required final int botRedirects,
}) {
  factory fromJson(Map<String, Object?> json) => DailyRedirects(
    day: DateTime.parse(json['day']! as String),
    humanRedirects: json['human_redirects']! as int,
    botRedirects: json['bot_redirects']! as int,
  );
}

final class const AdvertisingFunnel({
  required final int impressions,
  required final int timerCompletions,
  required final int redirects,
}) {
  factory fromJson(Map<String, Object?> json) => AdvertisingFunnel(
    impressions: json['impressions']! as int,
    timerCompletions: json['timer_completions']! as int,
    redirects: json['redirects']! as int,
  );
}

final class const AnalyticsLink({
  required final String id,
  required final String slug,
  required final String? title,
  required final String kind,
}) {
  factory fromJson(Map<String, Object?> json) => AnalyticsLink(
    id: json['id']! as String,
    slug: json['slug']! as String,
    title: json['title'] as String?,
    kind: json['kind']! as String,
  );
}

final class const AnalyticsReport({
  required final AnalyticsPeriod period,
  required final AnalyticsSummary summary,
  required final List<DailyRedirects> series,
  required final AdvertisingFunnel funnel,
  final AnalyticsLink? link,
}) {
  factory fromJson(Map<String, Object?> json) {
    try {
      return AnalyticsReport(
        link: json['link'] == null ? null : AnalyticsLink.fromJson((json['link']! as Map).cast<String, Object?>()),
        period: AnalyticsPeriod.fromJson((json['period']! as Map).cast<String, Object?>()),
        summary: AnalyticsSummary.fromJson((json['summary']! as Map).cast<String, Object?>()),
        series: (json['series']! as List<Object?>)
            .map((item) => DailyRedirects.fromJson((item! as Map).cast<String, Object?>()))
            .toList(growable: false),
        funnel: AdvertisingFunnel.fromJson((json['advertising_funnel']! as Map).cast<String, Object?>()),
      );
    } on ApiFailure {
      rethrow;
    } on Object {
      throw invalidResponseApiFailure;
    }
  }
}
