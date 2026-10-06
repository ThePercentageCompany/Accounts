import 'support/form_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/employees/presentation/payroll_editor.dart';

void main() {
  testWidgets(
    'payroll preview uses endpoint totals and invalidates after adjustment changes',
    (tester) async {
      Map<String, Object?>? submitted;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async =>
                    submitted = await showDialog<Map<String, Object?>>(
                      context: context,
                      builder: (_) => PayrollEditor(
                        employees: [
                          {
                            'recordId': 'e' * 43,
                            'fullName': 'Employee',
                            'basicSalary': 5000,
                            'allowances': 500,
                          },
                        ],
                        record: {
                          'employeeId': 'e' * 43,
                          'month': '2026-09',
                          'bonus': 0,
                          'deductions': 0,
                        },
                        preview: (values) async {
                          calls++;
                          expect(values.containsKey('netSalary'), isFalse);
                          return {
                            'totals': {
                              'basicSalary': 5000,
                              'allowances': 500,
                              'overtimeAmount': 100,
                              'bonus': values['bonus'],
                              'deductions': 0,
                              'grossSalary': 5600,
                              'netSalary': 5600,
                            },
                          };
                        },
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      expect(find.text('Net salary: 5600.00'), findsOneWidget);
      final bonus = find.ancestor(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Bonus',
        ),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(bonus);
      await tester.enterText(bonus, '250');
      await tester.pumpAndSettle();
      expect(find.text('Payroll preview'), findsNothing);
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(submitted, isNull);
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(submitted?['bonus'], 250);
      expect(submitted?.containsKey('netSalary'), isFalse);
    },
  );
  testWidgets('payroll draft submits only employee month and adjustments', (
    tester,
  ) async {
    Map<String, Object?>? result;
    final employees = [
      {'recordId': 'e' * 43, 'fullName': 'Employee'},
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showDialog<Map<String, Object?>>(
                    context: context,
                    builder: (_) => PayrollEditor(employees: employees),
                  ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an employee.'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Employee').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await fillFormField(tester, fields.at(0), '2026-09');
    await fillFormField(tester, fields.at(1), '250');
    await fillFormField(tester, fields.at(2), '100');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(result?['employeeId'], 'e' * 43);
    expect(result?['bonus'], 250.0);
    expect(result?.containsKey('grossSalary'), isFalse);
    expect(result?.containsKey('status'), isFalse);
  });

  testWidgets('payroll payment submits date account and reference', (
    tester,
  ) async {
    Map<String, Object?>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showDialog<Map<String, Object?>>(
                    context: context,
                    builder: (_) => const PayrollPaymentEditor(amount: 5650),
                  ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await fillFormField(tester, find.byType(TextFormField).last, 'WPS');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(result?['paymentAccount'], 'Bank');
    expect(result?['paymentReference'], 'WPS');
    expect(result?.containsKey('netSalary'), isFalse);
  });
}
