import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:linkso_client/src/core/clipboard/copy_text.dart';
import 'package:linkso_client/src/core/localization/build_context_localizations.dart';
import 'package:linkso_client/src/core/sharing/file_share.dart';
import 'package:linkso_client/src/features/shorten/data/created_link.dart';
import 'package:linkso_client/src/features/shorten/presentation/linkso_qr_code.dart';
import 'package:material_ui/material_ui.dart';

typedef CopyTextCallback = Future<void> Function(String value);

class const CreatedLinkCard({
  required final CreatedLink link,
  required final VoidCallback onCreateAnother,
  final CopyTextCallback? copyText,
  final ShareFileCallback? shareFile,
  super.key,
}) extends StatefulWidget {
  @override
  State<CreatedLinkCard> createState() => _CreatedLinkCardState();
}

class _CreatedLinkCardState() extends State<CreatedLinkCard> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final shortUrl = widget.link.shortUrl.toString();

    return Card(
      key: const ValueKey<String>('created-link-result'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.localizations.resultTitle, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            Text(context.localizations.shortUrlLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(
              shortUrl,
              key: const ValueKey<String>('short-url-value'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Center(
              child: Semantics(
                image: true,
                label: context.localizations.qrCodeLabel,
                child: RepaintBoundary(
                  key: _qrKey,
                  child: LinkSoQrCode(data: shortUrl),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const ValueKey<String>('copy-link-button'),
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(context.localizations.copyLinkAction),
                ),
                Builder(
                  builder: (buttonContext) => OutlinedButton.icon(
                    key: const ValueKey<String>('download-qr-button'),
                    onPressed: _isDownloading ? null : () => _downloadQrCode(buttonContext),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(context.localizations.downloadQrAction),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('create-another-button'),
                  onPressed: widget.onCreateAnother,
                  icon: const Icon(Icons.add_link_rounded),
                  label: Text(context.localizations.createAnotherAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLink() async {
    try {
      await (widget.copyText ?? copyText)(widget.link.shortUrl.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.localizations.linkCopied)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.localizations.unexpectedError)));
      }
    }
  }

  Future<void> _downloadQrCode(BuildContext buttonContext) async {
    setState(() => _isDownloading = true);
    try {
      final box = buttonContext.findRenderObject()! as RenderBox;
      final Rect sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      final boundary = _qrKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('QR image encoding returned no data');
      }
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await (widget.shareFile ?? shareFileBytes)(
        bytes: bytes,
        fileName: 'linkso-${widget.link.slug}.png',
        mimeType: 'image/png',
        sharePositionOrigin: sharePositionOrigin,
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.localizations.unexpectedError)));
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}
