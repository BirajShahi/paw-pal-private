/// Reads Supabase connection values from compile-time environment defines.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Whether both required values were provided at build/run time.
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
