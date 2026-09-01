import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/app/app_shell.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/auth/session_token_store.dart';
import 'package:linkso_client/src/core/theme/app_colors.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';
import 'package:linkso_client/src/l10n/generated/app_localizations_ru.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('native page navigation has no forward or reverse animation', (tester) async {
    await tester.pumpWidget(const LinkSoApp(locale: Locale('en')));
    await tester.pumpAndSettle();

    final GoRouter router = GoRouter.of(tester.element(find.byKey(const ValueKey<String>('home-page'))));
    for (final (String, String) route in [
      (rootPath, 'home-page'),
      (shortenPath, 'shorten-page'),
      (registerPath, 'register-page'),
      (loginPath, 'login-page'),
      (rootPath, 'home-page'),
    ]) {
      router.go(route.$1);
      await tester.pumpAndSettle();
      final ModalRoute<Object?> pageRoute = ModalRoute.of(tester.element(find.byKey(ValueKey<String>(route.$2))))!;
      expect(pageRoute.settings, isA<NoTransitionPage<void>>());
      expect(pageRoute.transitionDuration, Duration.zero);
      expect(pageRoute.reverseTransitionDuration, Duration.zero);
    }
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('native home restores a stored session without visiting a protected route', (tester) async {
    final store = MemorySessionTokenStore();
    await store.write('restored-native-session');
    var requests = 0;
    final api = LinkSoApiClient(
      baseUri: Uri.parse('http://localhost/'),
      usesBearerSession: true,
      sessionTokenStore: store,
      client: MockClient((request) async {
        requests++;
        expect(request.headers['authorization'], 'Bearer restored-native-session');
        return http.Response(
          '{"id":"native-user","email":"native@example.test","email_verified":true,"created_at":"2026-08-31T00:00:00Z"}',
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(LinkSoApp(apiClient: api, restoreSessionOnStart: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('top-navigation-/app/links')), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(requests, 1);
  });

  testWidgets('late native session response after disposal is ignored', (tester) async {
    final response = Completer<http.Response>();
    final api = LinkSoApiClient(
      baseUri: Uri.parse('http://localhost/'),
      usesBearerSession: true,
      sessionTokenStore: MemorySessionTokenStore(),
      client: MockClient((_) => response.future),
    );
    addTearDown(api.close);
    await tester.pumpWidget(LinkSoApp(apiClient: api, restoreSessionOnStart: true));
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(http.Response('{"error":{"code":"authentication_required","message":"Sign in"}}', 401));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('English is the default locale', (tester) async {
    await tester.pumpWidget(const LinkSoApp());
    await tester.pumpAndSettle();

    expect(find.text('Short links that work by your rules'), findsOneWidget);
  });

  testWidgets('root route opens the localized home page in the app shell', (tester) async {
    await tester.pumpWidget(const LinkSoApp(locale: Locale('ru')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('home-page')), findsOneWidget);
    expect(find.text(AppLocalizationsRu().homeTitle), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('app bar switches language and theme without an account', (tester) async {
    await tester.pumpWidget(const LinkSoApp(initialTheme: ThemePreference.light));
    await tester.pumpAndSettle();

    expect(find.text('EN'), findsOneWidget);
    final Finder languageMenu = find.byKey(const ValueKey<String>('language-menu'));
    final FocusNode languageFocus = tester
        .widget<InkWell>(find.descendant(of: languageMenu, matching: find.byType(InkWell)))
        .focusNode!;
    await tester.tap(languageMenu);
    await tester.pumpAndSettle();
    expect(languageFocus.hasFocus, isTrue);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Russian'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('language-option-ru')));
    await tester.pumpAndSettle();

    expect(languageFocus.hasFocus, isFalse);
    expect(find.text(AppLocalizationsRu().homeTitle), findsOneWidget);
    expect(find.text('RU'), findsOneWidget);

    final Finder themeMenu = find.byKey(const ValueKey<String>('theme-menu'));
    final FocusNode themeFocus = tester
        .widget<InkWell>(find.descendant(of: themeMenu, matching: find.byType(InkWell)))
        .focusNode!;
    await tester.tap(themeMenu);
    await tester.pumpAndSettle();
    expect(themeFocus.hasFocus, isTrue);
    await tester.tap(find.byKey(const ValueKey<String>('theme-option-dark')));
    await tester.pumpAndSettle();

    expect(themeFocus.hasFocus, isFalse);
    final BuildContext context = tester.element(find.byKey(const ValueKey<String>('home-page')));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(find.byKey(const ValueKey<String>('theme-current-dark')), findsOneWidget);
  });

  testWidgets('app bar flyout closes with Escape', (tester) async {
    await tester.pumpWidget(const LinkSoApp(initialTheme: ThemePreference.light));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('language-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Russian'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Russian'), findsNothing);
  });

  testWidgets('system routes show their matching English pages', (tester) async {
    final Map<String, ({String key, String title})> cases = {
      expiredPath: (key: 'expired-page', title: 'Link expired'),
      disabledPath: (key: 'disabled-page', title: 'Link disabled'),
      blockedPath: (key: 'blocked-page', title: 'Link blocked'),
      '/missing': (key: 'notFound-page', title: 'Page not found'),
    };

    for (final MapEntry<String, ({String key, String title})> entry in cases.entries) {
      await tester.pumpWidget(LinkSoApp(key: UniqueKey(), locale: const Locale('en'), initialLocation: entry.key));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>(entry.value.key)), findsOneWidget);
      expect(find.text(entry.value.title), findsOneWidget);
    }
  });

  testWidgets('app shell switches between compact and expanded layouts', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LinkSoApp(locale: Locale('en'), initialLocation: shortenPath));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('medium-app-content')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const ValueKey<String>('top-navigation-/app/shorten')), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('large-app-content')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    tester.view.physicalSize = const Size(1600, 900);
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey<String>('app-bar-content'))).width, maximumContentWidth);
  });

  testWidgets('system brightness selects the matching SpaceForum palette', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const LinkSoApp(locale: Locale('en'), initialLocation: shortenPath));
    await tester.pumpAndSettle();
    BuildContext context = tester.element(find.byKey(const ValueKey<String>('shorten-page')));
    expect(Theme.of(context).colorScheme.primary, linkSoPrimaryColor);
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    context = tester.element(find.byKey(const ValueKey<String>('shorten-page')));
    expect(Theme.of(context).colorScheme.primary, linkSoDarkPrimaryColor);
    expect(find.byIcon(Icons.brightness_3), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('theme-menu')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.brightness_6), findsOneWidget);
  });

  testWidgets('every Material text style uses Nunito with visible theme colors', (tester) async {
    await tester.pumpWidget(const LinkSoApp(locale: Locale('en')));
    await tester.pumpAndSettle();
    final BuildContext context = tester.element(find.byKey(const ValueKey<String>('home-page')));
    final ThemeData theme = Theme.of(context);
    final List<TextStyle?> styles = [
      theme.textTheme.displayLarge,
      theme.textTheme.displayMedium,
      theme.textTheme.displaySmall,
      theme.textTheme.headlineLarge,
      theme.textTheme.headlineMedium,
      theme.textTheme.headlineSmall,
      theme.textTheme.titleLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.titleSmall,
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.bodySmall,
      theme.textTheme.labelLarge,
      theme.textTheme.labelMedium,
      theme.textTheme.labelSmall,
    ];

    for (final style in styles) {
      expect(style?.fontFamily, 'Nunito');
      expect(style?.color, theme.colorScheme.onSurface);
    }
  });

  testWidgets('account route guard sends an anonymous visitor to login', (tester) async {
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient(
        (_) async =>
            http.Response('{"error":{"code":"authentication_required","message":"Authentication is required"}}', 401),
      ),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: accountPath, apiClient: apiClient));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('login-page')), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('login form opens the protected account page after a successful session response', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);
    final apiClient = LinkSoApiClient(
      baseUri: Uri.parse('https://linkso.su/'),
      client: MockClient(
        (request) async => request.url.path == '/api/v1/me/sessions'
            ? http.Response('[]', 200)
            : http.Response(
                '{"id":"01991a6c-b267-7a11-9b26-9cdd65e44071","email":"person@example.com","status":"active",'
                '"email_verified":true,"created_at":"2026-08-29T12:00:00Z","display_name":null,'
                '"timezone":"UTC"}',
                200,
                headers: {'set-cookie': 'linkso_session=session; HttpOnly; SameSite=Lax'},
              ),
      ),
    );
    addTearDown(apiClient.close);

    await tester.pumpWidget(LinkSoApp(locale: const Locale('en'), initialLocation: loginPath, apiClient: apiClient));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('auth-email-field')), 'person@example.com');
    await tester.enterText(find.byKey(const ValueKey<String>('auth-password-field')), 'correct horse battery staple');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('settings-page')), findsOneWidget);
    expect(find.text('person@example.com'), findsWidgets);
  });
}
