// ─────────────────────────────────────────────────────────────
// lib/features/bookmarks/providers/bookmark_providers.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/sync_result.dart';
import '../../../data/repositories/bookmark_repository.dart';
import '../../../data/repositories/local_bookmark_store.dart';
import '../../../data/services/anilist_service.dart';
import '../../../data/services/google_books_service.dart';
import '../../../data/services/rawg_service.dart';
import '../../../data/services/sync_resolver.dart';
import '../../../data/services/tmdb_service.dart';
import '../../auth/providers/auth_providers.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(sb.Supabase.instance.client);
});

final localBookmarkStoreProvider = Provider<LocalBookmarkStore>(
  (_) => LocalBookmarkStore(),
);

final tmdbServiceProvider = Provider<TmdbService>((ref) => TmdbService());
final anilistServiceProvider =
    Provider<AnilistService>((ref) => AnilistService());
final googleBooksServiceProvider =
    Provider<GoogleBooksService>((ref) => GoogleBooksService());
final rawgServiceProvider = Provider<RawgService>((ref) => RawgService());

// Holds the result of the last sync so the shell screen can show a snackbar.
// Reset to null after the snackbar has been consumed.
final syncResultProvider = StateProvider<SyncResult?>((ref) => null);

// ── Bookmark list ──────────────────────────────────────────────

class BookmarkListNotifier extends AsyncNotifier<List<Bookmark>> {
  late BookmarkRepository _repo;
  late LocalBookmarkStore _local;

  @override
  Future<List<Bookmark>> build() async {
    _repo = ref.read(bookmarkRepositoryProvider);
    _local = ref.read(localBookmarkStoreProvider);

    final authState = ref.watch(authProvider).value;

    if (authState is AuthStateAuthenticated) {
      final result = await SyncResolver(
        remote: _repo,
        local: _local,
      ).resolve();

      // Publish result so the shell screen can show the snackbar.
      // Use Future.microtask to avoid modifying another provider mid-build.
      if (result.hasChanges) {
        Future.microtask(
          () => ref.read(syncResultProvider.notifier).state = result,
        );
      }

      return _repo.fetchBookmarks();
    }

    // Guest mode: load active (non-deleted) bookmarks from local storage.
    return _local.loadAll();
  }

  Future<void> add(
    MediaItem item,
    String status, {
    int? rating,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? progressCount,
  }) async {
    final authState = ref.read(authProvider).value;
    final Bookmark bookmark;

    if (authState is AuthStateAuthenticated) {
      bookmark = await _repo.addBookmark(
        mediaItem: item,
        status: status,
        rating: rating,
        notes: notes,
        startDate: startDate,
        endDate: endDate,
        progressCount: progressCount,
      );
    } else {
      bookmark = await _local.add(
        mediaItem: item,
        status: status,
        rating: rating,
        notes: notes,
        startDate: startDate,
        endDate: endDate,
        progressCount: progressCount,
      );
    }

    state = AsyncData([bookmark, ...state.value ?? []]);
  }

  Future<void> editBookmark(
    String bookmarkId, {
    required String status,
    int? rating,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? progressCount,
  }) async {
    final authState = ref.read(authProvider).value;
    final Bookmark updated;

    if (authState is AuthStateAuthenticated) {
      updated = await _repo.updateBookmark(
        bookmarkId,
        status: status,
        rating: rating,
        notes: notes,
        startDate: startDate,
        endDate: endDate,
        progressCount: progressCount,
      );
    } else {
      updated = await _local.update(
        bookmarkId,
        status: status,
        rating: rating,
        notes: notes,
        startDate: startDate,
        endDate: endDate,
        progressCount: progressCount,
      );
    }

    state = AsyncData(
      state.value?.map((b) => b.id == bookmarkId ? updated : b).toList() ?? [],
    );
  }

  Future<void> remove(String bookmarkId) async {
    final authState = ref.read(authProvider).value;

    if (authState is AuthStateAuthenticated) {
      await _repo.deleteBookmark(bookmarkId);
    } else {
      await _local.delete(bookmarkId);
    }

    state = AsyncData(
      state.value?.where((b) => b.id != bookmarkId).toList() ?? [],
    );
  }
}

final bookmarkListProvider =
    AsyncNotifierProvider<BookmarkListNotifier, List<Bookmark>>(
      BookmarkListNotifier.new,
    );

// ── Status filter ──────────────────────────────────────────────

/// null = show all statuses
final statusFilterProvider = StateProvider<String?>((ref) => null);

/// Bookmark list after applying the active status filter.
final filteredBookmarksProvider = Provider<AsyncValue<List<Bookmark>>>((ref) {
  final bookmarks = ref.watch(bookmarkListProvider);
  final filter = ref.watch(statusFilterProvider);

  if (filter == null) return bookmarks;

  return bookmarks.whenData(
    (list) => list.where((b) => b.status == filter).toList(),
  );
});
