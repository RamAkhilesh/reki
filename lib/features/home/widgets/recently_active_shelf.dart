// ─────────────────────────────────────────────────────────────
// lib/features/home/widgets/recently_active_shelf.dart
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../data/models/bookmark.dart';
import '../../../features/bookmarks/providers/bookmark_providers.dart';
import '../../../features/bookmarks/widgets/add_edit_bookmark_sheet.dart';
import '../../library/providers/library_providers.dart';

class RecentlyActiveShelf extends ConsumerWidget {
  final VoidCallback? onSeeAll;
  const RecentlyActiveShelf({super.key, this.onSeeAll});

  static const _limit = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final recentAsync = ref.watch(recentlyActiveProvider);

    return recentAsync.when(
      loading: () => _ShelfSkeleton(cs: cs),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Add some bookmarks to see them here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          );
        }
        final visible = items.take(_limit).toList();
        return SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: visible.length + 1,
            itemBuilder: (context, i) {
              if (i < visible.length) {
                final bookmark = visible[i];
                return _PosterCard(
                  bookmark: bookmark,
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    showEditDeleteSheet(
                      context,
                      bookmark,
                      onDelete: () => ref
                          .read(bookmarkListProvider.notifier)
                          .remove(bookmark.id),
                    );
                  },
                )
                    .animate()
                    .fadeIn(duration: 260.ms, delay: (i * 35).ms);
              }
              return _SeeAllCard(onTap: onSeeAll)
                  .animate()
                  .fadeIn(duration: 260.ms, delay: (visible.length * 35).ms);
            },
          ),
        );
      },
    );
  }
}

// ── Shimmer loading skeleton ──────────────────────────────────

class _ShelfSkeleton extends StatelessWidget {
  final ColorScheme cs;
  const _ShelfSkeleton({required this.cs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 76,
              color: cs.surfaceContainerHighest,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80)),
        ),
      ),
    );
  }
}

// ── Individual poster card ────────────────────────────────────

class _PosterCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback? onLongPress;

  const _PosterCard({required this.bookmark, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final item = bookmark.mediaItem;
    final (Color badgeBg, Color badgeFg) = _badgeColors(item.mediaType, cs);

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.mediaDetail, extra: item),
        onLongPress: onLongPress,
        child: SizedBox(
          width: 76,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Poster image
                item.posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.posterUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: cs.surfaceContainerHighest),
                        errorWidget: (_, _, _) => _Fallback(cs: cs),
                      )
                    : _Fallback(cs: cs),

                // Subtle bottom gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(160),
                        ],
                      ),
                    ),
                  ),
                ),

                // Media type badge — bottom-left
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.mediaTypeLabel,
                      style: tt.labelSmall?.copyWith(
                        color: badgeFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (Color, Color) _badgeColors(String type, ColorScheme cs) =>
      switch (type) {
        'movie' => (cs.primaryContainer, cs.onPrimaryContainer),
        'tv' => (cs.secondaryContainer, cs.onSecondaryContainer),
        'anime' => (cs.tertiaryContainer, cs.onTertiaryContainer),
        'manga' => (cs.errorContainer, cs.onErrorContainer),
        'game' => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
        'book' => (cs.secondaryContainer, cs.onSecondaryContainer),
        _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      };
}

// ── See All card ──────────────────────────────────────────────

class _SeeAllCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _SeeAllCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: cs.primaryContainer.withAlpha(80),
                border: Border.all(
                  color: cs.primary.withAlpha(60),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: cs.onPrimary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'See All',
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 28),
    );
  }
}
