import 'package:http/http.dart' as http;

http.Client createSaasTransport() => throw UnsupportedError(
  'SaaS cookie sessions currently require the web application.',
);
