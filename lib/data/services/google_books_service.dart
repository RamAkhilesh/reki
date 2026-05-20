// ─────────────────────────────────────────────────────────────
// lib/data/services/google_books_service.dart
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';

import '../../core/config/google_books_config.dart';
import '../models/media_item.dart';
import '../models/tmdb_media_details.dart';

class GoogleBooksService {
  late final Dio _dio;

  GoogleBooksService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: GoogleBooksConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  bool get _hasKey => GoogleBooksConfig.apiKey.isNotEmpty;

  // ── Search ─────────────────────────────────────────────────

  /// [language] is a BCP-47 language code (e.g. 'en', 'ja', 'ko').
  /// Pass null to search across all languages.
  Future<List<MediaItem>> search(String query, {String? language}) async {
    if (query.trim().length < 2 || !_hasKey) return [];

    final params = <String, dynamic>{
      'q': query.trim(),
      'key': GoogleBooksConfig.apiKey,
      'maxResults': 20,
      'printType': 'books',
    };
    if (language != null) params['langRestrict'] = language;

    final response = await _dio.get<Map<String, dynamic>>(
      '/volumes',
      queryParameters: params,
    );

    final items = response.data?['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromGoogleBooksJson)
        .toList();
  }

  // ── Popular ────────────────────────────────────────────────

  Future<List<MediaItem>> fetchPopular() async {
    if (!_hasKey) return [];

    final response = await _dio.get<Map<String, dynamic>>(
      '/volumes',
      queryParameters: {
        'q': 'subject:fiction',
        'key': GoogleBooksConfig.apiKey,
        'maxResults': 15,
        'orderBy': 'relevance',
        'printType': 'books',
      },
    );

    final items = response.data?['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromGoogleBooksJson)
        .toList();
  }

  // ── Detail ─────────────────────────────────────────────────

  Future<MediaDetails> fetchDetails(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/volumes/$id',
      queryParameters: _hasKey ? {'key': GoogleBooksConfig.apiKey} : null,
    );

    if (response.data == null) {
      throw Exception('Google Books: no data for id $id');
    }
    return MediaDetails.fromGoogleBooksJson(response.data!);
  }
}
