import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/main.dart';

void main() {
  testWidgets('TpcApp initializes and mounts cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const TpcApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TpcApp), findsOneWidget);
    expect(find.byType(GoogleLogin), findsOneWidget);

    // Test entering demo mode
    session.startDemoMode();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Workspace), findsOneWidget);

    // Test logging out returns to GoogleLogin
    await session.signOut();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(GoogleLogin), findsOneWidget);
  });
}
