// ─────────────────────────────────────────────────────────────
// lib/features/library/screens/library_tab_settings_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/prism_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/library_providers.dart';

class LibraryTabSettingsScreen extends ConsumerWidget {
  const LibraryTabSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabOrder = ref.watch(libraryTabOrderProvider);
    final notifier = ref.read(libraryTabOrderProvider.notifier);

    final visibleEntries = tabOrder.where((e) => e.visible).toList();
    final hiddenEntries = tabOrder.where((e) => !e.visible).toList();

    final ink = P.ink(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: PrismBackdrop()),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
              ),

              // ── Header ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                  child: Row(
                    children: [
                      GlassButton(
                        size: 36,
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Library Tabs',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          letterSpacing: -0.035 * 28,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Info banner ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  child: GlassCard(
                    radius: 16,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: P.inkDim(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Types without any bookmarks are hidden automatically, '
                              'regardless of this setting.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: P.inkDim(context),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Shown section label ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 18, 8),
                  child: Row(
                    children: [
                      Text(
                        'SHOWN',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: P.inkDimmer(context),
                          letterSpacing: 0.06 * 10,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· Drag to reorder',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: P.inkDimmer(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Visible entries ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: visibleEntries.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 8),
                          child: Text(
                            'All tabs are hidden. Tap the eye icon below to show them.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: P.inkDim(context),
                            ),
                          ),
                        )
                      : GlassCard(
                          radius: 20,
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) =>
                                Material(
                                  type: MaterialType.transparency,
                                  child: child,
                                ),
                            onReorder: notifier.reorder,
                            itemCount: visibleEntries.length,
                            itemBuilder: (ctx, index) {
                              final entry = visibleEntries[index];
                              return _VisibleTile(
                                key: ValueKey(entry.type),
                                entry: entry,
                                index: index,
                                isLast: index == visibleEntries.length - 1,
                                onToggle: () => notifier.toggleVisibility(entry.type),
                              );
                            },
                          ),
                        ),
                ),
              ),

              // ── Hidden section ───────────────────────────────
              if (hiddenEntries.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 18, 8),
                    child: Row(
                      children: [
                        Text(
                          'HIDDEN',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: P.inkDimmer(context),
                            letterSpacing: 0.06 * 10,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· Tap eye to restore',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: P.inkDimmer(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                    child: GlassCard(
                      radius: 20,
                      child: Column(
                        children: [
                          for (int i = 0; i < hiddenEntries.length; i++)
                            _HiddenTile(
                              entry: hiddenEntries[i],
                              isFirst: i == 0,
                              onToggle: () =>
                                  notifier.toggleVisibility(hiddenEntries[i].type),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Visible tile ──────────────────────────────────────────────

class _VisibleTile extends StatelessWidget {
  const _VisibleTile({
    required super.key,
    required this.entry,
    required this.index,
    required this.isLast,
    required this.onToggle,
  });

  final LibraryTabEntry entry;
  final int index;
  final bool isLast;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: P.borderSoft(context), width: 0.5),
                ),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle_rounded,
                size: 20,
                color: P.inkDimmer(context),
              ),
            ),
            const SizedBox(width: 14),
            Icon(_typeIcon(entry.type), size: 18, color: P.inkDim(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _typeLabel(entry.type),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: P.ink(context),
                  letterSpacing: -0.01,
                ),
              ),
            ),
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.visibility_rounded,
                  size: 18,
                  color: P.accent(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hidden tile ───────────────────────────────────────────────

class _HiddenTile extends StatelessWidget {
  const _HiddenTile({
    required this.entry,
    required this.isFirst,
    required this.onToggle,
  });

  final LibraryTabEntry entry;
  final bool isFirst;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Container(
        decoration: isFirst
            ? null
            : BoxDecoration(
                border: Border(
                  top: BorderSide(color: P.borderSoft(context), width: 0.5),
                ),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(_typeIcon(entry.type), size: 18, color: P.inkDim(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _typeLabel(entry.type),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: P.ink(context),
                  letterSpacing: -0.01,
                ),
              ),
            ),
            GestureDetector(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.visibility_off_rounded,
                  size: 18,
                  color: P.inkDimmer(context),
                ),
              ),
            ),
          ],
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
