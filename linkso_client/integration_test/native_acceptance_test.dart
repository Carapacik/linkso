import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/auth/session_token_store.dart';
import 'package:linkso_client/src/features/advertising_link/data/advertising_link_service.dart';
import 'package:linkso_client/src/features/analytics/data/analytics_service.dart';
import 'package:linkso_client/src/features/auth/data/auth_service.dart';
import 'package:linkso_client/src/features/my_links/data/my_link.dart';
import 'package:linkso_client/src/features/my_links/data/my_links_service.dart';
import 'package:linkso_client/src/features/password_link/data/password_link_service.dart';
import 'package:linkso_client/src/features/settings/data/app_preferences_store.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';
import 'package:material_ui/material_ui.dart';

// Run only against the local stack, including Mailpit port 8025.
// No mocked HTTP, secure storage, preferences or clipboard implementations.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Native UI and HTTP account/link lifecycle', (tester) async {
    expect(Platform.isAndroid || Platform.isIOS, isTrue);
    expect(const bool.fromEnvironment('ALLOW_LOCAL_ACCEPTANCE'), isTrue);
    final Uri base = Uri.parse(const String.fromEnvironment('API_BASE_URL'));
    final Uri webBase = Uri.parse(
      const String.fromEnvironment('ACCEPTANCE_WEB_BASE_URL', defaultValue: 'http://127.0.0.1:8088'),
    );
    final Uri mailpitBase = Uri.parse(
      const String.fromEnvironment('ACCEPTANCE_MAILPIT_BASE_URL', defaultValue: 'http://127.0.0.1:8025'),
    );
    expect(base.scheme, 'http');
    expect(_isPrivateAcceptanceHost(base.host), isTrue);
    expect(_isPrivateAcceptanceHost(webBase.host), isTrue);
    expect(_isPrivateAcceptanceHost(mailpitBase.host), isTrue);
    final SessionTokenStore store = createSessionTokenStore();
    final String? originalToken = await store.read();
    final preferences = AppPreferencesStore();
    final AppPreferences originalPreferences = await preferences.load(systemLocale: const Locale('en'));
    final api = LinkSoApiClient(baseUri: base, usesBearerSession: true);
    final auth = AuthService(apiClient: api);
    final profile = ProfileService(apiClient: api);
    final links = MyLinksService(apiClient: api);
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    var email = 'android-$suffix@example.test';
    var password = 'Android-Acceptance-$suffix!';
    var registered = false;
    var deleted = false;

    Future<void> waitFor(Finder finder) async {
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 30));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(finder, findsWidgets);
      expect(tester.takeException(), isNull);
    }

    Finder key(String value) => find.byKey(ValueKey<String>(value));
    Future<void> tap(Finder finder) async {
      await waitFor(finder);
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 250));
    }

    Future<void> enter(String field, String value) async {
      await tester.ensureVisible(key(field));
      await tester.enterText(key(field), value);
      await tester.pump();
    }

    Future<void> page(String route) async {
      await tester.pumpWidget(
        LinkSoApp(key: UniqueKey(), initialLocation: route, locale: const Locale('en'), apiClient: api),
      );
      await tester.pumpAndSettle();
    }

    try {
      await store.clear();
      debugPrint('ACCEPTANCE: registration and verification email');
      await page('/app/auth/register');
      await enter('auth-email-field', email);
      await enter('auth-password-field', password);
      await enter('password-confirmation-field', password);
      await tap(key('register-submit'));
      await waitFor(key('registered-email'));
      registered = true;
      final String verification = await _mailToken(mailpitBase, email, '/app/auth/verify-email', 'token');
      await page('/app/auth/verify-email#token=$verification');
      await tap(find.widgetWithText(FilledButton, 'Verify email'));
      await waitFor(find.text('Email verified. You can now sign in.'));

      debugPrint('ACCEPTANCE: login and native secure-storage reload');
      await page('/app/auth/login');
      await enter('auth-email-field', email);
      await enter('auth-password-field', password);
      await tap(key('login-submit'));
      await waitFor(key('settings-display-name'));
      expect(await store.read(), isNotEmpty);
      final restored = LinkSoApiClient(baseUri: base, usesBearerSession: true);
      try {
        expect((await AuthService(apiClient: restored).currentSession()).email, email);
      } finally {
        restored.close();
      }

      debugPrint('ACCEPTANCE: direct/password/advertising creation and native clipboard');
      for (final LinkKind kind in LinkKind.values) {
        await page('/app/shorten');
        await enter('target-url-field', 'https://example.com/android/$suffix/${kind.name}');
        await enter('link-title-field', 'Android ${kind.name}');
        await enter('custom-slug-field', 'a$suffix-${kind.name}');
        await enter('link-tags-field', 'android, acceptance');
        if (kind != LinkKind.direct) {
          await tap(find.text(kind == LinkKind.password ? 'Password' : 'Advertising'));
        }
        if (kind == LinkKind.password) {
          await enter('link-password-field', 'Link-Password-42!');
        }
        await tap(key('create-link-button'));
        await waitFor(key('created-link-result'));
        await tap(key('copy-link-button'));
        final ClipboardData? clipboard = await Clipboard.getData(Clipboard.kTextPlain);
        expect(clipboard?.text, 'http://localhost:8088/a$suffix-${kind.name}');
      }
      final MyLinksResult owned = await links.list(tag: 'android');
      expect(owned.totalItems, 3);
      final MyLink direct = owned.items.singleWhere((item) => item.kind == LinkKind.direct);
      final MyLink protected = owned.items.singleWhere((item) => item.kind == LinkKind.password);
      final MyLink advertising = owned.items.singleWhere((item) => item.kind == LinkKind.advertising);
      await _redirect(webBase.resolve('/${direct.slug}'), direct.targetUrl.toString());

      debugPrint('ACCEPTANCE: password attempts and advertising timer/tickets');
      final passwordLinks = PasswordLinkService(apiClient: api);
      final PasswordLinkSession passwordSession = await passwordLinks.start(protected.slug);
      await expectLater(
        passwordLinks.verify(slug: protected.slug, sessionId: passwordSession.id, password: 'incorrect-password'),
        throwsA(isA<ApiFailure>()),
      );
      final PasswordLinkTicket ticket = await passwordLinks.verify(
        slug: protected.slug,
        sessionId: passwordSession.id,
        password: 'Link-Password-42!',
      );
      await _redirect(ticket.redirectUri, protected.targetUrl.toString());
      final ads = AdvertisingLinkService(apiClient: api);
      final AdvertisingSession adSession = await ads.start(advertising.slug);
      await expectLater(
        ads.continueSession(slug: advertising.slug, sessionId: adSession.id),
        throwsA(isA<ApiFailure>()),
      );
      while (DateTime.now().isBefore(adSession.unlocksAt.add(const Duration(milliseconds: 300)))) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final AdvertisingTicket adTicket = await ads.continueSession(slug: advertising.slug, sessionId: adSession.id);
      await _redirect(adTicket.redirectUri, advertising.targetUrl.toString());

      debugPrint('ACCEPTANCE: management, tags, analytics and profile UI');
      await links.update(
        id: direct.id,
        targetUrl: 'https://example.org/edited',
        slug: direct.slug,
        kind: LinkKind.direct,
        title: 'Android edited',
        tags: ['edited'],
      );
      expect((await links.list(query: 'Android edited', tag: 'edited')).totalItems, 1);
      await links.setEnabled(direct.id, enabled: false);
      final http.Response disabled = await _getWithoutRedirect(webBase.resolve('/${direct.slug}'));
      expect(disabled.headers['location'], isNot('https://example.org/edited'));
      await links.setEnabled(direct.id, enabled: true);
      await _redirect(webBase.resolve('/${direct.slug}'), 'https://example.org/edited');
      await page('/app/links');
      await waitFor(find.text('Android edited'));
      final analytics = AnalyticsService(apiClient: api);
      expect((await analytics.dashboard(days: 30)).summary.links, 3);
      await analytics.link(id: direct.id, days: 30);
      await page('/app/analytics');
      await waitFor(find.text('Links'));
      await page('/app/settings');
      await waitFor(key('settings-display-name'));
      await enter('settings-display-name', 'Android acceptance');
      await tap(key('save-display-name'));
      await tester.pumpAndSettle();
      expect((await profile.getProfile()).displayName, 'Android acceptance');
      expect((await profile.updateTimezone('Europe/Moscow')).timezone, 'Europe/Moscow');

      await preferences.saveLocale(LocalePreference.russian);
      await preferences.saveTheme(ThemePreference.dark);
      final AppPreferences loaded = await AppPreferencesStore().load(systemLocale: const Locale('en'));
      expect(loaded.locale, LocalePreference.russian);
      expect(loaded.theme, ThemePreference.dark);

      debugPrint('ACCEPTANCE: session revocation, logout and logout-all');
      final secondStore = MemorySessionTokenStore();
      final secondApi = LinkSoApiClient(baseUri: base, usesBearerSession: true, sessionTokenStore: secondStore);
      final secondAuth = AuthService(apiClient: secondApi);
      try {
        await secondAuth.login(email: email, password: password);
        final AccountSession otherSession = (await profile.listSessions()).singleWhere((item) => !item.isCurrent);
        await profile.revokeSession(otherSession.id);
        await expectLater(secondAuth.currentSession(), throwsA(isA<ApiFailure>()));
        await secondAuth.login(email: email, password: password);
        await auth.logoutAll();
        expect(await store.read(), isNull);
        await expectLater(secondAuth.currentSession(), throwsA(isA<ApiFailure>()));
      } finally {
        secondApi.close();
      }
      await auth.login(email: email, password: password);
      await auth.logout();
      expect(await store.read(), isNull);

      debugPrint('ACCEPTANCE: recovery, password/email change and deletion');
      await auth.requestPasswordReset(email);
      final String reset = await _mailToken(mailpitBase, email, '/app/auth/password-reset', 'token');
      final resetPassword = '$password-reset';
      await auth.confirmPasswordReset(token: reset, password: resetPassword);
      password = resetPassword;
      await auth.login(email: email, password: password);
      final changedPassword = '$password-changed';
      await profile.changePassword(currentPassword: password, newPassword: changedPassword);
      password = changedPassword;
      final newEmail = 'android-changed-$suffix@example.test';
      await profile.requestEmailChange(email: newEmail, currentPassword: password);
      final String change = await _mailToken(mailpitBase, newEmail, '/app/settings', 'email_token');
      expect((await profile.confirmEmailChange(change)).email, newEmail);
      email = newEmail;
      await links.delete(direct.id);
      expect((await links.list()).totalItems, 2);
      await profile.deleteAccount(currentPassword: password, confirmation: 'DELETE');
      deleted = true;
      await expectLater(auth.currentSession(), throwsA(isA<ApiFailure>()));
      debugPrint('ACCEPTANCE: completed');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      try {
        if (registered && !deleted) {
          // Only remove the disposable account created by this particular run.
          await auth.login(email: email, password: password);
          await profile.deleteAccount(currentPassword: password, confirmation: 'DELETE');
        }
      } finally {
        await store.clear();
        if (originalToken != null) {
          await store.write(originalToken);
        }
        await preferences.saveLocale(originalPreferences.locale);
        await preferences.saveTheme(originalPreferences.theme);
        api.close();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

bool _isPrivateAcceptanceHost(String host) {
  if (host == 'localhost' || host == '::1' || host.startsWith('127.')) {
    return true;
  }
  final List<int>? parts = InternetAddress.tryParse(host)?.rawAddress;
  if (parts == null || parts.length != 4) {
    return false;
  }
  return parts[0] == 10 ||
      (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) ||
      (parts[0] == 192 && parts[1] == 168) ||
      (parts[0] == 169 && parts[1] == 254);
}

Future<String> _mailToken(Uri mailpitBase, String email, String path, String parameter) async {
  final client = http.Client();
  try {
    for (var attempt = 0; attempt < 30; attempt++) {
      final Uri search = mailpitBase.replace(path: '/api/v1/search', queryParameters: {'query': 'to:$email'});
      final result = jsonDecode((await client.get(search)).body) as Map<String, dynamic>;
      for (final value in result['messages'] as List<Object?>) {
        final Map<String, Object?> message = (value! as Map).cast<String, Object?>();
        final Uri uri = mailpitBase.replace(path: '/api/v1/message/${message['ID']}');
        final body = jsonDecode((await client.get(uri)).body) as Map<String, dynamic>;
        for (final RegExpMatch match in RegExp(r'http://[^\s<>]+').allMatches(body['Text'] as String)) {
          final Uri link = Uri.parse(match.group(0)!);
          if (link.path == path) {
            final String? token = Uri.splitQueryString(link.fragment)[parameter];
            if (token != null) {
              return token;
            }
          }
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('No matching email in local Mailpit for this acceptance account');
  } finally {
    client.close();
  }
}

Future<http.Response> _getWithoutRedirect(Uri uri) async {
  final client = http.Client();
  try {
    return await http.Response.fromStream(await client.send(http.Request('GET', uri)..followRedirects = false));
  } finally {
    client.close();
  }
}

Future<void> _redirect(Uri uri, String target) async {
  final http.Response response = await _getWithoutRedirect(uri);
  expect(response.statusCode, 307);
  expect(response.headers['location'], target);
}
