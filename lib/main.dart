import 'package:flutter/material.dart';
import 'package:tpc_invoice/features/auth/presentation/saas_app.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/core/network/supabase_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.initialize();
  await initializeSupabase();
  runApp(const TpcApp());
}

/// Supabase Auth, Edge Functions, Storage and Realtime entrypoint.
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
