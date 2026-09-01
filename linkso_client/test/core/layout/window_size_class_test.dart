import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/core/layout/window_size_class.dart';

void main() {
  test('uses the Material 3 window size class boundaries', () {
    expect(WindowSizeClass.fromWidth(599), WindowSizeClass.compact);
    expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
    expect(WindowSizeClass.fromWidth(839), WindowSizeClass.medium);
    expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
    expect(WindowSizeClass.fromWidth(1199), WindowSizeClass.expanded);
    expect(WindowSizeClass.fromWidth(1200), WindowSizeClass.large);
    expect(WindowSizeClass.fromWidth(1599), WindowSizeClass.large);
    expect(WindowSizeClass.fromWidth(1600), WindowSizeClass.extraLarge);
    expect(WindowSizeClass.expanded.showsNavigationLabels, isFalse);
    expect(WindowSizeClass.large.showsNavigationLabels, isTrue);
  });
}
