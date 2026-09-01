import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';

final class const AuthUser({
  required final String id,
  required final String email,
  required final bool emailVerified,
  required final DateTime createdAt,
});

final class const RegistrationResult({required final AuthUser user, final String? developmentVerificationToken});

final class const PasswordResetRequestResult({final String? developmentResetToken});

final class AuthService({required LinkSoApiClient apiClient}) {
  final LinkSoApiClient _apiClient = apiClient;

  Future<RegistrationResult> register({required String email, required String password}) async {
    final Map<String, Object?> json = await _apiClient.postJson(
      path: '/api/v1/auth/register',
      body: {'email': email, 'password': password},
    );
    final Object? userJson = json['user'];
    if (userJson is! Map<String, Object?>) {
      throw invalidResponseApiFailure;
    }
    return RegistrationResult(
      user: _parseUser(userJson),
      developmentVerificationToken: json['development_verification_token'] as String?,
    );
  }

  Future<AuthUser> verifyEmail(String token) async {
    final Map<String, Object?> json = await _apiClient.postJson(
      path: '/api/v1/auth/verify-email',
      body: {'token': token},
    );
    return _parseUser(json);
  }

  Future<void> resendVerification(String email) async {
    await _apiClient.postJson(path: '/api/v1/auth/verification-resend', body: {'email': email});
  }

  Future<AuthUser> login({required String email, required String password}) async {
    final Map<String, Object?> json = await _apiClient.postJson(
      path: _apiClient.usesBearerSession ? '/api/v1/mobile/auth/login' : '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    if (!_apiClient.usesBearerSession) {
      return _parseUser(json);
    }
    final Object? userJson = json['user'];
    final Object? sessionToken = json['session_token'];
    if (userJson is! Map<String, Object?> || sessionToken is! String || sessionToken.isEmpty) {
      throw invalidResponseApiFailure;
    }
    await _apiClient.storeSessionToken(sessionToken);
    return _parseUser(userJson);
  }

  Future<AuthUser> currentSession() async => _parseUser(await _apiClient.getJson(path: '/api/v1/auth/session'));

  Future<void> logout() async {
    try {
      await _apiClient.postEmpty(path: '/api/v1/auth/logout');
    } finally {
      await _apiClient.clearSessionToken();
    }
  }

  Future<void> logoutAll() async {
    try {
      await _apiClient.postEmpty(path: '/api/v1/auth/logout-all');
    } finally {
      await _apiClient.clearSessionToken();
    }
  }

  Future<PasswordResetRequestResult> requestPasswordReset(String email) async {
    final Map<String, Object?> json = await _apiClient.postJson(
      path: '/api/v1/auth/password-reset',
      body: {'email': email},
    );
    return PasswordResetRequestResult(developmentResetToken: json['development_reset_token'] as String?);
  }

  Future<void> confirmPasswordReset({required String token, required String password}) async {
    await _apiClient.postEmpty(
      path: '/api/v1/auth/password-reset/confirm',
      body: {'token': token, 'password': password},
    );
    await _apiClient.clearSessionToken();
  }

  AuthUser _parseUser(Map<String, Object?> json) {
    final Object? id = json['id'];
    final Object? email = json['email'];
    final Object? emailVerified = json['email_verified'];
    final Object? createdAt = json['created_at'];
    if (id is! String || email is! String || emailVerified is! bool || createdAt is! String) {
      throw invalidResponseApiFailure;
    }
    final DateTime? parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) {
      throw invalidResponseApiFailure;
    }
    return AuthUser(id: id, email: email, emailVerified: emailVerified, createdAt: parsedCreatedAt);
  }
}
