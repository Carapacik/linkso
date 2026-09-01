import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/app/app_router.dart';
import 'package:linkso_client/src/app/linkso_app.dart';
import 'package:linkso_client/src/core/widgets/linkso_logo.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('opens the creation form from the home page', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LinkSoApp(locale: Locale('en')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('home-page')), findsOneWidget);
    expect(find.text('Short links that work by your rules'), findsOneWidget);
    expect(find.byType(LinkSoLogo), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey<String>('home-create-link-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('shorten-page')), findsOneWidget);
  });

  testWidgets('opens the home page when the logo is pressed', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LinkSoApp(locale: Locale('en'), initialLocation: expiredPath));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home-logo-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('home-page')), findsOneWidget);
  });
}
