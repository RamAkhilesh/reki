// ─────────────────────────────────────────────────────────────
// lib/features/library/widgets/compact_list_tile_card.dart
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/bookmark.dart';

class CompactListTileCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const CompactListTileCard({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final item = bookmark.mediaItem;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Cover art
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 68,
                child: item.posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.posterUrl!,
                        width: 48,
                        height: 68,
                        fit: BoxFit.cover,
                        memCacheWidth: 96,
                        placeholder: (_, _) =>
                            Container(color: cs.surfaceContainerHighest),
                        errorWidget: (_, _, _) => _Fallback(cs: cs),
                      )
                    : _Fallback(cs: cs),
              ),
            ),
            const SizedBox(width: 12),

            // Title + media type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style:
                        tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.mediaTypeLabel,
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Rating badge (if present)
            if (bookmark.rating != null)
              _RatingBadge(rating: bookmark.rating!),
          ],
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final ColorScheme cs;
  const _Fallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 68,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 22),
    );
  }
}

(Color, Color) _ratingColors(int r) => switch (r) {
      10 => (const Color(0xFFFFD700), Colors.black87),
      9 || 8 => (const Color(0xFF2ECC71), Colors.white),
      7 || 6 => (const Color(0xFF9ACD32), Colors.black87),
      5 => (const Color(0xFFFFC107), Colors.black87),
      4 => (const Color(0xFFFF9800), Colors.white),
      _ => (const Color(0xFFF44336), Colors.white),
    };

class _RatingBadge extends StatelessWidget {
  final int rating;
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _ratingColors(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 9, color: fg),
          const SizedBox(width: 2),
          Text(
            '$rating',
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
