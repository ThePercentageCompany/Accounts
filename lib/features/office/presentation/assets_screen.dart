import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../billing/domain/totals.dart';
import '../domain/office_repository.dart';
import '../domain/office_rules.dart';
import 'office_cubit.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Computers & IT Equipment',
    'Office Equipment',
    'Furniture & Fixtures',
    'Vehicles',
    'Software / Licences',
    'Machinery',
    'Mobile Phones',
    'Cameras & Photography',
    'Other Fixed Assets',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.watch<OfficeCubit>();
    final office = cubit.state.data;
    final assets = office.assets;

    var totalCostCents = 0, totalAccDepCents = 0, totalBookValueCents = 0, activeCount = 0;
    for (final a in assets) {
      if (a['status'] == 'void' || a['status'] == 'disposed') continue;
      final cost = (a['costCents'] as num?)?.toInt() ?? scaled((a['cost'] ?? 0).toString(), 2);
      final accDep = (a['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
      final book = (cost - accDep).clamp(0, cost);

      totalCostCents += cost;
      totalAccDepCents += accDep;
      totalBookValueCents += book;
      if (a['status'] == 'active') activeCount++;
    }

    final filteredAssets = assets.where((a) {
      if (a['status'] == 'void') return false;
      if (_selectedCategory != 'All' && (a['category'] ?? '') != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (a['name'] as String? ?? '').toLowerCase();
        final code = (a['code'] as String? ?? '').toLowerCase();
        final serial = (a['serialNumber'] as String? ?? '').toLowerCase();
        final staff = (a['assignedEmployeeName'] as String? ?? '').toLowerCase();
        return name.contains(q) || code.contains(q) || serial.contains(q) || staff.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Fixed Assets Register', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => _runDepreciation(context),
            icon: const Icon(Icons.calculate_outlined, size: 18),
            label: const Text('Run Depreciation'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _showAddAssetModal(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Asset'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: constraints.maxWidth > 900 ? 2.3 : 2.0,
                  children: [
                    _AssetKpiCard(
                      title: 'Original Asset Cost',
                      amount: currency(totalCostCents),
                      subtitle: '$activeCount active assets registered',
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF3B82F6),
                    ),
                    _AssetKpiCard(
                      title: 'Current Book Value',
                      amount: currency(totalBookValueCents),
                      subtitle: 'Net asset balance on balance sheet',
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF10B981),
                    ),
                    _AssetKpiCard(
                      title: 'Accumulated Depreciation',
                      amount: currency(totalAccDepCents),
                      subtitle: 'Total amortized to date',
                      icon: Icons.trending_down_outlined,
                      color: const Color(0xFFF59E0B),
                    ),
                    _AssetKpiCard(
                      title: 'Total Active Assets',
                      amount: '$activeCount Units',
                      subtitle: '${assets.length} items in registry',
                      icon: Icons.devices_other_outlined,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Category & Search Filters
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Search by asset name, code, serial number, or employee...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
                              checkmarkColor: const Color(0xFF2563EB),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Asset Register List / Table
            if (filteredAssets.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(Icons.devices_outlined, size: 64, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                      const SizedBox(height: 16),
                      const Text('No Assets Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('Click "Add Asset" to register laptops, vehicles, or equipment.'),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAssets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final a = filteredAssets[index];
                  final name = a['name'] as String? ?? 'Asset';
                  final code = a['code'] as String? ?? 'AST-${index + 1}';
                  final category = a['category'] as String? ?? 'Fixed Assets';
                  final cost = (a['costCents'] as num?)?.toInt() ?? scaled((a['cost'] ?? 0).toString(), 2);
                  final accDep = (a['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
                  final bookValue = (cost - accDep).clamp(0, cost);
                  final date = a['purchaseDate'] as String? ?? '';
                  final acqType = a['acquisitionType'] as String? ?? 'companyPurchase';
                  final status = a['status'] as String? ?? 'active';
                  final staff = a['assignedEmployeeName'] as String? ?? '';

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
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_getCategoryIcon(category), color: const Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$category • $date • ${_formatAcquisitionType(acqType)}${staff.isNotEmpty ? ' • Assigned to: $staff' : ''}',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Book: ${currency(bookValue)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981))),
                            const SizedBox(height: 2),
                            Text('Cost: ${currency(cost)}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          tooltip: 'Asset Details & Depreciation',
                          onPressed: () => _showAssetDetailsModal(context, a),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Edit Asset',
                          onPressed: () => _showAddAssetModal(context, asset: a),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          tooltip: 'Delete Asset',
                          onPressed: () => _confirmDelete(context, 'Asset', () {
                            context.read<OfficeCubit>().run('assetDelete', {'id': a['id']});
                          }),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    if (category.contains('Computer') || category.contains('IT')) return Icons.laptop_mac;
    if (category.contains('Vehicle')) return Icons.directions_car;
    if (category.contains('Furniture')) return Icons.chair;
    if (category.contains('Phone')) return Icons.smartphone;
    if (category.contains('Camera')) return Icons.camera_alt_outlined;
    if (category.contains('Software')) return Icons.code;
    return Icons.devices_other;
  }

  String _formatAcquisitionType(String type) {
    if (type == 'shareholderContribution') return 'Shareholder Contributed';
    if (type == 'openingBalance') return 'Opening Balance';
    return 'Company Purchased';
  }

  void _runDepreciation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Run Monthly Straight-Line Depreciation?'),
        content: const Text('This will compute 1 month of straight-line depreciation for all active assets, generate balanced journal entries, and update book values.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<OfficeCubit>().run('runDepreciation');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monthly depreciation posted successfully.')));
            },
            child: const Text('Run Depreciation'),
          ),
        ],
      ),
    );
  }
}

class _AssetKpiCard extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AssetKpiCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(amount, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.green.withOpacity(0.12);
    Color fg = Colors.green;
    String label = 'Active';

    if (status == 'maintenance') {
      bg = Colors.orange.withOpacity(0.12);
      fg = Colors.orange;
      label = 'Maintenance';
    } else if (status == 'damaged') {
      bg = Colors.red.withOpacity(0.12);
      fg = Colors.red;
      label = 'Damaged';
    } else if (status == 'disposed') {
      bg = Colors.grey.withOpacity(0.12);
      fg = Colors.grey;
      label = 'Disposed';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

void _showAddAssetModal(BuildContext context, {Map<String, dynamic>? asset}) {
  final office = context.read<OfficeCubit>().state.data;
  final shareholders = office.shareholders;
  final employees = office.employees;

  final nameCtrl = TextEditingController(text: asset?['name'] ?? '');
  final codeCtrl = TextEditingController(text: asset?['code'] ?? 'AST-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
  String selectedCategory = asset?['category'] ?? 'Computers & IT Equipment';
  String selectedAcquisitionType = asset?['acquisitionType'] ?? 'companyPurchase';
  String selectedPaymentAccount = asset?['paymentAccount'] ?? 'Bank';
  String? selectedShareholderId = asset?['shareholderId'] ?? (shareholders.isNotEmpty ? shareholders.first['id'] as String : null);
  String? selectedEmployeeId = asset?['assignedEmployeeId'];
  final costCtrl = TextEditingController(text: (asset?['cost'] ?? '').toString());
  final dateCtrl = TextEditingController(text: asset?['purchaseDate'] ?? DateTime.now().toIso8601String().substring(0, 10));
  final usefulMonthsCtrl = TextEditingController(text: (asset?['usefulLifeMonths'] ?? 36).toString());
  final residualCtrl = TextEditingController(text: (asset?['residualValue'] ?? '0.00').toString());
  final locationCtrl = TextEditingController(text: asset?['location'] ?? 'Main Office');
  final serialCtrl = TextEditingController(text: asset?['serialNumber'] ?? '');
  final notesCtrl = TextEditingController(text: asset?['notes'] ?? '');

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(asset == null ? 'Add New Asset' : 'Edit Asset'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Asset Name *', hintText: 'e.g. MacBook Pro 14"'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(labelText: 'Asset Code *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Asset Category *'),
                  items: const [
                    DropdownMenuItem(value: 'Computers & IT Equipment', child: Text('Computers & IT Equipment')),
                    DropdownMenuItem(value: 'Office Equipment', child: Text('Office Equipment')),
                    DropdownMenuItem(value: 'Furniture & Fixtures', child: Text('Furniture & Fixtures')),
                    DropdownMenuItem(value: 'Vehicles', child: Text('Vehicles')),
                    DropdownMenuItem(value: 'Software / Licences', child: Text('Software / Licences')),
                    DropdownMenuItem(value: 'Machinery', child: Text('Machinery')),
                    DropdownMenuItem(value: 'Mobile Phones', child: Text('Mobile Phones')),
                    DropdownMenuItem(value: 'Cameras & Photography', child: Text('Cameras & Photography')),
                    DropdownMenuItem(value: 'Other Fixed Assets', child: Text('Other Fixed Assets')),
                  ],
                  onChanged: (v) => setState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedAcquisitionType,
                  decoration: const InputDecoration(labelText: 'Acquisition Type *'),
                  items: const [
                    DropdownMenuItem(value: 'companyPurchase', child: Text('Company Purchase (Paid from Bank / Cash)')),
                    DropdownMenuItem(value: 'shareholderContribution', child: Text('Shareholder Contribution (Equity)')),
                    DropdownMenuItem(value: 'openingBalance', child: Text('Opening Balance Asset')),
                  ],
                  onChanged: (v) => setState(() => selectedAcquisitionType = v!),
                ),
                const SizedBox(height: 12),
                if (selectedAcquisitionType == 'companyPurchase') ...[
                  DropdownButtonFormField<String>(
                    value: selectedPaymentAccount,
                    decoration: const InputDecoration(labelText: 'Payment Account *'),
                    items: const [
                      DropdownMenuItem(value: 'Bank', child: Text('Bank Account')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash in Hand')),
                      DropdownMenuItem(value: 'Credit', child: Text('Supplier Credit (Accounts Payable)')),
                    ],
                    onChanged: (v) => setState(() => selectedPaymentAccount = v!),
                  ),
                  const SizedBox(height: 12),
                ],
                if (selectedAcquisitionType == 'shareholderContribution') ...[
                  if (shareholders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('No shareholders registered yet.', style: TextStyle(color: Colors.red, fontSize: 12)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedShareholderId,
                      decoration: const InputDecoration(labelText: 'Contributed By Shareholder *'),
                      items: shareholders.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name'] as String))).toList(),
                      onChanged: (v) => setState(() => selectedShareholderId = v),
                    ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cost / Value (AED) *', hintText: '7500.00'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: dateCtrl,
                        decoration: const InputDecoration(labelText: 'Purchase / Entry Date *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: usefulMonthsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Useful Life (Months) *', hintText: '36'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: residualCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Residual Value (AED)', hintText: '0.00'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(labelText: 'Location', hintText: 'Main Office'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: selectedEmployeeId,
                        decoration: const InputDecoration(labelText: 'Assigned Employee'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Unassigned')),
                          ...employees.map((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['name'] as String))),
                        ],
                        onChanged: (v) => setState(() => selectedEmployeeId = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: serialCtrl,
                  decoration: const InputDecoration(labelText: 'Serial Number / Hardware ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty || cost <= 0) return;

              String? shName;
              if (selectedShareholderId != null) {
                final match = shareholders.where((s) => s['id'] == selectedShareholderId).firstOrNull;
                shName = match?['name'] as String?;
              }

              String? empName;
              if (selectedEmployeeId != null) {
                final match = employees.where((e) => e['id'] == selectedEmployeeId).firstOrNull;
                empName = match?['name'] as String?;
              }

              final payload = {
                if (asset != null) 'id': asset['id'],
                if (asset != null) 'version': asset['version'] ?? 0,
                'name': name,
                'code': codeCtrl.text.trim(),
                'category': selectedCategory,
                'acquisitionType': selectedAcquisitionType,
                'paymentAccount': selectedPaymentAccount,
                'shareholderId': selectedShareholderId ?? '',
                'shareholderName': shName ?? '',
                'cost': cost,
                'purchaseDate': dateCtrl.text.trim(),
                'usefulLifeMonths': int.tryParse(usefulMonthsCtrl.text.trim()) ?? 36,
                'residualValue': double.tryParse(residualCtrl.text.trim()) ?? 0.0,
                'location': locationCtrl.text.trim(),
                'assignedEmployeeId': selectedEmployeeId ?? '',
                'assignedEmployeeName': empName ?? '',
                'serialNumber': serialCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'status': asset?['status'] ?? 'active',
              };

              context.read<OfficeCubit>().run('assetSave', payload);
              Navigator.pop(ctx);
            },
            child: const Text('Save Asset'),
          ),
        ],
      ),
    ),
  );
}

void _showAssetDetailsModal(BuildContext context, Map<String, dynamic> asset) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cost = (asset['costCents'] as num?)?.toInt() ?? scaled((asset['cost'] ?? 0).toString(), 2);
  final accDep = (asset['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
  final book = (cost - accDep).clamp(0, cost);
  final residual = scaled((asset['residualValue'] ?? 0).toString(), 2);
  final months = (asset['usefulLifeMonths'] as num?)?.toInt() ?? 36;
  final depCalc = calculateDepreciation(costCents: cost, residualValueCents: residual, usefulLifeMonths: months);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(asset['name'] as String? ?? 'Asset Details'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DetailTile('Original Cost', currency(cost)),
                _DetailTile('Accumulated Dep.', currency(accDep)),
                _DetailTile('Book Value', currency(book), isHighlight: true),
              ],
            ),
            const Divider(height: 24),
            Text('Depreciation Schedule (Straight-Line)', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly Depreciation:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                Text(currency(depCalc['monthlyCents'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Annual Depreciation:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                Text(currency(depCalc['annualCents'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Useful Life:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                Text('$months Months', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Acquisition Type:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                Text(asset['acquisitionType'] ?? 'Company Purchase', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if ((asset['shareholderName'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Contributed By:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Text(asset['shareholderName'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ],
              ),
            ],
            if ((asset['serialNumber'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Serial Number:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Text(asset['serialNumber'], style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

class _DetailTile extends StatelessWidget {
  final String title;
  final String value;
  final bool isHighlight;
  const _DetailTile(this.title, this.value, {this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFF10B981) : null)),
      ],
    );
  }
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
