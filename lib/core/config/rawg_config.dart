// ─────────────────────────────────────────────────────────────
// lib/core/config/rawg_config.dart
//
// Values are injected at build time via --dart-define-from-file=secrets.json
// ─────────────────────────────────────────────────────────────

class RawgConfig {
  static const String apiKey = String.fromEnvironment('RAWG_KEY');
  static const String baseUrl = 'https://api.rawg.io/api';
}
