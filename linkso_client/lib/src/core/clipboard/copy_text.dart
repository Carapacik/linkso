import 'package:linkso_client/src/core/clipboard/copy_text_native.dart'
    if (dart.library.js_interop) 'package:linkso_client/src/core/clipboard/copy_text_web.dart';

Future<void> copyText(String value) => copyTextImpl(value);
