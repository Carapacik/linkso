import 'package:flutter/widgets.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/navigation/app_url_strategy.dart';
import 'package:linkso_client/src/features/settings/data/app_preferences_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrlStrategy();
  final preferencesStore = AppPreferencesStore();
  final AppPreferences preferences = await preferencesStore.load(
    systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
  );
  runApp(
    LinkSoApp(
      preferencesStore: preferencesStore,
      initialLocale: preferences.locale,
      initialTheme: preferences.theme,
      restoreSessionOnStart: true,
    ),
  );
}
