import 'package:flutter/services.dart';

Future<void> copyTextImpl(String value) => Clipboard.setData(ClipboardData(text: value));
