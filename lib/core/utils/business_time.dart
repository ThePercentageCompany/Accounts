import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;
tz.Location _location(String zone) {
  if (!_initialized) {
    data.initializeTimeZones();
    _initialized = true;
  }
  return tz.getLocation(zone);
}

DateTime businessNow(String zone) => tz.TZDateTime.now(_location(zone));
DateTime businessTimestamp(int epoch, String zone) =>
    tz.TZDateTime.fromMillisecondsSinceEpoch(_location(zone), epoch);
