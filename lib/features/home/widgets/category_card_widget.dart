// ─────────────────────────────────────────────────────────────
// lib/features/home/widgets/category_card_widget.dart
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/bookmark.dart';
import '../../library/providers/library_providers.dart';

class CategoryCardWidget extends StatelessWidget {
  final CategoryStats stats;
  final VoidCallback onTap;

  const CategoryCardWidget({
    super.key,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = _typeInfo(stats.mediaType);
    final (iconBg, iconFg) = _typeBadge(stats.mediaType, cs);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: icon + name + count ───────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(info.icon, color: iconFg, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info.label,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (stats.total > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${stats.total}',
                        style: tt.labelSmall?.copyWith(
                          color: iconFg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // ── Poster mosaic or empty state ───────────────
              if (stats.total == 0)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_add_outlined,
                          color: cs.onSurfaceVariant.withAlpha(120),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nothing yet',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withAlpha(160),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _MosaicGrid(
                      items: stats.recentFour,
                      cs: cs,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static ({IconData icon, String label}) _typeInfo(String mediaType) =>
      switch (mediaType) {
        'movie' => (icon: Icons.movie_rounded, label: 'Movies'),
        'tv' => (icon: Icons.tv_rounded, label: 'TV Shows'),
        'anime' => (icon: Icons.animation_rounded, label: 'Anime'),
        'manga' => (icon: Icons.menu_book_rounded, label: 'Manga'),
        'game' => (icon: Icons.sports_esports_rounded, label: 'Games'),
        'book' => (icon: Icons.auto_stories_rounded, label: 'Books'),
        _ => (icon: Icons.bookmark_rounded, label: 'Other'),
      };

  static (Color, Color) _typeBadge(String type, ColorScheme cs) =>
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

// ── Mosaic grid ────────────────────────────────────────────────
// 1 item → full image; 2 → side by side; 3 → large left + two stacked right; 4 → 2×2

class _MosaicGrid extends StatelessWidget {
  final List<Bookmark> items;
  final ColorScheme cs;

  const _MosaicGrid({required this.items, required this.cs});

  @override
  Widget build(BuildContext context) {
    final count = items.length.clamp(0, 4);
    switch (count) {
      case 1:
        return _thumb(0);
      case 2:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _thumb(0)),
            const SizedBox(width: 3),
            Expanded(child: _thumb(1)),
          ],
        );
      case 3:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _thumb(0)),
            const SizedBox(width: 3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _thumb(1)),
                  const SizedBox(height: 3),
                  Expanded(child: _thumb(2)),
                ],
              ),
            ),
          ],
        );
      default: // 4
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _thumb(0)),
                  const SizedBox(width: 3),
                  Expanded(child: _thumb(1)),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _thumb(2)),
                  const SizedBox(width: 3),
                  Expanded(child: _thumb(3)),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _thumb(int index) =>
      _GridThumbnail(bookmark: items[index], cs: cs);
}

class _GridThumbnail extends StatelessWidget {
  final Bookmark? bookmark;
  final ColorScheme cs;

  const _GridThumbnail({required this.bookmark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final url = bookmark?.mediaItem.posterUrl;
    return url != null
        ? CachedNetworkImage(
            imageUrl: url,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, _) => _PlaceholderBox(cs: cs),
            errorWidget: (_, _, _) => _PlaceholderBox(cs: cs),
          )
        : _PlaceholderBox(cs: cs);
  }
}

class _PlaceholderBox extends StatelessWidget {
  final ColorScheme cs;
  const _PlaceholderBox({required this.cs});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: cs.onSurfaceVariant.withAlpha(80),
          size: 16,
        ),
      ),
    );
  }
}
