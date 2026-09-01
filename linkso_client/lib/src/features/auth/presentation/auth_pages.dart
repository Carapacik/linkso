import 'package:go_router/go_router.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/features/auth/data/auth_service.dart';
import 'package:linkso_client/src/features/auth/presentation/auth_controller.dart';
import 'package:material_ui/material_ui.dart';

const _minimumPasswordLength = 12;

class const LoginPage({required final AuthController authController, final String? emailChangeToken, super.key})
    extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState() extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
    pageKey: 'login-page',
    title: context.localizations.loginTitle,
    description: context.localizations.loginDescription,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _EmailField(controller: _email, enabled: !_busy),
          const SizedBox(height: 16),
          _PasswordField(controller: _password, enabled: !_busy),
          if (_error != null) ...[const SizedBox(height: 16), _ErrorText(_error!)],
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey<String>('login-submit'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? context.localizations.authWorking : context.localizations.loginAction),
          ),
          TextButton(
            onPressed: _busy ? null : () => context.go(registerPath),
            child: Text(context.localizations.registerAction),
          ),
          TextButton(
            onPressed: _busy ? null : () => context.go(passwordResetPath),
            child: Text(context.localizations.passwordResetAction),
          ),
          TextButton(
            onPressed: _busy ? null : () => context.go(resendVerificationPath),
            child: Text(context.localizations.resendVerificationAction),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authController.login(email: _email.text, password: _password.text);
      if (mounted) {
        context.go(
          widget.emailChangeToken == null
              ? accountPath
              : Uri(
                  path: accountPath,
                  fragment: Uri(queryParameters: {'email_token': widget.emailChangeToken}).query,
                ).toString(),
        );
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _error = _localizedFailure(context, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class const RegisterPage({required final AuthService authService, super.key}) extends StatefulWidget {
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState() extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;
  RegistrationResult? _result;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RegistrationResult? result = _result;
    return _AuthCard(
      pageKey: 'register-page',
      title: context.localizations.registerTitle,
      description: result == null ? context.localizations.registerDescription : context.localizations.verificationSent,
      child: result == null
          ? _form(context)
          : Column(
              children: [
                Text(result.user.email, key: const ValueKey<String>('registered-email')),
                if (result.developmentVerificationToken case final token?) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go(
                      Uri(
                        path: verifyEmailPath,
                        fragment: Uri(queryParameters: {'token': token}).query,
                      ).toString(),
                    ),
                    child: Text(context.localizations.verifyEmailAction),
                  ),
                ],
                TextButton(
                  onPressed: () => context.go(loginPath),
                  child: Text(context.localizations.backToLoginAction),
                ),
                TextButton(
                  onPressed: () => context.go(resendVerificationPath),
                  child: Text(context.localizations.resendVerificationAction),
                ),
              ],
            ),
    );
  }

  Widget _form(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      children: [
        _EmailField(controller: _email, enabled: !_busy),
        const SizedBox(height: 16),
        _PasswordField(controller: _password, enabled: !_busy),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey<String>('password-confirmation-field'),
          controller: _confirmation,
          obscureText: true,
          enabled: !_busy,
          decoration: InputDecoration(labelText: context.localizations.passwordConfirmationLabel),
          validator: (value) => value == _password.text ? null : context.localizations.passwordsDoNotMatch,
        ),
        if (_error != null) ...[const SizedBox(height: 16), _ErrorText(_error!)],
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey<String>('register-submit'),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? context.localizations.authWorking : context.localizations.registerAction),
        ),
        TextButton(
          onPressed: _busy ? null : () => context.go(loginPath),
          child: Text(context.localizations.backToLoginAction),
        ),
        TextButton(
          onPressed: _busy ? null : () => context.go(resendVerificationPath),
          child: Text(context.localizations.resendVerificationAction),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final RegistrationResult result = await widget.authService.register(email: _email.text, password: _password.text);
      if (mounted) {
        setState(() => _result = result);
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _error = _localizedFailure(context, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class const VerifyEmailPage({required final AuthService authService, final String? initialToken, super.key})
    extends StatefulWidget {
  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState() extends State<VerifyEmailPage> {
  late final TextEditingController _token = TextEditingController(text: widget.initialToken);
  bool _busy = false;
  bool _verified = false;
  String? _error;

  @override
  void didUpdateWidget(covariant VerifyEmailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialToken != widget.initialToken) {
      _token.text = widget.initialToken ?? '';
      _verified = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
    pageKey: 'verify-email-page',
    title: context.localizations.verifyEmailTitle,
    description: _verified ? context.localizations.emailVerified : context.localizations.verifyEmailDescription,
    child: _verified
        ? FilledButton(onPressed: () => context.go(loginPath), child: Text(context.localizations.loginAction))
        : Column(
            children: [
              if (widget.initialToken == null)
                TextField(
                  controller: _token,
                  enabled: !_busy,
                  decoration: InputDecoration(labelText: context.localizations.verificationTokenLabel),
                ),
              if (_error != null) ...[const SizedBox(height: 16), _ErrorText(_error!)],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? context.localizations.authWorking : context.localizations.verifyEmailAction),
              ),
              TextButton(
                onPressed: _busy ? null : () => context.go(resendVerificationPath),
                child: Text(context.localizations.resendVerificationAction),
              ),
            ],
          ),
  );

  Future<void> _submit() async {
    if (_token.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.verifyEmail(_token.text.trim());
      if (mounted) {
        setState(() => _verified = true);
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _error = _localizedFailure(context, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class const PasswordResetPage({required final AuthService authService, final String? initialToken, super.key})
    extends StatefulWidget {
  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState() extends State<PasswordResetPage> {
  final _email = TextEditingController();
  late final _token = TextEditingController(text: widget.initialToken);
  final _password = TextEditingController();
  late bool _confirming = widget.initialToken?.isNotEmpty ?? false;
  bool _requested = false;
  bool _busy = false;
  bool _complete = false;
  String? _error;

  @override
  void didUpdateWidget(covariant PasswordResetPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialToken != widget.initialToken) {
      _token.text = widget.initialToken ?? '';
      _confirming = _token.text.isNotEmpty;
      _complete = false;
      _requested = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
    pageKey: 'password-reset-page',
    title: context.localizations.passwordResetTitle,
    description: _complete
        ? context.localizations.passwordResetComplete
        : (_requested && !_confirming
              ? context.localizations.resetEmailRequested
              : context.localizations.passwordResetDescription),
    child: _complete
        ? FilledButton(onPressed: () => context.go(loginPath), child: Text(context.localizations.loginAction))
        : Column(
            children: [
              if (!_confirming)
                _EmailField(controller: _email, enabled: !_busy)
              else ...[
                if (widget.initialToken == null)
                  TextField(
                    controller: _token,
                    enabled: !_busy,
                    decoration: InputDecoration(labelText: context.localizations.resetTokenLabel),
                  ),
                const SizedBox(height: 16),
                _PasswordField(controller: _password, enabled: !_busy),
              ],
              if (_error != null) ...[const SizedBox(height: 16), _ErrorText(_error!)],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : (_confirming ? _confirm : _request),
                child: Text(
                  _busy
                      ? context.localizations.authWorking
                      : (_confirming
                            ? context.localizations.setNewPasswordAction
                            : context.localizations.sendResetAction),
                ),
              ),
            ],
          ),
  );

  Future<void> _request() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = context.localizations.emailInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PasswordResetRequestResult result = await widget.authService.requestPasswordReset(_email.text);
      if (mounted) {
        setState(() {
          _requested = true;
          _confirming = result.developmentResetToken != null;
          _token.text = result.developmentResetToken ?? '';
        });
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _error = _localizedFailure(context, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirm() async {
    if (_token.text.trim().isEmpty || _password.text.length < _minimumPasswordLength) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.confirmPasswordReset(token: _token.text.trim(), password: _password.text);
      if (mounted) {
        setState(() => _complete = true);
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _error = _localizedFailure(context, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class const ResendVerificationPage({required final AuthService authService, super.key}) extends StatefulWidget {
  @override
  State<ResendVerificationPage> createState() => _ResendVerificationPageState();
}

class _ResendVerificationPageState() extends State<ResendVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _requested = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
    pageKey: 'verification-resend-page',
    title: context.localizations.resendVerificationAction,
    description: _requested
        ? context.localizations.verificationResendRequested
        : context.localizations.resendVerificationDescription,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _EmailField(controller: _email, enabled: !_busy),
          if (_error != null) ...[const SizedBox(height: 16), _ErrorText(_error!)],
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey<String>('verification-resend-submit'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? context.localizations.authWorking : context.localizations.resendVerificationAction),
          ),
          TextButton(
            onPressed: _busy ? null : () => context.go(loginPath),
            child: Text(context.localizations.backToLoginAction),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.resendVerification(_email.text);
      if (mounted) {
        setState(() => _requested = true);
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _error = _localizedFailure(context, error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class const _AuthCard({
  required final String pageKey,
  required final String title,
  required final String description,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        key: ValueKey<String>(pageKey),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(description),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class const _EmailField({required final TextEditingController controller, required final bool enabled})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextFormField(
    key: const ValueKey<String>('auth-email-field'),
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.emailAddress,
    autofillHints: const [AutofillHints.email],
    decoration: InputDecoration(labelText: context.localizations.emailLabel),
    validator: (value) => (value?.contains('@') ?? false) ? null : context.localizations.emailInvalid,
  );
}

class const _PasswordField({required final TextEditingController controller, required final bool enabled})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextFormField(
    key: const ValueKey<String>('auth-password-field'),
    controller: controller,
    enabled: enabled,
    obscureText: true,
    autofillHints: const [AutofillHints.password],
    decoration: InputDecoration(labelText: context.localizations.accountPasswordLabel),
    validator: (value) =>
        (value?.length ?? 0) >= _minimumPasswordLength ? null : context.localizations.accountPasswordTooShort,
  );
}

class const _ErrorText(final String message) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error));
}

String _localizedFailure(BuildContext context, ApiFailure error) => switch (error.code) {
  'network_error' => context.localizations.networkError,
  'request_timeout' => context.localizations.requestTimeoutError,
  'invalid_credentials' => context.localizations.invalidCredentials,
  'email_not_verified' => context.localizations.emailNotVerified,
  'email_taken' => context.localizations.emailTaken,
  'login_temporarily_limited' ||
  'password_reset_temporarily_limited' ||
  'email_temporarily_limited' => context.localizations.authTemporarilyLimited,
  'verification_token_invalid' || 'password_reset_token_invalid' => context.localizations.authTokenInvalid,
  _ => context.localizations.authUnexpectedError,
};
