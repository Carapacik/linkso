// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LinkSo';

  @override
  String get homeTitle => 'Short links that work by your rules';

  @override
  String get homeDescription =>
      'Create instant, password-protected and advertising links, set expiration dates and track redirects in one LinkSo.';

  @override
  String get shortenTitle => 'Shorten a link';

  @override
  String get shortenDescription => 'Create a compact LinkSo address for any HTTP or HTTPS link.';

  @override
  String get targetUrlLabel => 'Target URL';

  @override
  String get targetUrlHint => 'https://example.com/article';

  @override
  String get targetUrlRequired => 'Enter a target URL';

  @override
  String get targetUrlTooLong => 'URL must not exceed 2048 characters';

  @override
  String get targetUrlInvalid => 'Enter a complete URL, for example https://example.com';

  @override
  String get targetUrlUnsupportedScheme => 'Only HTTP and HTTPS links are supported';

  @override
  String get linkModeLabel => 'Link type';

  @override
  String get directModeTitle => 'Direct';

  @override
  String get directModeDescription => 'Immediately redirects to the target website.';

  @override
  String get passwordModeTitle => 'Password';

  @override
  String get passwordModeDescription => 'Requires a password before the redirect.';

  @override
  String get advertisingModeTitle => 'Advertising';

  @override
  String get advertisingModeDescription => 'Shows an advertisement and enables Continue after 5 seconds.';

  @override
  String get linkTitleLabel => 'Title (optional)';

  @override
  String get linkTitleHint => 'Article for the team';

  @override
  String get linkTitleTooLong => 'Title must not exceed 120 characters';

  @override
  String get customSlugLabel => 'Custom slug (optional)';

  @override
  String get customSlugHint => 'my-link';

  @override
  String get customSlugSupporting => '3–64 letters, numbers, hyphens or underscores';

  @override
  String get customSlugTooShort => 'Slug must contain at least 3 characters';

  @override
  String get customSlugTooLong => 'Slug must not exceed 64 characters';

  @override
  String get customSlugInvalid =>
      'Use letters, numbers, hyphens or underscores and start and end with a letter or number';

  @override
  String get customSlugReserved => 'This slug is reserved by LinkSo';

  @override
  String get expirationLabel => 'Expiration (optional)';

  @override
  String get expirationAdd => 'Choose date and time';

  @override
  String get expirationClear => 'Remove expiration';

  @override
  String get expirationNotFuture => 'Expiration must be in the future';

  @override
  String get passwordLabel => 'Link password';

  @override
  String get passwordHint => 'At least 8 characters';

  @override
  String get passwordShow => 'Show password';

  @override
  String get passwordHide => 'Hide password';

  @override
  String get passwordRequired => 'Enter a link password';

  @override
  String get passwordTooShort => 'Password must contain at least 8 characters';

  @override
  String get passwordTooLong => 'Password must not exceed 128 characters';

  @override
  String get passwordAccessTitle => 'Password-protected link';

  @override
  String get passwordAccessDescription =>
      'Enter the link password to continue. The destination stays hidden until the server verifies it.';

  @override
  String get passwordSessionLoading => 'Preparing secure access…';

  @override
  String get passwordSessionUnavailable => 'This protected link or access session is no longer available.';

  @override
  String get passwordIncorrect => 'The password is incorrect';

  @override
  String passwordTemporarilyLocked(int seconds) {
    return 'Too many attempts. Try again in $seconds seconds.';
  }

  @override
  String get passwordContinueAction => 'Continue';

  @override
  String get passwordVerifyingAction => 'Checking…';

  @override
  String get tryAgainAction => 'Try again';

  @override
  String get advertisingSessionLoading => 'Loading advertisement…';

  @override
  String get advertisingSponsoredLabel => 'Advertisement';

  @override
  String get advertisingPlaceholderTitle => 'No ads yet';

  @override
  String get advertisingImageLabel => 'Advertising campaign image';

  @override
  String advertisingCountdown(int seconds) {
    return 'Continue will be available in $seconds seconds';
  }

  @override
  String get advertisingConfirming => 'Confirming with the server…';

  @override
  String get advertisingContinueAction => 'Continue';

  @override
  String get advertisingUnavailableTitle => 'Advertisement unavailable';

  @override
  String get advertisingUnavailableMessage => 'There is no active advertising campaign for this link right now.';

  @override
  String get advertisingSessionExpired => 'This advertising session has expired. Start it again.';

  @override
  String get createLinkAction => 'Create link';

  @override
  String get creatingLinkAction => 'Creating…';

  @override
  String get networkError => 'The server is unavailable. Check your connection and try again.';

  @override
  String get requestTimeoutError =>
      'The request timed out. Check your connection and whether the operation completed before trying again.';

  @override
  String get unexpectedError => 'The link could not be created. Try again.';

  @override
  String get linkSoTargetNotAllowed => 'A LinkSo address cannot be used as the target';

  @override
  String get slugTaken => 'This slug is already in use';

  @override
  String requestReference(String requestId) {
    return 'Request reference: $requestId';
  }

  @override
  String get resultTitle => 'Your link is ready';

  @override
  String get shortUrlLabel => 'Short URL';

  @override
  String get copyLinkAction => 'Copy link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get downloadQrAction => 'Save or share QR';

  @override
  String get createAnotherAction => 'Create another link';

  @override
  String get qrCodeLabel => 'QR code for the short link';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundMessage => 'The requested page or short link does not exist.';

  @override
  String get expiredTitle => 'Link expired';

  @override
  String get expiredMessage => 'This short link has reached its expiration time.';

  @override
  String get disabledTitle => 'Link disabled';

  @override
  String get disabledMessage => 'The owner has temporarily disabled this short link.';

  @override
  String get blockedTitle => 'Link blocked';

  @override
  String get blockedMessage => 'This short link is unavailable because it was blocked.';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginDescription => 'Use your verified email and password to access your links.';

  @override
  String get loginAction => 'Sign in';

  @override
  String get registerTitle => 'Create an account';

  @override
  String get registerDescription => 'Register with an email address and a password of at least 12 characters.';

  @override
  String get registerAction => 'Create account';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailInvalid => 'Enter a valid email address';

  @override
  String get accountPasswordLabel => 'Password';

  @override
  String get accountPasswordTooShort => 'Password must contain at least 12 characters';

  @override
  String get passwordConfirmationLabel => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get authWorking => 'Please wait…';

  @override
  String get backToLoginAction => 'Back to sign in';

  @override
  String get verificationSent => 'The account was created. Follow the link sent to your email to activate it.';

  @override
  String get verifyEmailTitle => 'Verify email';

  @override
  String get verifyEmailDescription =>
      'Confirm your email using the link you received. If the link has expired, request a new email.';

  @override
  String get verificationTokenLabel => 'Verification token';

  @override
  String get verifyEmailAction => 'Verify email';

  @override
  String get emailVerified => 'Email verified. You can now sign in.';

  @override
  String get passwordResetTitle => 'Reset password';

  @override
  String get passwordResetDescription => 'Request a reset email, or choose a new password after opening its link.';

  @override
  String get resendVerificationAction => 'Resend verification email';

  @override
  String get resendVerificationDescription =>
      'Enter the email you registered with. A new link replaces the previous one.';

  @override
  String get verificationResendRequested =>
      'If this address belongs to an unverified account, a new email will arrive shortly. Check your inbox and spam folder. If it does not arrive, try again later.';

  @override
  String get resetEmailRequested =>
      'If this address belongs to an active account, a reset email will arrive shortly. Check your inbox and spam folder. If it does not arrive, try again later.';

  @override
  String get emailChangeLinkDescription =>
      'Confirm the email change requested for this account. Only continue if you requested it.';

  @override
  String get passwordResetAction => 'Forgot password?';

  @override
  String get sendResetAction => 'Send reset link';

  @override
  String get resetTokenLabel => 'Reset token';

  @override
  String get setNewPasswordAction => 'Set new password';

  @override
  String get passwordResetComplete => 'The password was changed and all previous sessions were closed.';

  @override
  String get accountTitle => 'Account';

  @override
  String get logoutAction => 'Sign out';

  @override
  String get logoutAllAction => 'Sign out on all devices';

  @override
  String get invalidCredentials => 'The email or password is incorrect';

  @override
  String get emailNotVerified => 'Verify your email before signing in';

  @override
  String get emailTaken => 'An account with this email already exists';

  @override
  String get authTemporarilyLimited => 'Too many attempts. Try again later.';

  @override
  String get authTokenInvalid => 'The token is invalid or has expired';

  @override
  String get authUnexpectedError => 'The request could not be completed. Try again.';

  @override
  String get myLinksTitle => 'My links';

  @override
  String get myLinksDescription => 'Search, edit and manage the links owned by this account.';

  @override
  String get refreshAction => 'Refresh';

  @override
  String get myLinksSearchLabel => 'Search title, slug or target URL';

  @override
  String get myLinksStatusLabel => 'Status';

  @override
  String get filterAll => 'All';

  @override
  String get expirationNotExpired => 'Not expired';

  @override
  String get expirationExpired => 'Expired';

  @override
  String get expirationNever => 'Never expires';

  @override
  String get sortLabel => 'Sort by';

  @override
  String get sortCreatedAt => 'Creation date';

  @override
  String get sortRedirectCount => 'Redirect count';

  @override
  String get sortDirectionAction => 'Change sort direction';

  @override
  String get applyFiltersAction => 'Apply';

  @override
  String get clearFiltersAction => 'Clear';

  @override
  String get redirectCountLabel => 'Redirects';

  @override
  String get createdAtLabel => 'Created';

  @override
  String get actionsLabel => 'Actions';

  @override
  String redirectCountValue(int count) {
    return '$count redirects';
  }

  @override
  String paginationLabel(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String get showQrAction => 'Show QR code';

  @override
  String get editAction => 'Edit';

  @override
  String get enableAction => 'Enable';

  @override
  String get disableAction => 'Disable';

  @override
  String get deleteAction => 'Delete';

  @override
  String get closeAction => 'Close';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get saveAction => 'Save';

  @override
  String get statusActive => 'Active';

  @override
  String get statusDisabled => 'Disabled';

  @override
  String get statusBlocked => 'Blocked';

  @override
  String get myLinksEmpty => 'You have no links yet.';

  @override
  String get myLinksFilteredEmpty => 'No links match the selected filters.';

  @override
  String get myLinksLoadError => 'The links could not be loaded. Try again.';

  @override
  String get enableLinkTitle => 'Enable this link?';

  @override
  String get enableLinkMessage => 'The public link will become available again.';

  @override
  String get disableLinkTitle => 'Disable this link?';

  @override
  String get disableLinkMessage => 'Visitors will not be redirected until you enable it again.';

  @override
  String get deleteLinkTitle => 'Delete this link?';

  @override
  String get deleteLinkMessage =>
      'The link will stop working and disappear from My links. This action cannot be undone here.';

  @override
  String get editLinkTitle => 'Edit link';

  @override
  String get editPasswordSupporting => 'Leave blank to keep the current password.';

  @override
  String get editLinkError => 'The link could not be saved. Check the fields and try again.';

  @override
  String get customSlugRequired => 'Enter a slug';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get tagsHint => 'work, product launch';

  @override
  String get tagsSupporting => 'Separate tags with commas. Up to 10 tags, 32 characters each.';

  @override
  String get tagsAccountSupporting => 'Optional for signed-in users. Separate tags with commas.';

  @override
  String get tagTooLong => 'A tag must not exceed 32 characters';

  @override
  String get tooManyTags => 'A link can have at most 10 tags';

  @override
  String get invalidTag => 'Enter valid tag names';

  @override
  String get tagsAuthenticationRequired => 'Sign in to create a link with tags';

  @override
  String tagFilterValue(String name, int count) {
    return '$name ($count)';
  }

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get analyticsDescription =>
      'Real redirect activity for the selected period. Automated traffic is shown separately.';

  @override
  String linkAnalyticsTitle(String name) {
    return 'Analytics: $name';
  }

  @override
  String get analyticsAction => 'View analytics';

  @override
  String get analyticsLinks => 'Links';

  @override
  String get analyticsHumanRedirects => 'Human redirects';

  @override
  String get analyticsBotRedirects => 'Bot redirects';

  @override
  String get analyticsByDay => 'Redirects by day';

  @override
  String get advertisingFunnelTitle => 'Advertising funnel';

  @override
  String get advertisingImpressions => 'Impressions';

  @override
  String get advertisingTimerCompletions => 'Timer completions';

  @override
  String get advertisingRedirects => 'Advertising redirects';

  @override
  String get analyticsLoadError => 'Analytics could not be loaded. Try again.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsDescription => 'View your profile and manage the current account session.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileId => 'Account ID';

  @override
  String get profileCreatedAt => 'Joined';

  @override
  String get emailVerificationLabel => 'Email verification';

  @override
  String get emailVerificationConfirmed => 'Confirmed';

  @override
  String get emailVerificationPending => 'Pending';

  @override
  String get sessionSettingsTitle => 'Sessions';

  @override
  String get profileLoadError => 'The profile could not be loaded. Try again.';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get displayNameSupporting => 'Optional, up to 120 characters.';

  @override
  String get displayNameInvalid => 'Enter a display name of up to 120 characters.';

  @override
  String get appearanceSettingsTitle => 'Language, theme and time zone';

  @override
  String get languageLabel => 'Language';

  @override
  String get themeLabel => 'Theme';

  @override
  String get timezoneLabel => 'Time zone';

  @override
  String get preferenceSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Russian';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get savePreferencesAction => 'Save preferences';

  @override
  String get changeEmailTitle => 'Change email';

  @override
  String get changeEmailDescription =>
      'A new address becomes active only after confirmation. Other sessions will be closed.';

  @override
  String get newEmailLabel => 'New email';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get requestEmailChangeAction => 'Request confirmation';

  @override
  String get emailConfirmationTokenLabel => 'Confirmation token';

  @override
  String get emailConfirmationTokenSupporting => 'Paste the token from the confirmation email.';

  @override
  String get confirmEmailChangeAction => 'Confirm new email';

  @override
  String get emailChangeRequested => 'Confirmation was requested for the new email.';

  @override
  String get emailChanged => 'The email was changed.';

  @override
  String get emailUnchanged => 'Enter an email different from the current one.';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get changePasswordAction => 'Change password';

  @override
  String get passwordChanged => 'The password was changed. Other sessions were closed.';

  @override
  String get currentPasswordInvalid => 'The current password is incorrect.';

  @override
  String get currentSessionLabel => 'Current session';

  @override
  String get otherSessionLabel => 'Other session';

  @override
  String sessionLastSeen(String date) {
    return 'Last seen: $date';
  }

  @override
  String get revokeSessionAction => 'Close session';

  @override
  String get sessionRevoked => 'The session was closed.';

  @override
  String get sessionsEmpty => 'There are no active sessions.';

  @override
  String get sessionsLoadError => 'Active sessions could not be loaded.';

  @override
  String get dangerZoneTitle => 'Danger zone';

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get deleteAccountAction => 'Delete account';

  @override
  String get deleteAccountConsequences =>
      'The account will be anonymized and all owned links will be disabled and deleted. This cannot be undone.';

  @override
  String get deleteConfirmationLabel => 'Type DELETE';

  @override
  String get deleteConfirmationInvalid => 'Type DELETE exactly to confirm.';

  @override
  String get settingsFieldsRequired => 'Fill in all required fields.';

  @override
  String get settingsUnexpectedError => 'The settings could not be changed. Try again.';
}
