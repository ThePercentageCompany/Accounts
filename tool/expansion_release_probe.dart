// Run with flutter build web --release -t tool/expansion_release_probe.dart.
// This isolated harness uses production widgets and leaves Flutter's error UI
// and reporting intact. It never connects to a workspace or modifies records.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/reports/data/report_format.dart';
import 'package:tpc_invoice/features/reports/presentation/report_trends.dart';
import 'package:tpc_invoice/features/reports/presentation/report_grid.dart';
import 'package:tpc_invoice/features/reports/presentation/financial_report_body.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/workspace/presentation/system_settings_panel.dart';

int errors = 0;
String scenario = '';
void main() {
  final report = FlutterError.onError;
  FlutterError.onError = (details) {
    errors++;
    // Full traces are retained in release builds by this diagnostic entrypoint.
    debugPrint(
      'PROBE ERROR [$scenario]: ${details.exception}\n${details.stack}',
    );
    report?.call(details);
  };
  runApp(const _Probe());
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final root = GlobalKey();
  final api = SaasApi(origin: 'https://example.invalid');
  double width = 320, scale = 1;
  List<Map<String, dynamic>> rows = [];
  ReportFormat format = const ReportFormat();
  bool visible = true;
  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await WidgetsBinding.instance.endOfFrame;
  }

  void visit(void Function(Element) action) {
    void walk(Element element) {
      action(element);
      element.visitChildren(walk);
    }

    walk(root.currentContext! as Element);
  }

  Future<void> _run() async {
    await settle();
    for (final w in [320.0, 390.0, 1366.0]) {
      for (final count in [0, 1, 120]) {
        for (final s in [1.0, 3.0]) {
          scenario = 'width=$w rows=$count scale=$s';
          setState(() {
            width = w;
            scale = s;
            rows = [
              for (var i = 0; i < count; i++)
                {
                  'from': '2026-01-01',
                  'asOf': '2026-01-31',
                  'income': '1000.00',
                  'expenses': null,
                  'netProfit': '-12.34',
                },
            ];
          });
          await settle();
          for (var cycle = 0; cycle < 3; cycle++) {
            visit((e) {
              if (e.widget case Expansible(:final controller)) {
                controller.expand();
              }
            });
            await settle();
            visit((e) {
              if (e.widget case Scrollable()) {
                final state = (e as StatefulElement).state as ScrollableState;
                final p = state.position;
                if (!p.viewportDimension.isFinite ||
                    !p.maxScrollExtent.isFinite) {
                  throw StateError('Unbounded viewport in $scenario');
                }
                p.jumpTo(p.maxScrollExtent);
              }
            });
            await settle();
            setState(() => width = w == 320 ? 740 : 320);
            await settle();
            visit((e) {
              if (e.widget case Expansible(:final controller)) {
                controller.collapse();
              }
            });
            await settle();
          }
          setState(() => visible = false);
          await settle();
          setState(() => visible = true);
          await settle();
          debugPrint('PROBE CHECKED $scenario');
        }
      }
    }
    scenario = 'unsupported date formatting';
    setState(() {
      format = const ReportFormat(datePattern: 'yyyy-MM-dd EEEEEE');
      rows = [
        {
          'from': '2026-01-01',
          'asOf': '2026-01-31',
          'income': 'NaN',
          'expenses': 'Infinity',
          'netProfit': null,
        },
      ];
    });
    await settle();
    visit((e) {
      if (e.widget case Expansible(:final controller)) {
        controller.expand();
      }
    });
    await settle();
    debugPrint('PROBE COMPLETE errors=$errors');
    web.document.title = 'PROBE COMPLETE errors=$errors';
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
              textScaler: TextScaler.linear(scale),
            ),
            child: SingleChildScrollView(
              key: root,
              child: KeyedSubtree(
                key: const PageStorageKey('release-report-page'),
                child: visible
                    ? Column(
                        children: [
                          ReportTrends(trends: rows, format: format),
                          RecordCard(
                            title: const Text('Record probe'),
                            subtitle: const Text('Saved record'),
                            children: [
                              const RecordDetails(
                                record: {
                                  'number': 'INV-001',
                                  'total': '1234.56',
                                  'notes': 'A saved record',
                                },
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('Documents'),
                              ),
                            ],
                          ),
                          SystemSettingsPanel(api: api, companyId: 'probe'),
                          for (final kind in [
                            'profit-and-loss',
                            'general-ledger',
                          ])
                            FinancialReportBody(
                              kind: kind,
                              dense: false,
                              format: format,
                              data: {'trends': rows},
                              rows: [
                                {
                                  'accountId': 'income',
                                  'accountCode': '4000',
                                  'accountName': 'Sales',
                                  'accountGroup': 'Income',
                                  'amount': '1234.56',
                                  'opening': '0.00',
                                  'closing': '1234.56',
                                  'debit': '0.00',
                                  'credit': '1234.56',
                                  'entries': [
                                    for (var i = 0; i < rows.length; i++)
                                      {
                                        'date': '2026-01-01',
                                        'journalId': '$i',
                                        'lineNumber': i,
                                        'description': 'Posted activity',
                                        'sourceType': 'Invoice',
                                        'debit': '0.00',
                                        'credit': '1234.56',
                                        'balance': '1234.56',
                                      },
                                  ],
                                },
                              ],
                            ),
                          ExpansionTile(
                            key: const PageStorageKey('grid-probe-expansion'),
                            title: const Text('Grid viewport probe'),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              ReportGrid(
                                headers: const ['Account', 'Debit', 'Credit'],
                                rows: [
                                  for (final row in rows)
                                    [
                                      const Text('Account'),
                                      Text('${row['income']}'),
                                      const Text('0.00'),
                                    ],
                                ],
                                numeric: const {1, 2},
                                dense: false,
                              ),
                            ],
                          ),
                        ],
                      )
                    : const Text('Navigated away'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
