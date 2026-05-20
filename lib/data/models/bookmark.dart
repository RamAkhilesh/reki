// ─────────────────────────────────────────────────────────────
// lib/data/models/bookmark.dart
// ─────────────────────────────────────────────────────────────

import 'media_item.dart';

class Bookmark {
  final String id;
  final String userId;
  final MediaItem mediaItem;
  final String status;
  final int? rating; // 1–10, nullable
  final String? notes;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? progressCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Null means active; non-null means soft-deleted.
  final DateTime? deletedAt;

  const Bookmark({
    required this.id,
    required this.userId,
    required this.mediaItem,
    required this.status,
    this.rating,
    this.notes,
    this.startDate,
    this.endDate,
    this.progressCount,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Bookmark.fromSupabaseJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaItem: MediaItem.fromSupabaseJson(
        json['media_items'] as Map<String, dynamic>,
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

  Bookmark copyWith({
    String? status,
    int? rating,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    int? progressCount,
    DateTime? deletedAt,
    bool clearRating = false,
    bool clearNotes = false,
    bool clearDeletedAt = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearProgressCount = false,
  }) {
    return Bookmark(
      id: id,
      userId: userId,
      mediaItem: mediaItem,
      status: status ?? this.status,
      rating: clearRating ? null : (rating ?? this.rating),
      notes: clearNotes ? null : (notes ?? this.notes),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      progressCount:
          clearProgressCount ? null : (progressCount ?? this.progressCount),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

abstract class BookmarkStatus {
  static const wantToWatch = 'want_to_watch';
  static const watching = 'watching';
  static const completed = 'completed';
  static const dropped = 'dropped';
  static const onHold = 'on_hold';

  static const all = [
    wantToWatch,
    watching,
    completed,
    dropped,
    onHold,
  ];

  static String label(String status) {
    return switch (status) {
      wantToWatch => 'Plan to Start',
      watching => 'In Progress',
      completed => 'Completed',
      dropped => 'Dropped',
      onHold => 'On Hold',
      _ => status,
    };
  }
}
