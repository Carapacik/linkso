import 'package:linkso_client/src/core/auth/session_token_store_base.dart';

final class _WebSessionTokenStore() implements SessionTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}
}

SessionTokenStore createPlatformSessionTokenStore() => _WebSessionTokenStore();
