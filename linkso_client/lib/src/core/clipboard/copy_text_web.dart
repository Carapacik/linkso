import 'package:web/web.dart' as web;

Future<void> copyTextImpl(String value) async {
  final textArea = web.HTMLTextAreaElement()
    ..value = value
    ..readOnly = true;
  textArea.style
    ..setProperty('position', 'fixed')
    ..setProperty('inset', '0 auto auto 0')
    ..setProperty('width', '1px')
    ..setProperty('height', '1px')
    ..setProperty('opacity', '0')
    ..setProperty('pointer-events', 'none');

  final web.HTMLElement? body = web.document.body;
  if (body == null) {
    throw StateError('The document body is unavailable');
  }

  body.append(textArea);
  textArea
    ..focus()
    ..select()
    ..setSelectionRange(0, value.length);
  final bool copied = web.document.execCommand('copy');
  textArea.remove();
  if (!copied) {
    throw StateError('The browser rejected the clipboard operation');
  }
}
