/// Payroll periods follow the salary month, independently of creation/pay dates.
bool payrollMatchesPeriod(Map<String, dynamic> row,
    {required String scope, required int year, required int month}) {
  if (scope == 'all') return true;
  final value = '${row['month'] ?? ''}';
  if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) return false;
  if (int.parse(value.substring(0, 4)) != year) return false;
  return scope == 'year' || int.parse(value.substring(5, 7)) == month;
}
