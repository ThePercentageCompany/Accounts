import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/utils/business_time.dart';

void main() {
  test('entity timestamps preserve India half-hour offset', () {
    final instant = DateTime.utc(2026, 1, 14, 22).millisecondsSinceEpoch;
    final time = businessTimestamp(instant, 'Asia/Kolkata');
    expect(time.day, 15);
    expect(time.hour, 3);
    expect(time.minute, 30);
  });
  test('entity timestamps follow London daylight saving', () {
    expect(
        businessTimestamp(DateTime.utc(2026, 7, 14, 12).millisecondsSinceEpoch,
                'Europe/London')
            .hour,
        13);
    expect(
        businessTimestamp(DateTime.utc(2026, 1, 14, 12).millisecondsSinceEpoch,
                'Europe/London')
            .hour,
        12);
  });
}
