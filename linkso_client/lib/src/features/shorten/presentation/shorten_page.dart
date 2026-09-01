import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/features/shorten/data/created_link.dart';
import 'package:linkso_client/src/features/shorten/data/link_creation_service.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';
import 'package:linkso_client/src/features/shorten/domain/link_tags.dart';
import 'package:linkso_client/src/features/shorten/domain/shorten_form_validator.dart';
import 'package:linkso_client/src/features/shorten/domain/target_url_validator.dart';
import 'package:linkso_client/src/features/shorten/presentation/created_link_card.dart';
import 'package:linkso_client/src/features/shorten/presentation/link_kind_selector.dart';
import 'package:material_ui/material_ui.dart';

class const ShortenPage({required final LinkSoApiClient apiClient, super.key}) extends StatefulWidget {
  @override
  State<ShortenPage> createState() => _ShortenPageState();
}

class _ShortenPageState() extends State<ShortenPage> {
  final _formKey = GlobalKey<FormState>();
  final _targetUrlController = TextEditingController();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tagsController = TextEditingController();

  late final LinkCreationService _creationService;
  LinkKind _kind = LinkKind.direct;
  DateTime? _expiresAt;
  CreatedLink? _createdLink;
  bool _hasSubmitted = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _expirationError;
  String? _generalError;
  String? _requestId;
  final Map<String, String> _serverFieldErrors = {};

  @override
  void initState() {
    super.initState();
    _creationService = LinkCreationService(apiClient: widget.apiClient);
  }

  @override
  void dispose() {
    _targetUrlController.dispose();
    _titleController.dispose();
    _slugController.dispose();
    _passwordController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreatedLink? createdLink = _createdLink;
    if (createdLink != null) {
      return CreatedLinkCard(link: createdLink, onCreateAnother: _resetForm);
    }

    return Card(
      key: const ValueKey<String>('shorten-page'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          autovalidateMode: _hasSubmitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.localizations.shortenTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(context.localizations.shortenDescription, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 28),
              _buildTargetUrlField(context),
              const SizedBox(height: 24),
              _buildModeSelector(context),
              const SizedBox(height: 24),
              _buildTitleField(context),
              const SizedBox(height: 20),
              _buildSlugField(context),
              const SizedBox(height: 20),
              _buildTagsField(context),
              const SizedBox(height: 20),
              _buildExpirationField(context),
              if (_kind == LinkKind.password) ...[const SizedBox(height: 20), _buildPasswordField(context)],
              if (_generalError != null || _requestId != null) ...[
                const SizedBox(height: 20),
                _buildErrorMessage(context),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                key: const ValueKey<String>('create-link-button'),
                onPressed: !_isSubmitting ? _submit : null,
                icon: _isSubmitting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_link_rounded),
                label: Text(
                  _isSubmitting ? context.localizations.creatingLinkAction : context.localizations.createLinkAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetUrlField(BuildContext context) {
    return TextFormField(
      key: const ValueKey<String>('target-url-field'),
      controller: _targetUrlController,
      enabled: !_isSubmitting,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.url],
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: context.localizations.targetUrlLabel,
        hintText: context.localizations.targetUrlHint,
        prefixIcon: const Icon(Icons.link_rounded),
      ),
      validator: (value) => _targetUrlError(context, value ?? ''),
      onChanged: (_) => _clearServerFieldError('target_url'),
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.localizations.linkModeLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        LinkKindSelector(
          key: const ValueKey<String>('link-kind-selector'),
          selected: _kind,
          onSelectionChanged: _isSubmitting ? null : _selectKind,
        ),
        const SizedBox(height: 10),
        Text(_modeDescription(context), style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildTitleField(BuildContext context) {
    return TextFormField(
      key: const ValueKey<String>('link-title-field'),
      controller: _titleController,
      enabled: !_isSubmitting,
      textInputAction: TextInputAction.next,
      maxLength: maximumLinkTitleLength,
      decoration: InputDecoration(
        labelText: context.localizations.linkTitleLabel,
        hintText: context.localizations.linkTitleHint,
        prefixIcon: const Icon(Icons.title_rounded),
      ),
      validator: (value) => switch (validateLinkTitle(value ?? '')) {
        TitleValidationError.tooLong => context.localizations.linkTitleTooLong,
        null => _serverFieldErrors['title'],
      },
      onChanged: (_) => _clearServerFieldError('title'),
    );
  }

  Widget _buildSlugField(BuildContext context) {
    return TextFormField(
      key: const ValueKey<String>('custom-slug-field'),
      controller: _slugController,
      enabled: !_isSubmitting,
      textInputAction: TextInputAction.next,
      maxLength: maximumCustomSlugLength,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: context.localizations.customSlugLabel,
        hintText: context.localizations.customSlugHint,
        helperText: context.localizations.customSlugSupporting,
        prefixIcon: const Icon(Icons.alternate_email_rounded),
      ),
      validator: (value) => _slugError(context, value ?? ''),
      onChanged: (_) => _clearServerFieldError('slug'),
    );
  }

  Widget _buildExpirationField(BuildContext context) {
    final DateTime? expiresAt = _expiresAt;
    final String? value = expiresAt == null
        ? null
        : '${MaterialLocalizations.of(context).formatMediumDate(expiresAt)} '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(expiresAt))}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.localizations.expirationLabel, style: Theme.of(context).textTheme.labelLarge),
        if (value != null) ...[
          const SizedBox(height: 8),
          Text(value, key: const ValueKey<String>('expiration-value'), style: Theme.of(context).textTheme.titleMedium),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey<String>('expiration-picker-button'),
              onPressed: _isSubmitting ? null : _pickExpiration,
              icon: const Icon(Icons.event_rounded),
              label: Text(context.localizations.expirationAdd),
            ),
            if (expiresAt != null)
              TextButton(
                key: const ValueKey<String>('expiration-clear-button'),
                onPressed: _isSubmitting ? null : _clearExpiration,
                child: Text(context.localizations.expirationClear),
              ),
          ],
        ),
        if (_expirationError case final String error) ...[
          const SizedBox(height: 8),
          Text(
            error,
            key: const ValueKey<String>('expiration-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildTagsField(BuildContext context) {
    return TextFormField(
      key: const ValueKey<String>('link-tags-field'),
      controller: _tagsController,
      enabled: !_isSubmitting,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: context.localizations.tagsLabel,
        hintText: context.localizations.tagsHint,
        helperText: context.localizations.tagsAccountSupporting,
        prefixIcon: const Icon(Icons.sell_outlined),
      ),
      validator: (value) => _tagsError(context, value ?? ''),
      onChanged: (_) => _clearServerFieldError('tags'),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return TextFormField(
      key: const ValueKey<String>('link-password-field'),
      controller: _passwordController,
      enabled: !_isSubmitting,
      obscureText: _obscurePassword,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: context.localizations.passwordLabel,
        hintText: context.localizations.passwordHint,
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          tooltip: _obscurePassword ? context.localizations.passwordShow : context.localizations.passwordHide,
          icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded),
        ),
      ),
      validator: (value) => _passwordError(context, value ?? ''),
      onChanged: (_) => _clearServerFieldError('password'),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_generalError case final String generalError)
              Text(generalError, key: const ValueKey<String>('creation-error')),
            if (_requestId case final String requestId) ...[
              if (_generalError != null) const SizedBox(height: 8),
              SelectableText(context.localizations.requestReference(requestId)),
            ],
          ],
        ),
      ),
    );
  }

  String _modeDescription(BuildContext context) => switch (_kind) {
    LinkKind.direct => context.localizations.directModeDescription,
    LinkKind.password => context.localizations.passwordModeDescription,
    LinkKind.advertising => context.localizations.advertisingModeDescription,
  };

  String? _targetUrlError(BuildContext context, String value) {
    return switch (validateTargetUrl(value)) {
      TargetUrlValidationError.required => context.localizations.targetUrlRequired,
      TargetUrlValidationError.tooLong => context.localizations.targetUrlTooLong,
      TargetUrlValidationError.invalid => context.localizations.targetUrlInvalid,
      TargetUrlValidationError.unsupportedScheme => context.localizations.targetUrlUnsupportedScheme,
      null => _serverFieldErrors['target_url'],
    };
  }

  String? _slugError(BuildContext context, String value) {
    return switch (validateCustomSlug(value)) {
      SlugValidationError.tooShort => context.localizations.customSlugTooShort,
      SlugValidationError.tooLong => context.localizations.customSlugTooLong,
      SlugValidationError.invalidFormat => context.localizations.customSlugInvalid,
      SlugValidationError.reserved => context.localizations.customSlugReserved,
      null => _serverFieldErrors['slug'],
    };
  }

  String? _passwordError(BuildContext context, String value) {
    return switch (validateLinkPassword(value)) {
      PasswordValidationError.required => context.localizations.passwordRequired,
      PasswordValidationError.tooShort => context.localizations.passwordTooShort,
      PasswordValidationError.tooLong => context.localizations.passwordTooLong,
      null => _serverFieldErrors['password'],
    };
  }

  String? _tagsError(BuildContext context, String value) => switch (validateLinkTags(value)) {
    LinkTagsValidationError.tooLong => context.localizations.tagTooLong,
    LinkTagsValidationError.tooMany => context.localizations.tooManyTags,
    LinkTagsValidationError.empty => context.localizations.invalidTag,
    null => _serverFieldErrors['tags'],
  };

  void _selectKind(Set<LinkKind> selection) {
    final LinkKind selectedKind = selection.single;
    setState(() {
      _kind = selectedKind;
      _generalError = null;
      _requestId = null;
      if (selectedKind != LinkKind.password) {
        _passwordController.clear();
        _serverFieldErrors.remove('password');
      }
    });
  }

  Future<void> _pickExpiration() async {
    final now = DateTime.now();
    final DateTime initial = _expiresAt ?? now.add(const Duration(days: 1));
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10, now.month, now.day),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _expiresAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _expirationError = null;
      _serverFieldErrors.remove('expires_at');
    });
  }

  void _clearExpiration() {
    setState(() {
      _expiresAt = null;
      _expirationError = null;
      _serverFieldErrors.remove('expires_at');
    });
  }

  void _clearServerFieldError(String field) {
    if (_serverFieldErrors.remove(field) != null) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    setState(() {
      _hasSubmitted = true;
      _generalError = null;
      _requestId = null;
      _serverFieldErrors.clear();
      _expirationError = validateExpiration(_expiresAt, DateTime.now()) == null
          ? null
          : context.localizations.expirationNotFuture;
    });
    if (!(_formKey.currentState?.validate() ?? false) || _expirationError != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final CreatedLink link = await _creationService.create(
        targetUrl: _targetUrlController.text,
        kind: _kind,
        title: _titleController.text,
        slug: _slugController.text,
        expiresAt: _expiresAt,
        password: _kind == LinkKind.password ? _passwordController.text : null,
        tags: parseLinkTags(_tagsController.text),
      );
      if (mounted) {
        setState(() => _createdLink = link);
      }
    } on ApiFailure catch (error) {
      if (mounted) {
        _applyApiFailure(error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _applyApiFailure(ApiFailure error) {
    final String message = switch (error.code) {
      'network_error' => context.localizations.networkError,
      'request_timeout' => context.localizations.requestTimeoutError,
      'linkso_target_not_allowed' => context.localizations.linkSoTargetNotAllowed,
      'slug_taken' => context.localizations.slugTaken,
      'reserved_slug' => context.localizations.customSlugReserved,
      'invalid_slug' => context.localizations.customSlugInvalid,
      'invalid_target_url' => context.localizations.targetUrlInvalid,
      'invalid_title' => context.localizations.linkTitleTooLong,
      'invalid_expiration' => context.localizations.expirationNotFuture,
      'password_required' => context.localizations.passwordRequired,
      'invalid_password' => context.localizations.passwordTooShort,
      'invalid_tag' => context.localizations.invalidTag,
      'too_many_tags' => context.localizations.tooManyTags,
      'authentication_required' => context.localizations.tagsAuthenticationRequired,
      _ => context.localizations.unexpectedError,
    };
    setState(() {
      _requestId = error.requestId;
      if (error.field case final String field) {
        _serverFieldErrors[field] = message;
        if (field == 'expires_at') {
          _expirationError = message;
        }
        _formKey.currentState?.validate();
      } else {
        _generalError = message;
      }
    });
  }

  void _resetForm() {
    _targetUrlController.clear();
    _titleController.clear();
    _slugController.clear();
    _passwordController.clear();
    _tagsController.clear();
    setState(() {
      _kind = LinkKind.direct;
      _expiresAt = null;
      _createdLink = null;
      _hasSubmitted = false;
      _isSubmitting = false;
      _obscurePassword = true;
      _expirationError = null;
      _generalError = null;
      _requestId = null;
      _serverFieldErrors.clear();
    });
    _formKey.currentState?.reset();
  }
}
