/// New records first, independent of their editable business/issue date.
/// Older records without timestamps retain reverse insertion order.
List<Map<String, dynamic>> newestRecordsFirst(
    Iterable<Map<String, dynamic>> records) {
  final indexed = records.toList().asMap().entries.toList();
  int created(Map<String, dynamic> row) {
    final value = row['createdAt'] ?? row['created_at'];
    return (value is num ? value.toInt() : int.tryParse('$value')) ??
        DateTime.tryParse('$value')?.millisecondsSinceEpoch ?? 0;
  }
  indexed.sort((a, b) {
    final byCreated = created(b.value).compareTo(created(a.value));
    return byCreated != 0 ? byCreated : b.key.compareTo(a.key);
  });
  return indexed.map((entry) => entry.value).toList();
}
