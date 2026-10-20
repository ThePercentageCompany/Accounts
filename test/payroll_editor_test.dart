import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/features/employees/presentation/payroll_editor.dart';

void main() {
  testWidgets('selection loads salary and ignores a previous employee response',
      (tester) async {
    final first = Completer<Map<String, dynamic>>();
    final second = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(MaterialApp(
      home: PayrollEditor(
        employees: const [
          {'recordId': 'a', 'fullName': 'First', 'currency': 'AED'},
          {'recordId': 'b', 'fullName': 'Second', 'currency': 'AED'},
        ],
        preview: (values) =>
            values['employeeId'] == 'a' ? first.future : second.future,
      ),
    ));
    await tester.pump();
    tester
        .widget<SearchableRecordField>(find.byType(SearchableRecordField))
        .onChanged!('a');
    await tester.pump();
    expect(find.textContaining('Not set'), findsNothing);
    tester
        .widget<SearchableRecordField>(find.byType(SearchableRecordField))
        .onChanged!('b');
    second.complete({
      'totals': {'basicSalary': 4200, 'allowances': 850}
    });
    await tester.pump();
    expect(find.text('Monthly basic salary: AED 4200.00'), findsOneWidget);
    expect(find.text('Monthly allowances: AED 850.00'), findsOneWidget);
    first.complete({
      'totals': {'basicSalary': 1000, 'allowances': 100}
    });
    await tester.pump();
    expect(find.text('Monthly basic salary: AED 4200.00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
