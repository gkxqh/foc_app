import 'package:flutter_test/flutter_test.dart';
import 'package:foc_app/main.dart';

void main() {
  testWidgets('FeiyangApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FeiyangApp());
    // Drain microtasks and frame callbacks
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FeiyangApp), findsOneWidget);
  });
}
