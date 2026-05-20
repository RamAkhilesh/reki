// ─────────────────────────────────────────────────────────────
// lib/features/bookmarks/widgets/add_edit_bookmark_sheet.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
import 'add_to_library_sheet.dart';

/// Call this to add a new bookmark from a [MediaItem] search result.
Future<void> showAddBookmarkSheet(
  BuildContext context,
  MediaItem item,
) {
  return showAddToLibrarySheet(context, item);
}

/// Call this to edit an existing [Bookmark] and optionally delete it.
Future<void> showEditDeleteSheet(
  BuildContext context,
  Bookmark bookmark, {
  required Future<void> Function() onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddToLibrarySheet(
      existingBookmark: bookmark,
      onDelete: onDelete,
    ),
  );
}
