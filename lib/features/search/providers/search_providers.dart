// ─────────────────────────────────────────────────────────────
// lib/features/search/providers/search_providers.dart
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/media_item.dart';
import '../../bookmarks/providers/bookmark_providers.dart';

// ── Filter types ────────────────────────────────────────────────

enum LibraryFilter { all, inLibrary, notInLibrary }

class SearchFilters {
  final Set<String> mediaTypes; // empty = all
  final LibraryFilter libraryFilter;
  final String? language; // null = all; BCP-47 code e.g. 'en', 'ja', 'ko'

  const SearchFilters({
    this.mediaTypes = const {},
    this.libraryFilter = LibraryFilter.all,
    this.language,
  });

  bool get isActive =>
      mediaTypes.isNotEmpty ||
      libraryFilter != LibraryFilter.all ||
      language != null;

  SearchFilters copyWith({
    Set<String>? mediaTypes,
    LibraryFilter? libraryFilter,
    String? language,
    bool clearLanguage = false,
  }) =>
      SearchFilters(
        mediaTypes: mediaTypes ?? this.mediaTypes,
        libraryFilter: libraryFilter ?? this.libraryFilter,
        language: clearLanguage ? null : (language ?? this.language),
      );
}

// Incremented each time the Search tab is tapped while already active.
final searchFocusRequestProvider = StateProvider<int>((ref) => 0);

// Incremented when the user navigates away from the Search tab.
final searchResetProvider = StateProvider<int>((ref) => 0);

// Set by the Library screen when the user taps "Search in Discover".
// SearchScreen listens, pre-fills its field, and resets to null after consuming.
final pendingSearchQueryProvider = StateProvider<String?>((ref) => null);

// ── Discovery feed ─────────────────────────────────────────────

final trendingThisWeekProvider =
    FutureProvider.autoDispose<List<MediaItem>>((ref) {
  return ref.read(tmdbServiceProvider).fetchTrending(timeWindow: 'week');
});

final popularRightNowProvider =
    FutureProvider.autoDispose<List<MediaItem>>((ref) {
  return ref.read(tmdbServiceProvider).fetchTrending(timeWindow: 'day');
});

final trendingAnimeProvider =
    FutureProvider.autoDispose<List<MediaItem>>((ref) {
  return ref.read(anilistServiceProvider).fetchTrending(type: 'ANIME');
});

final trendingMangaProvider =
    FutureProvider.autoDispose<List<MediaItem>>((ref) {
  return ref.read(anilistServiceProvider).fetchTrending(type: 'MANGA');
});

final popularGamesProvider =
    FutureProvider.autoDispose<List<MediaItem>>((ref) {
  return ref.read(rawgServiceProvider).fetchPopular();
});

final popularBooksProvider =
    FutureProvider.autoDispose<List<MediaItem>>((ref) {
  return ref.read(googleBooksServiceProvider).fetchPopular();
});

// ── Library key set — for "already bookmarked" detection ───────

/// Set of "source:externalId" composite keys for items in the user's library.
final libraryKeySetProvider = Provider<Set<String>>((ref) {
  final bAsync = ref.watch(bookmarkListProvider);
  return bAsync
          .whenData(
            (list) => list
                .map((b) =>
                    '${b.mediaItem.source}:${b.mediaItem.externalId}')
                .toSet(),
          )
          .value ??
      {};
});

// ── Search state ───────────────────────────────────────────────

class SearchState {
  final String query;
  final List<MediaItem> results;
  final bool isSearching;
  final String? error;
  final SearchFilters activeFilters;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.error,
    this.activeFilters = const SearchFilters(),
  });

  bool get showResults => query.trim().isNotEmpty || isSearching;

  SearchState copyWith({
    String? query,
    List<MediaItem>? results,
    bool? isSearching,
    String? error,
    bool clearError = false,
    SearchFilters? activeFilters,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : (error ?? this.error),
      activeFilters: activeFilters ?? this.activeFilters,
    );
  }
}

// ── Search notifier ────────────────────────────────────────────

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(const SearchState());

  final Ref _ref;
  Timer? _debounce;

  void onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      state = const SearchState();
      return;
    }
    state = state.copyWith(query: q, isSearching: true, clearError: true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    final filters = state.activeFilters;
    final types = filters.mediaTypes; // empty = all

    // Decide which APIs to query based on active media type filter.
    // When a media type filter is set, only hit the relevant API(s).
    final wantsTmdb = types.isEmpty || types.any((t) => t == 'movie' || t == 'tv');
    // AniList takes precedence for anime/manga/manhwa.
    final wantsAnilist = types.isEmpty || types.any((t) => t == 'anime' || t == 'manga');
    final wantsBooks = types.isEmpty || types.contains('book');
    final wantsGames = types.isEmpty || types.contains('game');

    Future<List<MediaItem>> safe(Future<List<MediaItem>> f) =>
        f.catchError((_) => <MediaItem>[]);

    try {
      final results = await Future.wait([
        // AniList first so anime/manga results appear before TMDB's TV entries
        // for the same titles — gives AniList visual precedence.
        if (wantsAnilist)
          safe(_ref.read(anilistServiceProvider).search(q))
        else
          Future.value(<MediaItem>[]),
        if (wantsTmdb)
          safe(_ref.read(tmdbServiceProvider).searchMulti(q))
        else
          Future.value(<MediaItem>[]),
        if (wantsBooks)
          safe(_ref.read(googleBooksServiceProvider).search(q, language: filters.language))
        else
          Future.value(<MediaItem>[]),
        if (wantsGames)
          safe(_ref.read(rawgServiceProvider).search(q))
        else
          Future.value(<MediaItem>[]),
      ]);

      if (mounted) {
        // Flatten: AniList, TMDB, Books, Games
        final all = results.expand((list) => list).toList();
        state = state.copyWith(results: all, isSearching: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isSearching: false, error: e.toString());
      }
    }
  }

  void setFilters(SearchFilters filters) {
    state = state.copyWith(activeFilters: filters);
    // Re-run search with new filters if there's an active query.
    if (state.query.trim().isNotEmpty) {
      _debounce?.cancel();
      state = state.copyWith(isSearching: true, clearError: true);
      _debounce = Timer(
        const Duration(milliseconds: 100),
        () => _doSearch(state.query),
      );
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchNotifierProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});
