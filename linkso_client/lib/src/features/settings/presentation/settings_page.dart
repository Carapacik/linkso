import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/features/auth/presentation/auth_controller.dart';
import 'package:linkso_client/src/features/settings/data/profile_service.dart';
import 'package:linkso_client/src/features/settings/presentation/settings_controller.dart';
import 'package:material_ui/material_ui.dart';

class const SettingsPage({
  required final SettingsController settingsController,
  required final AuthController authController,
  final String? initialEmailToken,
  super.key,
}) extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState() extends State<SettingsPage> {
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _emailPassword = TextEditingController();
  late final _emailToken = TextEditingController(text: widget.initialEmailToken);
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  List<AccountSession> _sessions = const [];
  LocalePreference _locale = LocalePreference.english;
  ThemePreference _theme = ThemePreference.system;
  String _timezone = 'UTC';
  bool _busy = false;
  bool _sessionsLoading = true;

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEmailToken != widget.initialEmailToken) {
      _emailToken.text = widget.initialEmailToken ?? '';
    }
  }

  @override
  void initState() {
    super.initState();
    _syncProfile();
    widget.settingsController.addListener(_syncAppearancePreferences);
    unawaited(_loadSessions());
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_syncAppearancePreferences);
    _displayName.dispose();
    _email.dispose();
    _emailPassword.dispose();
    _emailToken.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _syncProfile() {
    final UserProfile? profile = widget.settingsController.profile;
    if (profile == null) {
      return;
    }
    _displayName.text = profile.displayName ?? '';
    _email.text = profile.email;
    _locale = widget.settingsController.localePreference;
    _theme = widget.settingsController.themePreference;
    _timezone = profile.timezone;
  }

  void _syncAppearancePreferences() {
    if (!mounted) {
      return;
    }
    setState(() {
      _locale = widget.settingsController.localePreference;
      _theme = widget.settingsController.themePreference;
    });
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile? profile = widget.settingsController.profile;
    return Column(
      key: const ValueKey<String>('settings-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.localizations.settingsTitle, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(context.localizations.settingsDescription),
        const SizedBox(height: 24),
        if (profile == null)
          _LoadError(onRetry: _reloadProfile)
        else ...[
          if (widget.initialEmailToken != null && _emailToken.text.isNotEmpty) ...[
            _SettingsCard(
              title: context.localizations.confirmEmailChangeAction,
              children: [
                Text(context.localizations.emailChangeLinkDescription),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey<String>('confirm-email-link'),
                  onPressed: _busy ? null : _confirmEmailChange,
                  child: Text(context.localizations.confirmEmailChangeAction),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _profileCard(context, profile),
          const SizedBox(height: 20),
          _preferencesCard(context),
          const SizedBox(height: 20),
          _emailCard(context),
          const SizedBox(height: 20),
          _passwordCard(context),
          const SizedBox(height: 20),
          _sessionsCard(context),
          const SizedBox(height: 20),
          _dangerCard(context),
        ],
      ],
    );
  }

  Widget _profileCard(BuildContext context, UserProfile profile) => _SettingsCard(
    title: context.localizations.profileTitle,
    children: [
      TextField(
        key: const ValueKey<String>('settings-display-name'),
        controller: _displayName,
        enabled: !_busy,
        maxLength: 120,
        decoration: InputDecoration(
          labelText: context.localizations.displayNameLabel,
          helperText: context.localizations.displayNameSupporting,
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          key: const ValueKey<String>('save-display-name'),
          onPressed: _busy ? null : _saveDisplayName,
          child: Text(context.localizations.saveAction),
        ),
      ),
      const Divider(height: 32),
      _ProfileRow(label: context.localizations.emailLabel, value: profile.email),
      _ProfileRow(
        label: context.localizations.emailVerificationLabel,
        value: profile.emailVerified
            ? context.localizations.emailVerificationConfirmed
            : context.localizations.emailVerificationPending,
      ),
      _ProfileRow(
        label: context.localizations.profileCreatedAt,
        value: MaterialLocalizations.of(context).formatFullDate(profile.createdAt.toLocal()),
      ),
      _ProfileRow(label: context.localizations.profileId, value: profile.id, selectable: true),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () => context.go(myLinksPath),
            icon: const Icon(Icons.link_rounded),
            label: Text(context.localizations.myLinksTitle),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.go(analyticsPath),
            icon: const Icon(Icons.analytics_outlined),
            label: Text(context.localizations.analyticsTitle),
          ),
        ],
      ),
    ],
  );

  Widget _preferencesCard(BuildContext context) => _SettingsCard(
    title: context.localizations.appearanceSettingsTitle,
    children: [
      DropdownButtonFormField<LocalePreference>(
        key: const ValueKey<String>('settings-locale'),
        initialValue: _locale,
        decoration: InputDecoration(labelText: context.localizations.languageLabel),
        items: LocalePreference.values
            .map((value) => DropdownMenuItem(value: value, child: Text(_localeLabel(context, value))))
            .toList(growable: false),
        onChanged: _busy ? null : (value) => setState(() => _locale = value ?? LocalePreference.english),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<ThemePreference>(
        key: const ValueKey<String>('settings-theme'),
        initialValue: _theme,
        decoration: InputDecoration(labelText: context.localizations.themeLabel),
        items: ThemePreference.values
            .map((value) => DropdownMenuItem(value: value, child: Text(_themeLabel(context, value))))
            .toList(growable: false),
        onChanged: _busy ? null : (value) => setState(() => _theme = value ?? ThemePreference.system),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: const ValueKey<String>('settings-timezone'),
        initialValue: _timezone,
        decoration: InputDecoration(labelText: context.localizations.timezoneLabel),
        items: supportedTimezones
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(growable: false),
        onChanged: _busy ? null : (value) => setState(() => _timezone = value ?? 'UTC'),
      ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          key: const ValueKey<String>('save-preferences'),
          onPressed: _busy ? null : _savePreferences,
          child: Text(context.localizations.savePreferencesAction),
        ),
      ),
    ],
  );

  Widget _emailCard(BuildContext context) => _SettingsCard(
    title: context.localizations.changeEmailTitle,
    children: [
      Text(context.localizations.changeEmailDescription),
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey<String>('settings-new-email'),
        controller: _email,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: context.localizations.newEmailLabel),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey<String>('settings-email-password'),
        controller: _emailPassword,
        enabled: !_busy,
        obscureText: true,
        decoration: InputDecoration(labelText: context.localizations.currentPasswordLabel),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonal(
          key: const ValueKey<String>('request-email-change'),
          onPressed: _busy ? null : _requestEmailChange,
          child: Text(context.localizations.requestEmailChangeAction),
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        key: const ValueKey<String>('settings-email-token'),
        controller: _emailToken,
        enabled: !_busy,
        decoration: InputDecoration(
          labelText: context.localizations.emailConfirmationTokenLabel,
          helperText: context.localizations.emailConfirmationTokenSupporting,
        ),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          key: const ValueKey<String>('confirm-email-change'),
          onPressed: _busy ? null : _confirmEmailChange,
          child: Text(context.localizations.confirmEmailChangeAction),
        ),
      ),
    ],
  );

  Widget _passwordCard(BuildContext context) => _SettingsCard(
    title: context.localizations.changePasswordTitle,
    children: [
      TextField(
        key: const ValueKey<String>('settings-current-password'),
        controller: _currentPassword,
        enabled: !_busy,
        obscureText: true,
        decoration: InputDecoration(labelText: context.localizations.currentPasswordLabel),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey<String>('settings-new-password'),
        controller: _newPassword,
        enabled: !_busy,
        obscureText: true,
        decoration: InputDecoration(labelText: context.localizations.newPasswordLabel),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey<String>('settings-confirm-password'),
        controller: _confirmPassword,
        enabled: !_busy,
        obscureText: true,
        decoration: InputDecoration(labelText: context.localizations.passwordConfirmationLabel),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          key: const ValueKey<String>('change-password'),
          onPressed: _busy ? null : _changePassword,
          child: Text(context.localizations.changePasswordAction),
        ),
      ),
    ],
  );

  Widget _sessionsCard(BuildContext context) => _SettingsCard(
    title: context.localizations.sessionSettingsTitle,
    children: [
      if (_sessionsLoading)
        const Center(child: CircularProgressIndicator())
      else if (_sessions.isEmpty)
        Text(context.localizations.sessionsEmpty)
      else
        ..._sessions.map(
          (session) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(session.isCurrent ? Icons.devices_rounded : Icons.devices_other_rounded),
            title: Text(
              session.isCurrent ? context.localizations.currentSessionLabel : context.localizations.otherSessionLabel,
            ),
            subtitle: Text(
              context.localizations.sessionLastSeen(
                MaterialLocalizations.of(context).formatShortDate(session.lastSeenAt.toLocal()),
              ),
            ),
            trailing: session.isCurrent
                ? null
                : IconButton(
                    onPressed: _busy ? null : () => _revokeSession(session.id),
                    tooltip: context.localizations.revokeSessionAction,
                    icon: const Icon(Icons.logout_rounded),
                  ),
          ),
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.tonal(
            onPressed: _busy ? null : () => _logout(allSessions: false),
            child: Text(context.localizations.logoutAction),
          ),
          TextButton(
            onPressed: _busy ? null : () => _logout(allSessions: true),
            child: Text(context.localizations.logoutAllAction),
          ),
        ],
      ),
    ],
  );

  Widget _dangerCard(BuildContext context) => _SettingsCard(
    title: context.localizations.dangerZoneTitle,
    children: [
      Text(context.localizations.deleteAccountConsequences),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          key: const ValueKey<String>('delete-account'),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: _busy ? null : _showDeleteDialog,
          child: Text(context.localizations.deleteAccountAction),
        ),
      ),
    ],
  );

  Future<void> _reloadProfile() async {
    await _run(() async {
      await widget.settingsController.ensureLoaded();
      _syncProfile();
    });
  }

  Future<void> _saveDisplayName() async {
    await _run(
      () => widget.settingsController.updateDisplayName(
        _displayName.text.trim().isEmpty ? null : _displayName.text.trim(),
      ),
    );
  }

  Future<void> _savePreferences() async {
    await _run(() => widget.settingsController.updatePreferences(locale: _locale, theme: _theme, timezone: _timezone));
  }

  Future<void> _requestEmailChange() async {
    if (_email.text.trim().isEmpty || _emailPassword.text.isEmpty) {
      _message(context.localizations.settingsFieldsRequired, error: true);
      return;
    }
    await _run(() async {
      final EmailChangeRequestResult result = await widget.settingsController.service.requestEmailChange(
        email: _email.text.trim(),
        currentPassword: _emailPassword.text,
      );
      if (result.developmentConfirmationToken case final token?) {
        _emailToken.text = token;
      }
      if (!mounted) {
        return;
      }
      _message(context.localizations.emailChangeRequested);
    });
  }

  Future<void> _confirmEmailChange() async {
    if (_emailToken.text.trim().isEmpty) {
      _message(context.localizations.settingsFieldsRequired, error: true);
      return;
    }
    await _run(() async {
      final UserProfile profile = await widget.settingsController.service.confirmEmailChange(_emailToken.text.trim());
      widget.settingsController.replaceProfile(profile);
      _emailPassword.clear();
      _emailToken.clear();
      _syncProfile();
      await _loadSessions();
      if (!mounted) {
        return;
      }
      _message(context.localizations.emailChanged);
      if (widget.initialEmailToken != null) {
        context.go(accountPath);
      }
    });
  }

  Future<void> _changePassword() async {
    if (_newPassword.text != _confirmPassword.text) {
      _message(context.localizations.passwordsDoNotMatch, error: true);
      return;
    }
    if (_currentPassword.text.isEmpty || _newPassword.text.length < 12) {
      _message(context.localizations.settingsFieldsRequired, error: true);
      return;
    }
    await _run(() async {
      await widget.settingsController.service.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      await _loadSessions();
      if (!mounted) {
        return;
      }
      _message(context.localizations.passwordChanged);
    });
  }

  Future<void> _loadSessions() async {
    if (mounted) {
      setState(() => _sessionsLoading = true);
    }
    try {
      final List<AccountSession> sessions = await widget.settingsController.service.listSessions();
      if (mounted) {
        setState(() => _sessions = sessions);
      }
    } on ApiFailure {
      if (mounted) {
        _message(context.localizations.sessionsLoadError, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _sessionsLoading = false);
      }
    }
  }

  Future<void> _revokeSession(String id) async {
    await _run(() async {
      await widget.settingsController.service.revokeSession(id);
      await _loadSessions();
      if (!mounted) {
        return;
      }
      _message(context.localizations.sessionRevoked);
    });
  }

  Future<void> _logout({required bool allSessions}) async {
    await _run(() async {
      await widget.authController.logout(allSessions: allSessions);
      widget.settingsController.clear();
      if (mounted) {
        context.go(shortenPath);
      }
    });
  }

  Future<void> _showDeleteDialog() async {
    var password = '';
    var confirmation = '';
    final ({String password, String confirmation})? deletion =
        await showDialog<({String password, String confirmation})>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.localizations.deleteAccountTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.localizations.deleteAccountConsequences),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey<String>('delete-account-password'),
                  onChanged: (value) => password = value,
                  obscureText: true,
                  decoration: InputDecoration(labelText: context.localizations.currentPasswordLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('delete-account-confirmation'),
                  onChanged: (value) => confirmation = value,
                  decoration: InputDecoration(labelText: context.localizations.deleteConfirmationLabel),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => context.pop(), child: Text(context.localizations.cancelAction)),
              FilledButton(
                key: const ValueKey<String>('confirm-delete-account'),
                onPressed: () => context.pop((password: password, confirmation: confirmation)),
                child: Text(context.localizations.deleteAccountAction),
              ),
            ],
          ),
        );
    if (deletion != null && mounted) {
      await _run(() async {
        await widget.settingsController.service.deleteAccount(
          currentPassword: deletion.password,
          confirmation: deletion.confirmation,
        );
        await widget.authController.logout();
        widget.settingsController.clear();
        if (mounted) {
          context.go(shortenPath);
        }
      });
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await operation();
    } on ApiFailure catch (failure) {
      if (mounted) {
        _message(_failureMessage(context, failure), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Theme.of(context).colorScheme.error : null),
    );
  }
}

class const _SettingsCard({required final String title, required final List<Widget> children}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    ),
  );
}

class const _ProfileRow({required final String label, required final String value, final bool selectable = false})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        if (selectable) SelectableText(value) else Text(value),
      ],
    ),
  );
}

class const _LoadError({required final VoidCallback onRetry}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(context.localizations.profileLoadError),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(context.localizations.tryAgainAction)),
        ],
      ),
    ),
  );
}

String _localeLabel(BuildContext context, LocalePreference value) => switch (value) {
  LocalePreference.english => context.localizations.languageEnglish,
  LocalePreference.russian => context.localizations.languageRussian,
};

String _themeLabel(BuildContext context, ThemePreference value) => switch (value) {
  ThemePreference.system => context.localizations.themeSystem,
  ThemePreference.light => context.localizations.themeLight,
  ThemePreference.dark => context.localizations.themeDark,
};

String _failureMessage(BuildContext context, ApiFailure failure) => switch (failure.code) {
  'current_password_invalid' => context.localizations.currentPasswordInvalid,
  'email_taken' => context.localizations.emailTaken,
  'email_unchanged' => context.localizations.emailUnchanged,
  'email_change_token_invalid' => context.localizations.authTokenInvalid,
  'email_temporarily_limited' => context.localizations.authTemporarilyLimited,
  'invalid_display_name' => context.localizations.displayNameInvalid,
  'invalid_password' => context.localizations.accountPasswordTooShort,
  'deletion_confirmation_invalid' => context.localizations.deleteConfirmationInvalid,
  'network_error' => context.localizations.networkError,
  'request_timeout' => context.localizations.requestTimeoutError,
  _ => context.localizations.settingsUnexpectedError,
};
