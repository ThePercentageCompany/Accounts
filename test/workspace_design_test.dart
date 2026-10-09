import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/reports/presentation/workspace_dashboard.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/core/widgets/appearance_selector.dart';

void main() {
  testWidgets('appearance selection persists dark preference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await themeController.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [AppearanceSelector()])),
      ),
    );
    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(themeController.themeMode, ThemeMode.dark);
    expect(
      (await SharedPreferences.getInstance()).getString('tpc_theme_mode'),
      'dark',
    );
    themeController.setThemeMode(ThemeMode.system);
  });
  for (final dark in [false, true]) {
    for (final width in [360.0, 1440.0]) {
      testWidgets('dashboard fits width $width in dark=$dark', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: WorkspaceDashboard(
                  data: {
                    'totalIncome': '123456.78',
                    'totalExpenses': '900.00',
                    'netProfit': '-123.45',
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('123,456.78'), findsNWidgets(2));
        expect(find.text('-123.45'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
