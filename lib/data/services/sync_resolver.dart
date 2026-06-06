// ─────────────────────────────────────────────────────────────
// lib/data/services/sync_resolver.dart
//
// Runs once at login.  Merges the guest's local bookmarks with the
// authenticated user's remote bookmarks using a "latest updated_at wins"
// strategy, field by field.
//
// Three cases:
//   local-only, active   → push to Supabase via sync_bookmark RPC
//   local-only, deleted  → skip (never reached the server)
//   remote-only          → pulled automatically by fetchBookmarks(); counted
//   both exist           → compare effective timestamps; winner's data is kept
// ─────────────────────────────────────────────────────────────

import '../models/bookmark.dart';
import '../models/sync_result.dart';
import '../repositories/bookmark_repository.dart';
import '../repositories/local_bookmark_store.dart';

class SyncResolver {
  final BookmarkRepository _remote;
  final LocalBookmarkStore _local;

  SyncResolver({
    required BookmarkRepository remote,
    required LocalBookmarkStore local,
  })  : _remote = remote,
        _local = local;

  // Resolves conflicts and returns a [SyncResult] describing what changed.
  // Clears the local store when done — caller should then call
  // fetchBookmarks() to rebuild the list from the authoritative remote state.
  Future<SyncResult> resolve() async {
    final localAll = await _local.loadAllForSync();
    if (localAll.isEmpty) {
      // No local guest bookmarks to merge — skip the remote fetch entirely.
      // The caller (BookmarkListNotifier) will fetch the authoritative list via fetchBookmarks().
      return const SyncResult(addedFromRemote: 0, pushedToRemote: 0);
    }

    final remoteAll = await _remote.fetchAllForSync();

    // Index remote bookmarks by "externalId:source" for O(1) lookup.
    final remoteByKey = <String, Bookmark>{
      for (final r in remoteAll)
        '${r.mediaItem.externalId}:${r.mediaItem.source}': r,
    };

    // Index local bookmarks the same way to detect remote-only items.
    final localKeys = {
      for (final l in localAll)
        '${l.mediaItem.externalId}:${l.mediaItem.source}',
    };

    int pushedToRemote = 0;

    for (final local in localAll) {
      final key = '${local.mediaItem.externalId}:${local.mediaItem.source}';
      final remote = remoteByKey[key];

      if (remote == null) {
        // ── Local-only ──────────────────────────────────────
        if (local.deletedAt == null) {
          // Active local bookmark has never been on the server — push it.
          await _remote.syncBookmark(local);
          pushedToRemote++;
        }
        // If already soft-deleted locally and never on server: nothing to do.
      } else {
        // ── Both exist — compare effective timestamps ────────
        // For a soft-delete, use deletedAt as the effective mutation time so
        // deletions compete on equal footing with edits.
        final localTime = local.deletedAt ?? local.updatedAt;
        final remoteTime = remote.deletedAt ?? remote.updatedAt;

        if (localTime.isAfter(remoteTime)) {
          // Local is newer — push via the conditional upsert RPC.
          // The DB will reject the write if a concurrent sync beat us to it.
          await _remote.syncBookmark(local);
          if (local.deletedAt == null) pushedToRemote++;
        }
        // Remote is newer (or equal) — remote state wins; no action needed.
        // fetchBookmarks() after sync will return the authoritative remote row.
      }
    }

    // Count remote-only active bookmarks (items from other devices/sessions).
    final addedFromRemote = remoteAll
        .where(
          (r) =>
              r.deletedAt == null &&
              !localKeys.contains(
                '${r.mediaItem.externalId}:${r.mediaItem.source}',
              ),
        )
        .length;

    // Local store is no longer needed — remote is now the source of truth.
    await _local.clearAll();

    return SyncResult(
      addedFromRemote: addedFromRemote,
      pushedToRemote: pushedToRemote,
    );
  }
}
