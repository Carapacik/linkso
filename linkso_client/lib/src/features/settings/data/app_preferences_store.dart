import 'package:flutter/widgets.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class const AppPreferences({required final LocalePreference locale, required final ThemePreference theme});

const defaultAppPreferences = AppPreferences(locale: LocalePreference.english, theme: ThemePreference.system);

final class AppPreferencesStore({SharedPreferencesAsync? preferences}) {
  static const _localeKey = 'linkso.locale';
  static const _themeKey = 'linkso.theme';

  final SharedPreferencesAsync _preferences = preferences ?? SharedPreferencesAsync();

  Future<AppPreferences> load({required Locale systemLocale}) async {
    try {
      final String? locale = await _preferences.getString(_localeKey);
      final String? theme = await _preferences.getString(_themeKey);
      return AppPreferences(
        locale: switch (locale) {
          'ru' => LocalePreference.russian,
          'en' => LocalePreference.english,
          _ => systemLocale.languageCode.toLowerCase() == 'ru' ? LocalePreference.russian : LocalePreference.english,
        },
        theme: switch (theme) {
          'light' => ThemePreference.light,
          'dark' => ThemePreference.dark,
          _ => ThemePreference.system,
        },
      );
    } on Object {
      return AppPreferences(
        locale: systemLocale.languageCode.toLowerCase() == 'ru' ? LocalePreference.russian : LocalePreference.english,
        theme: ThemePreference.system,
      );
    }
  }

  Future<void> saveLocale(LocalePreference locale) async {
    try {
      await _preferences.setString(_localeKey, locale.apiValue);
    } on Object {
      // Appearance preferences are non-critical and remain active in memory.
    }
  }

  Future<void> saveTheme(ThemePreference theme) async {
    try {
      await _preferences.setString(_themeKey, theme.apiValue);
    } on Object {
      // Appearance preferences are non-critical and remain active in memory.
    }
  }
}
