import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../billing/domain/totals.dart';
import '../domain/office_repository.dart';
import 'office_cubit.dart';

class CapitalEquityScreen extends StatefulWidget {
  const CapitalEquityScreen({super.key});

  @override
  State<CapitalEquityScreen> createState() => _CapitalEquityScreenState();
}

class _CapitalEquityScreenState extends State<CapitalEquityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return BlocConsumer<OfficeCubit, OfficeState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.error}'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      builder: (context, state) {
        final office = state.data;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Capital & Equity', style: TextStyle(fontWeight: FontWeight.w700)),
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            bottom: TabBar(
              controller: _tabController,
              isScrollable: isCompact,
              tabAlignment: isCompact ? TabAlignment.start : TabAlignment.fill,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Overview'),
                Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Shareholders'),
                Tab(icon: Icon(Icons.account_balance_outlined, size: 20), text: 'Contributions'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 20), text: 'Shareholder Loans'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(office: office),
              _ShareholdersTab(office: office),
              _ContributionsTab(office: office),
              _LoansTab(office: office),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final OfficeData office;
  const _OverviewTab({required this.office});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shareholders = office.shareholders;
    final capitalTx = office.capitalTransactions;
    final loans = office.shareholderLoans;

    var totalAgreedCents = 0;
    for (final s in shareholders) {
      totalAgreedCents += (s['agreedCapitalCents'] as num?)?.toInt() ??
          ((double.tryParse((s['agreedCapital'] ?? s['investedAmount'] ?? 0).toString().replaceAll(',', '')) ?? 0.0) * 100).round();
    }

    var totalCashInvested = 0, totalAssetContributed = 0, totalWithdrawals = 0;
    for (final cap in capitalTx) {
      if (cap['status'] == 'void') continue;
      final amt = (cap['amountCents'] as num?)?.toInt() ??
          ((double.tryParse(cap['amount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0) * 100).round();
      final type = cap['transactionType'] as String? ?? 'capitalContribution';
      final cType = cap['contributionType'] as String? ?? 'bank';

      if (type == 'capitalWithdrawal') {
        totalWithdrawals += amt;
      } else if (cType.toLowerCase() == 'asset') {
        totalAssetContributed += amt;
      } else {
        totalCashInvested += amt;
      }
    }
    for (final e in office.entries) {
      if (e['kind'] == 'capital' && e['status'] == 'paid') {
        final amt = (e['amountCents'] as num?)?.toInt() ??
            ((double.tryParse(e['amount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0) * 100).round();
        totalCashInvested += amt;
      }
    }

    var totalLoans = 0;
    for (final l in loans) {
      if (l['status'] == 'void') continue;
      final amt = (l['amountCents'] as num?)?.toInt() ??
          ((double.tryParse((l['amount'] ?? l['principalAmount'] ?? 0).toString().replaceAll(',', '')) ?? 0.0) * 100).round();
      final type = l['type'] as String? ?? 'loanReceived';
      if (type == 'loanReceived') {
        totalLoans += amt;
      } else if (type == 'loanRepayment') {
        totalLoans -= amt;
      }
    }

    final totalInvestedCents = (totalCashInvested + totalAssetContributed - totalWithdrawals).clamp(0, double.infinity).toInt();
    final outstandingCents = (totalAgreedCents - totalInvestedCents).clamp(0, double.infinity).toInt();
    final companyEquityCents = totalInvestedCents;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Company Equity Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Overview of shareholder capital, agreed equity, and liabilities',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showAddContributionModal(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Contribution'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 6 KPI Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 950 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 125,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MetricCard(
                    title: 'Agreed Capital',
                    amountCents: totalAgreedCents,
                    icon: Icons.gavel_outlined,
                    color: const Color(0xFF3B82F6),
                    subtitle: 'Nominal baseline equity',
                  ),
                  _MetricCard(
                    title: 'Total Capital Invested',
                    amountCents: totalInvestedCents,
                    icon: Icons.account_balance_outlined,
                    color: const Color(0xFF10B981),
                    subtitle: 'Paid-in cash & asset contributions',
                  ),
                  _MetricCard(
                    title: 'Outstanding Capital',
                    amountCents: outstandingCents,
                    icon: Icons.pending_actions_outlined,
                    color: const Color(0xFFF59E0B),
                    subtitle: 'Agreed minus paid-in capital',
                  ),
                  _MetricCard(
                    title: 'Asset Contributions',
                    amountCents: totalAssetContributed,
                    icon: Icons.devices_outlined,
                    color: const Color(0xFF8B5CF6),
                    subtitle: 'Laptops, vehicles & hardware',
                  ),
                  _MetricCard(
                    title: 'Shareholder Loans',
                    amountCents: totalLoans,
                    icon: Icons.handshake_outlined,
                    color: const Color(0xFFEC4899),
                    subtitle: 'Temporary payable liability',
                  ),
                  _MetricCard(
                    title: 'Current Equity',
                    amountCents: companyEquityCents,
                    icon: Icons.pie_chart_outline,
                    color: const Color(0xFF06B6D4),
                    subtitle: 'Total shareholder equity',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          // Shareholder Ownership Breakdown Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shareholder Equity Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${shareholders.length} Shareholders', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (shareholders.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No shareholders registered. Add shareholders in the Shareholders tab.'),
                      ),
                    )
                  else
                    ...shareholders.map((s) {
                      final name = s['name'] as String? ?? 'Partner';
                      final pct = (s['ownershipPercentage'] as num?)?.toDouble() ?? 0.0;
                      final agreed = (s['agreedCapitalCents'] as num?)?.toInt() ??
                          ((double.tryParse((s['agreedCapital'] ?? s['investedAmount'] ?? 0).toString().replaceAll(',', '')) ?? 0.0) * 100).round();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('$pct% (${currency(agreed)})', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (pct / 100.0).clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int amountCents;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.amountCents,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  currency(amountCents),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareholdersTab extends StatelessWidget {
  final OfficeData office;
  const _ShareholdersTab({required this.office});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shareholders = office.shareholders;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Shareholder Registry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showAddShareholderModal(context),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Shareholder'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (shareholders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 64, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 16),
                    const Text('No Shareholders Added Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Add company partners, investors, or founders to track equity contributions.'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: shareholders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final sh = shareholders[index];
                  final name = sh['name'] as String? ?? 'Partner';
                  final pct = (sh['ownershipPercentage'] as num?)?.toDouble() ?? 0.0;
                  final agreed = (sh['agreedCapitalCents'] as num?)?.toInt() ??
                      ((double.tryParse((sh['agreedCapital'] ?? sh['investedAmount'] ?? 0).toString().replaceAll(',', '')) ?? 0.0) * 100).round();
                  final notes = sh['notes'] as String? ?? '';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P',
                              style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (notes.isNotEmpty)
                                Text(notes, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$pct% Ownership', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            const SizedBox(height: 4),
                            Text('Agreed: ${currency(agreed)}', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showAddShareholderModal(context, shareholder: sh),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => _confirmDelete(context, 'Shareholder', () {
                            context.read<OfficeCubit>().run('shareholderDelete', {'id': sh['id']});
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ContributionsTab extends StatelessWidget {
  final OfficeData office;
  const _ContributionsTab({required this.office});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, dynamic>> transactions = [];

    for (final tx in office.capitalTransactions) {
      if (tx['status'] == 'void') continue;
      transactions.add({...tx, 'source': 'capital'});
    }
    for (final e in office.entries) {
      if (e['kind'] == 'capital' && e['status'] == 'paid') {
        final amt = (e['amountCents'] as num?)?.toInt() ??
            ((double.tryParse(e['amount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0) * 100).round();
        transactions.add({
          'id': e['id'],
          'shareholderName': (e['party'] != null && e['party'].toString().isNotEmpty)
              ? e['party']
              : ((e['description'] != null && e['description'].toString().isNotEmpty)
                  ? e['description']
                  : 'Shareholder Capital'),
          'date': e['date'] ?? '',
          'transactionType': 'capitalContribution',
          'contributionType': e['account'] ?? 'bank',
          'amountCents': amt,
          'reference': e['ref'] ?? e['category'] ?? 'Finance Entry',
          'source': 'finance',
        });
      }
    }
    transactions.sort((a, b) => (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Capital Contributions & Withdrawals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showAddContributionModal(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record Contribution'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.account_balance_outlined, size: 64, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 16),
                    const Text('No Capital Transactions Recorded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Record cash, bank, or asset injections into the company equity.'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  final sName = tx['shareholderName'] as String? ?? 'Shareholder';
                  final date = tx['date'] as String? ?? '';
                  final type = tx['transactionType'] as String? ?? 'capitalContribution';
                  final cType = tx['contributionType'] as String? ?? 'bank';
                  final amount = (tx['amountCents'] as num?)?.toInt() ?? 0;
                  final isWithdrawal = type == 'capitalWithdrawal';
                  final ref = tx['reference'] as String? ?? '';
                  final isFinanceSource = tx['source'] == 'finance';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isWithdrawal ? Colors.red : (isFinanceSource ? const Color(0xFF8B5CF6) : Colors.green)).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isWithdrawal
                                ? Icons.arrow_upward
                                : (isFinanceSource ? Icons.account_balance_wallet_outlined : Icons.arrow_downward),
                            color: isWithdrawal ? Colors.red : (isFinanceSource ? const Color(0xFF8B5CF6) : Colors.green),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                                  ),
                                  if (isFinanceSource) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Finance',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('$date • ${cType.toUpperCase()}${ref.isNotEmpty ? ' • Ref: $ref' : ''}',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Text(
                          '${isWithdrawal ? '-' : '+'}${currency(amount)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isWithdrawal ? Colors.red : (isFinanceSource ? const Color(0xFF8B5CF6) : Colors.green),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit Contribution',
                          onPressed: () {
                            if (isFinanceSource) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Finance entries can be edited from the Finance screen.')),
                              );
                            } else {
                              _showAddContributionModal(context, transaction: tx);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: 'Delete Contribution',
                          onPressed: () => _confirmDelete(context, 'Contribution', () {
                            if (isFinanceSource) {
                              context.read<OfficeCubit>().run('financeDelete', {'id': tx['id']});
                            } else {
                              context.read<OfficeCubit>().run('capitalTransactionDelete', {'id': tx['id']});
                            }
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LoansTab extends StatelessWidget {
  final OfficeData office;
  const _LoansTab({required this.office});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loans = office.shareholderLoans;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Shareholder Loans Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showAddLoanModal(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record Loan / Repayment'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.handshake_outlined, size: 64, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 16),
                    const Text('No Shareholder Loans Recorded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Track temporary money lent to or repaid by the company to shareholders.'),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: loans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final l = loans[index];
                  final sName = l['shareholderName'] as String? ?? 'Shareholder';
                  final date = l['date'] as String? ?? '';
                  final type = l['type'] as String? ?? 'loanReceived';
                  final amount = (l['amountCents'] as num?)?.toInt() ?? 0;
                  final isRepayment = type == 'loanRepayment';
                  final acc = l['paymentAccount'] as String? ?? 'Bank';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isRepayment ? Colors.blue : Colors.orange).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isRepayment ? Icons.payment_outlined : Icons.account_balance_wallet_outlined,
                            color: isRepayment ? Colors.blue : Colors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$sName (${isRepayment ? 'Repayment' : 'Loan Received'})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text('$date • Via $acc',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Text(
                          currency(amount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isRepayment ? Colors.blue : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit Loan Entry',
                          onPressed: () => _showAddLoanModal(context, loan: l),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: 'Delete Loan Entry',
                          onPressed: () => _confirmDelete(context, 'Loan Entry', () {
                            context.read<OfficeCubit>().run('shareholderLoanDelete', {'id': l['id']});
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

void _showAddShareholderModal(BuildContext context, {Map<String, dynamic>? shareholder}) {
  final cubit = context.read<OfficeCubit>();
  final nameCtrl = TextEditingController(text: shareholder?['name'] ?? '');
  final roleCtrl = TextEditingController(text: shareholder?['role'] ?? 'Partner & Shareholder');
  final pctVal = shareholder?['ownershipPercentage'] ?? shareholder?['sharesPercent'] ?? '50.0';
  final pctCtrl = TextEditingController(text: pctVal.toString());
  final capVal = shareholder?['agreedCapital'] ?? shareholder?['investedAmount'] ?? (shareholder?['agreedCapitalCents'] != null ? ((shareholder!['agreedCapitalCents'] as num) / 100.0).toStringAsFixed(2) : '50000.00');
  final capitalCtrl = TextEditingController(text: capVal.toString());
  final emailCtrl = TextEditingController(text: shareholder?['email'] ?? '');
  final phoneCtrl = TextEditingController(text: shareholder?['phone'] ?? '');
  final notesCtrl = TextEditingController(text: shareholder?['notes'] ?? '');
  String? validationError;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (modalCtx, setModalState) => AlertDialog(
        title: Text(shareholder == null ? 'Add New Shareholder' : 'Edit Shareholder'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (validationError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validationError!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Partner Name', prefixIcon: Icon(Icons.person_outline, size: 20)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(labelText: 'Role / Title', hintText: 'e.g. Managing Partner', prefixIcon: Icon(Icons.badge_outlined, size: 20)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pctCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Ownership Percentage (%) *', hintText: 'e.g. 50.0', prefixIcon: Icon(Icons.percent, size: 20)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capitalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Agreed Capital (AED) *', hintText: 'e.g. 50000.00', prefixIcon: Icon(Icons.payments_outlined, size: 20)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address', hintText: 'partner@example.com', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+971 50 123 4567', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes', hintText: 'Partner role or details', prefixIcon: Icon(Icons.notes_outlined, size: 20)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: isSaving ? null : () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                setModalState(() => validationError = 'Please enter the shareholder full name.');
                return;
              }
              final pct = double.tryParse(pctCtrl.text.replaceAll('%', '').replaceAll(',', '').trim()) ?? 0.0;
              final cap = double.tryParse(capitalCtrl.text.replaceAll('AED', '').replaceAll(',', '').trim()) ?? 0.0;

              setModalState(() {
                isSaving = true;
                validationError = null;
              });

              final payload = {
                if (shareholder != null) 'id': shareholder['id'],
                if (shareholder != null) 'version': shareholder['version'] ?? 0,
                'name': name,
                'role': roleCtrl.text.trim().isNotEmpty ? roleCtrl.text.trim() : 'Partner & Shareholder',
                'ownershipPercentage': pct,
                'sharesPercent': pct.toStringAsFixed(2),
                'agreedCapital': cap,
                'agreedCapitalCents': (cap * 100).round(),
                'investedAmount': cap.toStringAsFixed(2),
                'email': emailCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'status': 'active',
              };

              final ok = await cubit.run('shareholderSave', payload);
              if (!ok) {
                setModalState(() {
                  isSaving = false;
                  validationError = cubit.state.error ?? 'Failed to save shareholder. Please try again.';
                });
                return;
              }
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(shareholder == null ? 'Shareholder added successfully.' : 'Shareholder updated successfully.'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              }
            },
            child: isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Shareholder'),
          ),
        ],
      ),
    ),
  );
}

String _normalizeTransactionDate(String input) {
  final text = input.trim();
  if (text.isEmpty) return DateTime.now().toIso8601String().substring(0, 10);
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return text;
  final ddmmyyyy = RegExp(r'^(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})$').firstMatch(text);
  if (ddmmyyyy != null) {
    final day = ddmmyyyy.group(1)!.padLeft(2, '0');
    final month = ddmmyyyy.group(2)!.padLeft(2, '0');
    final year = ddmmyyyy.group(3)!;
    return '$year-$month-$day';
  }
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return parsed.toIso8601String().substring(0, 10);
  }
  return DateTime.now().toIso8601String().substring(0, 10);
}

void _showAddContributionModal(BuildContext context, {Map<String, dynamic>? transaction}) {
  final cubit = context.read<OfficeCubit>();
  final office = cubit.state.data;
  final List<Map<String, dynamic>> shareholders = [
    ...office.shareholders,
  ];

  String selectedShareholderId = transaction?['shareholderId'] ?? (shareholders.isNotEmpty ? shareholders.first['id'] as String : '__new__');
  if (selectedShareholderId != '__new__' && !shareholders.any((s) => s['id'] == selectedShareholderId)) {
    selectedShareholderId = shareholders.isNotEmpty ? shareholders.first['id'] as String : '__new__';
  }

  String selectedType = transaction?['transactionType'] ?? transaction?['type'] ?? 'capitalContribution';
  String selectedContributionType = transaction?['contributionType'] ?? 'bank';
  final amountVal = transaction?['amount'] ?? (transaction?['amountCents'] != null ? ((transaction!['amountCents'] as num) / 100.0).toStringAsFixed(2) : '');
  final amountCtrl = TextEditingController(text: amountVal.toString());
  final newShareholderNameCtrl = TextEditingController(text: transaction?['shareholderName'] ?? '');
  final assetNameCtrl = TextEditingController(text: transaction?['assetName'] ?? '');
  final refCtrl = TextEditingController(text: transaction?['reference'] ?? '');
  final notesCtrl = TextEditingController(text: transaction?['notes'] ?? '');
  final dateCtrl = TextEditingController(text: transaction?['date'] ?? DateTime.now().toIso8601String().substring(0, 10));
  String? validationError;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (modalCtx, setModalState) => AlertDialog(
        title: Text(transaction == null ? 'Record Capital Contribution' : 'Edit Capital Transaction'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (validationError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validationError!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (shareholders.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedShareholderId,
                    decoration: const InputDecoration(labelText: 'Shareholder *', prefixIcon: Icon(Icons.person_outline, size: 20)),
                    items: [
                      ...shareholders.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))),
                      const DropdownMenuItem(value: '__new__', child: Text('+ Add New Shareholder...')),
                    ],
                    onChanged: (v) => setModalState(() => selectedShareholderId = v!),
                  ),
                  const SizedBox(height: 12),
                ],
                if (shareholders.isEmpty || selectedShareholderId == '__new__') ...[
                  TextField(
                    controller: newShareholderNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shareholder Full Name *',
                      hintText: 'e.g. Partner Name',
                      prefixIcon: Icon(Icons.person_add_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Transaction Type *', prefixIcon: Icon(Icons.category_outlined, size: 20)),
                  items: const [
                    DropdownMenuItem(value: 'capitalContribution', child: Text('Capital Contribution')),
                    DropdownMenuItem(value: 'additionalCapital', child: Text('Additional Paid-in Capital')),
                    DropdownMenuItem(value: 'capitalWithdrawal', child: Text('Capital Withdrawal')),
                  ],
                  onChanged: (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                if (selectedType != 'capitalWithdrawal') ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedContributionType,
                    decoration: const InputDecoration(labelText: 'Contribution Method *', prefixIcon: Icon(Icons.account_balance_outlined, size: 20)),
                    items: const [
                      DropdownMenuItem(value: 'bank', child: Text('Bank Transfer (Bank Account)')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash (Cash in Hand)')),
                      DropdownMenuItem(value: 'asset', child: Text('Physical Asset Contribution')),
                    ],
                    onChanged: (v) => setModalState(() => selectedContributionType = v!),
                  ),
                  const SizedBox(height: 12),
                ],
                if (selectedContributionType == 'asset' && selectedType != 'capitalWithdrawal') ...[
                  TextField(
                    controller: assetNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contributed Asset Name *',
                      hintText: 'e.g. MacBook Pro 16", Office Equipment',
                      prefixIcon: Icon(Icons.devices_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (AED) *',
                    hintText: '10000.00',
                    prefixText: 'AED ',
                    prefixIcon: Icon(Icons.payments_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Transaction Date (YYYY-MM-DD) *',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.date_range_outlined),
                      tooltip: 'Select date',
                      onPressed: () async {
                        final now = DateTime.now();
                        final parsed = DateTime.tryParse(dateCtrl.text.trim()) ?? now;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: parsed,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() {
                            dateCtrl.text = picked.toIso8601String().substring(0, 10);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number',
                    hintText: 'e.g. Bank Ref / Receipt #',
                    prefixIcon: Icon(Icons.tag_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional remarks',
                    prefixIcon: Icon(Icons.notes_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: isSaving ? null : () async {
              final amt = double.tryParse(amountCtrl.text.replaceAll('AED', '').replaceAll('aed', '').replaceAll(',', '').trim()) ?? 0.0;
              if (amt <= 0) {
                setModalState(() => validationError = 'Please enter a valid amount greater than 0 AED.');
                return;
              }

              final dateStr = _normalizeTransactionDate(dateCtrl.text);

              if (selectedContributionType == 'asset' && selectedType != 'capitalWithdrawal' && assetNameCtrl.text.trim().isEmpty) {
                setModalState(() => validationError = 'Please enter the name of the contributed asset.');
                return;
              }

              String shareholderId = selectedShareholderId;
              String shareholderName = '';

              if (selectedShareholderId == '__new__' || shareholders.isEmpty) {
                final newName = newShareholderNameCtrl.text.trim();
                if (newName.isEmpty) {
                  setModalState(() => validationError = 'Please enter the shareholder full name.');
                  return;
                }
                shareholderName = newName;
                shareholderId = 'SHR_${DateTime.now().millisecondsSinceEpoch}';
              } else {
                final found = shareholders.firstWhere((s) => s['id'] == selectedShareholderId, orElse: () => {'id': selectedShareholderId, 'name': 'Shareholder'});
                shareholderName = found['name']?.toString() ?? 'Shareholder';
              }

              setModalState(() {
                isSaving = true;
                validationError = null;
              });

              final List<MapEntry<String, Map<String, dynamic>?>> commands = [];

              if (selectedShareholderId == '__new__' || shareholders.isEmpty) {
                commands.add(MapEntry('shareholderSave', {
                  'id': shareholderId,
                  'name': shareholderName,
                  'role': 'Partner & Shareholder',
                  'ownershipPercentage': 100.0,
                  'sharesPercent': '100.00',
                  'agreedCapital': amt,
                  'agreedCapitalCents': (amt * 100).round(),
                  'status': 'active',
                }));
              }

              if (transaction == null && selectedContributionType == 'asset' && selectedType != 'capitalWithdrawal') {
                commands.add(MapEntry('assetSave', {
                  'name': assetNameCtrl.text.trim().isNotEmpty ? assetNameCtrl.text.trim() : 'Contributed Asset',
                  'category': 'Computers & IT Equipment',
                  'acquisitionType': 'shareholderContribution',
                  'purchaseDate': dateStr,
                  'cost': amt,
                  'costCents': (amt * 100).round(),
                  'shareholderId': shareholderId,
                  'shareholderName': shareholderName,
                  'status': 'active',
                  'usefulLifeYears': 3,
                  'usefulLifeMonths': 36,
                  'skipJournal': true,
                }));
              }

              final payload = {
                if (transaction != null) 'id': transaction['id'],
                if (transaction != null) 'version': transaction['version'] ?? 0,
                'shareholderId': shareholderId,
                'shareholderName': shareholderName,
                'date': dateStr,
                'transactionType': selectedType,
                'type': selectedType,
                'contributionType': selectedContributionType,
                'amount': amt,
                'amountCents': (amt * 100).round(),
                'bankAccountId': selectedContributionType == 'cash' ? 'Cash' : 'Bank',
                'account': selectedContributionType == 'cash' ? 'Cash' : 'Bank',
                'assetName': assetNameCtrl.text.trim(),
                'reference': refCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'status': 'posted',
              };

              commands.add(MapEntry('capitalTransactionSave', payload));

              try {
                final success = await cubit.runBatch(commands);
                if (!success) {
                  setModalState(() {
                    isSaving = false;
                    validationError = cubit.state.error ?? 'Failed to save capital transaction. Please try again.';
                  });
                  return;
                }
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(transaction == null ? 'Capital transaction recorded successfully.' : 'Capital transaction updated successfully.'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              } catch (e) {
                setModalState(() {
                  isSaving = false;
                  validationError = e.toString();
                });
              }
            },
            child: isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(transaction == null ? 'Save Transaction' : 'Update Transaction'),
          ),
        ],
      ),
    ),
  );
}

void _showAddLoanModal(BuildContext context, {Map<String, dynamic>? loan}) {
  final cubit = context.read<OfficeCubit>();
  final office = cubit.state.data;
  final List<Map<String, dynamic>> shareholders = [
    ...office.shareholders,
  ];

  String selectedShareholderId = loan?['shareholderId'] ?? (shareholders.isNotEmpty ? shareholders.first['id'] as String : '__new__');
  if (selectedShareholderId != '__new__' && !shareholders.any((s) => s['id'] == selectedShareholderId)) {
    selectedShareholderId = shareholders.isNotEmpty ? shareholders.first['id'] as String : '__new__';
  }

  String selectedType = loan?['type'] ?? 'loanReceived';
  String selectedAccount = loan?['paymentAccount'] ?? loan?['account'] ?? 'Bank';
  final amountVal = loan?['amount'] ?? loan?['principalAmount'] ?? (loan?['amountCents'] != null ? ((loan!['amountCents'] as num) / 100.0).toStringAsFixed(2) : '');
  final amountCtrl = TextEditingController(text: amountVal.toString());
  final newShareholderNameCtrl = TextEditingController(text: loan?['shareholderName'] ?? '');
  final refCtrl = TextEditingController(text: loan?['reference'] ?? '');
  final notesCtrl = TextEditingController(text: loan?['notes'] ?? '');
  final dateCtrl = TextEditingController(text: loan?['date'] ?? DateTime.now().toIso8601String().substring(0, 10));
  String? validationError;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (modalCtx, setModalState) => AlertDialog(
        title: Text(loan == null ? 'Record Shareholder Loan / Repayment' : 'Edit Shareholder Loan'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (validationError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validationError!,
                            style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (shareholders.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedShareholderId,
                    decoration: const InputDecoration(labelText: 'Shareholder *', prefixIcon: Icon(Icons.person_outline, size: 20)),
                    items: [
                      ...shareholders.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))),
                      const DropdownMenuItem(value: '__new__', child: Text('+ Add New Shareholder...')),
                    ],
                    onChanged: (v) => setModalState(() => selectedShareholderId = v!),
                  ),
                  const SizedBox(height: 12),
                ],
                if (shareholders.isEmpty || selectedShareholderId == '__new__') ...[
                  TextField(
                    controller: newShareholderNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shareholder Full Name *',
                      hintText: 'e.g. Partner Name',
                      prefixIcon: Icon(Icons.person_add_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Loan Action *', prefixIcon: Icon(Icons.category_outlined, size: 20)),
                  items: const [
                    DropdownMenuItem(value: 'loanReceived', child: Text('Loan Received (From Shareholder to Company)')),
                    DropdownMenuItem(value: 'loanRepayment', child: Text('Loan Repayment (Company Repaying Shareholder)')),
                  ],
                  onChanged: (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccount,
                  decoration: const InputDecoration(labelText: 'Payment Account *', prefixIcon: Icon(Icons.account_balance_outlined, size: 20)),
                  items: const [
                    DropdownMenuItem(value: 'Bank', child: Text('Bank Account')),
                    DropdownMenuItem(value: 'Cash', child: Text('Cash in Hand')),
                  ],
                  onChanged: (v) => setModalState(() => selectedAccount = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (AED) *',
                    hintText: '5000.00',
                    prefixText: 'AED ',
                    prefixIcon: Icon(Icons.payments_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Date (YYYY-MM-DD) *',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.date_range_outlined),
                      tooltip: 'Select date',
                      onPressed: () async {
                        final now = DateTime.now();
                        final parsed = DateTime.tryParse(dateCtrl.text.trim()) ?? now;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: parsed,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() {
                            dateCtrl.text = picked.toIso8601String().substring(0, 10);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number',
                    prefixIcon: Icon(Icons.tag_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: isSaving ? null : () async {
              final amt = double.tryParse(amountCtrl.text.replaceAll('AED', '').replaceAll('aed', '').replaceAll(',', '').trim()) ?? 0.0;
              if (amt <= 0) {
                setModalState(() => validationError = 'Please enter a valid amount greater than 0 AED.');
                return;
              }

              final dateStr = _normalizeTransactionDate(dateCtrl.text);

              String shareholderId = selectedShareholderId;
              String shareholderName = '';

              if (selectedShareholderId == '__new__' || shareholders.isEmpty) {
                final newName = newShareholderNameCtrl.text.trim();
                if (newName.isEmpty) {
                  setModalState(() => validationError = 'Please enter the shareholder full name.');
                  return;
                }
                shareholderName = newName;
                shareholderId = 'SHR_${DateTime.now().millisecondsSinceEpoch}';
              } else {
                final found = shareholders.firstWhere((s) => s['id'] == selectedShareholderId, orElse: () => {'id': selectedShareholderId, 'name': 'Shareholder'});
                shareholderName = found['name']?.toString() ?? 'Shareholder';
              }

              setModalState(() {
                isSaving = true;
                validationError = null;
              });

              final List<MapEntry<String, Map<String, dynamic>?>> commands = [];

              if (selectedShareholderId == '__new__' || shareholders.isEmpty) {
                commands.add(MapEntry('shareholderSave', {
                  'id': shareholderId,
                  'name': shareholderName,
                  'role': 'Partner & Shareholder',
                  'ownershipPercentage': 100.0,
                  'sharesPercent': '100.00',
                  'agreedCapital': 0.0,
                  'agreedCapitalCents': 0,
                  'status': 'active',
                }));
              }

              final payload = {
                if (loan != null) 'id': loan['id'],
                if (loan != null) 'version': loan['version'] ?? 0,
                'shareholderId': shareholderId,
                'shareholderName': shareholderName,
                'date': dateStr,
                'type': selectedType,
                'amount': amt,
                'amountCents': (amt * 100).round(),
                'principalAmount': amt.toStringAsFixed(2),
                'paymentAccount': selectedAccount,
                'account': selectedAccount,
                'reference': refCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'status': 'posted',
              };

              commands.add(MapEntry('shareholderLoanSave', payload));

              try {
                final success = await cubit.runBatch(commands);
                if (!success) {
                  setModalState(() {
                    isSaving = false;
                    validationError = cubit.state.error ?? 'Failed to save shareholder loan. Please try again.';
                  });
                  return;
                }
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loan == null ? 'Shareholder loan recorded successfully.' : 'Shareholder loan updated.'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              } catch (e) {
                setModalState(() {
                  isSaving = false;
                  validationError = e.toString();
                });
              }
            },
            child: isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Loan Entry'),
          ),
        ],
      ),
    ),
  );
}

void _confirmDelete(BuildContext context, String itemType, VoidCallback onConfirmed) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $itemType?'),
      content: Text('Are you sure you want to delete this $itemType record? This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            Navigator.pop(ctx);
            onConfirmed();
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
