import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/widgets/forms/currency_fields.dart';

void main() {
  testWidgets('currency dropdown selection fetches the selected rate',
      (tester) async {
    final draft = CurrencyDraft(record: {'currency': 'AED', 'exchangeRate': 1});
    final date = TextEditingController(text: '2026-10-01');
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CurrencyFields(
      draft: draft,
      transactionDate: date,
      loadRate: (currency, day) async {
        calls.add(currency);
        return {
          'currency': currency,
          'baseCurrency': 'AED',
          'exchangeRate': 0.04,
          'rateDate': day,
          'rateSource': 'FRANKFURTER'
        };
      },
    ))));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INR — Indian Rupee').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(calls, ['INR']);
    expect(draft.currency.text, 'INR');
    expect(draft.values['exchangeRate'], 0.04);
    await tester.pumpWidget(const SizedBox());
    draft.dispose();
    date.dispose();
  });

  testWidgets('saved rate remains unchanged when reopening a transaction',
      (tester) async {
    final draft = CurrencyDraft(record: {
      'currency': 'GBP',
      'baseCurrency': 'AED',
      'exchangeRate': 4.65,
      'rateDate': '2026-10-01',
      'rateSource': 'MANUAL',
    });
    final date = TextEditingController(text: '2026-10-01');
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CurrencyFields(
      draft: draft,
      transactionDate: date,
      loadRate: (_, __) async {
        calls++;
        throw StateError('Saved rates must not be fetched again');
      },
    ))));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(draft.values['exchangeRate'], 4.65);
    expect(draft.values['rateSource'], 'MANUAL');
    await tester.pumpWidget(const SizedBox());
    draft.dispose();
    date.dispose();
  });

  testWidgets('provider outage allows a validated manual rate', (tester) async {
    final draft = CurrencyDraft(record: {'currency': 'INR'});
    final date = TextEditingController(text: '2026-10-01');
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
      key: form,
      child: CurrencyFields(
        draft: draft,
        transactionDate: date,
        loadRate: (_, __) async => throw StateError('Provider unavailable'),
      ),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Automatic rate unavailable. Enter your rate manually.'),
        findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Exchange rate'), '0.04');
    expect(form.currentState!.validate(), isTrue);
    expect(draft.values['exchangeRate'], 0.04);
    expect(draft.values['rateSource'], 'MANUAL');
    expect(draft.values['rateDate'], '2026-10-01');
    await tester.pumpWidget(const SizedBox());
    draft.dispose();
    date.dispose();
  });

  testWidgets('automatic rate can be overridden and refreshes for a new date',
      (tester) async {
    final draft = CurrencyDraft(record: {'currency': 'GBP'});
    final date = TextEditingController(text: '2026-10-01');
    final calls = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
                child: CurrencyFields(
      draft: draft,
      transactionDate: date,
      loadRate: (currency, day) async {
        calls.add('$currency:$day');
        return {
          'currency': currency,
          'baseCurrency': 'AED',
          'exchangeRate': 4.7,
          'rateDate': day,
          'rateSource': 'FRANKFURTER'
        };
      },
    )))));
    await tester.pumpAndSettle();
    expect(draft.rate.text, '4.70000000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Exchange rate'), '4.65');
    expect(draft.values['exchangeRate'], 4.65);
    expect(draft.values['rateSource'], 'MANUAL');
    date.text = '2026-10-02';
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(calls.last, 'GBP:2026-10-02');
    expect(draft.rate.text, '4.70000000');
    await tester.pumpWidget(const SizedBox());
    draft.dispose();
    date.dispose();
  });

  testWidgets('late automatic response cannot overwrite a manual rate',
      (tester) async {
    final response = Completer<Map<String, dynamic>>();
    final draft = CurrencyDraft(record: {'currency': 'INR'});
    final date = TextEditingController(text: '2026-10-01');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CurrencyFields(
      draft: draft,
      transactionDate: date,
      loadRate: (_, __) => response.future,
    ))));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Exchange rate'), '0.04');
    response.complete({
      'currency': 'INR',
      'baseCurrency': 'AED',
      'exchangeRate': 0.038,
      'rateDate': '2026-10-01',
      'rateSource': 'FRANKFURTER'
    });
    await tester.pumpAndSettle();
    expect(draft.rate.text, '0.04');
    expect(draft.source, 'MANUAL');
    await tester.pumpWidget(const SizedBox());
    draft.dispose();
    date.dispose();
  });
}
