import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/report_models.dart';

class ReportFilterBar extends StatelessWidget {
  final ReportFilter filter;
  final ValueChanged<ReportFilter> onFilterChanged;
  final VoidCallback? onRefresh;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportCsv;

  const ReportFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    this.onRefresh,
    this.onExportPdf,
    this.onExportCsv,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Date Range Preset Pill Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 0.8,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateRangePreset>(
                value: filter.preset,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                icon: const Icon(CupertinoIcons.chevron_down, size: 13),
                isDense: true,
                items: [
                  for (final p in DateRangePreset.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                ],
                onChanged: (p) {
                  if (p != null) {
                    onFilterChanged(filter.copyWith(preset: p));
                  }
                },
              ),
            ),
          ),

          // Formatted Date Range Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                const Icon(CupertinoIcons.calendar, size: 13, color: Color(0xFF10B981)),
                Text(
                  '${df.format(filter.startDate)} – ${df.format(filter.endDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),

          // Accounting Basis Selector & Actions Wrap
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Accounting Basis Selector
              SegmentedButton<AccountingBasis>(
                segments: const [
                  ButtonSegment(
                    value: AccountingBasis.accrual,
                    label: Text('Accrual', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                  ButtonSegment(
                    value: AccountingBasis.cash,
                    label: Text('Cash', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                ],
                selected: {filter.basis},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    onFilterChanged(filter.copyWith(basis: set.first));
                  }
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              // Export CSV / Excel Button
              if (onExportCsv != null)
                IconButton(
                  tooltip: 'Export CSV / Excel',
                  icon: const Icon(CupertinoIcons.arrow_down_doc, size: 18),
                  onPressed: onExportCsv,
                ),

              // Export PDF Button
              if (onExportPdf != null)
                IconButton(
                  tooltip: 'Export PDF Report',
                  icon: const Icon(CupertinoIcons.printer, size: 18),
                  onPressed: onExportPdf,
                ),

              // Refresh Button
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Refresh Ledger',
                  icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
                  onPressed: onRefresh,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
