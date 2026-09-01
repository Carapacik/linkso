import 'dart:async';

import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/core/navigation/external_redirect.dart';
import 'package:linkso_client/src/features/password_link/data/password_link_service.dart';
import 'package:material_ui/material_ui.dart';

class const PasswordLinkPage({
  required final String slug,
  required final LinkSoApiClient apiClient,
  final ExternalRedirect redirect = redirectToExternalUri,
  super.key,
}) extends StatefulWidget {
  @override
  State<PasswordLinkPage> createState() => _PasswordLinkPageState();
}

class _PasswordLinkPageState() extends State<PasswordLinkPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  late final PasswordLinkService _service;
  PasswordLinkSession? _session;
  Timer? _lockTimer;
  bool _loadingSession = true;
  bool _verifying = false;
  bool _obscurePassword = true;
  int _lockSeconds = 0;
  String? _passwordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _service = PasswordLinkService(apiClient: widget.apiClient);
    unawaited(_startSession());
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey<String>('password-link-page'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _loadingSession ? _buildLoading(context) : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: context.localizations.passwordSessionLoading,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.localizations.passwordSessionLoading),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_session == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.localizations.passwordAccessTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(_generalError ?? context.localizations.passwordSessionUnavailable),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey<String>('password-retry-session-button'),
            onPressed: _startSession,
            child: Text(context.localizations.tryAgainAction),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.localizations.passwordAccessTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(context.localizations.passwordAccessDescription),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey<String>('access-password-field'),
            controller: _passwordController,
            enabled: !_verifying && _lockSeconds == 0,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: context.localizations.passwordLabel,
              errorText: _passwordError,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                tooltip: _obscurePassword ? context.localizations.passwordShow : context.localizations.passwordHide,
                icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              ),
            ),
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
            onFieldSubmitted: (_) {
              if (_lockSeconds == 0 && !_verifying) {
                unawaited(_verify());
              }
            },
          ),
          if (_lockSeconds > 0) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                context.localizations.passwordTemporarilyLocked(_lockSeconds),
                key: const ValueKey<String>('password-lock-message'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          if (_generalError != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(_generalError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey<String>('verify-password-button'),
            onPressed: _verifying || _lockSeconds > 0 ? null : _verify,
            icon: _verifying
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_open_rounded),
            label: Text(
              _verifying ? context.localizations.passwordVerifyingAction : context.localizations.passwordContinueAction,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSession() async {
    _lockTimer?.cancel();
    setState(() {
      _loadingSession = true;
      _session = null;
      _lockSeconds = 0;
      _generalError = null;
    });
    try {
      final PasswordLinkSession session = await _service.start(widget.slug);
      if (mounted) {
        setState(() => _session = session);
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() {
          _generalError = switch (error.code) {
            'network_error' => context.localizations.networkError,
            'request_timeout' => context.localizations.requestTimeoutError,
            _ => context.localizations.passwordSessionUnavailable,
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSession = false);
      }
    }
  }

  Future<void> _verify() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = context.localizations.passwordRequired);
      return;
    }
    setState(() {
      _verifying = true;
      _passwordError = null;
      _generalError = null;
    });
    try {
      final PasswordLinkTicket ticket = await _service.verify(
        slug: widget.slug,
        sessionId: _session!.id,
        password: _passwordController.text,
      );
      await widget.redirect(ticket.redirectUri);
    } on ApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'password_incorrect') {
        setState(() => _passwordError = context.localizations.passwordIncorrect);
      } else if (error.code == 'password_temporarily_locked') {
        _startLockCountdown(error.retryAfterSeconds ?? 30);
      } else if (error.statusCode == 404 || error.statusCode == 410) {
        setState(() {
          _session = null;
          _generalError = context.localizations.passwordSessionUnavailable;
        });
      } else {
        setState(() {
          _generalError = switch (error.code) {
            'network_error' => context.localizations.networkError,
            'request_timeout' => context.localizations.requestTimeoutError,
            _ => context.localizations.unexpectedError,
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() => _lockSeconds = seconds);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _lockSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _lockSeconds = 0);
        }
      } else {
        setState(() => _lockSeconds--);
      }
    });
  }
}
