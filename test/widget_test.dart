import 'package:flutter_test/flutter_test.dart';

import 'package:paw_pal/main.dart';

void main() {
  testWidgets('PawPal app loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PawPalApp());

    expect(find.text('PawPal'), findsOneWidget);
    expect(find.text('Welcome to PawPal'), findsOneWidget);
  });
}
