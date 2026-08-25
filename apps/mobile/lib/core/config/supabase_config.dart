import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project configuration.
/// Replace these with your actual Supabase project values.
///
/// url  → Project Settings → API → Project URL
/// anonKey → Project Settings → API → anon/public key
class SupabaseConfig {
  SupabaseConfig._(); // Prevent instantiation

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ampsqwrdldvkldjwckrb.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFtcHNxd3JkbGR2a2xkandja3JiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NjY1NzksImV4cCI6MjA5NTU0MjU3OX0.AUK6KqOeg-Vd9uMRy4DGD9qzfuytxPnTy0LLXnzgViI',
  );

  static const String fastApiUrl = String.fromEnvironment(
    'FASTAPI_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Singleton Supabase client — use everywhere in the app
  static SupabaseClient get client => Supabase.instance.client;
}
