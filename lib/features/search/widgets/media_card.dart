// ─────────────────────────────────────────────────────────────
// lib/features/search/widgets/media_card.dart
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/media_item.dart';

/// Poster card used in the discovery carousels on the Search tab.
/// Shows a 3:2-ratio thumbnail, media-type badge, and title below the poster.
class MediaCard extends StatelessWidget {
  final MediaItem item;
  final bool inLibrary;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAdd;

  const MediaCard({
    super.key,
    required this.item,
    this.inLibrary = false,
    this.onTap,
    this.onLongPress,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 112,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Poster ──────────────────────────────────
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 100,
                      height: 126,
                      child: item.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: item.posterUrl!,
                              httpHeaders: item.posterHeaders,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(
                                color: cs.surfaceContainerHighest,
                              ),
                              errorWidget: (_, _, _) => _Fallback(cs: cs),
                            )
                          : _Fallback(cs: cs),
                    ),
                  ),

                  // In-library tint
                  if (inLibrary)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.primary.withAlpha(38),
                          ),
                        ),
                      ),
                    ),

                  // In-library banner
                  if (inLibrary)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          color: cs.primary,
                          child: Text(
                            'IN LIBRARY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 8,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Add button — only when not in library
                  if (!inLibrary && onAdd != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surface.withAlpha(204),
                          shape: BoxShape.circle,
                        ),
                        child: InkWell(
                          onTap: onAdd,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.add_rounded,
                              color: cs.onSurfaceVariant,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Type badge ───────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.mediaTypeLabel,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ── Title ────────────────────────────────────
              Text(
                item.title,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 32),
    );
  }
}
