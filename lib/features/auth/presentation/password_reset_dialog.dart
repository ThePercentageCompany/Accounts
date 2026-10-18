import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tpc_invoice/core/network/supabase_runtime.dart';

class PasswordResetDialog extends StatefulWidget {
  const PasswordResetDialog({super.key, this.onSave});
  final Future<void> Function(String password)? onSave;
  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(), confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('Set a new password'),
        content: SingleChildScrollView(
            child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      controller: password,
                      obscureText: true,
                      enabled: !busy,
                      decoration:
                          const InputDecoration(labelText: 'New password'),
                      validator: (value) => (value?.length ?? 0) >= 8
                          ? null
                          : 'Use at least eight characters.'),
                  TextFormField(
                      controller: confirm,
                      obscureText: true,
                      enabled: !busy,
                      decoration:
                          const InputDecoration(labelText: 'Confirm password'),
                      validator: (value) => value == password.text
                          ? null
                          : 'Passwords must match.'),
                  if (error != null) Text(error!),
                ]))),
        actions: [
          FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        if (widget.onSave != null) {
                          await widget.onSave!(password.text);
                        } else {
                          final client = currentSupabaseClient;
                          if (client?.auth.currentSession == null) {
                            throw const AuthException(
                                'Your reset link has expired. Request a new link from Forgot password.');
                          }
                          if (client!.auth.currentUser?.appMetadata['kind'] ==
                              'employee') {
                            throw const AuthException(
                                'Ask your admin to reset your employee login code.');
                          }
                          await client.auth.updateUser(
                              UserAttributes(password: password.text));
                        }
                        if (context.mounted) Navigator.pop(context, true);
                      } on AuthException catch (failure) {
                        if (mounted) setState(() => error = failure.message);
                      } catch (_) {
                        if (mounted) {
                          setState(() => error =
                              'Could not update your password. Check your connection and retry.');
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('Save password'))
        ],
      ));
}
