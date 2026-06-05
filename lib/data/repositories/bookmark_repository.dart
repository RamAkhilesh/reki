// ─────────────────────────────────────────────────────────────
// lib/data/repositories/bookmark_repository.dart
// ─────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bookmark.dart';
import '../models/media_item.dart';

class BookmarkRepository {
  final SupabaseClient _client;

  BookmarkRepository(this._client);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not authenticated');
    return id;
  }

  // ── Normal CRUD ────────────────────────────────────────────

  Future<List<Bookmark>> fetchBookmarks() async {
    final data = await _client
        .from('bookmarks')
        .select('*, media_items(*)')
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Bookmark.fromSupabaseJson)
        .toList();
  }

  Future<Bookmark> addBookmark({
    required MediaItem mediaItem,
    required String status,
    int? rating,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? progressCount,
  }) async {
    final miRow = await _client
        .from('media_items')
        .upsert(
          mediaItem.toSupabaseJson(),
          onConflict: 'external_id,source',
        )
        .select()
        .single();

    final persistedItem = MediaItem.fromSupabaseJson(miRow);

    final bookmarkRow = await _client
        .from('bookmarks')
        .upsert(
          {
            'user_id': _userId,
            'media_item_id': persistedItem.id,
            'status': status,
            'rating': ?rating,
            'notes': notes?.isNotEmpty == true ? notes : null,
            'start_date': ?startDate?.toIso8601String().substring(0, 10),
            'end_date': ?endDate?.toIso8601String().substring(0, 10),
            'progress_count': ?progressCount,
            'deleted_at': null,
            'created_at': DateTime.now().toIso8601String(),
            // updated_at intentionally omitted — DB trigger sets it to now()
          },
          onConflict: 'user_id,media_item_id',
        )
        .select('*, media_items(*)')
        .single();

    return Bookmark.fromSupabaseJson(bookmarkRow);
  }

  Future<Bookmark> updateBookmark(
    String bookmarkId, {
    required String status,
    int? rating,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? progressCount,
  }) async {
    final row = await _client
        .from('bookmarks')
        .update({
          'status': status,
          'rating': rating,
          'notes': (notes?.isEmpty ?? true) ? null : notes,
          'start_date': startDate?.toIso8601String().substring(0, 10),
          'end_date': endDate?.toIso8601String().substring(0, 10),
          'progress_count': progressCount,
          // updated_at intentionally omitted — DB trigger sets it to now()
        })
        .eq('id', bookmarkId)
        .eq('user_id', _userId)
        .select('*, media_items(*)')
        .single();

    return Bookmark.fromSupabaseJson(row);
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    await _client
        .from('bookmarks')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', bookmarkId)
        .eq('user_id', _userId);
  }

  // ── Sync support ───────────────────────────────────────────

  // Fetches ALL bookmarks including soft-deleted, for use by SyncResolver.
  Future<List<Bookmark>> fetchAllForSync() async {
    final data = await _client
        .from('bookmarks')
        .select('*, media_items(*)')
        .eq('user_id', _userId)
        .order('updated_at', ascending: false);

    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Bookmark.fromSupabaseJson)
        .toList();
  }

  // Conditional upsert via the sync_bookmark RPC.
  // Applies local data only when local.updatedAt > server's updated_at.
  // The DB trigger sets updated_at = now() server-side after a winning write.
  Future<void> syncBookmark(Bookmark local) async {
    // 1. Ensure the media item exists in Supabase and get its UUID.
    final miRow = await _client
        .from('media_items')
        .upsert(
          local.mediaItem.toSupabaseJson(),
          onConflict: 'external_id,source',
        )
        .select()
        .single();

    final mediaItemId = miRow['id'] as String;

    // 2. Conditional upsert: DB rejects stale writes via the WHERE clause.
    await _client.rpc('sync_bookmark', params: {
      'p_user_id': _userId,
      'p_media_item_id': mediaItemId,
      'p_status': local.status,
      'p_rating': local.rating,
      'p_notes': local.notes,
      'p_start_date': local.startDate?.toIso8601String().substring(0, 10),
      'p_end_date': local.endDate?.toIso8601String().substring(0, 10),
      'p_progress_count': local.progressCount,
      'p_deleted_at': local.deletedAt?.toIso8601String(),
      'p_local_updated_at': local.updatedAt.toIso8601String(),
    });
  }

  // Soft-delete a remote bookmark by setting deleted_at.
  // The BEFORE UPDATE trigger will also bump updated_at = now().
  Future<void> softDeleteBookmark(String bookmarkId) async {
    await _client
        .from('bookmarks')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', bookmarkId)
        .eq('user_id', _userId);
  }
}
