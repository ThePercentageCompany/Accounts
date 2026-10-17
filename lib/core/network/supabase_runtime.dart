import 'package:supabase_flutter/supabase_flutter.dart';

const _defaultSupabaseUrl = 'https://ifuucosaautgobwsunmp.supabase.co';
// Publishable keys are public client configuration; never put a secret key here.
const _defaultSupabaseKey = 'sb_publishable_lLPDVb8F51KcQfniJxisVg_3n1OOWJf';
const configuredSupabaseUrl =
    String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultSupabaseUrl);
const configuredSupabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY',
    defaultValue: configuredSupabaseUrl == _defaultSupabaseUrl
        ? _defaultSupabaseKey
        : '');

SupabaseClient? get currentSupabaseClient {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

Future<void> initializeSupabase() async {
  if (configuredSupabaseKey.isEmpty) return;
  await Supabase.initialize(
      url: configuredSupabaseUrl,
      publishableKey: configuredSupabaseKey,
      authOptions: const FlutterAuthClientOptions(
        persistSession: true,
        autoRefreshToken: true,
      ));
}
