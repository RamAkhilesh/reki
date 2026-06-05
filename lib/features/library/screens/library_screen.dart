// ─────────────────────────────────────────────────────────────
// lib/features/library/screens/library_screen.dart
// Prism redesign — glass library screen.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/prism_tokens.dart';
import '../../../data/models/bookmark.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../../bookmarks/widgets/add_edit_bookmark_sheet.dart';
import '../../search/providers/search_providers.dart';
import '../providers/library_providers.dart';
import '../widgets/comfortable_grid_card.dart';
import '../widgets/compact_list_tile_card.dart';
import '../widgets/library_filter_sheet.dart';
import '../widgets/poster_grid_card.dart';

String _typeLabel(String type) => switch (type) {
      'all'   => 'All',
      'movie' => 'Movies',
      'tv'    => 'TV Shows',
      'anime' => 'Anime',
      'manga' => 'Manga',
      'game'  => 'Games',
      'book'  => 'Books',
      _       => type,
    };

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _focusNode   = FocusNode();
  final _controller  = TextEditingController();
  bool  _searchActive = false;
  String _query       = '';

  void _activateSearch() {
    setState(() => _searchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { _focusNode.requestFocus(); }
    });
  }

  void _clearSearch() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() { _query = ''; _searchActive = false; });
  }

  void _openEditDeleteSheet(Bookmark bookmark) {
    HapticFeedback.mediumImpact();
    showEditDeleteSheet(
      context,
      bookmark,
      onDelete: () => ref.read(bookmarkListProvider.notifier).remove(bookmark.id),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(librarySearchFocusRequestProvider, (_, _) => _activateSearch());

    final displayMode      = ref.watch(displayModeProvider);
    final hasFilters       = ref.watch(hasActiveFiltersProvider);
    final presentTypesAsync = ref.watch(presentMediaTypesProvider);
    final allAsync         = ref.watch(bookmarkListProvider);

    final allBookmarks   = allAsync.value ?? [];

    final ink       = P.ink(context);
    final inkDim    = P.inkDim(context);

    return PopScope(
      canPop: !_searchActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSearch();
      },
      child: Stack(
      children: [
        // ── Ambient backdrop ──────────────────────────────
        const Positioned.fill(child: PrismBackdrop(variant: 'warm')),

        // ── Content ───────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: _searchActive
                    ? _buildSearchBar(context)
                    : _buildHeader(context, allBookmarks.length, hasFilters, ink, inkDim),
              ),

              // ── Tabs + content ────────────────────────────
              Expanded(
                child: presentTypesAsync.when(
                  loading: () => _LibraryLoadingSkeleton(displayMode: displayMode),
                  error: (e, _) => Center(
                    child: Text(
                      'Failed to load: $e',
                      style: GoogleFonts.inter(fontSize: 14, color: P.inkDim(context)),
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
      ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int total,
    bool hasFilters,
    Color ink,
    Color inkDim,
  ) {
    return Padding(
      key: const ValueKey('header'),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -0.035 * 32,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$total item${total == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(fontSize: 12, color: inkDim),
                ),
              ],
            ),
          ),
          GlassButton(
            size: 38,
            onTap: _activateSearch,
            child: Icon(Icons.search_rounded, size: 19, color: ink),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    return Padding(
      key: const ValueKey('search'),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
      child: GlassCard(
        radius: 28,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: ink, size: 20),
              onPressed: _clearSearch,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode:  _focusNode,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w500, color: ink,
                ),
                decoration: InputDecoration(
                  hintText: 'Search your library…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w500, color: inkDim,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 16,
                  ),
                  isDense: true,
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: inkDim, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab host ─────────────────────────────────────────────────

class _LibraryTabView extends ConsumerStatefulWidget {
  final List<String> tabs;
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
  final _pillScrollController = ScrollController();
  late List<GlobalKey> _pillKeys;

  @override
  void initState() {
    super.initState();
    _pillKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    final pendingType = ref.read(pendingLibraryTabTypeProvider);
    final lastTab     = ref.read(lastLibraryTabProvider);
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
    _scrollActivePillIntoView();
  }

  void _scrollActivePillIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = _tabController.index;
      if (idx >= _pillKeys.length) return;
      final ctx = _pillKeys[idx].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int _indexOf(String? type) {
    if (type == null) return 0;
    final idx = widget.tabs.indexOf(type);
    return idx != -1 ? idx : 0;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pillScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingLibraryTabTypeProvider, (_, next) {
      if (next == null) return;
      _tabController.animateTo(
        _indexOf(next),
        duration: const Duration(milliseconds: 200),
      );
      ref.read(pendingLibraryTabTypeProvider.notifier).state = null;
    });

    // Always compute per-tab counts from the full bookmark list.
    final allBookmarks = ref.watch(bookmarkListProvider).value ?? [];
    final tabCounts = <String, int>{
      for (final type in widget.tabs)
        type: type == 'all'
            ? allBookmarks.length
            : allBookmarks.where((b) => b.mediaItem.mediaType == type).length,
    };

    return Column(
      children: [
        // ── Tab labels ────────────────────────────────────
        ListenableBuilder(
          listenable: _tabController,
          builder: (ctx, _) {
            final selectedIndex = _tabController.index;
            return SizedBox(
              height: 42,
              child: ListView.builder(
                controller: _pillScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                itemCount: widget.tabs.length,
                itemBuilder: (ctx, i) {
                  final type     = widget.tabs[i];
                  final label    = _typeLabel(type);
                  final selected = i == selectedIndex;
                  final count    = tabCounts[type] ?? 0;

                  return SizedBox(
                    key: _pillKeys[i],
                    child: _TabLabel(
                      label: label,
                      count: count,
                      selected: selected,
                      onTap: () => _tabController.animateTo(
                        i,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),

        // ── Sort & filter row ─────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => showLibraryFilterSheet(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded, size: 13, color: P.inkDim(context)),
                  const SizedBox(width: 4),
                  Text(
                    'Sort & filter',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500, color: P.inkDim(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Tab content ───────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (int i = 0; i < widget.tabs.length; i++)
                _TabContent(
                  mediaType: widget.tabs[i],
                  tabIndex: i,
                  tabController: _tabController,
                  query: widget.query,
                  onLongPress: widget.onLongPress,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab label ─────────────────────────────────────────────────

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    final acc    = P.accent(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? acc.withAlpha(28) : Colors.transparent,
            border: Border.all(
              color: selected ? acc.withAlpha(90) : P.borderSoft(context),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? ink : inkDim,
                  letterSpacing: -0.01,
                ),
                child: Text(label),
              ),
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? acc.withAlpha(55) : ink.withAlpha(20),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? acc : inkDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab content ───────────────────────────────────────────────

class _TabContent extends ConsumerStatefulWidget {
  final String mediaType;
  final int tabIndex;
  final TabController tabController;
  final String query;
  final void Function(Bookmark) onLongPress;

  const _TabContent({
    required this.mediaType,
    required this.tabIndex,
    required this.tabController,
    required this.query,
    required this.onLongPress,
  });

  @override
  ConsumerState<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends ConsumerState<_TabContent>
    with AutomaticKeepAliveClientMixin {
  late Set<String> _collapsedStatuses;
  final _scrollController = ScrollController();

  final _groupKeys = <String, GlobalKey>{
    'watching':       GlobalKey(),
    'want_to_watch':  GlobalKey(),
    'completed':      GlobalKey(),
    'dropped':        GlobalKey(),
    'on_hold':        GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _collapsedStatuses = Set<String>.from(
      ref.read(collapsedStatusGroupsProvider)[widget.mediaType] ?? {},
    );
    widget.tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (widget.tabController.index == widget.tabIndex &&
        !widget.tabController.indexIsChanging) {
      final filter = ref.read(statusFilterProvider);
      if (filter != null) _scrollToGroup(filter);
    }
  }

  void _scrollToGroup(String status) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _groupKeys[status]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // When a filter is applied, immediately sync _collapsedStatuses to the
    // visual state it enforces (filtered section = expanded, all others =
    // collapsed) so that state persists after the filter is cleared.
    // Also guard the scroll call to the active tab only — otherwise
    // Scrollable.ensureVisible on a keepalive'd off-screen tab walks up to
    // the TabBarView (PageView) and switches tabs.
    ref.listen<String?>(statusFilterProvider, (_, next) {
      if (next != null) {
        setState(() {
          for (final s in BookmarkStatus.all) {
            if (s == next) {
              _collapsedStatuses.remove(s);
            } else {
              _collapsedStatuses.add(s);
            }
          }
        });
        ref.read(collapsedStatusGroupsProvider.notifier)
            .setCollapsedForTab(widget.mediaType, _collapsedStatuses);
        if (widget.tabController.index == widget.tabIndex) {
          _scrollToGroup(next);
        }
      }
    });

    final displayMode  = ref.watch(displayModeProvider);
    final bookmarksAsync = ref.watch(bookmarkListProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final sortOrder    = ref.watch(sortOrderProvider);
    final genre        = ref.watch(genreFilterProvider);

    return bookmarksAsync.when(
      loading: () => _LibraryLoadingSkeleton(displayMode: displayMode),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.inter(fontSize: 13, color: P.inkDim(context))),
      ),
      data: (allBookmarks) {
        var filtered = widget.mediaType == 'all'
            ? allBookmarks
            : allBookmarks
                .where((b) => b.mediaItem.mediaType == widget.mediaType)
                .toList();

        final q = widget.query.trim().toLowerCase();
        if (q.isNotEmpty) {
          filtered = filtered
              .where((b) => b.mediaItem.title.toLowerCase().contains(q))
              .toList();
        }
        // Status filter controls expand/collapse, not item visibility.
        if (genre != null) {
          filtered = filtered.where((b) => b.mediaItem.genres.contains(genre)).toList();
        }
        filtered = sortedBookmarks(filtered, sortOrder);

        if (filtered.isEmpty) {
          return q.isNotEmpty
              ? _EmptySearch(
                  query: widget.query.trim(),
                  onSearchGlobally: () {
                    ref.read(pendingSearchQueryProvider.notifier).state =
                        widget.query.trim();
                    ref.read(shellTabIndexProvider.notifier).state = ShellTab.search;
                  },
                )
              : const _EmptyState();
        }

        final groups = <String, List<Bookmark>>{};
        for (final status in BookmarkStatus.all) {
          final items = filtered.where((b) => b.status == status).toList();
          if (items.isNotEmpty) { groups[status] = items; }
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 110),
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final status = groups.keys.elementAt(i);
            final items  = groups[status]!;
            // When a filter is active: expand the matching section, collapse all others.
            // When no filter: restore each section's individually persisted state.
            final isExpanded = statusFilter != null
                ? status == statusFilter
                : !_collapsedStatuses.contains(status);
            return Container(
              key: _groupKeys[status],
              child: _StatusGroup(
                status: status,
                bookmarks: items,
                displayMode: displayMode,
                isExpanded: isExpanded,
                onToggle: () {
                  if (statusFilter != null) {
                    // _collapsedStatuses was already synced to visual state when
                    // the filter was applied, so isExpanded is the authoritative
                    // state. Toggle from it and persist the whole tab at once.
                    ref.read(statusFilterProvider.notifier).state = null;
                    setState(() {
                      if (isExpanded) {
                        _collapsedStatuses.add(status);
                      } else {
                        _collapsedStatuses.remove(status);
                      }
                    });
                    ref.read(collapsedStatusGroupsProvider.notifier)
                        .setCollapsedForTab(widget.mediaType, _collapsedStatuses);
                  } else {
                    setState(() {
                      if (_collapsedStatuses.contains(status)) {
                        _collapsedStatuses.remove(status);
                      } else {
                        _collapsedStatuses.add(status);
                      }
                    });
                    ref.read(collapsedStatusGroupsProvider.notifier)
                        .toggleStatus(widget.mediaType, status);
                  }
                },
                onTap: (b) => context.push(AppRoutes.mediaDetail, extra: b.mediaItem),
                onLongPress: widget.onLongPress,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Status group ──────────────────────────────────────────────

class _StatusGroup extends StatelessWidget {
  const _StatusGroup({
    required this.status,
    required this.bookmarks,
    required this.displayMode,
    required this.isExpanded,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
  });

  final String status;
  final List<Bookmark> bookmarks;
  final DisplayMode displayMode;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(Bookmark) onTap;
  final void Function(Bookmark) onLongPress;

  @override
  Widget build(BuildContext context) {
    final statusColor = P.statusColor(status);
    final ink         = P.ink(context);
    final inkDim      = P.inkDim(context);
    final borderSoft  = P.borderSoft(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [BoxShadow(color: statusColor, blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  BookmarkStatus.label(status),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    letterSpacing: -0.01,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${bookmarks.length}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: inkDim,
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: inkDim,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Animated content
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: isExpanded ? _buildContent(context) : const SizedBox(width: double.infinity),
        ),

        Divider(height: 1, thickness: 0.5, color: borderSoft),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
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

// ── Loading skeleton ──────────────────────────────────────────

class _LibraryLoadingSkeleton extends StatelessWidget {
  final DisplayMode displayMode;
  const _LibraryLoadingSkeleton({required this.displayMode});

  @override
  Widget build(BuildContext context) {
    final glass = P.glass(context);
    final ink   = P.ink(context);

    if (displayMode == DisplayMode.list) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 110),
        itemCount: 10,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 48, height: 68,
                decoration: BoxDecoration(
                  color: glass,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14, width: double.infinity,
                      decoration: BoxDecoration(
                        color: glass, borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12, width: 80,
                      decoration: BoxDecoration(
                        color: glass, borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1200.ms, color: ink.withAlpha(20)),
        ),
      );
    }

    final crossAxisCount = displayMode == DisplayMode.compactGrid ? 4 : 3;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: displayMode == DisplayMode.compactGrid ? 8 : 10,
        crossAxisSpacing: displayMode == DisplayMode.compactGrid ? 8 : 10,
        childAspectRatio: displayMode == DisplayMode.compactGrid ? 0.65 : 0.56,
      ),
      itemCount: crossAxisCount * 4,
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: glass,
          borderRadius: BorderRadius.circular(10),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: ink.withAlpha(20)),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(
              radius: 28,
              tint: P.accent(context),
              child: const SizedBox(
                width: 72, height: 72,
                child: Center(
                  child: Icon(Icons.video_library_outlined, size: 32, color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nothing here yet',
              style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.02,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: inkDim),
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
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(
              radius: 28,
              child: const SizedBox(
                width: 72, height: 72,
                child: Center(
                  child: Icon(Icons.search_off_rounded, size: 32, color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.02,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only titles in your library are searched.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: inkDim),
            ),
            if (onSearchGlobally != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onSearchGlobally,
                child: GlassCard(
                  radius: 100,
                  tint: P.accent(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'Search "$query" in Discover',
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
                      ),
                    ),
                  ),
                ),
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
