import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/features/shorten/presentation/link_kind_selector.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(412, 915),
    const Size(800, 1280),
    const Size(1280, 800),
    const Size(640, 360),
  ]) {
    for (final scale in [1.0, 2.0, 3.2]) {
      for (final language in ['en', 'ru']) {
        testWidgets('Native layout $size, text $scale, $language', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final api = LinkSoApiClient(
            baseUri: Uri.parse('http://localhost/'),
            client: MockClient((_) async => http.Response('{}', 401)),
          );
          addTearDown(api.close);
          for (final route in ['/', '/app/shorten', '/app/auth/register']) {
            await tester.pumpWidget(
              LinkSoApp(key: UniqueKey(), apiClient: api, locale: Locale(language), initialLocation: route),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$route at $size / $scale / $language');
            if (route == '/') {
              final RenderParagraph title = tester.renderObject(find.byKey(const ValueKey<String>('home-title')));
              final String plainText = title.text.toPlainText();
              for (final RegExpMatch word in RegExp(r'\S+').allMatches(plainText)) {
                expect(
                  title.getBoxesForSelection(TextSelection(baseOffset: word.start, extentOffset: word.end)),
                  hasLength(1),
                  reason: 'A home-title word must not split internally at $size / $scale / $language',
                );
              }
            }
            if (route == '/app/shorten') {
              final Finder finder = find.byType(LinkKindSelector);
              await tester.ensureVisible(finder);
              await tester.pumpAndSettle();
              for (final Element element in find.descendant(of: finder, matching: find.byType(RichText)).evaluate()) {
                final paragraph = element.renderObject! as RenderParagraph;
                expect(paragraph.didExceedMaxLines, isFalse);
                expect(
                  paragraph.getBoxesForSelection(
                    TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length),
                  ),
                  hasLength(1),
                  reason: 'A mode label must not split within words',
                );
              }
              final Finder field = find.byKey(const ValueKey<String>('target-url-field'));
              await tester.ensureVisible(field);
              await tester.tap(field);
              tester.view.viewInsets = FakeViewPadding(bottom: size.height * .4);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: 'Keyboard layout');
              tester.view.resetViewInsets();
            }
          }
        });
      }
    }
  }
}
