import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../widgets/brand_logo.dart';
import 'google_session.dart';

/// Opens only the camera; accepting a QR never starts Google authentication.
Future<String?> scanEmployeeQr(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const EmployeeQrScanner(),
  );
}

class EmployeeLoginView extends StatefulWidget {
  const EmployeeLoginView({super.key, required this.session, this.scanQr});

  final GoogleSession session;
  final Future<String?> Function(BuildContext)? scanQr;

  @override
  State<EmployeeLoginView> createState() => _EmployeeLoginViewState();
}

class _EmployeeLoginViewState extends State<EmployeeLoginView> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final value = await (widget.scanQr ?? scanEmployeeQr)(context);
    if (!mounted || value == null) return;
    final accepted = widget.session.acceptEmployeeInvite(value);
    setState(() {
      _code.clear();
      _error = accepted
          ? null
          : 'This employee QR is not supported. Ask your manager for a new QR.';
    });
  }

  Future<void> _login() async {
    if (_busy) return;
    final invite = widget.session.pendingEmployeeInvite;
    if (invite == null || invite.isEmpty) {
      setState(() => _error = 'Scan your employee QR before signing in.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.pairWithEmployeeInvite(
        invite,
        employeeCode: _code.text.trim(),
      );
      _code.clear();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst(
              RegExp(r'^(Exception|Bad state|StateError):\s*'),
              '',
            ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final hasInvite = widget.session.pendingEmployeeInvite?.isNotEmpty ?? false;
        final configured = widget.session.employeeGatewayUrl.isNotEmpty;
        return PopScope(
          canPop: !_busy,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Employee Login'),
              leading: IconButton(
                tooltip: 'Back to sign-in',
                onPressed: _busy ? null : widget.session.cancelEmployeeLogin,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: TpcBrandLogo(size: 60)),
                          const SizedBox(height: 24),
                          Text('Your employee workspace',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text(
                            'Scan the QR provided by your manager, then enter your private login code. No Google account is needed.',
                          ),
                          const SizedBox(height: 24),
                          if (!configured) ...[
                            _message(
                              'Employee login is not set up for this app yet. Ask the company owner to complete employee access setup.',
                              colors.errorContainer,
                              colors.onErrorContainer,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (hasInvite) ...[
                            _message('Employee QR accepted',
                                colors.secondaryContainer, colors.onSecondaryContainer),
                            const SizedBox(height: 12),
                          ],
                          OutlinedButton.icon(
                            onPressed: _busy || !configured ? null : _scan,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(hasInvite ? 'Scan a different QR' : 'Scan QR'),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _code,
                            enabled: hasInvite && configured && !_busy,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Private employee login code',
                              helperText: 'Use the generated login code, not your staff number.',
                              helperMaxLines: 2,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Show login code' : 'Hide login code',
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Enter your private login code.'
                                : null,
                            onFieldSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 20),
                          if (_error != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: _message(_error!, colors.errorContainer, colors.onErrorContainer),
                            ),
                            const SizedBox(height: 16),
                          ],
                          FilledButton.icon(
                            onPressed: hasInvite && configured && !_busy ? _login : null,
                            icon: _busy
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.login),
                            label: Text(_busy ? 'Connecting…' : 'Sign in to workspace'),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your company manages your access. Changes sync with the company workspace while you are online.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _message(String message, Color background, Color foreground) => Container(
        padding: const EdgeInsets.all(14),
        color: background,
        child: Text(message, style: TextStyle(color: foreground)),
      );
}

class EmployeeQrScanner extends StatefulWidget {
  const EmployeeQrScanner({super.key});

  @override
  State<EmployeeQrScanner> createState() => _EmployeeQrScannerState();
}

class _EmployeeQrScannerState extends State<EmployeeQrScanner> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Scan employee QR', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Point the camera at the QR provided by your company manager.'),
              const SizedBox(height: 16),
              Expanded(
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_handled) return;
                    for (final barcode in capture.barcodes) {
                      final value = barcode.rawValue?.trim();
                      if (value == null || value.isEmpty) continue;
                      _handled = true;
                      Navigator.pop(context, value);
                      break;
                    }
                  },
                  errorBuilder: (context, error) => Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        error.errorCode == MobileScannerErrorCode.permissionDenied
                            ? 'Camera access is blocked. Allow camera access in your ${kIsWeb ? 'browser' : 'device'} settings, then reopen the scanner. You can also open the login link from your manager.'
                            : 'Camera scanning is unavailable on this device. Open the employee login link from your manager, or scan the QR on a phone.${kIsWeb ? ' Web camera access requires HTTPS or localhost.' : ''}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ],
          ),
        ),
      );
}
