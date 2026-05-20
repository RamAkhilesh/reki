// ─────────────────────────────────────────────────────────────
// lib/data/models/media_item.dart
// ─────────────────────────────────────────────────────────────

import '../../core/config/tmdb_config.dart';

class MediaItem {
  final String? id; // Supabase UUID — null until persisted
  final String externalId; // TMDB / AniList / Google Books / RAWG ID
  final String source; // 'tmdb' | 'anilist' | 'google_books' | 'rawg'
  final String mediaType; // 'movie' | 'tv' | 'anime' | 'manga' | 'book' | 'game'
  final String title;
  final String? posterUrl;
  final List<String> genres;
  final int? runtimeMinutes;
  final int? episodeCount;
  final String? overview;

  const MediaItem({
    this.id,
    required this.externalId,
    required this.source,
    required this.mediaType,
    required this.title,
    this.posterUrl,
    this.genres = const [],
    this.runtimeMinutes,
    this.episodeCount,
    this.overview,
  });

  factory MediaItem.fromTmdbJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String;
    final title = (json['title'] ?? json['name'] ?? '') as String;
    final posterPath = json['poster_path'] as String?;

    return MediaItem(
      externalId: json['id'].toString(),
      source: 'tmdb',
      mediaType: mediaType == 'movie' ? 'movie' : 'tv',
      title: title,
      posterUrl:
          posterPath != null ? '${TmdbConfig.imageBaseUrl}$posterPath' : null,
      overview: json['overview'] as String?,
    );
  }

  /// Constructs from a single AniList `Media` node (ANIME or MANGA type).
  /// [json] is the media object from the AniList GraphQL response.
  factory MediaItem.fromAnilistJson(Map<String, dynamic> json) {
    final titleMap = json['title'] as Map<String, dynamic>? ?? {};
    final title = (titleMap['english'] as String?)?.isNotEmpty == true
        ? titleMap['english'] as String
        : (titleMap['romaji'] as String?) ?? '';

    final coverImage = json['coverImage'] as Map<String, dynamic>? ?? {};
    final posterUrl = (coverImage['large'] as String?) ??
        (coverImage['medium'] as String?);

    final format = json['format'] as String? ?? '';
    final type = json['type'] as String? ?? '';
    final mediaType = _anilistMediaType(type, format);

    final genres = (json['genres'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    final episodes = json['episodes'] as int?;
    final chapters = json['chapters'] as int?;

    return MediaItem(
      externalId: json['id'].toString(),
      source: 'anilist',
      mediaType: mediaType,
      title: title,
      posterUrl: posterUrl,
      genres: genres,
      episodeCount: episodes ?? chapters,
      overview: json['description'] as String?,
    );
  }

  factory MediaItem.fromGoogleBooksJson(Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? {};
    final title = (volumeInfo['title'] as String?) ?? '';
    final bookId = json['id'] as String;

    // Prefer imageLinks.thumbnail from the API response (most accurate).
    // Remove edge=curl (adds a visual curl effect) and normalise to HTTPS.
    // Fall back to a constructed URL when imageLinks is absent.
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    final rawUrl = (imageLinks?['thumbnail'] as String?) ??
        (imageLinks?['smallThumbnail'] as String?);
    final posterUrl = rawUrl != null
        ? rawUrl
            .replaceFirst('http://', 'https://')
            .replaceAll('&edge=curl', '')
        : 'https://books.google.com/books/content'
            '?id=$bookId&printsec=frontcover&img=1&zoom=1&source=gbs_api';

    final categories =
        (volumeInfo['categories'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    final pageCount = volumeInfo['pageCount'] as int?;

    return MediaItem(
      externalId: bookId,
      source: 'google_books',
      mediaType: 'book',
      title: title,
      posterUrl: posterUrl,
      genres: categories,
      runtimeMinutes: pageCount,
      overview: volumeInfo['description'] as String?,
    );
  }

  factory MediaItem.fromRawgJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? '';
    final posterUrl = json['background_image'] as String?;
    final genres = (json['genres'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((g) => g['name'] as String)
            .toList() ??
        [];

    return MediaItem(
      externalId: json['id'].toString(),
      source: 'rawg',
      mediaType: 'game',
      title: name,
      posterUrl: posterUrl,
      genres: genres,
      overview: json['short_screenshots'] != null
          ? null
          : null, // description comes from detail endpoint
    );
  }

  factory MediaItem.fromSupabaseJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      externalId: json['external_id'] as String,
      source: json['source'] as String,
      mediaType: json['media_type'] as String,
      title: json['title'] as String,
      posterUrl: json['poster_url'] as String?,
      genres:
          (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      runtimeMinutes: json['runtime_minutes'] as int?,
      episodeCount: json['episode_count'] as int?,
      overview: json['overview'] as String?,
    );
  }

  Map<String, dynamic> toSupabaseJson() => {
    'external_id': externalId,
    'source': source,
    'media_type': mediaType,
    'title': title,
    if (posterUrl != null) 'poster_url': posterUrl,
    'genres': genres,
    if (runtimeMinutes != null) 'runtime_minutes': runtimeMinutes,
    if (episodeCount != null) 'episode_count': episodeCount,
  };

  /// HTTP headers required to load [posterUrl] in CachedNetworkImage.
  /// books.google.com blocks requests without a browser User-Agent.
  Map<String, String>? get posterHeaders => source == 'google_books'
      ? const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://books.google.com',
        }
      : null;

  String get mediaTypeLabel {
    return switch (mediaType) {
      'movie' => 'Movie',
      'tv' => 'TV Show',
      'anime' => 'Anime',
      'manga' => 'Manga',
      'book' => 'Book',
      'game' => 'Game',
      _ => mediaType,
    };
  }

  // Maps AniList type + format to our internal mediaType string.
  static String _anilistMediaType(String type, String format) {
    if (type == 'ANIME') return 'anime';
    // MANGA type covers manga, manhwa, manhua, novels
    return 'manga';
  }
}
