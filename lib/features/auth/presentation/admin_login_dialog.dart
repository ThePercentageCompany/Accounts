import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key, required this.api});
  final SaasApi api;
  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false,
      createAccount = false,
      showPassword = false,
      resetting = false;
  String? message;
  bool hasError = false;

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
      hasError = false;
    });
    try {
      if (createAccount) {
        final signedIn = await widget.api.signUp(email.text, password.text);
        if (!signedIn) {
          if (mounted) {
            setState(() => message =
                'Check your email to confirm your account, then sign in.');
          }
          return;
        }
      } else {
        await widget.api.signInWithPassword(email.text, password.text);
      }
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          message = error.message;
          hasError = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          message = error is SaasApiException
              ? error.message
              : 'Could not sign in. Retry when connected.';
          hasError = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    if (busy) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
      setState(() {
        message = 'Enter a valid email to receive a reset link.';
        hasError = true;
      });
      return;
    }
    setState(() {
      busy = true;
      resetting = true;
      message = null;
      hasError = false;
    });
    try {
      await widget.api.resetPassword(email.text);
      if (mounted) {
        setState(() => message =
            'Check your email, including spam, for the reset link. Open it in this browser to set your new password.');
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          message = failure is AuthException
              ? failure.message
              : failure is SaasApiException
                  ? failure.message
                  : 'Could not send the reset email. Check your connection and retry.';
          hasError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          resetting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
        canPop: !busy,
        child: Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: AutofillGroup(
                        child: Form(
                            key: form,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: colors.primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        child: Icon(
                                            Icons.business_center_outlined,
                                            color: colors.onPrimaryContainer)),
                                    const Spacer(),
                                    IconButton(
                                        tooltip: 'Close',
                                        onPressed: busy
                                            ? null
                                            : () =>
                                                Navigator.pop(context, false),
                                        icon: const Icon(Icons.close)),
                                  ]),
                                  const SizedBox(height: 24),
                                  Text(
                                      createAccount
                                          ? 'Create your account'
                                          : 'Sign in to your workspace',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 10),
                                  Text(
                                      createAccount
                                          ? 'Set up an admin account to manage your business.'
                                          : 'Enter your admin email and password to continue.',
                                      style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          height: 1.5)),
                                  const SizedBox(height: 28),
                                  TextFormField(
                                      controller: email,
                                      enabled: !busy,
                                      autofillHints: const [
                                        AutofillHints.username,
                                        AutofillHints.email
                                      ],
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      decoration: const InputDecoration(
                                          labelText: 'Email address',
                                          prefixIcon: Icon(Icons.mail_outline),
                                          border: OutlineInputBorder()),
                                      validator: (value) =>
                                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                  .hasMatch(value?.trim() ?? '')
                                              ? null
                                              : 'Enter a valid email address.'),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                      controller: password,
                                      enabled: !busy,
                                      obscureText: !showPassword,
                                      autofillHints: [
                                        createAccount
                                            ? AutofillHints.newPassword
                                            : AutofillHints.password
                                      ],
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => submit(),
                                      decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon:
                                              const Icon(Icons.lock_outline),
                                          border: const OutlineInputBorder(),
                                          suffixIcon: IconButton(
                                              tooltip: showPassword
                                                  ? 'Hide password'
                                                  : 'Show password',
                                              onPressed: busy
                                                  ? null
                                                  : () => setState(() =>
                                                      showPassword =
                                                          !showPassword),
                                              icon: Icon(showPassword
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons
                                                      .visibility_outlined))),
                                      validator: (value) => createAccount
                                          ? (value?.length ?? 0) >= 8
                                              ? null
                                              : 'Use at least eight characters.'
                                          : (value?.isNotEmpty ?? false)
                                              ? null
                                              : 'Enter your password.'),
                                  if (!createAccount)
                                    Align(
                                        alignment: Alignment.centerRight,
                                        child: LoadingButton.text(
                                            onPressed:
                                                busy ? null : resetPassword,
                                            busy: resetting,
                                            child: const Text(
                                                'Forgot password?'))),
                                  if (message != null)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        child: Semantics(
                                            liveRegion: true,
                                            child: Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                    color: hasError
                                                        ? colors.errorContainer
                                                        : colors
                                                            .secondaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                child: Text(message!,
                                                    style: TextStyle(
                                                        color: hasError
                                                            ? colors
                                                                .onErrorContainer
                                                            : colors
                                                                .onSecondaryContainer))))),
                                  const SizedBox(height: 14),
                                  LoadingButton(
                                      key: const Key('admin-sign-in-button'),
                                      busy: busy && !resetting,
                                      onPressed: busy ? null : submit,
                                      style: FilledButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(52)),
                                      child: Text(busy && !resetting
                                          ? createAccount
                                              ? 'Creating account...'
                                              : 'Signing in...'
                                          : createAccount
                                              ? 'Create account'
                                              : 'Sign in')),
                                  const SizedBox(height: 16),
                                  TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => setState(() {
                                                createAccount = !createAccount;
                                                message = null;
                                                form.currentState?.reset();
                                              }),
                                      child: Text(createAccount
                                          ? 'Already have an account? Sign in'
                                          : 'New here? Create an admin account')),
                                ])))))));
  }
}
