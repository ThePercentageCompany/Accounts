import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/main.dart';

void main() {
  testWidgets('TpcApp initializes and mounts cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const TpcApp());
    expect(find.byType(TpcApp), findsOneWidget);
  });
}
