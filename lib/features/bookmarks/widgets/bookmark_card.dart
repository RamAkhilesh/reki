// ─────────────────────────────────────────────────────────────
// lib/features/bookmarks/widgets/bookmark_card.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../data/models/bookmark.dart';

class BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BookmarkCard({
    super.key,
    required this.bookmark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final item = bookmark.mediaItem;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Poster ────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.posterUrl != null
                    ? Image.network(
                        item.posterUrl!,
                        width: 72,
                        height: 108,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _PosterPlaceholder(cs: cs),
                      )
                    : _PosterPlaceholder(cs: cs),
              ),
              const SizedBox(width: 12),

              // ── Info ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _OptionsMenu(onEdit: onEdit, onDelete: onDelete),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Media type badge
                    _Badge(
                      label: item.mediaTypeLabel,
                      color: cs.secondaryContainer,
                      labelColor: cs.onSecondaryContainer,
                    ),
                    const SizedBox(height: 6),

                    // Status badge
                    _Badge(
                      label: BookmarkStatus.label(bookmark.status),
                      color: _statusColor(bookmark.status, cs),
                      labelColor: cs.onPrimaryContainer,
                    ),

                    // Rating
                    if (bookmark.rating != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16, color: cs.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${bookmark.rating}/10',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status, ColorScheme cs) {
    return switch (status) {
      BookmarkStatus.watching => cs.primaryContainer,
      BookmarkStatus.completed => cs.tertiaryContainer,
      BookmarkStatus.dropped => cs.errorContainer,
      _ => cs.surfaceContainerHighest,
    };
  }
}

class _PosterPlaceholder extends StatelessWidget {
  final ColorScheme cs;
  const _PosterPlaceholder({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 108,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 32),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color labelColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: labelColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OptionsMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OptionsMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Action>(
      icon: const Icon(Icons.more_vert, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (action) {
        if (action == _Action.edit) onEdit();
        if (action == _Action.delete) onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _Action.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          value: _Action.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

enum _Action { edit, delete }
