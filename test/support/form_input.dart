import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seed imported/invalid date fixtures directly. User picker interactions are
/// covered separately in date_time_field_test; text inputs use the keyboard.
Future<void> fillFormField(
  WidgetTester tester,
  Finder field,
  String value,
) async {
  final input = tester.widget<TextFormField>(field);
  final text = tester.widget<TextField>(
    find.descendant(of: field, matching: find.byType(TextField)).first,
  );
  if (text.readOnly) {
    input.controller!.text = value;
    await tester.pump();
  } else {
    await tester.enterText(field, value);
  }
}
