import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';

enum LocalePreference() {
  english,
  russian;

  String get apiValue => switch (this) {
    english => 'en',
    russian => 'ru',
  };
}

enum ThemePreference() {
  system,
  light,
  dark;

  String get apiValue => name;
}

const supportedTimezones = [
  'UTC',
  'Europe/Moscow',
  'Europe/London',
  'Europe/Berlin',
  'America/New_York',
  'America/Los_Angeles',
  'Asia/Tokyo',
  'Asia/Shanghai',
];

final class const UserProfile({
  required final String id,
  required final String email,
  required final String status,
  required final bool emailVerified,
  required final DateTime createdAt,
  required final String timezone,
  final String? displayName,
}) {
  factory fromJson(Map<String, Object?> json) {
    try {
      return UserProfile(
        id: json['id']! as String,
        email: json['email']! as String,
        displayName: json['display_name'] as String?,
        status: json['status']! as String,
        emailVerified: json['email_verified']! as bool,
        createdAt: DateTime.parse(json['created_at']! as String),
        timezone: json['timezone']! as String,
      );
    } on ApiFailure {
      rethrow;
    } on Object {
      throw invalidResponseApiFailure;
    }
  }
}

final class const AccountSession({
  required final String id,
  required final DateTime createdAt,
  required final DateTime lastSeenAt,
  required final DateTime expiresAt,
  required final bool isCurrent,
}) {
  factory fromJson(Map<String, Object?> json) {
    try {
      return AccountSession(
        id: json['id']! as String,
        createdAt: DateTime.parse(json['created_at']! as String),
        lastSeenAt: DateTime.parse(json['last_seen_at']! as String),
        expiresAt: DateTime.parse(json['expires_at']! as String),
        isCurrent: json['is_current']! as bool,
      );
    } on Object {
      throw invalidResponseApiFailure;
    }
  }
}

final class const EmailChangeRequestResult({final String? developmentConfirmationToken});

final class ProfileService({required final LinkSoApiClient apiClient}) {
  Future<UserProfile> getProfile() async => UserProfile.fromJson(await apiClient.getJson(path: '/api/v1/me/profile'));

  Future<UserProfile> updateDisplayName(String? displayName) async =>
      UserProfile.fromJson(await apiClient.putJson(path: '/api/v1/me/profile', body: {'display_name': displayName}));

  Future<UserProfile> updateTimezone(String timezone) async =>
      UserProfile.fromJson(await apiClient.putJson(path: '/api/v1/me/preferences', body: {'timezone': timezone}));

  Future<EmailChangeRequestResult> requestEmailChange({required String email, required String currentPassword}) async {
    final Map<String, Object?> json = await apiClient.postJson(
      path: '/api/v1/me/email-change',
      body: {'email': email, 'current_password': currentPassword},
    );
    return EmailChangeRequestResult(developmentConfirmationToken: json['development_confirmation_token'] as String?);
  }

  Future<UserProfile> confirmEmailChange(String token) async =>
      UserProfile.fromJson(await apiClient.postJson(path: '/api/v1/me/email-change/confirm', body: {'token': token}));

  Future<void> changePassword({required String currentPassword, required String newPassword}) => apiClient.putEmpty(
    path: '/api/v1/me/password',
    body: {'current_password': currentPassword, 'new_password': newPassword},
  );

  Future<List<AccountSession>> listSessions() async {
    final List<Object?> json = await apiClient.getJsonList(path: '/api/v1/me/sessions');
    try {
      return json
          .map((item) => AccountSession.fromJson((item! as Map).cast<String, Object?>()))
          .toList(growable: false);
    } on ApiFailure {
      rethrow;
    } on Object {
      throw invalidResponseApiFailure;
    }
  }

  Future<void> revokeSession(String id) =>
      apiClient.deleteEmpty(path: '/api/v1/me/sessions/${Uri.encodeComponent(id)}');

  Future<void> deleteAccount({required String currentPassword, required String confirmation}) => apiClient.deleteEmpty(
    path: '/api/v1/me/profile',
    body: {'current_password': currentPassword, 'confirmation': confirmation},
  );
}
