import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:linkso_client/src/app/app_shell.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/navigation/external_redirect.dart';
import 'package:linkso_client/src/features/advertising_link/presentation/advertising_link_page.dart';
import 'package:linkso_client/src/features/analytics/data/analytics_service.dart';
import 'package:linkso_client/src/features/analytics/presentation/analytics_page.dart';
import 'package:linkso_client/src/features/auth/data/auth_service.dart';
import 'package:linkso_client/src/features/auth/presentation/auth_controller.dart';
import 'package:linkso_client/src/features/auth/presentation/auth_pages.dart';
import 'package:linkso_client/src/features/home/presentation/home_page.dart';
import 'package:linkso_client/src/features/my_links/data/my_links_service.dart';
import 'package:linkso_client/src/features/my_links/presentation/edit_link_page.dart';
import 'package:linkso_client/src/features/my_links/presentation/my_links_page.dart';
import 'package:linkso_client/src/features/password_link/presentation/password_link_page.dart';
import 'package:linkso_client/src/features/settings/presentation/settings_controller.dart';
import 'package:linkso_client/src/features/settings/presentation/settings_page.dart';
import 'package:linkso_client/src/features/shorten/presentation/shorten_page.dart';
import 'package:linkso_client/src/features/system_pages/presentation/link_status_page.dart';

const rootPath = '/';
const shortenPath = '/app/shorten';
const passwordPath = '/app/password/:slug';
const advertisingPath = '/app/advertising/:slug';
const loginPath = '/app/auth/login';
const registerPath = '/app/auth/register';
const verifyEmailPath = '/app/auth/verify-email';
const resendVerificationPath = '/app/auth/verification-resend';
const passwordResetPath = '/app/auth/password-reset';
const accountPath = '/app/settings';
const legacyAccountPath = '/app/account';
const myLinksPath = '/app/links';
const editLinkPath = '/app/links/:id/edit';
const analyticsPath = '/app/analytics';
const linkAnalyticsPath = '/app/links/:id/analytics';
const expiredPath = '/errors/expired';
const disabledPath = '/errors/disabled';
const blockedPath = '/errors/blocked';

GoRouter createAppRouter({
  required LinkSoApiClient apiClient,
  required AuthService authService,
  required AuthController authController,
  required SettingsController settingsController,
  ExternalRedirect redirect = redirectToExternalUri,
  String initialLocation = rootPath,
}) {
  final myLinksService = MyLinksService(apiClient: apiClient);
  final analyticsService = AnalyticsService(apiClient: apiClient);
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authController,
    redirect: (context, state) async {
      final bool protectedRoute =
          state.uri.path == accountPath ||
          state.uri.path == legacyAccountPath ||
          state.uri.path == analyticsPath ||
          state.uri.path.startsWith(myLinksPath);
      if (protectedRoute && !await authController.ensureSessionLoaded()) {
        if (state.uri.path == accountPath && emailLinkParameter(state.uri, 'email_token') != null) {
          return Uri(
            path: loginPath,
            fragment: Uri(queryParameters: {'email_token': emailLinkParameter(state.uri, 'email_token')}).query,
          ).toString();
        }
        return loginPath;
      }
      if (state.uri.path == accountPath || state.uri.path == legacyAccountPath) {
        await settingsController.ensureLoaded();
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          authController: authController,
          settingsController: settingsController,
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: rootPath, pageBuilder: (context, state) => _page(state, const HomePage())),
          GoRoute(
            path: shortenPath,
            pageBuilder: (context, state) => _page(state, ShortenPage(apiClient: apiClient)),
          ),
          GoRoute(
            path: passwordPath,
            pageBuilder: (context, state) => _page(
              state,
              PasswordLinkPage(slug: state.pathParameters['slug']!, apiClient: apiClient, redirect: redirect),
            ),
          ),
          GoRoute(
            path: advertisingPath,
            pageBuilder: (context, state) => _page(
              state,
              AdvertisingLinkPage(slug: state.pathParameters['slug']!, apiClient: apiClient, redirect: redirect),
            ),
          ),
          GoRoute(
            path: loginPath,
            pageBuilder: (context, state) => _page(
              state,
              LoginPage(authController: authController, emailChangeToken: emailLinkParameter(state.uri, 'email_token')),
            ),
          ),
          GoRoute(
            path: registerPath,
            pageBuilder: (context, state) => _page(state, RegisterPage(authService: authService)),
          ),
          GoRoute(
            path: verifyEmailPath,
            pageBuilder: (context, state) => _page(
              state,
              VerifyEmailPage(authService: authService, initialToken: emailLinkParameter(state.uri, 'token')),
            ),
          ),
          GoRoute(
            path: passwordResetPath,
            pageBuilder: (context, state) => _page(
              state,
              PasswordResetPage(authService: authService, initialToken: emailLinkParameter(state.uri, 'token')),
            ),
          ),
          GoRoute(
            path: accountPath,
            pageBuilder: (context, state) => _page(
              state,
              SettingsPage(
                settingsController: settingsController,
                authController: authController,
                initialEmailToken: emailLinkParameter(state.uri, 'email_token'),
              ),
            ),
          ),
          GoRoute(
            path: resendVerificationPath,
            pageBuilder: (context, state) => _page(state, ResendVerificationPage(authService: authService)),
          ),
          GoRoute(path: legacyAccountPath, redirect: (context, state) => accountPath),
          GoRoute(
            path: myLinksPath,
            pageBuilder: (context, state) => _page(state, MyLinksPage(service: myLinksService)),
          ),
          GoRoute(
            path: editLinkPath,
            pageBuilder: (context, state) =>
                _page(state, EditLinkPage(id: state.pathParameters['id']!, service: myLinksService)),
          ),
          GoRoute(
            path: analyticsPath,
            pageBuilder: (context, state) => _page(state, AnalyticsPage(service: analyticsService)),
          ),
          GoRoute(
            path: linkAnalyticsPath,
            pageBuilder: (context, state) =>
                _page(state, AnalyticsPage(service: analyticsService, linkId: state.pathParameters['id'])),
          ),
          GoRoute(
            path: expiredPath,
            pageBuilder: (context, state) => _page(state, const LinkStatusPage(kind: LinkStatusPageKind.expired)),
          ),
          GoRoute(
            path: disabledPath,
            pageBuilder: (context, state) => _page(state, const LinkStatusPage(kind: LinkStatusPageKind.disabled)),
          ),
          GoRoute(
            path: blockedPath,
            pageBuilder: (context, state) => _page(state, const LinkStatusPage(kind: LinkStatusPageKind.blocked)),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AppShell(
      authController: authController,
      settingsController: settingsController,
      location: state.uri.path,
      child: const LinkStatusPage(kind: LinkStatusPageKind.notFound),
    ),
  );
}

NoTransitionPage<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

String? emailLinkParameter(Uri uri, String name) {
  try {
    return Uri.splitQueryString(uri.fragment)[name] ?? uri.queryParameters[name];
  } on FormatException {
    return null;
  }
}
