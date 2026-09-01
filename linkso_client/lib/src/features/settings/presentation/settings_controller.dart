import 'package:linkso_client/src/features/settings/data/app_preferences_store.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';
import 'package:material_ui/material_ui.dart';

final class SettingsController({
  required ProfileService service,
  AppPreferencesStore? preferencesStore,
  LocalePreference initialLocale = LocalePreference.english,
  ThemePreference initialTheme = ThemePreference.system,
}) extends ChangeNotifier {
  final ProfileService _service = service;
  final AppPreferencesStore? _preferencesStore = preferencesStore;
  UserProfile? _profile;
  bool _loaded = false;
  Future<UserProfile>? _loading;
  LocalePreference _localePreference = initialLocale;
  ThemePreference _themePreference = initialTheme;

  UserProfile? get profile => _profile;

  ProfileService get service => _service;

  LocalePreference get localePreference => _localePreference;

  ThemePreference get themePreference => _themePreference;

  Locale get locale => switch (_localePreference) {
    LocalePreference.english => const Locale('en'),
    LocalePreference.russian => const Locale('ru'),
  };

  ThemeMode get themeMode => switch (_themePreference) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.system => ThemeMode.system,
  };

  Future<void> setLocalePreference(LocalePreference locale) async {
    if (_localePreference == locale) {
      return;
    }
    _localePreference = locale;
    notifyListeners();
    await _preferencesStore?.saveLocale(locale);
  }

  Future<void> setThemePreference(ThemePreference theme) async {
    if (_themePreference == theme) {
      return;
    }
    _themePreference = theme;
    notifyListeners();
    await _preferencesStore?.saveTheme(theme);
  }

  Future<UserProfile> ensureLoaded() async {
    if (_loaded && _profile != null) {
      return _profile!;
    }
    if (_loading case final loading?) {
      return await loading;
    }
    final Future<UserProfile> loading = _load();
    _loading = loading;
    try {
      return await loading;
    } finally {
      _loading = null;
    }
  }

  Future<UserProfile> _load() async {
    final UserProfile profile = await _service.getProfile();
    _profile = profile;
    _loaded = true;
    notifyListeners();
    return profile;
  }

  Future<void> updateDisplayName(String? displayName) async {
    _profile = await _service.updateDisplayName(displayName);
    notifyListeners();
  }

  Future<void> updatePreferences({
    required LocalePreference locale,
    required ThemePreference theme,
    required String timezone,
  }) async {
    await setLocalePreference(locale);
    await setThemePreference(theme);
    _profile = await _service.updateTimezone(timezone);
    notifyListeners();
  }

  void replaceProfile(UserProfile profile) {
    _profile = profile;
    _loaded = true;
    notifyListeners();
  }

  void clear() {
    _profile = null;
    _loaded = false;
    _loading = null;
    notifyListeners();
  }
}
