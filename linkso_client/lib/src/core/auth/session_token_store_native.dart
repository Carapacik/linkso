import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:linkso_client/src/core/auth/session_token_store_base.dart';

const _sessionTokenKey = 'linkso.session_token';

final class const _NativeSessionTokenStore() implements SessionTokenStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> clear() => _storage.delete(key: _sessionTokenKey);

  @override
  Future<String?> read() => _storage.read(key: _sessionTokenKey);

  @override
  Future<void> write(String token) => _storage.write(key: _sessionTokenKey, value: token);
}

SessionTokenStore createPlatformSessionTokenStore() => const _NativeSessionTokenStore();
