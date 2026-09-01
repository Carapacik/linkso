import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/features/auth/data/auth_service.dart';
import 'package:material_ui/material_ui.dart';

final class AuthController({required AuthService service}) extends ChangeNotifier {
  final AuthService _service = service;
  AuthUser? _user;
  bool _sessionChecked = false;
  Future<bool>? _sessionLoading;
  bool _disposed = false;
  int _sessionRevision = 0;

  AuthUser? get user => _user;

  bool get isAuthenticated => _user != null;

  Future<bool> ensureSessionLoaded() {
    if (_sessionChecked) {
      return Future.value(isAuthenticated);
    }
    return _sessionLoading ??= _loadSession();
  }

  Future<bool> _loadSession() async {
    final int revision = _sessionRevision;
    try {
      final AuthUser user = await _service.currentSession();
      if (!_disposed && revision == _sessionRevision) {
        _user = user;
        _sessionChecked = true;
        notifyListeners();
      }
    } on ApiFailure catch (error) {
      if (error.statusCode != 401) {
        rethrow;
      }
      if (!_disposed && revision == _sessionRevision) {
        _user = null;
        _sessionChecked = true;
        notifyListeners();
      }
    } finally {
      _sessionLoading = null;
    }
    return isAuthenticated;
  }

  Future<void> login({required String email, required String password}) async {
    _sessionRevision++;
    _user = await _service.login(email: email, password: password);
    _sessionChecked = true;
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> logout({bool allSessions = false}) async {
    _sessionRevision++;
    if (allSessions) {
      await _service.logoutAll();
    } else {
      await _service.logout();
    }
    _user = null;
    _sessionChecked = true;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
