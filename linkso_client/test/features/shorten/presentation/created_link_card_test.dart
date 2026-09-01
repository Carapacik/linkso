import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/features/shorten/data/created_link.dart';
import 'package:linkso_client/src/features/shorten/domain/link_kind.dart';
import 'package:linkso_client/src/features/shorten/presentation/created_link_card.dart';
import 'package:linkso_client/src/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('copies the exact short URL and confirms the action', (tester) async {
    String? copiedValue;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        home: Scaffold(
          body: CreatedLinkCard(
            link: CreatedLink(
              id: '01991a6c-b267-7a11-9b26-9cdd65e44071',
              slug: 'team-link',
              shortUrl: Uri.parse('https://linkso.su/team-link'),
              targetUrl: Uri.parse('https://example.com'),
              kind: LinkKind.direct,
            ),
            onCreateAnother: () {},
            copyText: (value) async => copiedValue = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('copy-link-button')), findsOneWidget);
    final Finder shortUrl = find.byKey(const ValueKey<String>('short-url-value'));
    expect(tester.widget<SelectableText>(shortUrl).data, 'https://linkso.su/team-link');
    expect(copiedValue, isNull);

    final Finder copyButton = find.byKey(const ValueKey<String>('copy-link-button'));
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();

    expect(copiedValue, 'https://linkso.su/team-link');
    expect(find.text('Link copied'), findsOneWidget);
  });
}
