import 'package:flutter/material.dart';

enum CalendarFieldMode { date, month, time, dateTime }

/// Stores API dates as YYYY-MM-DD and times as HH:mm; input uses pickers on
/// desktop and mobile alike.
class CalendarFormField extends StatelessWidget {
  const CalendarFormField({
    super.key,
    required this.controller,
    required this.decoration,
    this.validator,
    this.enabled = true,
    this.optional = false,
    this.mode = CalendarFieldMode.date,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool optional;
  final CalendarFieldMode mode;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    readOnly: true,
    enableInteractiveSelection: false,
    validator: validator,
    onTap: () => pickCalendarValue(context, controller, mode: mode),
    decoration: decoration.copyWith(
      hintText: mode == CalendarFieldMode.time ? 'Select time' : 'Select date',
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (optional)
            IconButton(
              tooltip: 'Clear ${decoration.labelText ?? 'date'}',
              onPressed: enabled ? controller.clear : null,
              icon: const Icon(Icons.clear, size: 18),
            ),
          IconButton(
            tooltip: mode == CalendarFieldMode.time
                ? 'Select time'
                : 'Select date',
            onPressed: enabled
                ? () => pickCalendarValue(context, controller, mode: mode)
                : null,
            icon: Icon(
              mode == CalendarFieldMode.time
                  ? Icons.schedule_outlined
                  : Icons.calendar_today_outlined,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> pickCalendarValue(
  BuildContext context,
  TextEditingController controller, {
  CalendarFieldMode mode = CalendarFieldMode.date,
}) async {
  final parsed = DateTime.tryParse(
    mode == CalendarFieldMode.month ? '${controller.text}-01' : controller.text,
  );
  final now = DateTime.now();
  final initial = parsed ?? now;
  if (mode == CalendarFieldMode.month) {
    var year = initial.year.clamp(1900, 2200);
    final month = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Select month'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous year',
                      onPressed: year > 1900
                          ? () => update(() => year--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(child: Center(child: Text('$year'))),
                    IconButton(
                      tooltip: 'Next year',
                      onPressed: year < 2200
                          ? () => update(() => year++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var m = 1; m <= 12; m++)
                      SizedBox(
                        width: 88,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, DateTime(year, m)),
                          child: Text(
                            const [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                              'Jul',
                              'Aug',
                              'Sep',
                              'Oct',
                              'Nov',
                              'Dec',
                            ][m - 1],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (month != null && context.mounted) {
      controller.text = month.toIso8601String().substring(0, 7);
    }
    return;
  }
  DateTime? date;
  if (mode != CalendarFieldMode.time) {
    final first = DateTime(1900), last = DateTime(2200, 12, 31);
    date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(last)
          ? last
          : initial,
      firstDate: first,
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (date == null || !context.mounted) return;
  }
  if (mode == CalendarFieldMode.date) {
    controller.text = date!.toIso8601String().substring(0, 10);
    return;
  }
  final parts = controller.text.split(':');
  final hour = int.tryParse(parts.first) ?? initial.hour;
  final minute = parts.length > 1
      ? int.tryParse(parts[1]) ?? initial.minute
      : initial.minute;
  final time = await showTimePicker(
    context: context,
    initialTime: mode == CalendarFieldMode.dateTime
        ? TimeOfDay.fromDateTime(initial)
        : TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59)),
    initialEntryMode: TimePickerEntryMode.dialOnly,
  );
  if (time == null || !context.mounted) return;
  final text =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  controller.text = mode == CalendarFieldMode.time
      ? text
      : '${date!.toIso8601String().substring(0, 10)}T$text';
}
