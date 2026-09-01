import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/config/app_config.dart';
import 'package:linkso_client/src/core/navigation/external_redirect.dart';
import 'package:linkso_client/src/core/theme/app_theme.dart';
import 'package:linkso_client/src/features/auth/data/auth_service.dart';
import 'package:linkso_client/src/features/auth/presentation/auth_controller.dart';
import 'package:linkso_client/src/features/settings/data/app_preferences_store.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';
import 'package:linkso_client/src/features/settings/presentation/settings_controller.dart';
import 'package:linkso_client/src/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class const LinkSoApp({
  super.key,
  final String initialLocation = rootPath,
  final Locale? locale,
  final LinkSoApiClient? apiClient,
  final AppPreferencesStore? preferencesStore,
  final LocalePreference initialLocale = LocalePreference.english,
  final ThemePreference initialTheme = ThemePreference.system,
  final bool restoreSessionOnStart = false,
  final ExternalRedirect redirect = redirectToExternalUri,
}) extends StatefulWidget {
  @override
  State<LinkSoApp> createState() => _LinkSoAppState();
}

class _LinkSoAppState() extends State<LinkSoApp> {
  late final LinkSoApiClient _apiClient;
  late final bool _ownsApiClient;
  late final GoRouter _router;
  late final AuthController _authController;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _ownsApiClient = widget.apiClient == null;
    _apiClient = widget.apiClient ?? LinkSoApiClient(baseUri: createApiBaseUri(), usesBearerSession: !kIsWeb);
    final authService = AuthService(apiClient: _apiClient);
    _authController = AuthController(service: authService);
    _settingsController = SettingsController(
      service: ProfileService(apiClient: _apiClient),
      preferencesStore: widget.preferencesStore,
      initialLocale: widget.initialLocale,
      initialTheme: widget.initialTheme,
    );
    _router = createAppRouter(
      apiClient: _apiClient,
      authService: authService,
      authController: _authController,
      settingsController: _settingsController,
      redirect: widget.redirect,
      initialLocation: widget.initialLocation,
    );
    if (widget.restoreSessionOnStart && _apiClient.usesBearerSession) {
      unawaited(_restoreNativeSession());
    }
  }

  Future<void> _restoreNativeSession() async {
    try {
      await _authController.ensureSessionLoaded();
    } on ApiFailure {
      // Keep public screens usable offline. A protected route can retry later.
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _authController.dispose();
    _settingsController.dispose();
    if (_ownsApiClient) {
      _apiClient.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsController,
      builder: (context, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        locale: widget.locale ?? _settingsController.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        theme: createLightTheme(),
        darkTheme: createDarkTheme(),
        themeMode: _settingsController.themeMode,
        routerConfig: _router,
      ),
    );
  }
}
