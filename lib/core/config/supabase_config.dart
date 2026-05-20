// ─────────────────────────────────────────────────────────────
// lib/core/config/supabase_config.dart
//
// Values are injected at build time via --dart-define-from-file=secrets.json
// ─────────────────────────────────────────────────────────────

class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
