import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/analytics/data/analytics_models.dart';

abstract interface class AnalyticsDataSource() {
  Future<AnalyticsReport> dashboard({required int days});

  Future<AnalyticsReport> link({required String id, required int days});
}

final class AnalyticsService({required final LinkSoApiClient apiClient}) implements AnalyticsDataSource {
  @override
  Future<AnalyticsReport> dashboard({required int days}) async =>
      AnalyticsReport.fromJson(await apiClient.getJson(path: '/api/v1/me/analytics?days=$days'));

  @override
  Future<AnalyticsReport> link({required String id, required int days}) async => AnalyticsReport.fromJson(
    await apiClient.getJson(path: '/api/v1/me/links/${Uri.encodeComponent(id)}/analytics?days=$days'),
  );
}
