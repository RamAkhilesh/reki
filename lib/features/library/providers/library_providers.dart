// ─────────────────────────────────────────────────────────────
// lib/features/library/providers/library_providers.dart
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models/bookmark.dart';
import '../../bookmarks/providers/bookmark_providers.dart';

// Named indices for ShellScreen tabs — use these instead of magic numbers
abstract class ShellTab {
  static const home = 0;
  static const search = 1;
  static const library = 2;
  static const settings = 3;
}

// Controls which tab is active in ShellScreen (0 = Home, 1 = Search, 2 = Library)
final shellTabIndexProvider = StateProvider<int>((ref) => 0);

// Incremented each time the Library tab is tapped while already active.
// LibraryScreen listens and requests focus on its search field.
final librarySearchFocusRequestProvider = StateProvider<int>((ref) => 0);

// Set by the Home screen before switching to the Library shell tab.
// _LibraryTabView reads this to jump to the correct media-type tab on mount,
// and via ref.listen for navigations when the Library is already visible.
// Reset to null after it is consumed.
final pendingLibraryTabTypeProvider = StateProvider<String?>((ref) => null);

// ── Sort order ────────────────────────────────────────────────

enum SortOrder { recentlyAdded, lastUpdated, titleAZ, titleZA, highestRated, lowestRated }

extension SortOrderLabel on SortOrder {
  String get label => switch (this) {
        SortOrder.recentlyAdded => 'Recently Added',
        SortOrder.lastUpdated => 'Last Updated',
        SortOrder.titleAZ => 'Title A–Z',
        SortOrder.titleZA => 'Title Z–A',
        SortOrder.highestRated => 'Highest Rated',
        SortOrder.lowestRated => 'Lowest Rated',
      };
}

// ── Display mode ──────────────────────────────────────────────

enum DisplayMode { compactGrid, comfortableGrid, list }

extension DisplayModeInfo on DisplayMode {
  String get label => switch (this) {
        DisplayMode.compactGrid => 'Compact Grid',
        DisplayMode.comfortableGrid => 'Comfortable Grid',
        DisplayMode.list => 'List',
      };

  String get description => switch (this) {
        DisplayMode.compactGrid => '4 columns · title over poster',
        DisplayMode.comfortableGrid => '3 columns · title below poster',
        DisplayMode.list => 'Single column list',
      };
}

// ── SharedPreferences ─────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in ProviderScope');
});

// ── Display mode notifier (persisted) ────────────────────────

class DisplayModeNotifier extends Notifier<DisplayMode> {
  static const _key = 'library_display_mode';

  @override
  DisplayMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_key);
    return DisplayMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => DisplayMode.comfortableGrid,
    );
  }

  void set(DisplayMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final displayModeProvider =
    NotifierProvider<DisplayModeNotifier, DisplayMode>(DisplayModeNotifier.new);

// ── Filter providers ──────────────────────────────────────────

// Media type filter for the library — null means All
final typeFilterProvider = StateProvider<String?>((ref) => null);

// Current sort order
final sortOrderProvider =
    StateProvider<SortOrder>((ref) => SortOrder.recentlyAdded);

// Minimum rating filter (out of 10) — null means no filter
final minRatingFilterProvider = StateProvider<int?>((ref) => null);

// Genre filter — null means no filter
final genreFilterProvider = StateProvider<String?>((ref) => null);

// True when any non-default filter/sort is active — drives the header badge dot.
// Type filter is handled by the tab bar, so only status, rating, genre + sort are checked.
final hasActiveFiltersProvider = Provider<bool>((ref) {
  final status = ref.watch(statusFilterProvider);
  final sort = ref.watch(sortOrderProvider);
  final minRating = ref.watch(minRatingFilterProvider);
  final genre = ref.watch(genreFilterProvider);
  return status != null ||
      sort != SortOrder.recentlyAdded ||
      minRating != null ||
      genre != null;
});

// Filtered and sorted library bookmarks (type + status + rating + genre + sort combined)
final libraryBookmarksProvider = Provider<AsyncValue<List<Bookmark>>>((ref) {
  final bookmarksAsync = ref.watch(bookmarkListProvider);
  final typeFilter = ref.watch(typeFilterProvider);
  final statusFilter = ref.watch(statusFilterProvider);
  final sortOrder = ref.watch(sortOrderProvider);
  final minRating = ref.watch(minRatingFilterProvider);
  final genre = ref.watch(genreFilterProvider);

  return bookmarksAsync.whenData((list) {
    var filtered = list;
    if (typeFilter != null) {
      filtered =
          filtered.where((b) => b.mediaItem.mediaType == typeFilter).toList();
    }
    if (statusFilter != null) {
      filtered = filtered.where((b) => b.status == statusFilter).toList();
    }
    if (minRating != null) {
      filtered =
          filtered.where((b) => (b.rating ?? 0) >= minRating).toList();
    }
    if (genre != null) {
      filtered =
          filtered.where((b) => b.mediaItem.genres.contains(genre)).toList();
    }
    return sortedBookmarks(filtered, sortOrder);
  });
});

List<Bookmark> sortedBookmarks(List<Bookmark> list, SortOrder order) {
  final copy = [...list];
  switch (order) {
    case SortOrder.recentlyAdded:
      copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case SortOrder.lastUpdated:
      copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    case SortOrder.titleAZ:
      copy.sort(
        (a, b) => a.mediaItem.title
            .toLowerCase()
            .compareTo(b.mediaItem.title.toLowerCase()),
      );
    case SortOrder.titleZA:
      copy.sort(
        (a, b) => b.mediaItem.title
            .toLowerCase()
            .compareTo(a.mediaItem.title.toLowerCase()),
      );
    case SortOrder.highestRated:
      copy.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    case SortOrder.lowestRated:
      copy.sort((a, b) => (a.rating ?? 0).compareTo(b.rating ?? 0));
  }
  return copy;
}

// Top 10 most recently updated bookmarks across all types
final recentlyActiveProvider = Provider<AsyncValue<List<Bookmark>>>((ref) {
  final bookmarksAsync = ref.watch(bookmarkListProvider);
  return bookmarksAsync.whenData((list) {
    final copy = [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy.take(10).toList();
  });
});

// ── Library tab order & visibility ───────────────────────────
// Persists which media-type tabs are visible and in what order.

class LibraryTabEntry {
  final String type;
  final bool visible;

  const LibraryTabEntry({required this.type, required this.visible});
}

class LibraryTabOrderNotifier extends Notifier<List<LibraryTabEntry>> {
  static const _key = 'library_tab_config';
  static const allTypes = [
    'all', 'movie', 'tv', 'anime', 'manga', 'game', 'book',
  ];

  @override
  List<LibraryTabEntry> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw == null) {
      return allTypes.map((t) => LibraryTabEntry(type: t, visible: true)).toList();
    }
    try {
      final decoded = jsonDecode(raw) as List;
      final entries = decoded
          .map((e) => LibraryTabEntry(type: e['t'] as String, visible: e['v'] as bool))
          .toList();
      // Append any newly-supported type that isn't in the stored list yet.
      for (final type in allTypes) {
        if (!entries.any((e) => e.type == type)) {
          entries.add(LibraryTabEntry(type: type, visible: true));
        }
      }
      return entries;
    } catch (_) {
      return allTypes.map((t) => LibraryTabEntry(type: t, visible: true)).toList();
    }
  }

  // Called by SliverReorderableList — indices are within the visible sublist.
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final visible = state.where((e) => e.visible).toList();
    final hidden = state.where((e) => !e.visible).toList();
    final item = visible.removeAt(oldIndex);
    visible.insert(newIndex, item);
    state = [...visible, ...hidden];
    _persist();
  }

  void toggleVisibility(String type) {
    state = [
      for (final e in state)
        if (e.type == type)
          LibraryTabEntry(type: e.type, visible: !e.visible)
        else
          e,
    ];
    _persist();
  }

  void _persist() {
    final json = jsonEncode(
      state.map((e) => {'t': e.type, 'v': e.visible}).toList(),
    );
    ref.read(sharedPreferencesProvider).setString(_key, json);
  }
}

final libraryTabOrderProvider =
    NotifierProvider<LibraryTabOrderNotifier, List<LibraryTabEntry>>(
  LibraryTabOrderNotifier.new,
);

// Ordered, visibility-filtered list of types that also have bookmarks.
// 'all' is always included when visible (it aggregates everything).
// This is what drives the library tab bar.
final presentMediaTypesProvider = Provider<AsyncValue<List<String>>>((ref) {
  final bookmarksAsync = ref.watch(bookmarkListProvider);
  final tabOrder = ref.watch(libraryTabOrderProvider);
  return bookmarksAsync.whenData((list) {
    final found = <String>{for (final b in list) b.mediaItem.mediaType};
    return tabOrder
        .where((e) => e.visible && (e.type == 'all' || found.contains(e.type)))
        .map((e) => e.type)
        .toList();
  });
});

// ── Last active library tab (persisted) ───────────────────────

class LastLibraryTabNotifier extends Notifier<String?> {
  static const _key = 'library_last_tab';

  @override
  String? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_key);
  }

  void save(String type) {
    state = type;
    ref.read(sharedPreferencesProvider).setString(_key, type);
  }
}

final lastLibraryTabProvider =
    NotifierProvider<LastLibraryTabNotifier, String?>(LastLibraryTabNotifier.new);

// ── Collapsed status groups per tab (persisted) ───────────────
// Maps tab type ('all', 'movie', etc.) → set of collapsed status strings.

class CollapsedStatusGroupsNotifier
    extends Notifier<Map<String, Set<String>>> {
  static const _key = 'library_collapsed_groups';

  @override
  Map<String, Set<String>> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, Set<String>.from((v as List).cast<String>())),
      );
    } catch (_) {
      return {};
    }
  }

  void toggleStatus(String tabType, String status) {
    final next = Map<String, Set<String>>.from(
      state.map((k, v) => MapEntry(k, Set<String>.from(v))),
    );
    final tabSet = next[tabType] ?? {};
    if (tabSet.contains(status)) {
      tabSet.remove(status);
    } else {
      tabSet.add(status);
    }
    next[tabType] = tabSet;
    state = next;
    _persist();
  }

  void _persist() {
    final json = jsonEncode(
      state.map((k, v) => MapEntry(k, v.toList())),
    );
    ref.read(sharedPreferencesProvider).setString(_key, json);
  }
}

final collapsedStatusGroupsProvider = NotifierProvider<
    CollapsedStatusGroupsNotifier, Map<String, Set<String>>>(
  CollapsedStatusGroupsNotifier.new,
);

// Per-category stats used by the Home tab category cards
class CategoryStats {
  final String mediaType;
  final int total;
  final List<Bookmark> recentFour;
  final Map<String, int> statusCounts;

  const CategoryStats({
    required this.mediaType,
    required this.total,
    required this.recentFour,
    required this.statusCounts,
  });

  String get statusSummary {
    final parts = <String>[];
    void add(String key) {
      final n = statusCounts[key];
      if (n != null && n > 0) parts.add('$n ${BookmarkStatus.label(key)}');
    }

    add(BookmarkStatus.watching);
    add(BookmarkStatus.completed);
    add(BookmarkStatus.wantToWatch);
    add(BookmarkStatus.onHold);
    add(BookmarkStatus.dropped);
    return parts.join(' · ');
  }
}

final categoryStatsProvider = Provider<AsyncValue<List<CategoryStats>>>((ref) {
  final bookmarksAsync = ref.watch(bookmarkListProvider);
  return bookmarksAsync.whenData((list) {
    const types = ['movie', 'tv', 'anime', 'manga', 'game', 'book'];
    return types.map((type) {
      final forType =
          list.where((b) => b.mediaItem.mediaType == type).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final counts = <String, int>{};
      for (final b in forType) {
        counts[b.status] = (counts[b.status] ?? 0) + 1;
      }
      return CategoryStats(
        mediaType: type,
        total: forType.length,
        recentFour: forType.take(4).toList(),
        statusCounts: counts,
      );
    }).toList();
  });
});
