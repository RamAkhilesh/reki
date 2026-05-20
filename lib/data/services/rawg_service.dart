// ─────────────────────────────────────────────────────────────
// lib/data/services/rawg_service.dart
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';

import '../../core/config/rawg_config.dart';
import '../models/media_item.dart';
import '../models/tmdb_media_details.dart';

class RawgService {
  late final Dio _dio;

  RawgService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: RawgConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  bool get _hasKey => RawgConfig.apiKey.isNotEmpty;

  // ── Search ─────────────────────────────────────────────────

  Future<List<MediaItem>> search(String query) async {
    if (query.trim().length < 2 || !_hasKey) return [];

    final response = await _dio.get<Map<String, dynamic>>(
      '/games',
      queryParameters: {
        'key': RawgConfig.apiKey,
        'search': query.trim(),
        'page_size': 20,
        'search_precise': true,
      },
    );

    final results = response.data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((g) => (g['background_image'] as String?) != null)
        .map(MediaItem.fromRawgJson)
        .toList();
  }

  // ── Popular ────────────────────────────────────────────────

  Future<List<MediaItem>> fetchPopular() async {
    if (!_hasKey) return [];

    final response = await _dio.get<Map<String, dynamic>>(
      '/games',
      queryParameters: {
        'key': RawgConfig.apiKey,
        'ordering': '-metacritic',
        'page_size': 15,
      },
    );

    final results = response.data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((g) => (g['background_image'] as String?) != null)
        .map(MediaItem.fromRawgJson)
        .toList();
  }

  // ── Detail ─────────────────────────────────────────────────

  Future<MediaDetails> fetchDetails(int id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/games/$id',
      queryParameters: _hasKey ? {'key': RawgConfig.apiKey} : null,
    );

    if (response.data == null) {
      throw Exception('RAWG: no data for id $id');
    }
    return MediaDetails.fromRawgJson(response.data!);
  }
}
