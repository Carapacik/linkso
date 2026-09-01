import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

typedef ShareFileCallback = Future<void> Function({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required Rect sharePositionOrigin,
});

Future<void> shareFileBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required Rect sharePositionOrigin,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}
