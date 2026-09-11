import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../billing/domain/totals.dart';
import '../../billing/presentation/billing_cubit.dart';
import '../domain/office_repository.dart';
import '../domain/office_rules.dart';
import 'office_cubit.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final billing = context.watch<BillingCubit>().state.data;
    final office = context.watch<OfficeCubit>().state.data;

    final balanceSheet = calculateBalanceSheet(billing.invoices, office, billing.company.shareholders);
    final trialBalance = calculateTrialBalance(billing.invoices, office);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Accounting & Balance Sheet', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance, size: 20), text: 'Balance Sheet'),
            Tab(icon: Icon(Icons.menu_book_outlined, size: 20), text: 'General Ledger'),
            Tab(icon: Icon(Icons.compare_arrows_outlined, size: 20), text: 'Trial Balance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BalanceSheetView(bs: balanceSheet),
          _GeneralLedgerView(office: office),
          _TrialBalanceView(tb: trialBalance),
        ],
      ),
    );
  }
}

class _BalanceSheetView extends StatelessWidget {
  final Map<String, dynamic> bs;
  const _BalanceSheetView({required this.bs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBalanced = bs['isBalanced'] as bool? ?? false;
    final totalAssets = bs['totalAssetsCents'] as int? ?? 0;
    final totalLiabilities = bs['totalLiabilitiesCents'] as int? ?? 0;
    final totalEquity = bs['totalEquityCents'] as int? ?? 0;
    final totalLiabAndEquity = bs['totalLiabilitiesAndEquityCents'] as int? ?? 0;

    final currentAssets = (bs['currentAssets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final fixedAssets = (bs['fixedAssetsByCategory'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final liabilities = (bs['liabilities'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final shareholderRows = (bs['shareholderEquityRows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final currentProfit = bs['currentYearNetProfitCents'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Balance Indicator
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Statement of Financial Position', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('As of ${DateTime.now().toIso8601String().substring(0, 10)} • Double-Entry Balance Verification',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: (isBalanced ? Colors.green : Colors.orange).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: (isBalanced ? Colors.green : Colors.orange).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isBalanced ? Icons.check_circle : Icons.warning_amber_rounded, color: isBalanced ? Colors.green : Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isBalanced ? 'Balanced: Assets = Liab + Equity' : 'Imbalance Detected',
                            style: TextStyle(color: isBalanced ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ASSETS SECTION
              _SectionContainer(
                title: '1. ASSETS',
                color: const Color(0xFF3B82F6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Assets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB))),
                    const SizedBox(height: 8),
                    ...currentAssets.map((item) => _ReportRow(name: item['name'], amountCents: item['amountCents'] ?? 0)),
                    const SizedBox(height: 4),
                    _SubtotalRow(title: 'Total Current Assets', amountCents: bs['totalCurrentAssetsCents'] ?? 0),
                    const Divider(height: 24),
                    const Text('Fixed Assets (Net of Depreciation)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB))),
                    const SizedBox(height: 8),
                    if (fixedAssets.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('No fixed assets recorded', style: TextStyle(color: Colors.grey, fontSize: 13)))
                    else
                      ...fixedAssets.map((item) => _ReportRow(name: item['category'], amountCents: item['amountCents'] ?? 0)),
                    const SizedBox(height: 4),
                    _SubtotalRow(title: 'Total Fixed Assets', amountCents: bs['totalFixedAssetsCents'] ?? 0),
                    const Divider(height: 24, thickness: 1.5),
                    _TotalRow(title: 'TOTAL ASSETS', amountCents: totalAssets, color: const Color(0xFF3B82F6)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // LIABILITIES SECTION
              _SectionContainer(
                title: '2. LIABILITIES',
                color: const Color(0xFFEF4444),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Liabilities & Payables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFEF4444))),
                    const SizedBox(height: 8),
                    ...liabilities.map((item) => _ReportRow(name: item['name'], amountCents: item['amountCents'] ?? 0)),
                    const Divider(height: 24, thickness: 1.5),
                    _TotalRow(title: 'TOTAL LIABILITIES', amountCents: totalLiabilities, color: const Color(0xFFEF4444)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // EQUITY SECTION
              _SectionContainer(
                title: '3. EQUITY',
                color: const Color(0xFF10B981),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shareholder Capital & Contributed Equity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                    const SizedBox(height: 8),
                    if (shareholderRows.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('No shareholders registered', style: TextStyle(color: Colors.grey, fontSize: 13)))
                    else
                      ...shareholderRows.map((s) => _ReportRow(
                            name: '${s['name']} (${s['ownershipPercentage']}%)',
                            amountCents: s['totalInvestedCents'] ?? 0,
                          )),
                    const SizedBox(height: 4),
                    _SubtotalRow(title: 'Total Shareholder Capital', amountCents: bs['totalShareholderEquityCents'] ?? 0),
                    const SizedBox(height: 12),
                    const Text('Retained Earnings & Profit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                    const SizedBox(height: 8),
                    _ReportRow(name: 'Current Period Operating Net Profit', amountCents: currentProfit, isProfit: true),
                    const Divider(height: 24, thickness: 1.5),
                    _TotalRow(title: 'TOTAL EQUITY', amountCents: totalEquity, color: const Color(0xFF10B981)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // TOTAL LIABILITIES & EQUITY GRAND TOTAL
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2563EB), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL LIABILITIES & EQUITY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    Text(currency(totalLiabAndEquity), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneralLedgerView extends StatefulWidget {
  final OfficeData office;
  const _GeneralLedgerView({required this.office});

  @override
  State<_GeneralLedgerView> createState() => _GeneralLedgerViewState();
}

class _GeneralLedgerViewState extends State<_GeneralLedgerView> {
  String _selectedAccount = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final journals = widget.office.journals;

    // Flatten journal lines with header context
    final List<Map<String, dynamic>> flatEntries = [];
    for (final j in journals) {
      final jDate = j['date'] as String? ?? '';
      final jNum = j['journalNumber'] as String? ?? '';
      final jDesc = j['description'] as String? ?? '';
      final lines = (j['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      for (final line in lines) {
        flatEntries.add({
          'date': jDate,
          'journalNumber': jNum,
          'description': jDesc,
          'accountId': line['accountId'] ?? '',
          'accountName': line['accountName'] ?? '',
          'accountGroup': line['accountGroup'] ?? '',
          'debitCents': line['debitCents'] ?? 0,
          'creditCents': line['creditCents'] ?? 0,
        });
      }
    }

    final filtered = flatEntries.where((e) {
      if (_selectedAccount != 'All' && e['accountGroup'] != _selectedAccount) return false;
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('General Ledger Entries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _selectedAccount,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Account Groups')),
                  DropdownMenuItem(value: 'Asset', child: Text('Assets')),
                  DropdownMenuItem(value: 'Liability', child: Text('Liabilities')),
                  DropdownMenuItem(value: 'Equity', child: Text('Equity')),
                  DropdownMenuItem(value: 'Income', child: Text('Income')),
                  DropdownMenuItem(value: 'Expense', child: Text('Expenses')),
                ],
                onChanged: (v) => setState(() => _selectedAccount = v!),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 64, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 16),
                    const Text('No Journal Entries Recorded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Transactions in Invoicing, Capital, and Assets automatically generate balanced double-entry journals.'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = filtered[index];
                    final deb = e['debitCents'] as int? ?? 0;
                    final cred = e['creditCents'] as int? ?? 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Row(
                        children: [
                          Text(e['accountName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(e['accountGroup'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      subtitle: Text('${e['date']} • ${e['journalNumber']} • ${e['description']}',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (deb > 0)
                            Text('Dr ${currency(deb)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 14)),
                          if (cred > 0)
                            Text('Cr ${currency(cred)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrialBalanceView extends StatelessWidget {
  final Map<String, dynamic> tb;
  const _TrialBalanceView({required this.tb});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = (tb['rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalDebits = tb['totalDebitCents'] as int? ?? 0;
    final totalCredits = tb['totalCreditCents'] as int? ?? 0;
    final isBalanced = tb['isBalanced'] as bool? ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Trial Balance Statement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Verification of ledger debit and credit equality', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isBalanced ? Colors.green : Colors.orange).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isBalanced ? 'Balanced' : 'Imbalance',
                        style: TextStyle(color: isBalanced ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Debit (AED)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Credit (AED)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No active ledger accounts')))
                else
                  ...rows.map((r) {
                    final deb = r['displayDebitCents'] as int? ?? 0;
                    final cred = r['displayCreditCents'] as int? ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(r['accountName'], style: const TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text(r['accountGroup'], style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13))),
                          Expanded(flex: 2, child: Text(deb > 0 ? currency(deb) : '-', textAlign: TextAlign.right, style: TextStyle(color: deb > 0 ? const Color(0xFF2563EB) : null))),
                          Expanded(flex: 2, child: Text(cred > 0 ? currency(cred) : '-', textAlign: TextAlign.right, style: TextStyle(color: cred > 0 ? const Color(0xFF10B981) : null))),
                        ],
                      ),
                    );
                  }),
                const Divider(height: 32, thickness: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(flex: 5, child: Text('TOTALS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                      Expanded(flex: 2, child: Text(currency(totalDebits), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF2563EB)))),
                      Expanded(flex: 2, child: Text(currency(totalCredits), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF10B981)))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final String title;
  final Color color;
  final Widget child;

  const _SectionContainer({required this.title, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String name;
  final int amountCents;
  final bool isProfit;

  const _ReportRow({required this.name, required this.amountCents, this.isProfit = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
          Text(
            currency(amountCents),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isProfit ? const Color(0xFF10B981) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtotalRow extends StatelessWidget {
  final String title;
  final int amountCents;
  const _SubtotalRow({required this.title, required this.amountCents});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          Text(currency(amountCents), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String title;
  final int amountCents;
  final Color color;

  const _TotalRow({required this.title, required this.amountCents, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        Text(currency(amountCents), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}
