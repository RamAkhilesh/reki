// ─────────────────────────────────────────────────────────────
// lib/features/library/screens/library_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../data/models/bookmark.dart';
import '../../../features/bookmarks/providers/bookmark_providers.dart';
import '../../../features/bookmarks/widgets/add_edit_bookmark_sheet.dart';
import '../../../features/search/providers/search_providers.dart';
import '../providers/library_providers.dart';
import '../widgets/comfortable_grid_card.dart';
import '../widgets/compact_list_tile_card.dart';
import '../widgets/library_filter_sheet.dart';
import '../widgets/poster_grid_card.dart';

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


class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  bool _searchActive = false;
  String _query = '';

  void _activateSearch() {
    setState(() => _searchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _clearSearch() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _query = '';
      _searchActive = false;
    });
  }

  void _openEditDeleteSheet(Bookmark bookmark) {
    HapticFeedback.mediumImpact();
    showEditDeleteSheet(
      context,
      bookmark,
      onDelete: () =>
          ref.read(bookmarkListProvider.notifier).remove(bookmark.id),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildTitleRow(TextTheme tt, ColorScheme cs, bool hasFilters) {
    return Padding(
      key: const ValueKey('title'),
      padding: const EdgeInsets.fromLTRB(20, 10, 4, 2),
      child: Row(
        children: [
          Text(
            'Library',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: _activateSearch,
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Filter, Sort & Display',
                onPressed: () => showLibraryFilterSheet(context),
              ),
              if (hasFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return Padding(
      key: const ValueKey('search'),
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _clearSearch,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search your library…',
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                isDense: true,
              ),
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final displayMode = ref.watch(displayModeProvider);
    final hasFilters = ref.watch(hasActiveFiltersProvider);
    final presentTypesAsync = ref.watch(presentMediaTypesProvider);

    ref.listen(librarySearchFocusRequestProvider, (_, _) {
      _activateSearch();
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title row / Search bar (toggled) ──────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _searchActive
                  ? _buildSearchBar(cs)
                  : _buildTitleRow(tt, cs, hasFilters),
            ),

            // ── Tabs + content ────────────────────────────────
            Expanded(
              child: presentTypesAsync.when(
                loading: () =>
                    _LibraryLoadingSkeleton(displayMode: displayMode),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load: $e'),
                  ),
                ),
                data: (presentTypes) {
                  if (presentTypes.isEmpty) {
                    return const _EmptyState();
                  }
                  return _LibraryTabView(
                    key: ValueKey(presentTypes.join(',')),
                    tabs: presentTypes,
                    query: _query,
                    onLongPress: _openEditDeleteSheet,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab host ─────────────────────────────────────────────────
// Keyed by the tab list so it rebuilds when new media types appear.

class _LibraryTabView extends ConsumerStatefulWidget {
  final List<String> tabs; // 'all' = show all types, else a media type string
  final String query;
  final void Function(Bookmark) onLongPress;

  const _LibraryTabView({
    required super.key,
    required this.tabs,
    required this.query,
    required this.onLongPress,
  });

  @override
  ConsumerState<_LibraryTabView> createState() => _LibraryTabViewState();
}

class _LibraryTabViewState extends ConsumerState<_LibraryTabView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final pendingType = ref.read(pendingLibraryTabTypeProvider);
    final lastTab = ref.read(lastLibraryTabProvider);
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: _indexOf(pendingType ?? lastTab),
    );
    _tabController.addListener(_onTabChanged);
    if (pendingType != null) {
      Future.microtask(() {
        if (mounted) {
          ref.read(pendingLibraryTabTypeProvider.notifier).state = null;
        }
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final currentType = widget.tabs[_tabController.index];
    ref.read(lastLibraryTabProvider.notifier).save(currentType);
  }

  // Returns the tab index for [type], or 0 if not found / null.
  int _indexOf(String? type) {
    if (type == null) return 0;
    final idx = widget.tabs.indexOf(type);
    return idx != -1 ? idx : 0;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle navigations when this widget is already mounted.
    ref.listen<String?>(pendingLibraryTabTypeProvider, (_, next) {
      if (next == null) return;
      _tabController.animateTo(_indexOf(next));
      ref.read(pendingLibraryTabTypeProvider.notifier).state = null;
    });

    final cs = Theme.of(context).colorScheme;

    // Compute per-tab result counts while the search query is active.
    Map<String, int>? tabCounts;
    final q = widget.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final statusFilter = ref.watch(statusFilterProvider);
      final minRating = ref.watch(minRatingFilterProvider);
      final genre = ref.watch(genreFilterProvider);
      ref.watch(bookmarkListProvider).whenData((all) {
        var matched = all
            .where((b) => b.mediaItem.title.toLowerCase().contains(q))
            .toList();
        if (statusFilter != null) {
          matched = matched.where((b) => b.status == statusFilter).toList();
        }
        if (minRating != null) {
          matched =
              matched.where((b) => (b.rating ?? 0) >= minRating).toList();
        }
        if (genre != null) {
          matched =
              matched.where((b) => b.mediaItem.genres.contains(genre)).toList();
        }
        tabCounts = {
          for (final type in widget.tabs)
            type: type == 'all'
                ? matched.length
                : matched
                    .where((b) => b.mediaItem.mediaType == type)
                    .length,
        };
      });
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: cs.outlineVariant,
          tabs: [
            for (final type in widget.tabs)
              _buildTab(type, tabCounts?[type]),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (final type in widget.tabs)
                _TabContent(
                  mediaType: type,
                  query: widget.query,
                  onLongPress: widget.onLongPress,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Tab _buildTab(String type, int? count) {
    final label = _typeLabel(type);
    if (count == null || count == 0) return Tab(text: label);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 5),
          _SearchCountBadge(count: count),
        ],
      ),
    );
  }
}

// ── Tab content ───────────────────────────────────────────────
// Filters by media type, applies status filter + sort, groups by status.

class _TabContent extends ConsumerStatefulWidget {
  final String mediaType; // 'all' = show all types
  final String query;
  final void Function(Bookmark) onLongPress;

  const _TabContent({
    required this.mediaType,
    required this.query,
    required this.onLongPress,
  });

  @override
  ConsumerState<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends ConsumerState<_TabContent>
    with AutomaticKeepAliveClientMixin {
  late Set<String> _collapsedStatuses;

  @override
  void initState() {
    super.initState();
    _collapsedStatuses = Set<String>.from(
      ref.read(collapsedStatusGroupsProvider)[widget.mediaType] ?? {},
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final displayMode = ref.watch(displayModeProvider);
    final bookmarksAsync = ref.watch(bookmarkListProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final sortOrder = ref.watch(sortOrderProvider);

    final minRating = ref.watch(minRatingFilterProvider);
    final genre = ref.watch(genreFilterProvider);

    return bookmarksAsync.when(
      loading: () => _LibraryLoadingSkeleton(displayMode: displayMode),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allBookmarks) {
        var filtered = widget.mediaType == 'all'
            ? allBookmarks
            : allBookmarks
                .where((b) => b.mediaItem.mediaType == widget.mediaType)
                .toList();

        final q = widget.query.trim().toLowerCase();
        if (q.isNotEmpty) {
          filtered = filtered
              .where(
                  (b) => b.mediaItem.title.toLowerCase().contains(q))
              .toList();
        }

        if (statusFilter != null) {
          filtered =
              filtered.where((b) => b.status == statusFilter).toList();
        }

        if (minRating != null) {
          filtered =
              filtered.where((b) => (b.rating ?? 0) >= minRating).toList();
        }

        if (genre != null) {
          filtered =
              filtered.where((b) => b.mediaItem.genres.contains(genre)).toList();
        }

        filtered = sortedBookmarks(filtered, sortOrder);

        if (filtered.isEmpty) {
          return q.isNotEmpty
              ? _EmptySearch(
                  query: widget.query.trim(),
                  onSearchGlobally: () {
                    ref.read(pendingSearchQueryProvider.notifier).state =
                        widget.query.trim();
                    ref.read(shellTabIndexProvider.notifier).state =
                        ShellTab.search;
                  },
                )
              : const _EmptyState();
        }

        // Group by status in canonical order
        final groups = <String, List<Bookmark>>{};
        for (final status in BookmarkStatus.all) {
          final items = filtered.where((b) => b.status == status).toList();
          if (items.isNotEmpty) groups[status] = items;
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final status = groups.keys.elementAt(i);
            final items = groups[status]!;
            final isExpanded = !_collapsedStatuses.contains(status);
            return _StatusGroup(
              status: status,
              bookmarks: items,
              displayMode: displayMode,
              isExpanded: isExpanded,
              onToggle: () {
                setState(() {
                  if (_collapsedStatuses.contains(status)) {
                    _collapsedStatuses.remove(status);
                  } else {
                    _collapsedStatuses.add(status);
                  }
                });
                ref
                    .read(collapsedStatusGroupsProvider.notifier)
                    .toggleStatus(widget.mediaType, status);
              },
              onTap: (b) =>
                  context.push(AppRoutes.mediaDetail, extra: b.mediaItem),
              onLongPress: widget.onLongPress,
            );
          },
        );
      },
    );
  }
}

// ── Status group (collapsible) ────────────────────────────────

class _StatusGroup extends StatelessWidget {
  final String status;
  final List<Bookmark> bookmarks;
  final DisplayMode displayMode;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(Bookmark) onTap;
  final void Function(Bookmark) onLongPress;

  const _StatusGroup({
    required this.status,
    required this.bookmarks,
    required this.displayMode,
    required this.isExpanded,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
            child: Row(
              children: [
                Text(
                  BookmarkStatus.label(status),
                  style:
                      tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${bookmarks.length}',
                    style: tt.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Animated body ────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: isExpanded
              ? _buildContent()
              : const SizedBox(width: double.infinity),
        ),

        Divider(height: 1, thickness: 0.5, color: cs.outlineVariant),
      ],
    );
  }

  Widget _buildContent() {
    if (displayMode == DisplayMode.list) {
      return Column(
        children: [
          for (final b in bookmarks)
            CompactListTileCard(
              bookmark: b,
              onTap: () => onTap(b),
              onLongPress: () => onLongPress(b),
            ),
          const SizedBox(height: 8),
        ],
      );
    }

    final isCompact = displayMode == DisplayMode.compactGrid;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isCompact ? 4 : 3,
        mainAxisSpacing: isCompact ? 8 : 10,
        crossAxisSpacing: isCompact ? 8 : 10,
        childAspectRatio: isCompact ? 0.65 : 0.56,
      ),
      itemCount: bookmarks.length,
      itemBuilder: (context, i) => isCompact
          ? PosterGridCard(
              bookmark: bookmarks[i],
              onTap: () => onTap(bookmarks[i]),
              onLongPress: () => onLongPress(bookmarks[i]),
            )
          : ComfortableGridCard(
              bookmark: bookmarks[i],
              onTap: () => onTap(bookmarks[i]),
              onLongPress: () => onLongPress(bookmarks[i]),
            ),
    );
  }
}

// ── Search result count badge (shown inline in tab labels) ────

class _SearchCountBadge extends StatelessWidget {
  final int count;
  const _SearchCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────

class _LibraryLoadingSkeleton extends StatelessWidget {
  final DisplayMode displayMode;
  const _LibraryLoadingSkeleton({required this.displayMode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (displayMode == DisplayMode.list) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 88),
        itemCount: 10,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 68,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80)),
        ),
      );
    }

    final crossAxisCount = displayMode == DisplayMode.compactGrid ? 4 : 3;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: displayMode == DisplayMode.compactGrid ? 8 : 10,
        crossAxisSpacing: displayMode == DisplayMode.compactGrid ? 8 : 10,
        childAspectRatio:
            displayMode == DisplayMode.compactGrid ? 0.65 : 0.56,
      ),
      itemCount: crossAxisCount * 4,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80)),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 36,
                color: cs.onSurfaceVariant.withAlpha(160),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nothing here yet',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0, duration: 300.ms);
  }
}

class _EmptySearch extends StatelessWidget {
  final String query;
  final VoidCallback? onSearchGlobally;

  const _EmptySearch({required this.query, this.onSearchGlobally});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36,
                color: cs.onSurfaceVariant.withAlpha(160),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only titles in your library are searched.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (onSearchGlobally != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onSearchGlobally,
                child: Text('Search "$query" in Discover'),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0, duration: 300.ms);
  }
}
