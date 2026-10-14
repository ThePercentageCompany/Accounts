import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/features/auth/presentation/admin_login_dialog.dart';
import 'package:tpc_invoice/features/auth/presentation/landing_view.dart';

class PendingLoginApi extends SaasApi {
  PendingLoginApi() : super(origin: 'https://api.test');
  final pending = Completer<void>();
  int calls = 0;
  @override
  Future<void> signInWithPassword(String email, String password) {
    calls++;
    return pending.future;
  }
}

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('login layout fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: LandingView(
                  busy: false,
                  onSignIn: () {},
                  onFaq: () {},
                  onEmployeeLogin: () {}))));
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Employee sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'sign-in button shows progress and prevents duplicate submissions',
      (tester) async {
    final api = PendingLoginApi();
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => AdminLoginDialog(api: api)),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'admin@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    final button = find.byKey(const Key('admin-sign-in-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(api.calls, 1);
    expect(
        find.descendant(
            of: button, matching: find.byType(AppActivityIndicator)),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.descendant(
                of: button, matching: find.byType(FilledButton)))
            .onPressed,
        isNull);
    await tester.tap(button);
    await tester.pump();
    expect(api.calls, 1);
    api.pending.completeError(
        const SaasApiException('NETWORK', 'Retry when connected.'));
    await tester.pumpAndSettle();
    expect(find.text('Retry when connected.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.descendant(
                of: button, matching: find.byType(FilledButton)))
            .onPressed,
        isNotNull);
  });
}
