abstract interface class SessionTokenStore() {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

final class MemorySessionTokenStore() implements SessionTokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
