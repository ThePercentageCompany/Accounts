import 'package:flutter/material.dart';
import 'core/saas/saas_app.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.initialize();
  runApp(const TpcApp());
}

/// Shared-backend entrypoint. No Apps Script or direct Sheets login fallback.
class TpcApp extends StatelessWidget {
  const TpcApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: themeController,
    builder: (context, _) => MaterialApp(
      title: 'TPC Accounts',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.themeMode,
      home: const SaasApp(),
    ),
  );
}
