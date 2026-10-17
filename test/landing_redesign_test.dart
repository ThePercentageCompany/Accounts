import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/auth/presentation/landing_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final dark in [false, true]) {
    for (final width in [320.0, 1440.0]) {
      testWidgets('editorial landing fits $width dark=$dark and routes sign in',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var admin = 0, employee = 0;
        final boundary = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                    body: LandingView(
                        busy: false,
                        onSignIn: () => admin++,
                        onEmployeeLogin: () => employee++,
                        onFaq: () {})))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Admin sign in'));
        await tester.tap(find.text('Employee sign in'));
        expect(admin, 1);
        expect(employee, 1);
        if (!dark && width == 1440) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/design-preview/landing.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
