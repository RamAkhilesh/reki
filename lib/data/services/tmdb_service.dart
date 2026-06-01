// ─────────────────────────────────────────────────────────────
// lib/data/services/tmdb_service.dart
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';

import '../../core/config/tmdb_config.dart';
import '../models/media_item.dart';
import '../models/tmdb_media_details.dart';

class TmdbService {
  late final Dio _dio;

  TmdbService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: TmdbConfig.baseUrl,
        headers: {'Authorization': 'Bearer ${TmdbConfig.readAccessToken}'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  /// Fetches trending movies+TV from TMDB.
  /// [timeWindow] is either 'day' or 'week'.
  Future<List<MediaItem>> fetchTrending({String timeWindow = 'week'}) async {
    if (TmdbConfig.readAccessToken.isEmpty) return [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/trending/all/$timeWindow',
      queryParameters: {'include_adult': false},
    );
    final results = response.data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv')
        .where((r) => (r['poster_path'] as String?) != null)
        .map(MediaItem.fromTmdbJson)
        .take(10)
        .toList();
  }

  /// Fetches movies currently playing in theatres.
  Future<List<MediaItem>> fetchNowPlayingMovies() async {
    if (TmdbConfig.readAccessToken.isEmpty) return [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/now_playing',
      queryParameters: {'include_adult': false},
    );
    final results = response.data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((r) => (r['poster_path'] as String?) != null)
        .map((r) => MediaItem.fromTmdbJson({...r, 'media_type': 'movie'}))
        .take(10)
        .toList();
  }

  /// Fetches trending TV shows for the week.
  Future<List<MediaItem>> fetchTrendingTv() async {
    if (TmdbConfig.readAccessToken.isEmpty) return [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/trending/tv/week',
      queryParameters: {'include_adult': false},
    );
    final results = response.data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((r) => !_isAnime(r))
        .where((r) => (r['poster_path'] as String?) != null)
        .map((r) => MediaItem.fromTmdbJson({...r, 'media_type': 'tv'}))
        .take(10)
        .toList();
  }

  /// Fetches movies similar to [id].
  Future<List<MediaItem>> fetchSimilarMovies(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/movie/$id/similar');
    final results = response.data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((r) => (r['poster_path'] as String?) != null)
        .map((r) => MediaItem.fromTmdbJson({...r, 'media_type': 'movie'}))
        .take(15)
        .toList();
  }

  /// Fetches TV shows similar to [id].
  Future<List<MediaItem>> fetchSimilarTv(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/tv/$id/similar');
    final results = response.data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((r) => (r['poster_path'] as String?) != null)
        .map((r) => MediaItem.fromTmdbJson({...r, 'media_type': 'tv'}))
        .take(15)
        .toList();
  }

  /// Fetches full details for a movie, including credits.
  Future<MediaDetails> fetchMovieDetails(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/$id',
      queryParameters: {'append_to_response': 'credits'},
    );
    return MediaDetails.fromMovieJson(response.data!);
  }

  /// Fetches full details for a TV show, including credits and created_by.
  Future<MediaDetails> fetchTvDetails(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/tv/$id',
      queryParameters: {'append_to_response': 'credits'},
    );
    return MediaDetails.fromTvJson(response.data!);
  }

  // Returns true for Japanese animated TV shows (anime) so they can be
  // excluded from TMDB results — AniList is the authoritative source for those.
  // Returns true for Japanese animated content (anime TV shows and movies)
  // so they can be excluded from TMDB results — AniList is authoritative.
  static bool _isAnime(Map<String, dynamic> r) {
    final genreIds = (r['genre_ids'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];
    if (!genreIds.contains(16)) return false; // not Animation

    final mediaType = r['media_type'] as String?;

    if (mediaType == 'tv') {
      final countries = (r['origin_country'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [];
      return countries.contains('JP');
    }

    if (mediaType == 'movie') {
      // Movies don't have origin_country in /search/multi; use
      // original_language as the signal instead.
      return r['original_language'] == 'ja';
    }

    return false;
  }

  /// Searches TMDB for movies and TV shows matching [query].
  Future<List<MediaItem>> searchMulti(String query) async {
    if (query.trim().length < 2 || TmdbConfig.readAccessToken.isEmpty) {
      return [];
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/search/multi',
      queryParameters: {'query': query.trim(), 'include_adult': false},
    );

    final results = response.data?['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv')
        .where((r) => (r['poster_path'] as String?) != null)
        .where((r) => !_isAnime(r))
        .map(MediaItem.fromTmdbJson)
        .toList();
  }
}
