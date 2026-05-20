// ─────────────────────────────────────────────────────────────
// lib/features/media_detail/providers/media_detail_providers.dart
//
// Key format for both providers: "source:mediaType:externalId"
// e.g. "tmdb:movie:550" | "anilist:anime:20" | "google_books:book:abc123"
// ─────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/media_item.dart';
import '../../../data/models/tmdb_media_details.dart';
import '../../bookmarks/providers/bookmark_providers.dart';

final mediaDetailsProvider =
    FutureProvider.autoDispose.family<MediaDetails, String>(
  (ref, key) async {
    final parts = key.split(':');
    if (parts.length < 3) {
      throw ArgumentError('Invalid detail key format: $key');
    }
    final source = parts[0];
    final mediaType = parts[1];
    final externalId = parts.sublist(2).join(':'); // re-join in case id has colons

    switch (source) {
      case 'tmdb':
        final tmdb = ref.read(tmdbServiceProvider);
        if (mediaType == 'movie') return tmdb.fetchMovieDetails(externalId);
        if (mediaType == 'tv') return tmdb.fetchTvDetails(externalId);
        throw UnsupportedError('TMDB detail not supported for type: $mediaType');

      case 'anilist':
        final anilistId = int.tryParse(externalId);
        if (anilistId == null) throw ArgumentError('Invalid AniList ID: $externalId');
        return ref.read(anilistServiceProvider).fetchDetails(anilistId);

      case 'google_books':
        return ref.read(googleBooksServiceProvider).fetchDetails(externalId);

      case 'rawg':
        final rawgId = int.tryParse(externalId);
        if (rawgId == null) throw ArgumentError('Invalid RAWG ID: $externalId');
        return ref.read(rawgServiceProvider).fetchDetails(rawgId);

      default:
        throw UnsupportedError('Unknown source: $source');
    }
  },
);

final relatedMediaProvider =
    FutureProvider.autoDispose.family<List<MediaItem>, String>(
  (ref, key) async {
    final parts = key.split(':');
    if (parts.length < 3) return [];
    final source = parts[0];
    final mediaType = parts[1];
    final externalId = parts.sublist(2).join(':');

    switch (source) {
      case 'tmdb':
        final tmdb = ref.read(tmdbServiceProvider);
        if (mediaType == 'movie') return tmdb.fetchSimilarMovies(externalId);
        if (mediaType == 'tv') return tmdb.fetchSimilarTv(externalId);
        return [];

      case 'anilist':
        final anilistId = int.tryParse(externalId);
        if (anilistId == null) return [];
        return ref.read(anilistServiceProvider).fetchRelated(anilistId);

      // Google Books and RAWG: no related items for now
      default:
        return [];
    }
  },
);
