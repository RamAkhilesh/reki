// ─────────────────────────────────────────────────────────────
// lib/core/config/tmdb_config.dart
//
// Values are injected at build time via --dart-define-from-file=secrets.json
// ─────────────────────────────────────────────────────────────

class TmdbConfig {
  static const String readAccessToken = String.fromEnvironment('TMDB_TOKEN');

  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
}
