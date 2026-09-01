import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/features/settings/data/app_preferences_store.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test('uses the supported system locale on first launch and the system theme', () async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

    final AppPreferences preferences = await AppPreferencesStore().load(systemLocale: const Locale('ru', 'RU'));

    expect(preferences.locale, LocalePreference.russian);
    expect(preferences.theme, ThemePreference.system);
  });

  test('falls back to English for an unsupported system locale', () async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

    final AppPreferences preferences = await AppPreferencesStore().load(systemLocale: const Locale('de', 'DE'));

    expect(preferences.locale, LocalePreference.english);
    expect(preferences.theme, ThemePreference.system);
  });

  test('restores an explicit local language and theme selection', () async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData({
      'linkso.locale': 'en',
      'linkso.theme': 'dark',
    });

    final AppPreferences preferences = await AppPreferencesStore().load(systemLocale: const Locale('ru', 'RU'));

    expect(preferences.locale, LocalePreference.english);
    expect(preferences.theme, ThemePreference.dark);
  });
}
