// ─────────────────────────────────────────────────────────────
// lib/features/library/widgets/library_filter_sheet.dart
// ─────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/prism_tokens.dart';
import '../../../data/models/bookmark.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../providers/library_providers.dart';

void showLibraryFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(100),
    builder: (_) => const LibraryFilterSheet(),
  );
}

class LibraryFilterSheet extends ConsumerStatefulWidget {
  const LibraryFilterSheet({super.key});

  @override
  ConsumerState<LibraryFilterSheet> createState() => _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends ConsumerState<LibraryFilterSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);
    final ink    = P.ink(context);
    final acc    = P.accent(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: P.bg(context).withAlpha(240),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: P.border(context), width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(56)
                          : Colors.black.withAlpha(46),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Tab bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    for (final (i, label) in [
                      (0, 'Filter'), (1, 'Sort'), (2, 'Display'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tabs.animateTo(i)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _tabs.index == i
                                      ? acc
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _tabs.index == i
                                    ? ink
                                    : P.inkDim(context),
                                letterSpacing: -0.015,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 0.5, color: P.borderSoft(context)),

              // Tab content
              SizedBox(
                height: 300,
                child: TabBarView(
                  controller: _tabs,
                  children: const [
                    _FilterTab(),
                    _SortTab(),
                    _DisplayTab(),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter tab ───────────────────────────────────────────────

class _FilterTab extends ConsumerStatefulWidget {
  const _FilterTab();

  @override
  ConsumerState<_FilterTab> createState() => _FilterTabState();
}

class _FilterTabState extends ConsumerState<_FilterTab> {
  String? _draftStatus;
  String? _draftGenre;

  @override
  void initState() {
    super.initState();
    _draftStatus = ref.read(statusFilterProvider);
    _draftGenre  = ref.read(genreFilterProvider);
  }

  void _applyFilters() {
    ref.read(statusFilterProvider.notifier).state = _draftStatus;
    ref.read(genreFilterProvider.notifier).state  = _draftGenre;
    Navigator.of(context).pop();
  }

  void _clearFilters() {
    setState(() {
      _draftStatus = null;
      _draftGenre  = null;
    });
    ref.read(statusFilterProvider.notifier).state = null;
    ref.read(genreFilterProvider.notifier).state  = null;
  }

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkListProvider);

    final sortedStatuses = BookmarkStatus.all.toList()
      ..sort((a, b) => BookmarkStatus.label(a).compareTo(BookmarkStatus.label(b)));

    final allGenres = bookmarksAsync.whenOrNull(
          data: (list) {
            final genres = <String>{};
            for (final b in list) { genres.addAll(b.mediaItem.genres); }
            return (genres.toList()..sort());
          },
        ) ??
        <String>[];

    final effectiveGenre = (_draftGenre != null && allGenres.contains(_draftGenre))
        ? _draftGenre
        : null;

    final hasLocalFilters = _draftStatus != null || effectiveGenre != null;

    final sectionLabel = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: P.inkDimmer(context),
      letterSpacing: 0.08 * 10,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Genre ────────────────────────────────
                if (allGenres.isNotEmpty) ...[
                  Text('GENRE', style: sectionLabel),
                  const SizedBox(height: 8),
                  _GlassDropdown<String?>(
                    value: effectiveGenre,
                    onChanged: (v) => setState(() => _draftGenre = v),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      for (final g in allGenres)
                        DropdownMenuItem(value: g, child: Text(g)),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Status ──────────────────────────────────
                Text('STATUS', style: sectionLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: 'All',
                      selected: _draftStatus == null,
                      onTap: () => setState(() => _draftStatus = null),
                    ),
                    for (final s in sortedStatuses)
                      _StatusChip(
                        label: BookmarkStatus.label(s),
                        selected: _draftStatus == s,
                        onTap: () => setState(() => _draftStatus = s),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Apply / Clear ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _SheetButton(
                  label: 'Clear',
                  onTap: hasLocalFilters ? _clearFilters : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetButton(
                  label: 'Apply',
                  filled: true,
                  onTap: _applyFilters,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sort tab ──────────────────────────────────────────────────

class _SortTab extends ConsumerWidget {
  const _SortTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sortOrderProvider);
    final isDark  = P.isDark(context);
    final ink     = P.ink(context);
    final inkDim  = P.inkDim(context);
    final acc     = P.accent(context);

    Widget sortItem({
      required String label,
      required IconData icon,
      required SortOrder primary,
      SortOrder? secondary,
      String hint = '',
    }) {
      final isToggle   = secondary != null;
      final isSelected = current == primary || (isToggle && current == secondary);

      String subtitle() {
        if (!isToggle) return '';
        if (!isSelected) return hint;
        return switch (current) {
          SortOrder.titleAZ      => 'A → Z  ·  tap again to reverse',
          SortOrder.titleZA      => 'Z → A  ·  tap again to reverse',
          SortOrder.highestRated => 'Highest first  ·  tap again to reverse',
          SortOrder.lowestRated  => 'Lowest first  ·  tap again to reverse',
          _                      => hint,
        };
      }

      IconData? directionIcon() => switch (current) {
        SortOrder.titleAZ || SortOrder.lowestRated  => Icons.arrow_upward_rounded,
        SortOrder.titleZA || SortOrder.highestRated => Icons.arrow_downward_rounded,
        _                                           => null,
      };

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () {
            final s    = secondary;
            final next = (isToggle && current == primary && s != null) ? s : primary;
            ref.read(sortOrderProvider.notifier).state = next;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? Colors.white.withAlpha(22) : acc.withAlpha(22))
                  : (isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? (isDark ? Colors.white.withAlpha(50) : acc.withAlpha(80))
                    : P.borderSoft(context),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isSelected ? ink : inkDim),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? ink : inkDim,
                          letterSpacing: -0.01,
                        ),
                      ),
                      if (subtitle().isNotEmpty)
                        Text(
                          subtitle(),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: P.inkDimmer(context),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isToggle && isSelected)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: Icon(
                      directionIcon(),
                      key: ValueKey(current),
                      size: 18,
                      color: isDark ? Colors.white.withAlpha(180) : acc,
                    ),
                  )
                else if (!isToggle && isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: isDark ? Colors.white.withAlpha(180) : acc,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        sortItem(
          label: 'Recently Added',
          icon: Icons.schedule_rounded,
          primary: SortOrder.recentlyAdded,
        ),
        sortItem(
          label: 'Last Updated',
          icon: Icons.update_rounded,
          primary: SortOrder.lastUpdated,
        ),
        sortItem(
          label: 'Title',
          icon: Icons.sort_by_alpha_rounded,
          primary: SortOrder.titleAZ,
          secondary: SortOrder.titleZA,
          hint: 'A → Z  or  Z → A',
        ),
        sortItem(
          label: 'Rating',
          icon: Icons.star_rounded,
          primary: SortOrder.highestRated,
          secondary: SortOrder.lowestRated,
          hint: 'Highest  or  Lowest first',
        ),
      ],
    );
  }
}

// ── Display tab ───────────────────────────────────────────────

class _DisplayTab extends ConsumerWidget {
  const _DisplayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(displayModeProvider);
    final isDark  = P.isDark(context);
    final ink     = P.ink(context);
    final inkDim  = P.inkDim(context);
    final acc     = P.accent(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final mode in DisplayMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => ref.read(displayModeProvider.notifier).set(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: current == mode
                      ? (isDark ? Colors.white.withAlpha(22) : acc.withAlpha(22))
                      : (isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: current == mode
                        ? (isDark ? Colors.white.withAlpha(50) : acc.withAlpha(80))
                        : P.borderSoft(context),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(mode),
                      size: 20,
                      color: current == mode ? ink : inkDim,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.label,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: current == mode
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: current == mode ? ink : inkDim,
                              letterSpacing: -0.01,
                            ),
                          ),
                          Text(
                            mode.description,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: P.inkDimmer(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (current == mode)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: isDark ? Colors.white.withAlpha(180) : acc,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(DisplayMode mode) => switch (mode) {
    DisplayMode.compactGrid     => Icons.grid_view_rounded,
    DisplayMode.comfortableGrid => Icons.dashboard_rounded,
    DisplayMode.list            => Icons.view_list_rounded,
  };
}

// ── _GlassDropdown ────────────────────────────────────────────

class _GlassDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _GlassDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.borderSoft(context), width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.expand_more_rounded, size: 18, color: inkDim),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: ink),
          dropdownColor: isDark ? const Color(0xFF16161F) : const Color(0xFFF5F4F0),
          borderRadius: BorderRadius.circular(14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── _StatusChip ───────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    final acc    = P.accent(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white.withAlpha(22) : acc.withAlpha(22))
              : (isDark ? Colors.white.withAlpha(8)  : Colors.black.withAlpha(5)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white.withAlpha(50) : acc.withAlpha(80))
                : P.borderSoft(context),
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? ink : inkDim,
            letterSpacing: -0.01,
          ),
        ),
      ),
    );
  }
}

// ── _SheetButton ──────────────────────────────────────────────

class _SheetButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _SheetButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = P.isDark(context);
    final ink     = P.ink(context);
    final inkDim  = P.inkDim(context);
    final acc     = P.accent(context);
    final enabled = onTap != null;

    final Color bg;
    final Color border;
    final Color textColor;

    if (filled) {
      bg        = isDark ? Colors.white.withAlpha(28) : acc.withAlpha(28);
      border    = isDark ? Colors.white.withAlpha(56) : acc.withAlpha(80);
      textColor = ink;
    } else {
      bg = enabled
          ? (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8))
          : Colors.transparent;
      border    = enabled ? P.border(context) : P.borderSoft(context);
      textColor = enabled ? inkDim : P.inkDimmer(context);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: -0.01,
          ),
        ),
      ),
    );
  }
}
