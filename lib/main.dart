import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:tpc_invoice/features/auth/presentation/saas_app.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/core/network/supabase_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
          title: 'TPC Business Suite',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,
          home: const SaasApp(),
        ),
      );
}
