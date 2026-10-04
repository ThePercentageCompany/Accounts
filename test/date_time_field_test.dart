import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/widgets/forms/date_time_field.dart';

void main() {
  for (final size in [const Size(390, 740), const Size(1366, 900)]) {
    testWidgets('calendar input selects dates without a keyboard at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: '2026-10-04');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarFormField(
              controller: controller,
              optional: true,
              decoration: const InputDecoration(labelText: 'Due date'),
            ),
          ),
        ),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.tap(find.text('2026-10-04'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.initialEntryMode, DatePickerEntryMode.calendarOnly);
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(controller.text, '2026-10-15');
      await tester.tap(find.byTooltip('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.text, '2026-10-15');
      await tester.tap(find.byTooltip('Clear Due date'));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('month picker uses calendar selection and preserves YYYY-MM', (
    tester,
  ) async {
    final controller = TextEditingController(text: '2026-09');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarFormField(
            controller: controller,
            mode: CalendarFieldMode.month,
            decoration: const InputDecoration(labelText: 'Payroll month'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feb'));
    await tester.pumpAndSettle();
    expect(controller.text, '2027-02');
  });
  testWidgets(
    'clock picker stores 24-hour times and cancellation preserves input',
    (tester) async {
      final controller = TextEditingController(text: '15:30');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarFormField(
              controller: controller,
              mode: CalendarFieldMode.time,
              decoration: const InputDecoration(labelText: 'Start time'),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Select time'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<TimePickerDialog>(
        find.byType(TimePickerDialog),
      );
      expect(dialog.initialEntryMode, TimePickerEntryMode.dialOnly);
      expect(dialog.initialTime, const TimeOfDay(hour: 15, minute: 30));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(controller.text, '15:30');
      await tester.tap(find.byTooltip('Select time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.text, '15:30');
    },
  );
  testWidgets('out-of-range imported dates open a clamped calendar', (
    tester,
  ) async {
    final controller = TextEditingController(text: '9999-12-31');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Date'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Select date'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate,
      DateTime(2200, 12, 31),
    );
    expect(tester.takeException(), isNull);
  });
}
