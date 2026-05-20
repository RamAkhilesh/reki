// ─────────────────────────────────────────────────────────────
// lib/data/models/tmdb_media_details.dart
//
// Unified media details model used by the detail screen.
// Named MediaDetails; factories exist for TMDB, AniList, Google Books, RAWG.
// ─────────────────────────────────────────────────────────────

class TvSeason {
  final int seasonNumber;
  final String name;
  final int? episodeCount;
  final String? posterUrl;
  final String? airDate;

  const TvSeason({
    required this.seasonNumber,
    required this.name,
    this.episodeCount,
    this.posterUrl,
    this.airDate,
  });

  String? get airYear {
    if (airDate == null || airDate!.length < 4) return null;
    return airDate!.substring(0, 4);
  }
}

class CastMember {
  final String name;
  final String? character;
  final String? profileUrl;

  const CastMember({
    required this.name,
    this.character,
    this.profileUrl,
  });
}

class CrewMember {
  final String name;
  final String job;
  final String? profileUrl;

  const CrewMember({
    required this.name,
    required this.job,
    this.profileUrl,
  });
}

class MediaDetails {
  final String externalId;
  final String source; // 'tmdb' | 'anilist' | 'google_books' | 'rawg'
  final String mediaType; // 'movie' | 'tv' | 'anime' | 'manga' | 'book' | 'game'
  final String title;
  final String? tagline;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final String? releaseDate;
  final int? runtimeMinutes;
  final int? episodeCount;
  final int? seasonCount;
  final int? pageCount; // books: page count; manga: chapter count
  final List<String> genres;
  final double? score; // normalized 0–10 for display
  final int? scoreCount;
  final String? scoreSource; // 'TMDB' | 'AniList' | 'Google Books' | 'Metacritic'
  final String? status;
  final List<CastMember> cast;
  final List<CrewMember> crew; // directors / authors / developers
  final List<TvSeason> seasons;
  final List<String> platforms; // games only
  final String? anilistFormat; // e.g. 'MANGA' | 'MANHWA' | 'ONA' | 'TV'

  const MediaDetails({
    required this.externalId,
    required this.source,
    required this.mediaType,
    required this.title,
    this.tagline,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.releaseDate,
    this.runtimeMinutes,
    this.episodeCount,
    this.seasonCount,
    this.pageCount,
    this.genres = const [],
    this.score,
    this.scoreCount,
    this.scoreSource,
    this.status,
    this.cast = const [],
    this.crew = const [],
    this.seasons = const [],
    this.platforms = const [],
    this.anilistFormat,
  });

  // ── TMDB factories ─────────────────────────────────────────

  factory MediaDetails.fromMovieJson(Map<String, dynamic> json) {
    final credits = json['credits'] as Map<String, dynamic>?;
    final rawCast = (credits?['cast'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .take(15)
            .toList() ??
        [];
    final rawCrew = (credits?['crew'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .where((c) => c['job'] == 'Director')
            .toList() ??
        [];

    return MediaDetails(
      externalId: json['id'].toString(),
      source: 'tmdb',
      mediaType: 'movie',
      title: (json['title'] as String?) ?? '',
      tagline: _nonEmpty(json['tagline'] as String?),
      overview: _nonEmpty(json['overview'] as String?),
      posterUrl: _tmdbImageUrl(json['poster_path'] as String?, 'w500'),
      backdropUrl: _tmdbImageUrl(json['backdrop_path'] as String?, 'w1280'),
      releaseDate: json['release_date'] as String?,
      runtimeMinutes: json['runtime'] as int?,
      genres: _parseGenreList(json['genres']),
      score: (json['vote_average'] as num?)?.toDouble(),
      scoreCount: json['vote_count'] as int?,
      scoreSource: 'TMDB',
      status: json['status'] as String?,
      cast: rawCast
          .map((c) => CastMember(
                name: (c['name'] as String?) ?? '',
                character: _nonEmpty(c['character'] as String?),
                profileUrl: _tmdbImageUrl(c['profile_path'] as String?, 'w185'),
              ))
          .toList(),
      crew: rawCrew
          .map((c) => CrewMember(
                name: (c['name'] as String?) ?? '',
                job: (c['job'] as String?) ?? 'Director',
                profileUrl: _tmdbImageUrl(c['profile_path'] as String?, 'w185'),
              ))
          .toList(),
    );
  }

  factory MediaDetails.fromTvJson(Map<String, dynamic> json) {
    final credits = json['credits'] as Map<String, dynamic>?;
    final rawCast = (credits?['cast'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .take(15)
            .toList() ??
        [];
    final rawCreators = (json['created_by'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final rawSeasons = (json['seasons'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .where((s) => (s['season_number'] as int? ?? 0) > 0)
            .toList() ??
        [];

    return MediaDetails(
      externalId: json['id'].toString(),
      source: 'tmdb',
      mediaType: 'tv',
      title: (json['name'] as String?) ?? '',
      tagline: _nonEmpty(json['tagline'] as String?),
      overview: _nonEmpty(json['overview'] as String?),
      posterUrl: _tmdbImageUrl(json['poster_path'] as String?, 'w500'),
      backdropUrl: _tmdbImageUrl(json['backdrop_path'] as String?, 'w1280'),
      releaseDate: json['first_air_date'] as String?,
      episodeCount: json['number_of_episodes'] as int?,
      seasonCount: json['number_of_seasons'] as int?,
      genres: _parseGenreList(json['genres']),
      score: (json['vote_average'] as num?)?.toDouble(),
      scoreCount: json['vote_count'] as int?,
      scoreSource: 'TMDB',
      status: json['status'] as String?,
      cast: rawCast
          .map((c) => CastMember(
                name: (c['name'] as String?) ?? '',
                character: _nonEmpty(c['character'] as String?),
                profileUrl: _tmdbImageUrl(c['profile_path'] as String?, 'w185'),
              ))
          .toList(),
      crew: rawCreators
          .map((c) => CrewMember(
                name: (c['name'] as String?) ?? '',
                job: 'Creator',
                profileUrl: _tmdbImageUrl(c['profile_path'] as String?, 'w185'),
              ))
          .toList(),
      seasons: rawSeasons
          .map((s) => TvSeason(
                seasonNumber: s['season_number'] as int,
                name: (s['name'] as String?) ??
                    'Season ${s['season_number']}',
                episodeCount: s['episode_count'] as int?,
                posterUrl: _tmdbImageUrl(s['poster_path'] as String?, 'w300'),
                airDate: s['air_date'] as String?,
              ))
          .toList(),
    );
  }

  // ── AniList factory ────────────────────────────────────────

  /// [json] is the `Media` object from the AniList `Media(id:)` query.
  factory MediaDetails.fromAnilistJson(Map<String, dynamic> json) {
    final titleMap = json['title'] as Map<String, dynamic>? ?? {};
    final title = (titleMap['english'] as String?)?.isNotEmpty == true
        ? titleMap['english'] as String
        : (titleMap['romaji'] as String?) ?? '';

    final coverImage = json['coverImage'] as Map<String, dynamic>? ?? {};
    final posterUrl = (coverImage['extraLarge'] as String?) ??
        (coverImage['large'] as String?) ??
        (coverImage['medium'] as String?);

    final type = json['type'] as String? ?? '';
    final format = json['format'] as String? ?? '';
    final mediaType = type == 'ANIME' ? 'anime' : 'manga';

    final genres = (json['genres'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    // score from AniList is 0–100, normalize to 0–10
    final rawScore = json['averageScore'] as int?;
    final score = rawScore != null ? rawScore / 10.0 : null;

    // Start date
    final startDate = json['startDate'] as Map<String, dynamic>?;
    final year = startDate?['year'] as int?;
    final month = startDate?['month'] as int?;
    final day = startDate?['day'] as int?;
    String? releaseDate;
    if (year != null) {
      releaseDate = [
        year.toString(),
        if (month != null) month.toString().padLeft(2, '0'),
        if (day != null) day.toString().padLeft(2, '0'),
      ].join('-');
    }

    // Cast: characters + voice actors
    final charEdges = (json['characters'] as Map<String, dynamic>?)?['edges']
            as List<dynamic>? ??
        [];
    final cast = charEdges.whereType<Map<String, dynamic>>().map((edge) {
      final node = edge['node'] as Map<String, dynamic>? ?? {};
      final charName =
          (node['name'] as Map<String, dynamic>?)?['full'] as String? ?? '';
      final charImage =
          (node['image'] as Map<String, dynamic>?)?['medium'] as String?;
      final vaList =
          (edge['voiceActors'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final va = vaList.isNotEmpty ? vaList.first : null;
      final vaName =
          va != null
              ? ((va['name'] as Map<String, dynamic>?)?['full'] as String?)
              : null;
      return CastMember(
        name: vaName ?? charName,
        character: vaName != null ? charName : null,
        profileUrl: charImage,
      );
    }).toList();

    // Crew: staff
    final staffEdges =
        (json['staff'] as Map<String, dynamic>?)?['edges'] as List<dynamic>? ??
        [];
    final crew = staffEdges.whereType<Map<String, dynamic>>().map((edge) {
      final node = edge['node'] as Map<String, dynamic>? ?? {};
      final name =
          (node['name'] as Map<String, dynamic>?)?['full'] as String? ?? '';
      final profileUrl =
          (node['image'] as Map<String, dynamic>?)?['medium'] as String?;
      final role = (edge['role'] as String?) ?? 'Staff';
      return CrewMember(name: name, job: role, profileUrl: profileUrl);
    }).toList();

    final anilistStatus = json['status'] as String?;
    final status = _anilistStatus(anilistStatus);

    return MediaDetails(
      externalId: json['id'].toString(),
      source: 'anilist',
      mediaType: mediaType,
      title: title,
      overview: _nonEmpty(json['description'] as String?),
      posterUrl: posterUrl,
      backdropUrl: json['bannerImage'] as String?,
      releaseDate: releaseDate,
      episodeCount:
          (json['episodes'] as int?) ?? (json['chapters'] as int?),
      genres: genres,
      score: score,
      scoreCount: json['popularity'] as int?,
      scoreSource: 'AniList',
      status: status,
      cast: cast,
      crew: crew,
      anilistFormat: format.isNotEmpty ? format : null,
    );
  }

  // ── Google Books factory ───────────────────────────────────

  /// [json] is a single Google Books volume object.
  factory MediaDetails.fromGoogleBooksJson(Map<String, dynamic> json) {
    final vol = json['volumeInfo'] as Map<String, dynamic>? ?? {};

    final title = (vol['title'] as String?) ?? '';
    // Construct cover URL from ID — zoom=0 gives the largest available size.
    final bookId = json['id'] as String;
    final posterUrl =
        'https://books.google.com/books/content'
        '?id=$bookId&printsec=frontcover&img=1&zoom=0';

    final authors = (vol['authors'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    final categories = (vol['categories'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    final rawScore = vol['averageRating'] as num?;
    final score = rawScore?.toDouble();
    final scoreCount = vol['ratingsCount'] as int?;

    final crew = authors
        .map((a) => CrewMember(name: a, job: 'Author'))
        .toList();

    return MediaDetails(
      externalId: json['id'] as String,
      source: 'google_books',
      mediaType: 'book',
      title: title,
      overview: _nonEmpty(vol['description'] as String?),
      posterUrl: posterUrl,
      releaseDate: vol['publishedDate'] as String?,
      pageCount: vol['pageCount'] as int?,
      genres: categories,
      score: score,
      scoreCount: scoreCount,
      scoreSource: 'Google Books',
      status: vol['printType'] as String?,
      crew: crew,
    );
  }

  // ── RAWG factory ───────────────────────────────────────────

  /// [json] is a RAWG game detail object (from /games/{id}).
  factory MediaDetails.fromRawgJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? '';
    final posterUrl = json['background_image'] as String?;
    final backdropUrl = json['background_image_additional'] as String?;

    final genres = (json['genres'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((g) => g['name'] as String)
            .toList() ??
        [];
    final platforms = (json['platforms'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((p) =>
                ((p['platform'] as Map<String, dynamic>?))?['name']
                    as String? ??
                '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final devs = (json['developers'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final pubs = (json['publishers'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final crew = [
      ...devs.map(
        (d) => CrewMember(name: (d['name'] as String?) ?? '', job: 'Developer'),
      ),
      ...pubs.map(
        (p) =>
            CrewMember(name: (p['name'] as String?) ?? '', job: 'Publisher'),
      ),
    ];

    // Metacritic is 0–100; normalize to 0–10
    final metacritic = json['metacritic'] as int?;
    final score = metacritic != null ? metacritic / 10.0 : null;

    return MediaDetails(
      externalId: json['id'].toString(),
      source: 'rawg',
      mediaType: 'game',
      title: name,
      overview: _nonEmpty(json['description_raw'] as String?),
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      releaseDate: json['released'] as String?,
      genres: genres,
      score: score,
      scoreCount: json['ratings_count'] as int?,
      scoreSource: 'Metacritic',
      status: json['tba'] == true ? 'TBA' : null,
      crew: crew,
      platforms: platforms,
    );
  }

  // ── Derived helpers ────────────────────────────────────────

  String? get releaseYear {
    if (releaseDate == null || releaseDate!.length < 4) return null;
    return releaseDate!.substring(0, 4);
  }

  String? get runtimeLabel {
    if (runtimeMinutes == null) return null;
    final h = runtimeMinutes! ~/ 60;
    final m = runtimeMinutes! % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String? get episodeLabel {
    if (mediaType == 'book') {
      if (pageCount == null) return null;
      return '$pageCount pages';
    }
    if (episodeCount == null && seasonCount == null) return null;
    final parts = <String>[];
    if (seasonCount != null) {
      parts.add('$seasonCount ${seasonCount == 1 ? 'season' : 'seasons'}');
    }
    if (episodeCount != null) {
      final label = mediaType == 'manga' ? 'ch' : 'ep';
      parts.add('$episodeCount $label');
    }
    return parts.join(' · ');
  }

  String get crewLabel {
    return switch (mediaType) {
      'movie' => 'Director',
      'tv' => 'Created by',
      'anime' => 'Staff',
      'manga' => 'Staff',
      'book' => 'Author',
      'game' => 'Developer',
      _ => 'Credits',
    };
  }

  // ── Private helpers ────────────────────────────────────────

  static String? _nonEmpty(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s;

  static String? _tmdbImageUrl(String? path, String size) {
    if (path == null) return null;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  static List<String> _parseGenreList(dynamic raw) {
    return (raw as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((g) => g['name'] as String)
            .toList() ??
        [];
  }

  static String? _anilistStatus(String? raw) {
    return switch (raw) {
      'FINISHED' => 'Finished',
      'RELEASING' => 'Releasing',
      'NOT_YET_RELEASED' => 'Not yet released',
      'CANCELLED' => 'Cancelled',
      'HIATUS' => 'On Hiatus',
      _ => null,
    };
  }
}

// Keep type alias so any code still referencing TmdbMediaDetails compiles.
typedef TmdbMediaDetails = MediaDetails;
