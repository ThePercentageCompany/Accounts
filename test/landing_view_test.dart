import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/auth/presentation/landing_view.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('landing adapts at $width and preserves actions',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var signIn = 0, help = 0, employee = 0;
      final capture = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RepaintBoundary(
                  key: capture,
                  child: LandingView(
                      busy: false,
                      onSignIn: () => signIn++,
                      onFaq: () => help++,
                      onEmployeeLogin: () => employee++)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Get started with Google'));
      expect(signIn, 1);
      await tester.tap(find.text('Getting started'));
      expect(help, 1);
      await tester.tap(find.text('Employee login').first);
      expect(employee, 1);
      if (width == 1440 || width == 390) {
        await tester.runAsync(() async {
          final image = await (capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.dart_tool/landing-$width.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -2600));
      await tester.pumpAndSettle();
      if (width == 1440 || width == 390) {
        await tester.runAsync(() async {
          final image = await (capture.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.dart_tool/landing-lower-$width.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('busy landing disables sign-in and shows errors', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LandingView(
                busy: true,
                error: 'Connection failed',
                onSignIn: () => fail('busy sign in'),
                onFaq: () {},
                onEmployeeLogin: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Connection failed'), findsOneWidget);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
}
