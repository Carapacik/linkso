import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';

final class PasswordLinkSession({
  required final String id,
  required final DateTime expiresAt,
  required final int maxAttempts,
});

final class PasswordLinkTicket({required final Uri redirectUri, required final DateTime expiresAt});

final class PasswordLinkService({required final LinkSoApiClient apiClient}) {
  Future<PasswordLinkSession> start(String slug) async {
    final Map<String, Object?> response = await apiClient.postJson(
      path: '/api/v1/password-links/${Uri.encodeComponent(slug)}/sessions',
      body: const {},
    );
    _rejectLeakedTarget(response);
    try {
      return PasswordLinkSession(
        id: response['session_id']! as String,
        expiresAt: DateTime.parse(response['expires_at']! as String),
        maxAttempts: response['max_attempts']! as int,
      );
    } on Object {
      throw invalidResponseApiFailure;
    }
  }

  Future<PasswordLinkTicket> verify({required String slug, required String sessionId, required String password}) async {
    final Map<String, Object?> response = await apiClient.postJson(
      path: '/api/v1/password-links/${Uri.encodeComponent(slug)}/verify',
      body: {'session_id': sessionId, 'password': password},
    );
    _rejectLeakedTarget(response);
    try {
      return PasswordLinkTicket(
        redirectUri: Uri.parse(response['redirect_url']! as String),
        expiresAt: DateTime.parse(response['expires_at']! as String),
      );
    } on Object {
      throw invalidResponseApiFailure;
    }
  }

  void _rejectLeakedTarget(Map<String, Object?> response) {
    if (response.containsKey('target_url')) {
      throw invalidResponseApiFailure;
    }
  }
}
