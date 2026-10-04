import 'report_print_stub.dart'
    if (dart.library.js_interop) 'report_print_web.dart';

Future<void> printReport(String html) => printReportPlatform(html);
