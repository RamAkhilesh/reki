// ─────────────────────────────────────────────────────────────
// lib/core/config/google_books_config.dart
//
// Values are injected at build time via --dart-define-from-file=secrets.json
// ─────────────────────────────────────────────────────────────

class GoogleBooksConfig {
  static const String apiKey = String.fromEnvironment('GOOGLE_BOOKS_KEY');
  static const String baseUrl = 'https://www.googleapis.com/books/v1';
}
