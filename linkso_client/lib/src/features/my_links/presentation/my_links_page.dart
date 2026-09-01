import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/clipboard/copy_text.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/core/sharing/file_share.dart';
import 'package:linkso_client/src/features/my_links/data/my_link.dart';
import 'package:linkso_client/src/features/my_links/data/my_links_service.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';
import 'package:linkso_client/src/features/shorten/presentation/linkso_qr_code.dart';
import 'package:material_ui/material_ui.dart';

const myLinksExpandedBreakpoint = 850.0;

class const MyLinksPage({required final MyLinksService service, super.key}) extends StatefulWidget {
  @override
  State<MyLinksPage> createState() => _MyLinksPageState();
}

class _MyLinksPageState() extends State<MyLinksPage> {
  final _search = TextEditingController();
  MyLinksResult? _page;
  ApiFailure? _failure;
  LinkKind? _kind;
  MyLinkStatus? _status;
  MyLinksExpirationFilter? _expiration;
  String? _tag;
  List<MyTagSummary> _availableTags = const [];
  MyLinksSort _sort = MyLinksSort.createdAt;
  SortDirection _direction = SortDirection.descending;
  int _currentPage = 1;
  bool _loading = true;
  final Set<String> _busyLinks = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('my-links-page'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(context.localizations.myLinksTitle, style: Theme.of(context).textTheme.headlineMedium)),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: context.localizations.refreshAction,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(context.localizations.myLinksDescription),
      const SizedBox(height: 24),
      _filters(context),
      const SizedBox(height: 24),
      if (_loading)
        const Center(child: CircularProgressIndicator())
      else if (_failure case final failure?)
        _ErrorState(failure: failure, onRetry: _load)
      else if (_page case final page?)
        if (page.items.isEmpty)
          _EmptyState(hasFilters: _hasFilters)
        else ...[
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= myLinksExpandedBreakpoint
                ? _table(context, page.items)
                : _cards(context, page.items),
          ),
          const SizedBox(height: 20),
          _pagination(context, page),
        ],
    ],
  );

  bool get _hasFilters =>
      _search.text.trim().isNotEmpty || _kind != null || _status != null || _expiration != null || _tag != null;

  Widget _filters(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            key: const ValueKey<String>('my-links-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: context.localizations.myLinksSearchLabel,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(onPressed: _applyFilters, icon: const Icon(Icons.arrow_forward_rounded)),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FilterField<LinkKind?>(
                label: context.localizations.linkModeLabel,
                value: _kind,
                items: [
                  DropdownMenuItem(child: Text(context.localizations.filterAll)),
                  ...LinkKind.values.map(
                    (value) => DropdownMenuItem(value: value, child: Text(_kindLabel(context, value))),
                  ),
                ],
                onChanged: (value) => setState(() => _kind = value),
              ),
              _FilterField<MyLinkStatus?>(
                label: context.localizations.myLinksStatusLabel,
                value: _status,
                items: [
                  DropdownMenuItem(child: Text(context.localizations.filterAll)),
                  ...MyLinkStatus.values.map(
                    (value) => DropdownMenuItem(value: value, child: Text(_statusLabel(context, value))),
                  ),
                ],
                onChanged: (value) => setState(() => _status = value),
              ),
              _FilterField<MyLinksExpirationFilter?>(
                label: context.localizations.expirationLabel,
                value: _expiration,
                items: [
                  DropdownMenuItem(child: Text(context.localizations.filterAll)),
                  DropdownMenuItem(
                    value: MyLinksExpirationFilter.notExpired,
                    child: Text(context.localizations.expirationNotExpired),
                  ),
                  DropdownMenuItem(
                    value: MyLinksExpirationFilter.expired,
                    child: Text(context.localizations.expirationExpired),
                  ),
                  DropdownMenuItem(
                    value: MyLinksExpirationFilter.never,
                    child: Text(context.localizations.expirationNever),
                  ),
                ],
                onChanged: (value) => setState(() => _expiration = value),
              ),
              _FilterField<String?>(
                label: context.localizations.tagsLabel,
                value: _tag,
                items: [
                  DropdownMenuItem(child: Text(context.localizations.filterAll)),
                  ..._availableTags.map(
                    (tag) => DropdownMenuItem(
                      value: tag.name,
                      child: Text(context.localizations.tagFilterValue(tag.name, tag.linkCount)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _tag = value),
              ),
              _FilterField<MyLinksSort>(
                label: context.localizations.sortLabel,
                value: _sort,
                items: [
                  DropdownMenuItem(value: MyLinksSort.createdAt, child: Text(context.localizations.sortCreatedAt)),
                  DropdownMenuItem(
                    value: MyLinksSort.redirectCount,
                    child: Text(context.localizations.sortRedirectCount),
                  ),
                ],
                onChanged: (value) => setState(() => _sort = value ?? MyLinksSort.createdAt),
              ),
              IconButton.filledTonal(
                onPressed: () => setState(() {
                  _direction = _direction == SortDirection.ascending
                      ? SortDirection.descending
                      : SortDirection.ascending;
                }),
                tooltip: context.localizations.sortDirectionAction,
                icon: Icon(
                  _direction == SortDirection.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                ),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('apply-link-filters'),
                onPressed: _applyFilters,
                icon: const Icon(Icons.filter_alt_rounded),
                label: Text(context.localizations.applyFiltersAction),
              ),
              TextButton(
                onPressed: _hasFilters ? _clearFilters : null,
                child: Text(context.localizations.clearFiltersAction),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _table(BuildContext context, List<MyLink> links) => Card(
    key: const ValueKey<String>('my-links-table'),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(context.localizations.shortUrlLabel)),
          DataColumn(label: Text(context.localizations.linkTitleLabel)),
          DataColumn(label: Text(context.localizations.linkModeLabel)),
          DataColumn(label: Text(context.localizations.myLinksStatusLabel)),
          DataColumn(label: Text(context.localizations.tagsLabel)),
          DataColumn(label: Text(context.localizations.redirectCountLabel), numeric: true),
          DataColumn(label: Text(context.localizations.createdAtLabel)),
          DataColumn(label: Text(context.localizations.actionsLabel)),
        ],
        rows: links
            .map(
              (link) => DataRow(
                cells: [
                  DataCell(SelectableText(link.shortUrl.toString())),
                  DataCell(Text(link.title ?? '—')),
                  DataCell(Text(_kindLabel(context, link.kind))),
                  DataCell(_StatusChip(status: link.status)),
                  DataCell(_TagChips(tags: link.tags)),
                  DataCell(Text('${link.redirectCount}')),
                  DataCell(Text(MaterialLocalizations.of(context).formatMediumDate(link.createdAt.toLocal()))),
                  DataCell(_actions(context, link)),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );

  Widget _cards(BuildContext context, List<MyLink> links) => Column(
    key: const ValueKey<String>('my-links-cards'),
    children: links
        .map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(link.title ?? link.slug, style: Theme.of(context).textTheme.titleMedium)),
                        _StatusChip(status: link.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(link.shortUrl.toString()),
                    const SizedBox(height: 8),
                    Text(link.targetUrl.toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Text(
                      '${_kindLabel(context, link.kind)} · ${context.localizations.redirectCountValue(link.redirectCount)}',
                    ),
                    if (link.tags.isNotEmpty) ...[const SizedBox(height: 8), _TagChips(tags: link.tags)],
                    const SizedBox(height: 12),
                    _actions(context, link),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList(),
  );

  Widget _actions(BuildContext context, MyLink link) {
    final bool busy = _busyLinks.contains(link.id);
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          onPressed: busy ? null : () => _copy(link),
          tooltip: context.localizations.copyLinkAction,
          icon: const Icon(Icons.copy_rounded),
        ),
        IconButton(
          onPressed: busy ? null : () => _showQr(link),
          tooltip: context.localizations.showQrAction,
          icon: const Icon(Icons.qr_code_rounded),
        ),
        IconButton(
          onPressed: busy ? null : () => context.go('/app/links/${link.id}/edit'),
          tooltip: context.localizations.editAction,
          icon: const Icon(Icons.edit_rounded),
        ),
        IconButton(
          onPressed: busy ? null : () => context.go('/app/links/${link.id}/analytics'),
          tooltip: context.localizations.analyticsAction,
          icon: const Icon(Icons.analytics_outlined),
        ),
        IconButton(
          onPressed: busy || link.status == MyLinkStatus.blocked ? null : () => _toggle(link),
          tooltip: link.status == MyLinkStatus.disabled
              ? context.localizations.enableAction
              : context.localizations.disableAction,
          icon: Icon(link.status == MyLinkStatus.disabled ? Icons.play_arrow_rounded : Icons.pause_rounded),
        ),
        IconButton(
          onPressed: busy ? null : () => _delete(link),
          tooltip: context.localizations.deleteAction,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }

  Widget _pagination(BuildContext context, MyLinksResult page) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: page.page > 1 ? () => _goToPage(page.page - 1) : null,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Text(context.localizations.paginationLabel(page.page, page.totalPages)),
      IconButton(
        onPressed: page.page < page.totalPages ? () => _goToPage(page.page + 1) : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final List<Object> results = await Future.wait<Object>([
        widget.service.list(
          page: _currentPage,
          query: _search.text,
          kind: _kind,
          status: _status,
          expiration: _expiration,
          sort: _sort,
          direction: _direction,
          tag: _tag,
        ),
        widget.service.listTags(),
      ]);
      final page = results[0] as MyLinksResult;
      final tags = results[1] as List<MyTagSummary>;
      if (mounted) {
        setState(() {
          _page = page;
          _availableTags = tags;
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() => _failure = failure);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilters() {
    _currentPage = 1;
    unawaited(_load());
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _kind = null;
      _status = null;
      _expiration = null;
      _tag = null;
      _currentPage = 1;
    });
    unawaited(_load());
  }

  void _goToPage(int page) {
    _currentPage = page;
    unawaited(_load());
  }

  Future<void> _copy(MyLink link) async {
    try {
      await copyText(link.shortUrl.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.localizations.linkCopied)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.localizations.unexpectedError)));
      }
    }
  }

  Future<void> _showQr(MyLink link) => showDialog<void>(
    context: context,
    builder: (context) => _QrDialog(link: link),
  );

  Future<void> _toggle(MyLink link) async {
    final enabling = link.status == MyLinkStatus.disabled;
    if (!await _confirm(
      title: enabling ? context.localizations.enableLinkTitle : context.localizations.disableLinkTitle,
      message: enabling ? context.localizations.enableLinkMessage : context.localizations.disableLinkMessage,
      action: enabling ? context.localizations.enableAction : context.localizations.disableAction,
    )) {
      return;
    }
    await _mutate(link.id, () => widget.service.setEnabled(link.id, enabled: enabling));
  }

  Future<void> _delete(MyLink link) async {
    if (!await _confirm(
      title: context.localizations.deleteLinkTitle,
      message: context.localizations.deleteLinkMessage,
      action: context.localizations.deleteAction,
    )) {
      return;
    }
    await _mutate(link.id, () async {
      await widget.service.delete(link.id);
    });
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.localizations.cancelAction)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _mutate(String id, Future<void> Function() operation) async {
    setState(() => _busyLinks.add(id));
    try {
      await operation();
      await _load();
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_failureMessage(context, failure))));
      }
    } finally {
      if (mounted) {
        setState(() => _busyLinks.remove(id));
      }
    }
  }
}

class const _FilterField<T>({
  required final String label,
  required final T value,
  required final List<DropdownMenuItem<T>> items,
  required final ValueChanged<T?> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 270,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class const _StatusChip({required final MyLinkStatus status}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Chip(label: Text(_statusLabel(context, status)));
}

class const _TagChips({required final List<String> tags}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Text('—');
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags.map((tag) => Chip(label: Text(tag), visualDensity: VisualDensity.compact)).toList(),
    );
  }
}

class const _QrDialog({required final MyLink link}) extends StatefulWidget {
  @override
  State<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState() extends State<_QrDialog> {
  final GlobalKey _qrKey = GlobalKey();
  bool _downloading = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.link.shortUrl.toString()),
    content: RepaintBoundary(
      key: _qrKey,
      child: LinkSoQrCode(data: widget.link.shortUrl.toString()),
    ),
    actions: [
      FilledButton.tonalIcon(
        onPressed: _downloading ? null : _download,
        icon: const Icon(Icons.ios_share_rounded),
        label: Text(context.localizations.downloadQrAction),
      ),
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.localizations.closeAction)),
    ],
  );

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final box = context.findRenderObject()! as RenderBox;
      final Rect sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      final boundary = _qrKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('QR image encoding returned no data');
      }
      await shareFileBytes(
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        fileName: 'linkso-${widget.link.slug}.png',
        mimeType: 'image/png',
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }
}

class const _EmptyState({required final bool hasFilters}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey<String>('my-links-empty'),
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.link_off_rounded, size: 48),
          const SizedBox(height: 12),
          Text(hasFilters ? context.localizations.myLinksFilteredEmpty : context.localizations.myLinksEmpty),
        ],
      ),
    ),
  );
}

class const _ErrorState({required final ApiFailure failure, required final VoidCallback onRetry})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(_failureMessage(context, failure)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(context.localizations.tryAgainAction)),
        ],
      ),
    ),
  );
}

String _kindLabel(BuildContext context, LinkKind kind) => switch (kind) {
  LinkKind.direct => context.localizations.directModeTitle,
  LinkKind.password => context.localizations.passwordModeTitle,
  LinkKind.advertising => context.localizations.advertisingModeTitle,
};

String _statusLabel(BuildContext context, MyLinkStatus status) => switch (status) {
  MyLinkStatus.active => context.localizations.statusActive,
  MyLinkStatus.disabled => context.localizations.statusDisabled,
  MyLinkStatus.blocked => context.localizations.statusBlocked,
};

String _failureMessage(BuildContext context, ApiFailure failure) => switch (failure.code) {
  'network_error' => context.localizations.networkError,
  'request_timeout' => context.localizations.requestTimeoutError,
  _ => context.localizations.myLinksLoadError,
};
