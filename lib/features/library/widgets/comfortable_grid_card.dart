// ─────────────────────────────────────────────────────────────
// lib/features/library/widgets/comfortable_grid_card.dart
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/bookmark.dart';

class ComfortableGridCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ComfortableGridCard({
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

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster with rating badge overlay
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: item.posterUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 260,
                            placeholder: (_, _) =>
                                Container(color: cs.surfaceContainerHighest),
                            errorWidget: (_, _, _) => _Fallback(cs: cs),
                          )
                        : _Fallback(cs: cs),
                  ),
                ),
                if (bookmark.rating != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _RatingBadge(rating: bookmark.rating!),
                  ),
              ],
            ),
          ),
          // Title below poster
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
            child: Text(
              item.title,
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final ColorScheme cs;
  const _Fallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 40),
      ),
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
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
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
