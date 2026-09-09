import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';

void main() {
  test('GoogleSession initial state is unauthenticated', () {
    final session = GoogleSession();
    expect(session.user, isNull);
    expect(session.authorized, isFalse);
    expect(session.workspace, isNull);
    expect(session.isAuthorizing, isFalse);
  });

  test('GoogleSession expire resets authorized state', () {
    final session = GoogleSession();
    session.authorized = true;
    session.expire();
    expect(session.authorized, isFalse);
  });
}

