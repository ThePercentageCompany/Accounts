import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('stable independent loading and recovery at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final request = Completer<void>();
      var calls = 0;
      var otherCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LoadingButton.icon(
                    key: const Key('save'),
                    onPressed: () {
                      calls++;
                      return request.future;
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save invoice'),
                  ),
                  LoadingButton(
                    key: const Key('other'),
                    onPressed: () {
                      otherCalls++;
                    },
                    child: const Text('Other'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final button = find.descendant(
        of: find.byKey(const Key('save')),
        matching: find.byType(FilledButton),
      );
      final before = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      expect(tester.getRect(button), before);
      expect(
        tester.getCenter(find.byType(AppActivityIndicator)),
        before.center,
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(button);
      await tester.tap(find.byKey(const Key('other')));
      await tester.pump();
      expect(calls, 1);
      expect(otherCalls, 1);
      request.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(AppActivityIndicator), findsNothing);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(
        find.text('The action could not be completed. Please try again.'),
        findsOneWidget,
      );
      expect(tester.getRect(button), before);
    });
  }
  testWidgets('container centering and reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: SizedBox(width: 300, height: 200, child: CenteredLoading()),
          ),
        ),
      ),
    );
    expect(
      tester.getCenter(find.byType(AppActivityIndicator)),
      tester.getCenter(find.byType(CenteredLoading)),
    );
    expect(
      tester
          .widget<CupertinoActivityIndicator>(
            find.byType(CupertinoActivityIndicator),
          )
          .animating,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard activation retains an accessible busy label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final gate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingButton(
            onPressed: () {
              calls++;
              return gate.future;
            },
            child: const Text('Submit'),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(AppActivityIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Submit'), findsOneWidget);
    expect(tester.getSemantics(find.byType(LoadingButton)).value, 'Busy');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AppActivityIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    semantics.dispose();
  });
  testWidgets('icon action preserves size and restores after cancellation', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LoadingButton.iconOnly(
              tooltip: 'Refresh',
              onPressed: () => gate.future,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(IconButton);
    final before = tester.getRect(button);
    await tester.tap(button);
    await tester.pump();
    expect(tester.getRect(button), before);
    expect(tester.getCenter(find.byType(AppActivityIndicator)), before.center);
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
    expect(find.byType(AppActivityIndicator), findsNothing);
  });
}
