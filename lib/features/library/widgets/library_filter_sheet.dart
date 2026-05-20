// ─────────────────────────────────────────────────────────────
// lib/features/library/widgets/library_filter_sheet.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/bookmark.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../providers/library_providers.dart';

void showLibraryFilterSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Tab bar
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Filter'),
            Tab(text: 'Sort'),
            Tab(text: 'Display'),
          ],
        ),

        // Fixed-height tab content — sized to the tallest tab (Filter)
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
  int? _draftMinRating;
  String? _draftGenre;

  @override
  void initState() {
    super.initState();
    _draftStatus = ref.read(statusFilterProvider);
    _draftMinRating = ref.read(minRatingFilterProvider);
    _draftGenre = ref.read(genreFilterProvider);
  }

  void _applyFilters() {
    ref.read(statusFilterProvider.notifier).state = _draftStatus;
    ref.read(minRatingFilterProvider.notifier).state = _draftMinRating;
    ref.read(genreFilterProvider.notifier).state = _draftGenre;
    Navigator.of(context).pop();
  }

  void _clearFilters() {
    setState(() {
      _draftStatus = null;
      _draftMinRating = null;
      _draftGenre = null;
    });
    ref.read(statusFilterProvider.notifier).state = null;
    ref.read(minRatingFilterProvider.notifier).state = null;
    ref.read(genreFilterProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkListProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Statuses sorted A–Z (All always first)
    final sortedStatuses = BookmarkStatus.all.toList()
      ..sort(
        (a, b) => BookmarkStatus.label(a).compareTo(BookmarkStatus.label(b)),
      );

    // Genres sorted A–Z from bookmarks
    final allGenres = bookmarksAsync.whenOrNull(
          data: (list) {
            final genres = <String>{};
            for (final b in list) {
              genres.addAll(b.mediaItem.genres);
            }
            return (genres.toList()..sort());
          },
        ) ??
        [];

    // Guard against a stale draft genre that no longer exists
    final effectiveGenre =
        (_draftGenre != null && allGenres.contains(_draftGenre))
            ? _draftGenre
            : null;

    final hasLocalFilters =
        _draftStatus != null || _draftMinRating != null || effectiveGenre != null;

    final labelStyle =
        tt.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant);

    const dropdownBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );
    const dropdownDecoration = InputDecoration(
      border: dropdownBorder,
      enabledBorder: dropdownBorder,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      isDense: true,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status ────────────────────────────────────────
          Text('Status', style: labelStyle),
          const SizedBox(height: 4),
          InputDecorator(
            decoration: dropdownDecoration,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _draftStatus,
                isExpanded: true,
                isDense: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final s in sortedStatuses)
                    DropdownMenuItem(
                      value: s,
                      child: Text(BookmarkStatus.label(s)),
                    ),
                ],
                onChanged: (v) => setState(() => _draftStatus = v),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Rating ────────────────────────────────────────
          Text('Rating', style: labelStyle),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int?>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: null, label: Text('Any')),
                ButtonSegment(value: 6, label: Text('3★+')),
                ButtonSegment(value: 8, label: Text('4★+')),
                ButtonSegment(value: 10, label: Text('5★')),
              ],
              selected: {_draftMinRating},
              onSelectionChanged: (s) =>
                  setState(() => _draftMinRating = s.first),
            ),
          ),

          const SizedBox(height: 10),

          // ── Genre ─────────────────────────────────────────
          Text('Genre', style: labelStyle),
          const SizedBox(height: 4),
          InputDecorator(
            decoration: dropdownDecoration,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: effectiveGenre,
                isExpanded: true,
                isDense: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  for (final g in allGenres)
                    DropdownMenuItem(value: g, child: Text(g)),
                ],
                onChanged: allGenres.isEmpty
                    ? null
                    : (v) => setState(() => _draftGenre = v),
              ),
            ),
          ),

          const Spacer(),

          // ── Apply / Clear ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: hasLocalFilters ? _clearFilters : null,
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _applyFilters,
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sort tab ──────────────────────────────────────────────────

class _SortTab extends ConsumerWidget {
  const _SortTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sortOrderProvider);

    return RadioGroup<SortOrder>(
      groupValue: current,
      onChanged: (v) {
        if (v != null) ref.read(sortOrderProvider.notifier).state = v;
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          for (final order in SortOrder.values)
            RadioListTile<SortOrder>(
              title: Text(order.label),
              value: order,
              dense: true,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

// ── Display tab ───────────────────────────────────────────────

class _DisplayTab extends ConsumerWidget {
  const _DisplayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(displayModeProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final mode in DisplayMode.values)
          _DisplayModeTile(
            mode: mode,
            isSelected: current == mode,
            onTap: () => ref.read(displayModeProvider.notifier).set(mode),
          ),
      ],
    );
  }
}

class _DisplayModeTile extends StatelessWidget {
  final DisplayMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _DisplayModeTile({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon => switch (mode) {
        DisplayMode.compactGrid => Icons.grid_view_rounded,
        DisplayMode.comfortableGrid => Icons.dashboard_rounded,
        DisplayMode.list => Icons.view_list_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? cs.secondaryContainer : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? cs.secondary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _icon,
                size: 24,
                color:
                    isSelected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? cs.onSecondaryContainer : cs.onSurface,
                      ),
                    ),
                    Text(
                      mode.description,
                      style: tt.bodySmall?.copyWith(
                        color: isSelected
                            ? cs.onSecondaryContainer.withAlpha(180)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, size: 20, color: cs.secondary),
            ],
          ),
        ),
      ),
    );
  }
}
