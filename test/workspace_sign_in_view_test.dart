import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/workspace_sign_in_view.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';

void main() {
  for (final width in [375.0, 1200.0]) {
    testWidgets('sign-in stays usable at width $width with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = GoogleSession();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: WorkspaceSignInView(session: session),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final employee = find.text('Employee Login');
      await tester.ensureVisible(employee);
      await tester.tap(employee);
      await tester.pump();
      expect(session.employeeLoginRequested, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
}
