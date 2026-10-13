import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key, required this.api});
  final SaasApi api;
  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false, createAccount = false;
  String? message;
  Future<void> run(Future<void> Function() action) async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } on AuthException catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => message = error is SaasApiException
            ? error.message
            : 'Could not sign in. Retry when connected.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(createAccount ? 'Create admin account' : 'Admin sign in'),
        content: SizedBox(
            width: 400,
            child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      controller: email,
                      enabled: !busy,
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter a valid email.'),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: password,
                      enabled: !busy,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : 'Use at least eight characters.'),
                  if (message != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(message!)),
                  if (busy)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator()),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                createAccount = !createAccount;
                                message = null;
                              }),
                      child: Text(createAccount
                          ? 'Already have an account? Sign in'
                          : 'Create an admin account')),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (!email.text.contains('@')) {
                                setState(
                                    () => message = 'Enter your email first.');
                                return;
                              }
                              setState(() => busy = true);
                              try {
                                await widget.api.resetPassword(email.text);
                                if (mounted) {
                                  setState(() => message =
                                      'Check your email for the password reset link.');
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(() => message =
                                      'Could not send the reset email. Retry.');
                                }
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      child: const Text('Forgot password?')),
                ]))),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                        if (createAccount) {
                          final signedIn = await widget.api
                              .signUp(email.text, password.text);
                          if (!signedIn) {
                            if (mounted) {
                              setState(() => message =
                                  'Check your email to confirm your account, then sign in.');
                            }
                            return;
                          }
                        } else {
                          await widget.api
                              .signInWithPassword(email.text, password.text);
                        }
                        if (context.mounted) Navigator.pop(context, true);
                      }),
              child: Text(createAccount ? 'Create account' : 'Sign in')),
        ],
      );
}
