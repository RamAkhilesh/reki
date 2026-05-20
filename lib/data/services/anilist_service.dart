// ─────────────────────────────────────────────────────────────
// lib/data/services/anilist_service.dart
//
// AniList GraphQL API via plain HTTP POST (no graphql_flutter needed).
// No API key required for public read queries.
// ─────────────────────────────────────────────────────────────

import 'package:dio/dio.dart';

import '../../core/config/anilist_config.dart';
import '../models/media_item.dart';
import '../models/tmdb_media_details.dart';

class AnilistService {
  late final Dio _dio;

  AnilistService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AnilistConfig.graphqlUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────

  /// Searches for anime AND manga matching [query]. Returns up to 10 of each.
  Future<List<MediaItem>> search(String query) async {
    if (query.trim().length < 2) return [];

    const gql = r'''
query ($search: String!) {
  anime: Page(perPage: 10) {
    media(search: $search, type: ANIME, isAdult: false) {
      id
      type
      format
      title { romaji english native }
      coverImage { large medium }
      episodes
      genres
      description(asHtml: false)
    }
  }
  manga: Page(perPage: 10) {
    media(search: $search, type: MANGA, isAdult: false) {
      id
      type
      format
      title { romaji english native }
      coverImage { large medium }
      chapters
      genres
      description(asHtml: false)
    }
  }
}
''';

    final response = await _dio.post<Map<String, dynamic>>(
      '',
      data: {'query': gql, 'variables': {'search': query.trim()}},
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};

    final animeList =
        ((data['anime'] as Map<String, dynamic>?)?['media'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .where((m) => _hasCover(m))
            .map(MediaItem.fromAnilistJson)
            .toList() ??
        [];

    final mangaList =
        ((data['manga'] as Map<String, dynamic>?)?['media'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .where((m) => _hasCover(m))
            .map(MediaItem.fromAnilistJson)
            .toList() ??
        [];

    return [...animeList, ...mangaList];
  }

  // ── Trending ───────────────────────────────────────────────

  /// Fetches currently trending entries for [type] ('ANIME' or 'MANGA').
  Future<List<MediaItem>> fetchTrending({required String type}) async {
    const gql = r'''
query ($type: MediaType) {
  Page(perPage: 15) {
    media(sort: TRENDING_DESC, type: $type, isAdult: false) {
      id type format
      title { romaji english }
      coverImage { large medium }
      episodes chapters genres
    }
  }
}
''';

    final response = await _dio.post<Map<String, dynamic>>(
      '',
      data: {'query': gql, 'variables': {'type': type}},
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    final mediaList =
        ((data['Page'] as Map<String, dynamic>?)?['media'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .where((m) => _hasCover(m))
            .map(MediaItem.fromAnilistJson)
            .toList() ??
        [];
    return mediaList;
  }

  // ── Detail ─────────────────────────────────────────────────

  /// Fetches full details for an AniList media entry by [id].
  Future<MediaDetails> fetchDetails(int id) async {
    const gql = r'''
query ($id: Int!) {
  Media(id: $id) {
    id
    type
    format
    title { romaji english native }
    coverImage { extraLarge large medium }
    bannerImage
    episodes
    chapters
    averageScore
    popularity
    genres
    description(asHtml: false)
    status
    startDate { year month day }
    characters(sort: ROLE, perPage: 12) {
      edges {
        node {
          name { full }
          image { medium }
        }
        voiceActors(language: JAPANESE) {
          name { full }
          image { medium }
        }
      }
    }
    staff(perPage: 8) {
      edges {
        node { name { full } image { medium } }
        role
      }
    }
  }
}
''';

    final response = await _dio.post<Map<String, dynamic>>(
      '',
      data: {'query': gql, 'variables': {'id': id}},
    );

    final media =
        (response.data?['data'] as Map<String, dynamic>?)?['Media']
            as Map<String, dynamic>?;

    if (media == null) throw Exception('AniList: no data for id $id');
    return MediaDetails.fromAnilistJson(media);
  }

  /// Fetches related/recommended media for [id] to populate "More Like This".
  Future<List<MediaItem>> fetchRelated(int id) async {
    const gql = r'''
query ($id: Int!) {
  Media(id: $id) {
    relations {
      edges {
        node {
          id
          type
          format
          title { romaji english }
          coverImage { large medium }
          episodes
          chapters
        }
        relationType
      }
    }
  }
}
''';

    final response = await _dio.post<Map<String, dynamic>>(
      '',
      data: {'query': gql, 'variables': {'id': id}},
    );

    final media =
        (response.data?['data'] as Map<String, dynamic>?)?['Media']
            as Map<String, dynamic>?;

    final edges =
        (media?['relations'] as Map<String, dynamic>?)?['edges']
            as List<dynamic>? ??
        [];

    return edges
        .whereType<Map<String, dynamic>>()
        .where((e) {
          final relType = e['relationType'] as String? ?? '';
          // Only include sequels, prequels, alternative, spin-offs
          return ['SEQUEL', 'PREQUEL', 'ALTERNATIVE', 'SIDE_STORY', 'SPIN_OFF']
              .contains(relType);
        })
        .map((e) => e['node'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .where((n) => _hasCover(n))
        .map(MediaItem.fromAnilistJson)
        .take(15)
        .toList();
  }

  static bool _hasCover(Map<String, dynamic> m) {
    final cover = m['coverImage'] as Map<String, dynamic>?;
    return (cover?['large'] ?? cover?['medium']) != null;
  }
}
