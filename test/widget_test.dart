import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/main.dart';

void main() {
  testWidgets('TpcApp initializes and mounts cleanly into GoogleLogin', (WidgetTester tester) async {
    await tester.pumpWidget(const TpcApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TpcApp), findsOneWidget);
    expect(find.byType(GoogleLogin), findsOneWidget);
  });
}
