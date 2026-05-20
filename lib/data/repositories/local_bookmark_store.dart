// ─────────────────────────────────────────────────────────────
// lib/data/repositories/local_bookmark_store.dart
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark.dart';
import '../models/media_item.dart';

class LocalBookmarkStore {
  static const _key = 'guest_bookmarks';

  // Returns only active (non-deleted) bookmarks — used for normal UI reads.
  Future<List<Bookmark>> loadAll() async {
    final all = await loadAllForSync();
    return all.where((b) => b.deletedAt == null).toList();
  }

  // Returns every bookmark including soft-deleted — used by SyncResolver.
  Future<List<Bookmark>> loadAllForSync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Bookmark> add({
    required MediaItem mediaItem,
    required String status,
    int? rating,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? progressCount,
  }) async {
    final all = await loadAllForSync();
    final now = DateTime.now();
    final bookmark = Bookmark(
      id: 'local_${now.millisecondsSinceEpoch}',
      userId: 'guest',
      mediaItem: mediaItem,
      status: status,
      rating: rating,
      notes: notes?.isNotEmpty == true ? notes : null,
      startDate: startDate,
      endDate: endDate,
      progressCount: progressCount,
      createdAt: now,
      updatedAt: now,
    );
    all.insert(0, bookmark);
    await _save(all);
    return bookmark;
  }

  Future<Bookmark> update(
    String bookmarkId, {
    required String status,
    int? rating,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? progressCount,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) async {
    final all = await loadAllForSync();
    final idx = all.indexWhere((b) => b.id == bookmarkId);
    if (idx == -1) throw StateError('Local bookmark $bookmarkId not found');
    final updated = all[idx].copyWith(
      status: status,
      rating: rating,
      notes: notes,
      startDate: startDate,
      endDate: endDate,
      progressCount: progressCount,
      clearRating: rating == null,
      clearNotes: notes == null || notes.isEmpty,
      clearStartDate: clearStartDate,
      clearEndDate: clearEndDate,
      clearDeletedAt: true,
    );
    all[idx] = updated;
    await _save(all);
    return updated;
  }

  // Soft-delete: marks the bookmark deleted locally so SyncResolver can
  // propagate the deletion to Supabase on next login.
  Future<void> delete(String bookmarkId) async {
    final all = await loadAllForSync();
    final idx = all.indexWhere((b) => b.id == bookmarkId);
    if (idx == -1) return;
    all[idx] = all[idx].copyWith(deletedAt: DateTime.now());
    await _save(all);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _save(List<Bookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(bookmarks.map(_toJson).toList()));
  }

  Map<String, dynamic> _toJson(Bookmark b) => {
    'id': b.id,
    'user_id': b.userId,
    'status': b.status,
    'rating': b.rating,
    'notes': b.notes,
    'start_date': b.startDate?.toIso8601String(),
    'end_date': b.endDate?.toIso8601String(),
    'progress_count': b.progressCount,
    'created_at': b.createdAt.toIso8601String(),
    'updated_at': b.updatedAt.toIso8601String(),
    'deleted_at': b.deletedAt?.toIso8601String(),
    'media_item': {
      'id': b.mediaItem.id,
      'external_id': b.mediaItem.externalId,
      'source': b.mediaItem.source,
      'media_type': b.mediaItem.mediaType,
      'title': b.mediaItem.title,
      'poster_url': b.mediaItem.posterUrl,
      'genres': b.mediaItem.genres,
      'runtime_minutes': b.mediaItem.runtimeMinutes,
      'episode_count': b.mediaItem.episodeCount,
      'overview': b.mediaItem.overview,
    },
  };

  Bookmark _fromJson(Map<String, dynamic> json) {
    final mi = json['media_item'] as Map<String, dynamic>;
    return Bookmark(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaItem: MediaItem(
        id: mi['id'] as String?,
        externalId: mi['external_id'] as String,
        source: mi['source'] as String,
        mediaType: mi['media_type'] as String,
        title: mi['title'] as String,
        posterUrl: mi['poster_url'] as String?,
        genres: (mi['genres'] as List<dynamic>?)?.cast<String>() ?? [],
        runtimeMinutes: mi['runtime_minutes'] as int?,
        episodeCount: mi['episode_count'] as int?,
        overview: mi['overview'] as String?,
      ),
      status: json['status'] as String,
      rating: json['rating'] as int?,
      notes: json['notes'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      progressCount: json['progress_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }
}
