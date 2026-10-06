// Release-only fixture using production editors; no API calls or credentials.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/customers/presentation/customer_editor.dart';
import 'package:tpc_invoice/features/workspace/presentation/company_profile_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/cash_entry_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/asset_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/capital_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/cash_payment_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/receipt_editor.dart';

int errors = 0;
String scenario = '';
void main() {
  final report = FlutterError.onError;
  FlutterError.onError = (details) {
    errors++;
    debugPrint(
        'FORM PROBE ERROR [$scenario]: ${details.exception}\n${details.stack}');
    report?.call(details);
  };
  runApp(const Probe());
}

class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => ProbeState();
}

class ProbeState extends State<Probe> {
  final root = GlobalKey();
  double width = 320, scale = 1;
  Widget editor = const SizedBox();
  int generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(run());
  }

  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await WidgetsBinding.instance.endOfFrame;
  }

  void visit(void Function(Element) action) {
    void walk(Element element) {
      action(element);
      element.visitChildren(walk);
    }

    final context = root.currentContext;
    if (context != null) walk(context as Element);
  }

  Future<void> run() async {
    try {
      final factories = <String, Widget Function()>{
        'customer create': () => const CustomerEditor(),
        'customer edit': () => const CustomerEditor(record: {
              'name': "O'Connor & Sons – شركة",
              'email': 'accounts+sales@example.com',
              'phone': '+971 50 123 4567',
              'address': 'Dubai, Building #2\nFloor 1'
            }),
        'company edit': () => const CompanyProfileEditor(
            record: {'name': 'Business', 'currency': 'AED'}),
        'expense': () => const CashEntryEditor(expense: true),
        'legacy expense': () => const CashEntryEditor(expense: true, record: {
              'description': 'Imported',
              'paymentStatus': 'UNPAID',
              'account': 'Legacy wallet',
              'date': '2026-10-07',
              'amount': '100.50',
              'taxRate': '5'
            }),
        'asset': () => const AssetEditor(),
        'shareholder': () => const ShareholderEditor(),
        'payment': () => const CashPaymentEditor(total: 100.50),
        'receipt': () => const ReceiptEditor(invoices: []),
      };
      for (final w in [320.0, 740.0, 1366.0]) {
        for (final s in [1.0, 2.0, 3.0]) {
          for (final entry in factories.entries) {
            scenario = '${entry.key} width=$w scale=$s';
            setState(() {
              width = w;
              scale = s;
              editor = entry.value();
              generation++;
            });
            await settle();
            visit((e) {
              if (e is StatefulElement && e.state is FormState) {
                (e.state as FormState).validate();
              }
            });
            await settle();
            visit((e) {
              if (e is StatefulElement && e.state is ScrollableState) {
                final p = (e.state as ScrollableState).position;
                if (!p.viewportDimension.isFinite ||
                    !p.maxScrollExtent.isFinite) {
                  throw StateError('Unbounded viewport in $scenario');
                }
                p.jumpTo(p.maxScrollExtent);
              }
            });
            await settle();
            debugPrint('FORM PROBE CHECKED $scenario');
          }
        }
      }
      web.document.title = 'PROBE COMPLETE errors=$errors';
    } catch (error, stack) {
      debugPrint('FORM PROBE ERROR [$scenario]: $error\n$stack');
      web.document.title = 'PROBE COMPLETE errors=1';
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
                width: width,
                child: MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 900),
                        textScaler: TextScaler.linear(scale)),
                    child: KeyedSubtree(
                        key: root,
                        child: KeyedSubtree(
                            key: ValueKey(generation), child: editor))))),
      ));
}
