import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/saas/payroll_editor.dart';

void main() {
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
    await tester.enterText(fields.at(0), '2026-09');
    await tester.enterText(fields.at(1), '250');
    await tester.enterText(fields.at(2), '100');
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
    await tester.enterText(find.byType(TextFormField).last, 'WPS');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(result?['paymentAccount'], 'Bank');
    expect(result?['paymentReference'], 'WPS');
    expect(result?.containsKey('netSalary'), isFalse);
  });
}
