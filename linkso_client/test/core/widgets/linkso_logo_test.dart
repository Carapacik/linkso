import 'dart:ui' show PathMetric;

import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/core/theme/app_theme.dart';
import 'package:linkso_client/src/core/widgets/linkso_logo.dart';
import 'package:linkso_client/src/core/widgets/linkso_logo_paths.g.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('the SVG has two nonempty closed contours', () {
    final List<Path> paths = createLinkSoLogoPaths();
    expect(paths, hasLength(2));
    for (final path in paths) {
      final List<PathMetric> metrics = path.computeMetrics().toList();
      expect(metrics, hasLength(1));
      expect(metrics.single.isClosed, isTrue);
      expect(metrics.single.length, greaterThan(0));
    }
  });

  testWidgets('paints a sized vector logo and repaints when the theme changes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: createLightTheme(),
        home: const Center(child: LinkSoLogo(size: 40)),
      ),
    );
    await tester.pumpAndSettle();
    final Finder paintFinder = find.descendant(of: find.byType(LinkSoLogo), matching: find.byType(CustomPaint));
    final CustomPainter lightPainter = tester.widget<CustomPaint>(paintFinder).painter!;
    expect(tester.getSize(paintFinder), const Size(40, 40));

    await tester.pumpWidget(
      MaterialApp(
        theme: createDarkTheme(),
        home: const Center(child: LinkSoLogo(size: 40)),
      ),
    );
    await tester.pumpAndSettle();
    final CustomPainter darkPainter = tester.widget<CustomPaint>(paintFinder).painter!;
    expect(darkPainter.shouldRepaint(lightPainter), isTrue);
    expect(darkPainter.shouldRepaint(darkPainter), isFalse);
    expect(tester.takeException(), isNull);
  });
}
