import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traders/main.dart';

void main() {
  testWidgets('SaravanasApp renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SaravanasApp(),
      ),
    );

    // Verify Saravanas branding is rendered
    expect(find.text('SARAVANAS'), findsOneWidget);
    expect(find.text('People. Work. Management.'), findsOneWidget);
  });
}
