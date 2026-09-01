import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:linkso_client/src/features/shorten/data/created_link.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';
import 'package:linkso_client/src/features/shorten/presentation/created_link_card.dart';
import 'package:linkso_client/src/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final size in [const Size(744, 1133), const Size(1133, 744)]) {
    testWidgets('QR sharing is anchored to its button at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final shared = Completer<Rect>();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: Scaffold(
            body: SingleChildScrollView(
              child: CreatedLinkCard(
                link: CreatedLink(
                  id: 'qr-share-test',
                  slug: 'team-link',
                  shortUrl: Uri.parse('http://localhost:8088/team-link'),
                  targetUrl: Uri.parse('http://example.com'),
                  kind: LinkKind.direct,
                ),
                onCreateAnother: () {},
                shareFile:
                    ({required bytes, required fileName, required mimeType, required sharePositionOrigin}) async {
                      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
                      expect(fileName, 'linkso-team-link.png');
                      expect(mimeType, 'image/png');
                      shared.complete(sharePositionOrigin);
                    },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder button = find.byKey(const ValueKey<String>('download-qr-button'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final Rect expectedOrigin = tester.getRect(button);
      await tester.runAsync(() async {
        tester.widget<OutlinedButton>(button).onPressed!();
        expect(await shared.future.timeout(const Duration(seconds: 5)), expectedOrigin);
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    });
  }
}
