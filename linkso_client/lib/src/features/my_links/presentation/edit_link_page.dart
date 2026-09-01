import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/features/my_links/data/my_link.dart';
import 'package:linkso_client/src/features/my_links/data/my_links_service.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';
import 'package:linkso_client/src/features/shorten/domain/link_tags.dart';
import 'package:linkso_client/src/features/shorten/domain/shorten_form_validator.dart';
import 'package:linkso_client/src/features/shorten/domain/target_url_validator.dart';
import 'package:linkso_client/src/features/shorten/presentation/link_kind_selector.dart';
import 'package:material_ui/material_ui.dart';

class const EditLinkPage({required final String id, required final MyLinksService service, super.key})
    extends StatefulWidget {
  @override
  State<EditLinkPage> createState() => _EditLinkPageState();
}

class _EditLinkPageState() extends State<EditLinkPage> {
  final _formKey = GlobalKey<FormState>();
  final _targetUrl = TextEditingController();
  final _slug = TextEditingController();
  final _title = TextEditingController();
  final _password = TextEditingController();
  final _tags = TextEditingController();
  MyLink? _link;
  LinkKind _kind = LinkKind.direct;
  DateTime? _expiresAt;
  ApiFailure? _failure;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _targetUrl.dispose();
    _slug.dispose();
    _title.dispose();
    _password.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failure != null && _link == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.localizations.myLinksLoadError),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: Text(context.localizations.tryAgainAction)),
          ],
        ),
      );
    }
    return Card(
      key: const ValueKey<String>('edit-link-page'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.localizations.editLinkTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              TextFormField(
                controller: _targetUrl,
                enabled: !_saving,
                decoration: InputDecoration(labelText: context.localizations.targetUrlLabel),
                validator: (value) => _targetError(context, value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _slug,
                enabled: !_saving,
                decoration: InputDecoration(labelText: context.localizations.customSlugLabel),
                validator: (value) => _slugError(context, value ?? ''),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('edit-title-field'),
                controller: _title,
                enabled: !_saving,
                maxLength: maximumLinkTitleLength,
                decoration: InputDecoration(labelText: context.localizations.linkTitleLabel),
                validator: (value) => validateLinkTitle(value ?? '') == TitleValidationError.tooLong
                    ? context.localizations.linkTitleTooLong
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('edit-tags-field'),
                controller: _tags,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: context.localizations.tagsLabel,
                  hintText: context.localizations.tagsHint,
                  helperText: context.localizations.tagsSupporting,
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
                validator: (value) => _tagsError(context, value ?? ''),
              ),
              const SizedBox(height: 16),
              Text(context.localizations.linkModeLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              LinkKindSelector(
                selected: _kind,
                onSelectionChanged: _saving ? null : (values) => setState(() => _kind = values.single),
              ),
              if (_kind == LinkKind.password) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_saving,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.localizations.passwordLabel,
                    helperText: context.localizations.editPasswordSupporting,
                  ),
                  validator: (value) => _passwordError(context, value ?? ''),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _chooseExpiration,
                    icon: const Icon(Icons.event_rounded),
                    label: Text(_expirationLabel(context)),
                  ),
                  if (_expiresAt != null)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _expiresAt = null),
                      child: Text(context.localizations.expirationClear),
                    ),
                ],
              ),
              if (_failure != null) ...[
                const SizedBox(height: 16),
                Text(switch (_failure!.code) {
                  'network_error' => context.localizations.networkError,
                  'request_timeout' => context.localizations.requestTimeoutError,
                  _ => context.localizations.editLinkError,
                }, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    key: const ValueKey<String>('save-link-button'),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? context.localizations.authWorking : context.localizations.saveAction),
                  ),
                  TextButton(
                    onPressed: _saving ? null : () => context.go(myLinksPath),
                    child: Text(context.localizations.cancelAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final MyLink link = await widget.service.get(widget.id);
      _link = link;
      _targetUrl.text = link.targetUrl.toString();
      _slug.text = link.slug;
      _title.text = link.title ?? '';
      _tags.text = link.tags.join(', ');
      _kind = link.kind;
      _expiresAt = link.expiresAt?.toLocal();
    } on ApiFailure catch (failure) {
      _failure = failure;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await widget.service.update(
        id: widget.id,
        targetUrl: _targetUrl.text,
        slug: _slug.text,
        title: _title.text,
        kind: _kind,
        expiresAt: _expiresAt,
        password: _password.text,
        tags: parseLinkTags(_tags.text),
      );
      if (mounted) {
        context.go(myLinksPath);
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() => _failure = failure);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _chooseExpiration() async {
    final now = DateTime.now();
    final DateTime initial = _expiresAt?.isAfter(now) ?? false ? _expiresAt! : now.add(const Duration(days: 1));
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time != null && mounted) {
      setState(() => _expiresAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  String _expirationLabel(BuildContext context) {
    final DateTime? value = _expiresAt;
    if (value == null) {
      return context.localizations.expirationAdd;
    }
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(value)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
  }

  String? _passwordError(BuildContext context, String value) {
    if (value.isEmpty && _link?.kind == LinkKind.password) {
      return null;
    }
    return switch (validateLinkPassword(value)) {
      PasswordValidationError.required => context.localizations.passwordRequired,
      PasswordValidationError.tooShort => context.localizations.passwordTooShort,
      PasswordValidationError.tooLong => context.localizations.passwordTooLong,
      null => null,
    };
  }

  String? _tagsError(BuildContext context, String value) => switch (validateLinkTags(value)) {
    LinkTagsValidationError.tooLong => context.localizations.tagTooLong,
    LinkTagsValidationError.tooMany => context.localizations.tooManyTags,
    LinkTagsValidationError.empty => context.localizations.invalidTag,
    null => null,
  };
}

String? _targetError(BuildContext context, String value) => switch (validateTargetUrl(value)) {
  TargetUrlValidationError.required => context.localizations.targetUrlRequired,
  TargetUrlValidationError.tooLong => context.localizations.targetUrlTooLong,
  TargetUrlValidationError.invalid => context.localizations.targetUrlInvalid,
  TargetUrlValidationError.unsupportedScheme => context.localizations.targetUrlUnsupportedScheme,
  null => null,
};

String? _slugError(BuildContext context, String value) => switch (validateCustomSlug(value)) {
  SlugValidationError.tooShort => context.localizations.customSlugTooShort,
  SlugValidationError.tooLong => context.localizations.customSlugTooLong,
  SlugValidationError.invalidFormat => context.localizations.customSlugInvalid,
  SlugValidationError.reserved => context.localizations.customSlugReserved,
  null when value.trim().isEmpty => context.localizations.customSlugRequired,
  null => null,
};
