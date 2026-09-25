import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'saas_api.dart';

/// Opens only the camera; accepting a QR never starts Google authentication.
Future<String?> scanEmployeeQr(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const EmployeeQrScanner(),
  );
}

class EmployeeQrScanner extends StatefulWidget {
  const EmployeeQrScanner({super.key});

  @override
  State<EmployeeQrScanner> createState() => _EmployeeQrScannerState();
}

class _EmployeeQrScannerState extends State<EmployeeQrScanner> {
  bool _handled = false;
  String? _scanError;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scan employee QR',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Point the camera at the QR provided by your company manager.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: MobileScanner(
              // Let the scanner own its controller so it resumes the
              // camera after app/browser lifecycle changes and disposes it.
              onDetect: (capture) {
                if (!mounted || _handled) return;
                for (final barcode in capture.barcodes) {
                  if (barcode.format != BarcodeFormat.qrCode) continue;
                  final value = barcode.rawValue?.trim();
                  if (value == null || value.isEmpty) continue;
                  final link = Uri.tryParse(value);
                  if (link == null ||
                      SaasApi.invitation(link, Uri.base) == null) {
                    setState(
                      () => _scanError =
                          'This is not a current employee QR. Ask your manager to generate a new one.',
                    );
                    continue;
                  }
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
          if (_scanError != null)
            Text(
              _scanError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
