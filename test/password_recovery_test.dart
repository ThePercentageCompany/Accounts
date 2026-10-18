import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/auth/domain/password_recovery.dart';
import 'package:tpc_invoice/features/auth/presentation/password_reset_dialog.dart';

class RecoveryTestStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test('reset redirect uses the app origin and identifies recovery', () {
    expect(
        passwordRecoveryRedirect(
                Uri.parse('https://accounts.example/app/#task=private'))
            .toString(),
        'https://accounts.example/?auth=recovery');
    expect(passwordRecoveryRedirect(Uri.parse('file:///app')).toString(),
        'https://accounts.thepercentagecompany.com/?auth=recovery');
    expect(isPasswordRecoveryLink(Uri.parse('https://app/?auth=recovery')),
        isTrue);
    expect(
        isPasswordRecoveryLink(
            Uri.parse('https://app/#type=recovery&access_token=example')),
        isTrue);
    expect(
        isPasswordRecoveryLink(Uri.parse('https://app/#employee-invite=abc')),
        isFalse);
  });

  test('forgot password sends the email and callback to Supabase recovery',
      () async {
    var calls = 0;
    final auth = SupabaseClient('https://auth.test', 'public-key',
        authOptions: AuthClientOptions(pkceAsyncStorage: RecoveryTestStorage()),
        httpClient: MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/auth/v1/recover');
      expect((jsonDecode(request.body) as Map)['email'], 'admin@example.com');
      expect(request.url.queryParameters['redirect_to'],
          contains('auth=recovery'));
      return http.Response('{}', 200);
    }));
    final api = SaasApi(origin: 'https://api.test', auth: auth);
    addTearDown(api.close);
    addTearDown(auth.dispose);
    await api.resetPassword(' admin@example.com ');
    expect(calls, 1);
  });

  testWidgets(
      'reset validates confirmation and retries after a network failure',
      (tester) async {
    var calls = 0;
    bool? saved;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      saved = await showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              PasswordResetDialog(onSave: (password) async {
                                calls++;
                                expect(password, 'new-password-123');
                                if (calls == 1) throw Exception('Network down');
                              }));
                    },
                    child: const Text('Reset'))))));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new-password-123');
    await tester.enterText(fields.at(1), 'different');
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Passwords must match.'), findsOneWidget);
    await tester.enterText(fields.at(1), 'new-password-123');
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Check your connection and retry'), findsOneWidget);
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(saved, isTrue);
  });
}
