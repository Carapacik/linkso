import 'package:flutter_test/flutter_test.dart';
import 'package:linkso_client/src/features/shorten/presentation/linkso_qr_code.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('renders and updates the custom QR painter', (tester) async {
    const firstUrl = 'https://linkso.su/first-link';
    const secondUrl = 'https://linkso.su/second-link';

    await tester.pumpWidget(const MaterialApp(home: LinkSoQrCode(data: firstUrl)));

    expect(find.byType(LinkSoQrCode), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('linkso-qr-painter')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(home: LinkSoQrCode(data: secondUrl)));

    expect(tester.widget<LinkSoQrCode>(find.byType(LinkSoQrCode)).data, secondUrl);
    expect(tester.takeException(), isNull);
  });
}
