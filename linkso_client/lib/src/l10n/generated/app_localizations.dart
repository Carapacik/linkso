import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('ru')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LinkSo'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Short links that work by your rules'**
  String get homeTitle;

  /// No description provided for @homeDescription.
  ///
  /// In en, this message translates to:
  /// **'Create instant, password-protected and advertising links, set expiration dates and track redirects in one LinkSo.'**
  String get homeDescription;

  /// No description provided for @shortenTitle.
  ///
  /// In en, this message translates to:
  /// **'Shorten a link'**
  String get shortenTitle;

  /// No description provided for @shortenDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a compact LinkSo address for any HTTP or HTTPS link.'**
  String get shortenDescription;

  /// No description provided for @targetUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Target URL'**
  String get targetUrlLabel;

  /// No description provided for @targetUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/article'**
  String get targetUrlHint;

  /// No description provided for @targetUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a target URL'**
  String get targetUrlRequired;

  /// No description provided for @targetUrlTooLong.
  ///
  /// In en, this message translates to:
  /// **'URL must not exceed 2048 characters'**
  String get targetUrlTooLong;

  /// No description provided for @targetUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a complete URL, for example https://example.com'**
  String get targetUrlInvalid;

  /// No description provided for @targetUrlUnsupportedScheme.
  ///
  /// In en, this message translates to:
  /// **'Only HTTP and HTTPS links are supported'**
  String get targetUrlUnsupportedScheme;

  /// No description provided for @linkModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Link type'**
  String get linkModeLabel;

  /// No description provided for @directModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get directModeTitle;

  /// No description provided for @directModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Immediately redirects to the target website.'**
  String get directModeDescription;

  /// No description provided for @passwordModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordModeTitle;

  /// No description provided for @passwordModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Requires a password before the redirect.'**
  String get passwordModeDescription;

  /// No description provided for @advertisingModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Advertising'**
  String get advertisingModeTitle;

  /// No description provided for @advertisingModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows an advertisement and enables Continue after 5 seconds.'**
  String get advertisingModeDescription;

  /// No description provided for @linkTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get linkTitleLabel;

  /// No description provided for @linkTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Article for the team'**
  String get linkTitleHint;

  /// No description provided for @linkTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Title must not exceed 120 characters'**
  String get linkTitleTooLong;

  /// No description provided for @customSlugLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom slug (optional)'**
  String get customSlugLabel;

  /// No description provided for @customSlugHint.
  ///
  /// In en, this message translates to:
  /// **'my-link'**
  String get customSlugHint;

  /// No description provided for @customSlugSupporting.
  ///
  /// In en, this message translates to:
  /// **'3–64 letters, numbers, hyphens or underscores'**
  String get customSlugSupporting;

  /// No description provided for @customSlugTooShort.
  ///
  /// In en, this message translates to:
  /// **'Slug must contain at least 3 characters'**
  String get customSlugTooShort;

  /// No description provided for @customSlugTooLong.
  ///
  /// In en, this message translates to:
  /// **'Slug must not exceed 64 characters'**
  String get customSlugTooLong;

  /// No description provided for @customSlugInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use letters, numbers, hyphens or underscores and start and end with a letter or number'**
  String get customSlugInvalid;

  /// No description provided for @customSlugReserved.
  ///
  /// In en, this message translates to:
  /// **'This slug is reserved by LinkSo'**
  String get customSlugReserved;

  /// No description provided for @expirationLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiration (optional)'**
  String get expirationLabel;

  /// No description provided for @expirationAdd.
  ///
  /// In en, this message translates to:
  /// **'Choose date and time'**
  String get expirationAdd;

  /// No description provided for @expirationClear.
  ///
  /// In en, this message translates to:
  /// **'Remove expiration'**
  String get expirationClear;

  /// No description provided for @expirationNotFuture.
  ///
  /// In en, this message translates to:
  /// **'Expiration must be in the future'**
  String get expirationNotFuture;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Link password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordHint;

  /// No description provided for @passwordShow.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShow;

  /// No description provided for @passwordHide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHide;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a link password'**
  String get passwordRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordTooLong.
  ///
  /// In en, this message translates to:
  /// **'Password must not exceed 128 characters'**
  String get passwordTooLong;

  /// No description provided for @passwordAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Password-protected link'**
  String get passwordAccessTitle;

  /// No description provided for @passwordAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the link password to continue. The destination stays hidden until the server verifies it.'**
  String get passwordAccessDescription;

  /// No description provided for @passwordSessionLoading.
  ///
  /// In en, this message translates to:
  /// **'Preparing secure access…'**
  String get passwordSessionLoading;

  /// No description provided for @passwordSessionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This protected link or access session is no longer available.'**
  String get passwordSessionUnavailable;

  /// No description provided for @passwordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'The password is incorrect'**
  String get passwordIncorrect;

  /// No description provided for @passwordTemporarilyLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} seconds.'**
  String passwordTemporarilyLocked(int seconds);

  /// No description provided for @passwordContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get passwordContinueAction;

  /// No description provided for @passwordVerifyingAction.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get passwordVerifyingAction;

  /// No description provided for @tryAgainAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgainAction;

  /// No description provided for @advertisingSessionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading advertisement…'**
  String get advertisingSessionLoading;

  /// No description provided for @advertisingSponsoredLabel.
  ///
  /// In en, this message translates to:
  /// **'Advertisement'**
  String get advertisingSponsoredLabel;

  /// No description provided for @advertisingPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'No ads yet'**
  String get advertisingPlaceholderTitle;

  /// No description provided for @advertisingImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Advertising campaign image'**
  String get advertisingImageLabel;

  /// No description provided for @advertisingCountdown.
  ///
  /// In en, this message translates to:
  /// **'Continue will be available in {seconds} seconds'**
  String advertisingCountdown(int seconds);

  /// No description provided for @advertisingConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming with the server…'**
  String get advertisingConfirming;

  /// No description provided for @advertisingContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get advertisingContinueAction;

  /// No description provided for @advertisingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Advertisement unavailable'**
  String get advertisingUnavailableTitle;

  /// No description provided for @advertisingUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'There is no active advertising campaign for this link right now.'**
  String get advertisingUnavailableMessage;

  /// No description provided for @advertisingSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'This advertising session has expired. Start it again.'**
  String get advertisingSessionExpired;

  /// No description provided for @createLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Create link'**
  String get createLinkAction;

  /// No description provided for @creatingLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get creatingLinkAction;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'The server is unavailable. Check your connection and try again.'**
  String get networkError;

  /// No description provided for @requestTimeoutError.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Check your connection and whether the operation completed before trying again.'**
  String get requestTimeoutError;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'The link could not be created. Try again.'**
  String get unexpectedError;

  /// No description provided for @linkSoTargetNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'A LinkSo address cannot be used as the target'**
  String get linkSoTargetNotAllowed;

  /// No description provided for @slugTaken.
  ///
  /// In en, this message translates to:
  /// **'This slug is already in use'**
  String get slugTaken;

  /// No description provided for @requestReference.
  ///
  /// In en, this message translates to:
  /// **'Request reference: {requestId}'**
  String requestReference(String requestId);

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your link is ready'**
  String get resultTitle;

  /// No description provided for @shortUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Short URL'**
  String get shortUrlLabel;

  /// No description provided for @copyLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLinkAction;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @downloadQrAction.
  ///
  /// In en, this message translates to:
  /// **'Save or share QR'**
  String get downloadQrAction;

  /// No description provided for @createAnotherAction.
  ///
  /// In en, this message translates to:
  /// **'Create another link'**
  String get createAnotherAction;

  /// No description provided for @qrCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code for the short link'**
  String get qrCodeLabel;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The requested page or short link does not exist.'**
  String get notFoundMessage;

  /// No description provided for @expiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Link expired'**
  String get expiredTitle;

  /// No description provided for @expiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This short link has reached its expiration time.'**
  String get expiredMessage;

  /// No description provided for @disabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Link disabled'**
  String get disabledTitle;

  /// No description provided for @disabledMessage.
  ///
  /// In en, this message translates to:
  /// **'The owner has temporarily disabled this short link.'**
  String get disabledMessage;

  /// No description provided for @blockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Link blocked'**
  String get blockedTitle;

  /// No description provided for @blockedMessage.
  ///
  /// In en, this message translates to:
  /// **'This short link is unavailable because it was blocked.'**
  String get blockedMessage;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your verified email and password to access your links.'**
  String get loginDescription;

  /// No description provided for @loginAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginAction;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get registerTitle;

  /// No description provided for @registerDescription.
  ///
  /// In en, this message translates to:
  /// **'Register with an email address and a password of at least 12 characters.'**
  String get registerDescription;

  /// No description provided for @registerAction.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerAction;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailInvalid;

  /// No description provided for @accountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountPasswordLabel;

  /// No description provided for @accountPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must contain at least 12 characters'**
  String get accountPasswordTooShort;

  /// No description provided for @passwordConfirmationLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get passwordConfirmationLabel;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @authWorking.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get authWorking;

  /// No description provided for @backToLoginAction.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToLoginAction;

  /// No description provided for @verificationSent.
  ///
  /// In en, this message translates to:
  /// **'The account was created. Follow the link sent to your email to activate it.'**
  String get verificationSent;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email using the link you received. If the link has expired, request a new email.'**
  String get verifyEmailDescription;

  /// No description provided for @verificationTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification token'**
  String get verificationTokenLabel;

  /// No description provided for @verifyEmailAction.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmailAction;

  /// No description provided for @emailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified. You can now sign in.'**
  String get emailVerified;

  /// No description provided for @passwordResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get passwordResetTitle;

  /// No description provided for @passwordResetDescription.
  ///
  /// In en, this message translates to:
  /// **'Request a reset email, or choose a new password after opening its link.'**
  String get passwordResetDescription;

  /// No description provided for @resendVerificationAction.
  ///
  /// In en, this message translates to:
  /// **'Resend verification email'**
  String get resendVerificationAction;

  /// No description provided for @resendVerificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you registered with. A new link replaces the previous one.'**
  String get resendVerificationDescription;

  /// No description provided for @verificationResendRequested.
  ///
  /// In en, this message translates to:
  /// **'If this address belongs to an unverified account, a new email will arrive shortly. Check your inbox and spam folder. If it does not arrive, try again later.'**
  String get verificationResendRequested;

  /// No description provided for @resetEmailRequested.
  ///
  /// In en, this message translates to:
  /// **'If this address belongs to an active account, a reset email will arrive shortly. Check your inbox and spam folder. If it does not arrive, try again later.'**
  String get resetEmailRequested;

  /// No description provided for @emailChangeLinkDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm the email change requested for this account. Only continue if you requested it.'**
  String get emailChangeLinkDescription;

  /// No description provided for @passwordResetAction.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get passwordResetAction;

  /// No description provided for @sendResetAction.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetAction;

  /// No description provided for @resetTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset token'**
  String get resetTokenLabel;

  /// No description provided for @setNewPasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get setNewPasswordAction;

  /// No description provided for @passwordResetComplete.
  ///
  /// In en, this message translates to:
  /// **'The password was changed and all previous sessions were closed.'**
  String get passwordResetComplete;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @logoutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logoutAction;

  /// No description provided for @logoutAllAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out on all devices'**
  String get logoutAllAction;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'The email or password is incorrect'**
  String get invalidCredentials;

  /// No description provided for @emailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Verify your email before signing in'**
  String get emailNotVerified;

  /// No description provided for @emailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get emailTaken;

  /// No description provided for @authTemporarilyLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get authTemporarilyLimited;

  /// No description provided for @authTokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'The token is invalid or has expired'**
  String get authTokenInvalid;

  /// No description provided for @authUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'The request could not be completed. Try again.'**
  String get authUnexpectedError;

  /// No description provided for @myLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'My links'**
  String get myLinksTitle;

  /// No description provided for @myLinksDescription.
  ///
  /// In en, this message translates to:
  /// **'Search, edit and manage the links owned by this account.'**
  String get myLinksDescription;

  /// No description provided for @refreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshAction;

  /// No description provided for @myLinksSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search title, slug or target URL'**
  String get myLinksSearchLabel;

  /// No description provided for @myLinksStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get myLinksStatusLabel;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @expirationNotExpired.
  ///
  /// In en, this message translates to:
  /// **'Not expired'**
  String get expirationNotExpired;

  /// No description provided for @expirationExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expirationExpired;

  /// No description provided for @expirationNever.
  ///
  /// In en, this message translates to:
  /// **'Never expires'**
  String get expirationNever;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortLabel;

  /// No description provided for @sortCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Creation date'**
  String get sortCreatedAt;

  /// No description provided for @sortRedirectCount.
  ///
  /// In en, this message translates to:
  /// **'Redirect count'**
  String get sortRedirectCount;

  /// No description provided for @sortDirectionAction.
  ///
  /// In en, this message translates to:
  /// **'Change sort direction'**
  String get sortDirectionAction;

  /// No description provided for @applyFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyFiltersAction;

  /// No description provided for @clearFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFiltersAction;

  /// No description provided for @redirectCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Redirects'**
  String get redirectCountLabel;

  /// No description provided for @createdAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdAtLabel;

  /// No description provided for @actionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsLabel;

  /// No description provided for @redirectCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} redirects'**
  String redirectCountValue(int count);

  /// No description provided for @paginationLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String paginationLabel(int page, int pages);

  /// No description provided for @showQrAction.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get showQrAction;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @enableAction.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enableAction;

  /// No description provided for @disableAction.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disableAction;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get statusDisabled;

  /// No description provided for @statusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get statusBlocked;

  /// No description provided for @myLinksEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no links yet.'**
  String get myLinksEmpty;

  /// No description provided for @myLinksFilteredEmpty.
  ///
  /// In en, this message translates to:
  /// **'No links match the selected filters.'**
  String get myLinksFilteredEmpty;

  /// No description provided for @myLinksLoadError.
  ///
  /// In en, this message translates to:
  /// **'The links could not be loaded. Try again.'**
  String get myLinksLoadError;

  /// No description provided for @enableLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable this link?'**
  String get enableLinkTitle;

  /// No description provided for @enableLinkMessage.
  ///
  /// In en, this message translates to:
  /// **'The public link will become available again.'**
  String get enableLinkMessage;

  /// No description provided for @disableLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable this link?'**
  String get disableLinkTitle;

  /// No description provided for @disableLinkMessage.
  ///
  /// In en, this message translates to:
  /// **'Visitors will not be redirected until you enable it again.'**
  String get disableLinkMessage;

  /// No description provided for @deleteLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this link?'**
  String get deleteLinkTitle;

  /// No description provided for @deleteLinkMessage.
  ///
  /// In en, this message translates to:
  /// **'The link will stop working and disappear from My links. This action cannot be undone here.'**
  String get deleteLinkMessage;

  /// No description provided for @editLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit link'**
  String get editLinkTitle;

  /// No description provided for @editPasswordSupporting.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the current password.'**
  String get editPasswordSupporting;

  /// No description provided for @editLinkError.
  ///
  /// In en, this message translates to:
  /// **'The link could not be saved. Check the fields and try again.'**
  String get editLinkError;

  /// No description provided for @customSlugRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a slug'**
  String get customSlugRequired;

  /// No description provided for @tagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsLabel;

  /// No description provided for @tagsHint.
  ///
  /// In en, this message translates to:
  /// **'work, product launch'**
  String get tagsHint;

  /// No description provided for @tagsSupporting.
  ///
  /// In en, this message translates to:
  /// **'Separate tags with commas. Up to 10 tags, 32 characters each.'**
  String get tagsSupporting;

  /// No description provided for @tagsAccountSupporting.
  ///
  /// In en, this message translates to:
  /// **'Optional for signed-in users. Separate tags with commas.'**
  String get tagsAccountSupporting;

  /// No description provided for @tagTooLong.
  ///
  /// In en, this message translates to:
  /// **'A tag must not exceed 32 characters'**
  String get tagTooLong;

  /// No description provided for @tooManyTags.
  ///
  /// In en, this message translates to:
  /// **'A link can have at most 10 tags'**
  String get tooManyTags;

  /// No description provided for @invalidTag.
  ///
  /// In en, this message translates to:
  /// **'Enter valid tag names'**
  String get invalidTag;

  /// No description provided for @tagsAuthenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create a link with tags'**
  String get tagsAuthenticationRequired;

  /// No description provided for @tagFilterValue.
  ///
  /// In en, this message translates to:
  /// **'{name} ({count})'**
  String tagFilterValue(String name, int count);

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Real redirect activity for the selected period. Automated traffic is shown separately.'**
  String get analyticsDescription;

  /// No description provided for @linkAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics: {name}'**
  String linkAnalyticsTitle(String name);

  /// No description provided for @analyticsAction.
  ///
  /// In en, this message translates to:
  /// **'View analytics'**
  String get analyticsAction;

  /// No description provided for @analyticsLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get analyticsLinks;

  /// No description provided for @analyticsHumanRedirects.
  ///
  /// In en, this message translates to:
  /// **'Human redirects'**
  String get analyticsHumanRedirects;

  /// No description provided for @analyticsBotRedirects.
  ///
  /// In en, this message translates to:
  /// **'Bot redirects'**
  String get analyticsBotRedirects;

  /// No description provided for @analyticsByDay.
  ///
  /// In en, this message translates to:
  /// **'Redirects by day'**
  String get analyticsByDay;

  /// No description provided for @advertisingFunnelTitle.
  ///
  /// In en, this message translates to:
  /// **'Advertising funnel'**
  String get advertisingFunnelTitle;

  /// No description provided for @advertisingImpressions.
  ///
  /// In en, this message translates to:
  /// **'Impressions'**
  String get advertisingImpressions;

  /// No description provided for @advertisingTimerCompletions.
  ///
  /// In en, this message translates to:
  /// **'Timer completions'**
  String get advertisingTimerCompletions;

  /// No description provided for @advertisingRedirects.
  ///
  /// In en, this message translates to:
  /// **'Advertising redirects'**
  String get advertisingRedirects;

  /// No description provided for @analyticsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Analytics could not be loaded. Try again.'**
  String get analyticsLoadError;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDescription.
  ///
  /// In en, this message translates to:
  /// **'View your profile and manage the current account session.'**
  String get settingsDescription;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get profileId;

  /// No description provided for @profileCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get profileCreatedAt;

  /// No description provided for @emailVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Email verification'**
  String get emailVerificationLabel;

  /// No description provided for @emailVerificationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get emailVerificationConfirmed;

  /// No description provided for @emailVerificationPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get emailVerificationPending;

  /// No description provided for @sessionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionSettingsTitle;

  /// No description provided for @profileLoadError.
  ///
  /// In en, this message translates to:
  /// **'The profile could not be loaded. Try again.'**
  String get profileLoadError;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @displayNameSupporting.
  ///
  /// In en, this message translates to:
  /// **'Optional, up to 120 characters.'**
  String get displayNameSupporting;

  /// No description provided for @displayNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name of up to 120 characters.'**
  String get displayNameInvalid;

  /// No description provided for @appearanceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Language, theme and time zone'**
  String get appearanceSettingsTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @timezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timezoneLabel;

  /// No description provided for @preferenceSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get preferenceSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @savePreferencesAction.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get savePreferencesAction;

  /// No description provided for @changeEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmailTitle;

  /// No description provided for @changeEmailDescription.
  ///
  /// In en, this message translates to:
  /// **'A new address becomes active only after confirmation. Other sessions will be closed.'**
  String get changeEmailDescription;

  /// No description provided for @newEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get newEmailLabel;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @requestEmailChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Request confirmation'**
  String get requestEmailChangeAction;

  /// No description provided for @emailConfirmationTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmation token'**
  String get emailConfirmationTokenLabel;

  /// No description provided for @emailConfirmationTokenSupporting.
  ///
  /// In en, this message translates to:
  /// **'Paste the token from the confirmation email.'**
  String get emailConfirmationTokenSupporting;

  /// No description provided for @confirmEmailChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm new email'**
  String get confirmEmailChangeAction;

  /// No description provided for @emailChangeRequested.
  ///
  /// In en, this message translates to:
  /// **'Confirmation was requested for the new email.'**
  String get emailChangeRequested;

  /// No description provided for @emailChanged.
  ///
  /// In en, this message translates to:
  /// **'The email was changed.'**
  String get emailChanged;

  /// No description provided for @emailUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Enter an email different from the current one.'**
  String get emailUnchanged;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @changePasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordAction;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'The password was changed. Other sessions were closed.'**
  String get passwordChanged;

  /// No description provided for @currentPasswordInvalid.
  ///
  /// In en, this message translates to:
  /// **'The current password is incorrect.'**
  String get currentPasswordInvalid;

  /// No description provided for @currentSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Current session'**
  String get currentSessionLabel;

  /// No description provided for @otherSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Other session'**
  String get otherSessionLabel;

  /// No description provided for @sessionLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {date}'**
  String sessionLastSeen(String date);

  /// No description provided for @revokeSessionAction.
  ///
  /// In en, this message translates to:
  /// **'Close session'**
  String get revokeSessionAction;

  /// No description provided for @sessionRevoked.
  ///
  /// In en, this message translates to:
  /// **'The session was closed.'**
  String get sessionRevoked;

  /// No description provided for @sessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no active sessions.'**
  String get sessionsEmpty;

  /// No description provided for @sessionsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Active sessions could not be loaded.'**
  String get sessionsLoadError;

  /// No description provided for @dangerZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZoneTitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountAction;

  /// No description provided for @deleteAccountConsequences.
  ///
  /// In en, this message translates to:
  /// **'The account will be anonymized and all owned links will be disabled and deleted. This cannot be undone.'**
  String get deleteAccountConsequences;

  /// No description provided for @deleteConfirmationLabel.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE'**
  String get deleteConfirmationLabel;

  /// No description provided for @deleteConfirmationInvalid.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE exactly to confirm.'**
  String get deleteConfirmationInvalid;

  /// No description provided for @settingsFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill in all required fields.'**
  String get settingsFieldsRequired;

  /// No description provided for @settingsUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'The settings could not be changed. Try again.'**
  String get settingsUnexpectedError;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
