import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';

final class AdvertisingCampaign({
  required final String id,
  required final String title,
  required final String body,
  required final Uri? imageUri,
  required final Uri advertiserUri,
  required final DateTime endsAt,
});

final class AdvertisingSession({
  required final String id,
  required final DateTime unlocksAt,
  required final DateTime expiresAt,
  required final AdvertisingCampaign? campaign,
});

final class AdvertisingTicket({required final Uri redirectUri, required final DateTime expiresAt});

final class AdvertisingLinkService({required final LinkSoApiClient apiClient}) {
  Future<AdvertisingSession> start(String slug) async {
    final Map<String, Object?> response = await apiClient.postJson(
      path: '/api/v1/advertising-links/${Uri.encodeComponent(slug)}/sessions',
      body: const {},
    );
    _rejectTargetLeak(response);
    try {
      final Object? campaignValue = response['campaign'];
      final Map<String, Object?>? campaign = campaignValue == null
          ? null
          : (campaignValue as Map).cast<String, Object?>();
      final imageUrl = campaign?['image_url'] as String?;
      return AdvertisingSession(
        id: response['session_id']! as String,
        unlocksAt: DateTime.parse(response['unlocks_at']! as String),
        expiresAt: DateTime.parse(response['expires_at']! as String),
        campaign: campaign == null
            ? null
            : AdvertisingCampaign(
                id: campaign['id']! as String,
                title: campaign['title']! as String,
                body: campaign['body']! as String,
                imageUri: imageUrl == null ? null : Uri.parse(imageUrl),
                advertiserUri: Uri.parse(campaign['advertiser_url']! as String),
                endsAt: DateTime.parse(campaign['ends_at']! as String),
              ),
      );
    } on Object {
      throw invalidResponseApiFailure;
    }
  }

  Future<AdvertisingTicket> continueSession({required String slug, required String sessionId}) async {
    final Map<String, Object?> response = await apiClient.postJson(
      path:
          '/api/v1/advertising-links/${Uri.encodeComponent(slug)}/sessions/${Uri.encodeComponent(sessionId)}/continue',
      body: const {},
    );
    _rejectTargetLeak(response);
    try {
      return AdvertisingTicket(
        redirectUri: Uri.parse(response['redirect_url']! as String),
        expiresAt: DateTime.parse(response['expires_at']! as String),
      );
    } on Object {
      throw invalidResponseApiFailure;
    }
  }

  void _rejectTargetLeak(Object? value) {
    if (_containsTargetUrl(value)) {
      throw invalidResponseApiFailure;
    }
  }

  bool _containsTargetUrl(Object? value) {
    if (value case final Map<Object?, Object?> map) {
      return map.entries.any((entry) => entry.key == 'target_url' || _containsTargetUrl(entry.value));
    }
    if (value case final Iterable<Object?> values) {
      return values.any(_containsTargetUrl);
    }
    return false;
  }
}
