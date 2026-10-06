import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/core/widgets/forms/payment_method_dropdown.dart';

void main() {
  testWidgets(
      'submit focuses the first invalid field and does not validate on focus alone',
      (tester) async {
    final form = GlobalKey<FormState>();
    final first = FocusNode(), second = FocusNode();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
                key: form,
                child: Column(children: [
                  ValidatedTextField(
                      required: true,
                      focusNode: first,
                      decoration: const InputDecoration(labelText: 'First')),
                  ValidatedTextField(
                      required: true,
                      focusNode: second,
                      decoration: const InputDecoration(labelText: 'Second')),
                ])))));
    second.requestFocus();
    await tester.pump();
    expect(find.text('This field is required.'), findsNothing);
    expect(AppFormValidation.validate(form.currentState!), isFalse);
    await tester.pumpAndSettle();
    expect(first.hasFocus, isTrue);
    expect(find.text('This field is required.'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    second.dispose();
  });
  test(
      'type-specific validators preserve legitimate text and reject malformed values',
      () {
    for (final email in [
      ' user+tag@example.co.uk ',
      'o\'hara@example.com',
      '用户@example.com'
    ]) {
      expect(AppValidators.email(email), isNull);
    }
    for (final email in [
      'a@',
      'a@@example.com',
      'name example.com',
      'a b@example.com'
    ]) {
      expect(AppValidators.email(email), isNotNull);
    }
    for (final phone in [
      '+971 50 123 4567',
      '0501234567',
      '+44 (20) 7946-0958'
    ]) {
      expect(AppValidators.phone(phone), isNull);
    }
    expect(AppValidators.phone('12abc'), isNotNull);
    expect(AppValidators.phone('++971501234567'), isNotNull);
    expect(AppValidators.phone(''), isNull);
    expect(AppValidators.name("  O'Connor & Sons – شركة  "), isNull);
    expect(AppValidators.name(' '), isNotNull);
    expect(AppValidators.name('A\u0000B'), isNotNull);
    expect(AppValidators.text('Notes\nAddress, floor #2\tGate A'), isNull);
    expect(AppValidators.reference('SKU-USB-C-45W'), isNull);
    expect(AppValidators.reference('INV-2026-00125'), isNull);
    for (final number in ['100', '100.50', '0.75']) {
      expect(AppValidators.money(number), isNull);
    }
    for (final number in [
      '10..50',
      '12abc',
      '@500',
      'NaN',
      'Infinity',
      '1e3',
      '1.234'
    ]) {
      expect(AppValidators.money(number), isNotNull);
    }
    expect(AppValidators.integer('1.5'), isNotNull);
    expect(AppValidators.integer('12345'), isNull);
    expect(AppValidators.percentage('100'), isNull);
    expect(AppValidators.percentage('100.01'), isNotNull);
    expect(AppValidators.percentage('-1'), isNotNull);
    expect(AppValidators.money('-0.75', min: -100), isNull);
  });
  test(
      'formatters preserve caret and reject malformed decimal paste atomically',
      () {
    const old = TextEditingValue(
        text: '12.5', selection: TextSelection.collapsed(offset: 2));
    for (final text in ['10..50', '12abc', '@500', '12.555']) {
      expect(
          AppInputFormatters.money
              .formatEditUpdate(old, TextEditingValue(text: text)),
          old);
    }
    const typing = TextEditingValue(
        text: '12.', selection: TextSelection.collapsed(offset: 3));
    expect(AppInputFormatters.money.formatEditUpdate(old, typing), typing);
    expect(AppValidators.money(typing.text), isNotNull);
    expect(
        AppInputFormatters.integerOnly
            .formatEditUpdate(
                TextEditingValue.empty, const TextEditingValue(text: '12abc'))
            .text,
        '12');
    expect(
        AppInputFormatters.phone
            .formatEditUpdate(TextEditingValue.empty,
                const TextEditingValue(text: '+971 50 123 4567'))
            .text,
        '+971 50 123 4567');
    final composing =
        old.copyWith(text: 'あ', composing: const TextRange(start: 0, end: 1));
    expect(
        AppInputFormatters.money.formatEditUpdate(old, composing), composing);
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets(
        'payment dropdown and inline validation at $width with large text',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final form = GlobalKey<FormState>();
      String? selected;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 1000),
                  textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Form(
                          key: form,
                          child: Column(children: [
                            PaymentMethodDropdown(
                                onChanged: (v) => selected = v),
                            const ValidatedTextField(
                                kind: AppInputKind.email,
                                decoration:
                                    InputDecoration(labelText: 'Email')),
                          ])))))));
      expect(find.text('Select payment method'), findsOneWidget);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bank').last);
      await tester.pumpAndSettle();
      expect(selected, 'Bank');
      expect(form.currentState!.validate(), isTrue);
      await tester.enterText(find.byType(TextFormField), 'wrong@');
      await tester.pump();
      expect(form.currentState!.validate(), isFalse);
      expect(find.text('Invalid email address'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'unknown legacy account displays without assertion and needs explicit correction',
      (tester) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
                key: form,
                child: PaymentMethodDropdown(
                    value: 'Legacy wallet', onChanged: (_) {})))));
    expect(find.text('Legacy wallet (legacy)'), findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
                key: form,
                child: PaymentMethodDropdown(
                    value: 'Legacy wallet',
                    allowLegacyValue: true,
                    onChanged: (_) {})))));
    expect(form.currentState!.validate(), isTrue);
  });
}
