import 'package:supabase_flutter/supabase_flutter.dart';

const configuredSupabaseUrl = String.fromEnvironment('SUPABASE_URL',
    defaultValue: 'https://ifuucosaautgobwsunmp.supabase.co');
const configuredSupabaseKey =
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

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
      url: configuredSupabaseUrl, publishableKey: configuredSupabaseKey);
}
