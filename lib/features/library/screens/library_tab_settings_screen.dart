// ─────────────────────────────────────────────────────────────
// lib/features/library/screens/library_tab_settings_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_providers.dart';

class LibraryTabSettingsScreen extends ConsumerWidget {
  const LibraryTabSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabOrder = ref.watch(libraryTabOrderProvider);
    final notifier = ref.read(libraryTabOrderProvider.notifier);

    final visibleEntries = tabOrder.where((e) => e.visible).toList();
    final hiddenEntries = tabOrder.where((e) => !e.visible).toList();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Library Tabs')),
      body: CustomScrollView(
        slivers: [
          // ── Info banner ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: cs.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Types without any bookmarks are hidden automatically, '
                        'regardless of this setting.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Visible section ──────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionLabel(
              label: 'Shown',
              subtitle: 'Drag to reorder',
              cs: cs,
              tt: tt,
            ),
          ),

          if (visibleEntries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'All tabs are hidden. Tap the eye icon below to show them.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),

          SliverReorderableList(
            itemCount: visibleEntries.length,
            onReorder: notifier.reorder,
            itemBuilder: (ctx, index) {
              final entry = visibleEntries[index];
              return _VisibleEntryTile(
                key: ValueKey(entry.type),
                entry: entry,
                index: index,
                onToggle: () => notifier.toggleVisibility(entry.type),
              );
            },
          ),

          // ── Hidden section ───────────────────────────────────
          if (hiddenEntries.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                label: 'Hidden',
                subtitle: 'Tap eye to restore',
                cs: cs,
                tt: tt,
              ),
            ),
            SliverList.builder(
              itemCount: hiddenEntries.length,
              itemBuilder: (ctx, index) {
                final entry = hiddenEntries[index];
                return _HiddenEntryTile(
                  key: ValueKey(entry.type),
                  entry: entry,
                  onToggle: () => notifier.toggleVisibility(entry.type),
                );
              },
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme tt;

  const _SectionLabel({
    required this.label,
    required this.subtitle,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: tt.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· $subtitle',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Visible entry tile (has drag handle) ──────────────────────

class _VisibleEntryTile extends StatelessWidget {
  final LibraryTabEntry entry;
  final int index;
  final VoidCallback onToggle;

  const _VisibleEntryTile({
    required super.key,
    required this.entry,
    required this.index,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      child: ListTile(
        // Drag handle — initiates the drag
        leading: ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.drag_handle_rounded, color: cs.onSurfaceVariant),
          ),
        ),
        title: Row(
          children: [
            Icon(_typeIcon(entry.type), size: 20, color: cs.onSurface),
            const SizedBox(width: 12),
            Text(_typeLabel(entry.type)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.visibility_outlined),
          tooltip: 'Hide',
          color: cs.primary,
          onPressed: onToggle,
        ),
      ),
    );
  }
}

// ── Hidden entry tile (no drag handle) ───────────────────────

class _HiddenEntryTile extends StatelessWidget {
  final LibraryTabEntry entry;
  final VoidCallback onToggle;

  const _HiddenEntryTile({
    required super.key,
    required this.entry,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Opacity(
      opacity: 0.5,
      child: ListTile(
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(_typeIcon(entry.type), size: 20, color: cs.onSurface),
        ),
        title: Text(_typeLabel(entry.type)),
        trailing: IconButton(
          icon: const Icon(Icons.visibility_off_outlined),
          tooltip: 'Show',
          color: cs.onSurfaceVariant,
          onPressed: onToggle,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

String _typeLabel(String type) => switch (type) {
      'all' => 'All',
      'movie' => 'Movies',
      'tv' => 'TV Shows',
      'anime' => 'Anime',
      'manga' => 'Manga',
      'game' => 'Games',
      'book' => 'Books',
      _ => type,
    };

IconData _typeIcon(String type) => switch (type) {
      'all' => Icons.grid_view_rounded,
      'movie' => Icons.movie_outlined,
      'tv' => Icons.tv_outlined,
      'anime' => Icons.smart_display_outlined,
      'manga' => Icons.menu_book_outlined,
      'game' => Icons.sports_esports_outlined,
      'book' => Icons.auto_stories_outlined,
      _ => Icons.category_outlined,
    };
