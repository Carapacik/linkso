import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/core/layout/window_size_class.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/core/widgets/flyout_menu.dart';
import 'package:linkso_client/src/core/widgets/linkso_logo.dart';
import 'package:linkso_client/src/features/auth/presentation/auth_controller.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';
import 'package:linkso_client/src/features/settings/presentation/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

const maximumContentWidth = 1200.0;

class const AppShell({
  required final AuthController authController,
  required final SettingsController settingsController,
  required final String location,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: authController,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final WindowSizeClass sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
        final List<_AppDestination> destinations = _destinations(context, authController.isAuthenticated);
        final int selectedIndex = _selectedIndex(destinations, location);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Padding(
              padding: EdgeInsets.symmetric(horizontal: sizeClass.contentPadding),
              child: Center(
                child: ConstrainedBox(
                  key: const ValueKey<String>('app-bar-content'),
                  constraints: const BoxConstraints(maxWidth: maximumContentWidth),
                  child: Row(
                    children: [
                      TextButton.icon(
                        key: const ValueKey<String>('home-logo-button'),
                        onPressed: () => context.go(rootPath),
                        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
                        icon: const LinkSoLogo(),
                        label: Text(context.localizations.appTitle),
                      ),
                      const Spacer(),
                      if (sizeClass.isCompact)
                        IconButton(
                          key: const ValueKey<String>('account-navigation-button'),
                          onPressed: () => context.go(authController.isAuthenticated ? accountPath : loginPath),
                          tooltip: authController.isAuthenticated
                              ? context.localizations.settingsTitle
                              : context.localizations.loginTitle,
                          icon: Icon(
                            authController.isAuthenticated ? Icons.account_circle_rounded : Icons.login_rounded,
                          ),
                        )
                      else
                        ..._topNavigationActions(context, destinations, selectedIndex, sizeClass),
                      _LanguageMenu(settingsController: settingsController),
                      _ThemeMenu(settingsController: settingsController),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: sizeClass.isCompact
              ? NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => context.go(destinations[index].path),
                  destinations: [
                    for (final destination in destinations)
                      NavigationDestination(icon: Icon(destination.icon), label: destination.label),
                  ],
                )
              : null,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(sizeClass.contentPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maximumContentWidth),
                  child: KeyedSubtree(key: ValueKey<String>('${sizeClass.name}-app-content'), child: child),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

List<Widget> _topNavigationActions(
  BuildContext context,
  List<_AppDestination> destinations,
  int selectedIndex,
  WindowSizeClass sizeClass,
) => [
  for (int index = 1; index < destinations.length; index++)
    if (!sizeClass.showsNavigationLabels)
      IconButton(
        key: ValueKey<String>('top-navigation-${destinations[index].path}'),
        onPressed: () => context.go(destinations[index].path),
        tooltip: destinations[index].label,
        isSelected: selectedIndex == index,
        icon: Icon(destinations[index].icon),
      )
    else
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton.icon(
          key: ValueKey<String>('top-navigation-${destinations[index].path}'),
          onPressed: () => context.go(destinations[index].path),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: selectedIndex == index ? Theme.of(context).colorScheme.secondaryContainer : null,
          ),
          icon: Icon(destinations[index].icon),
          label: Text(destinations[index].label),
        ),
      ),
];

class const _LanguageMenu({required final SettingsController settingsController}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => FlyoutMenu<LocalePreference>(
    key: const ValueKey<String>('language-menu'),
    value: settingsController.localePreference,
    onSelected: (value) => unawaited(settingsController.setLocalePreference(value! as LocalePreference)),
    tooltip: context.localizations.languageLabel,
    entries: [
      for (final LocalePreference value in LocalePreference.values)
        FlyoutMenuEntry(
          key: ValueKey<String>('language-option-${value.apiValue}'),
          value: value,
          label: switch (value) {
            LocalePreference.english => context.localizations.languageEnglish,
            LocalePreference.russian => context.localizations.languageRussian,
          },
        ),
    ],
    child: SizedBox.square(
      dimension: 48,
      child: Center(
        child: Text(
          settingsController.localePreference.apiValue.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    ),
  );
}

class const _ThemeMenu({required final SettingsController settingsController}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemePreference effectivePreference = Theme.of(context).brightness == Brightness.dark
        ? ThemePreference.dark
        : ThemePreference.light;

    return FlyoutMenu<ThemePreference>(
      key: const ValueKey<String>('theme-menu'),
      value: settingsController.themePreference,
      onSelected: (value) => unawaited(settingsController.setThemePreference(value! as ThemePreference)),
      tooltip: context.localizations.themeLabel,
      entries: [
        for (final ThemePreference value in ThemePreference.values)
          FlyoutMenuEntry(
            key: ValueKey<String>('theme-option-${value.apiValue}'),
            value: value,
            leading: Icon(_themeIcon(value), size: 20, color: Theme.of(context).colorScheme.onSurface),
            label: switch (value) {
              ThemePreference.system => context.localizations.themeSystem,
              ThemePreference.light => context.localizations.themeLight,
              ThemePreference.dark => context.localizations.themeDark,
            },
          ),
      ],
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: Icon(
            key: ValueKey<String>('theme-current-${effectivePreference.apiValue}'),
            _themeIcon(effectivePreference),
            color: Theme.of(context).colorScheme.onSurface,
            size: 22,
          ),
        ),
      ),
    );
  }
}

IconData _themeIcon(ThemePreference value) => switch (value) {
  ThemePreference.system => Icons.brightness_6,
  ThemePreference.light => Icons.wb_sunny,
  ThemePreference.dark => Icons.brightness_3,
};

List<_AppDestination> _destinations(BuildContext context, bool isAuthenticated) => [
  _AppDestination(path: rootPath, label: context.localizations.appTitle, icon: Icons.home_rounded),
  _AppDestination(path: shortenPath, label: context.localizations.createLinkAction, icon: Icons.add_link_rounded),
  if (isAuthenticated) ...[
    _AppDestination(path: myLinksPath, label: context.localizations.myLinksTitle, icon: Icons.link_rounded),
    _AppDestination(path: analyticsPath, label: context.localizations.analyticsTitle, icon: Icons.analytics_outlined),
    _AppDestination(path: accountPath, label: context.localizations.settingsTitle, icon: Icons.account_circle_rounded),
  ] else
    _AppDestination(path: loginPath, label: context.localizations.loginTitle, icon: Icons.login_rounded),
];

int _selectedIndex(List<_AppDestination> destinations, String location) {
  final int index = destinations.indexWhere(
    (destination) => destination.path == rootPath
        ? location == rootPath
        : location == destination.path || location.startsWith('${destination.path}/'),
  );
  return index < 0 ? 0 : index;
}

class const _AppDestination({required final String path, required final String label, required final IconData icon});
