import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;
  final bool isRequired;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.validator,
    this.isRequired = false,
    this.firstDate,
    this.lastDate,
  });

  Future<void> _pickDate(BuildContext context) async {
    DateTime initial = DateTime.tryParse(value) ?? DateTime.now();
    final first = firstDate ?? DateTime(2020);
    final last = lastDate ?? DateTime(2035);

    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark ? AppTheme.dark() : AppTheme.light(),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      onChanged(DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _applyOffset(int days) {
    final now = DateTime.now();
    final target = now.add(Duration(days: days));
    onChanged(DateFormat('yyyy-MM-dd').format(target));
  }

  void _applyEndOfMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final endOfMonth = nextMonth.subtract(const Duration(days: 1));
    onChanged(DateFormat('yyyy-MM-dd').format(endOfMonth));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: ValueKey(value),
            initialValue: value,
            readOnly: true,
            onTap: () => _pickDate(context),
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(CupertinoIcons.calendar, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(CupertinoIcons.calendar_today, size: 18),
                onPressed: () => _pickDate(context),
                tooltip: 'Select date',
              ),
            ),
            validator: validator ?? (isRequired ? (v) => v == null || v.isEmpty ? 'Required' : null : null),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _presetPill(context, 'Today', () => _applyOffset(0), isDark),
                _presetPill(context, '+7d', () => _applyOffset(7), isDark),
                _presetPill(context, '+15d', () => _applyOffset(15), isDark),
                _presetPill(context, '+30d', () => _applyOffset(30), isDark),
                _presetPill(context, 'End of month', _applyEndOfMonth, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetPill(BuildContext context, String title, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.pastelBlue : AppTheme.pastelBlue,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}
