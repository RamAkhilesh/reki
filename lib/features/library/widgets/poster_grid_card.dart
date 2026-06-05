// ─────────────────────────────────────────────────────────────
// lib/features/library/widgets/poster_grid_card.dart
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/bookmark.dart';

class PosterGridCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const PosterGridCard({
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster
            item.posterUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: cs.surfaceContainerHighest),
                    errorWidget: (_, _, _) => _GridFallback(cs: cs),
                  )
                : _GridFallback(cs: cs),

            // Gradient overlay — always dark so white text is readable on any poster
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(220),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom info
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: tt.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Rating badge — top right
            if (bookmark.rating != null)
              Positioned(
                top: 4,
                right: 4,
                child: _RatingBadge(rating: bookmark.rating!),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridFallback extends StatelessWidget {
  final ColorScheme cs;
  const _GridFallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 48),
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
