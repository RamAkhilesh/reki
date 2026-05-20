// ─────────────────────────────────────────────────────────────
// lib/features/search/screens/search_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../../bookmarks/widgets/add_edit_bookmark_sheet.dart';
import '../providers/search_providers.dart';
import '../widgets/media_card.dart';
import '../widgets/search_filter_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _clearAndCollapse() {
    _controller.clear();
    _focusNode.unfocus();
    ref.read(searchNotifierProvider.notifier).clearSearch();
  }

  void _showFilterSheet(BuildContext context) {
    final currentFilters = ref.read(searchNotifierProvider).activeFilters;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SearchFilterSheet(
        initialFilters: currentFilters,
        onApply: (filters) =>
            ref.read(searchNotifierProvider.notifier).setFilters(filters),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchFocusRequestProvider, (_, _) {
      _focusNode.requestFocus();
    });
    ref.listen(searchResetProvider, (_, _) {
      _clearAndCollapse();
    });
    ref.listen<String?>(pendingSearchQueryProvider, (_, query) {
      if (query == null) return;
      _controller.text = query;
      ref.read(searchNotifierProvider.notifier).onQueryChanged(query);
      ref.read(pendingSearchQueryProvider.notifier).state = null;
      setState(() {});
      _focusNode.requestFocus();
    });

    final searchState = ref.watch(searchNotifierProvider);
    final showResultsPanel = _isFocused || searchState.showResults;
    final cs = Theme.of(context).colorScheme;

    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── "Discover" title — collapses when searching ──
            AnimatedSize(
              duration: 220.ms,
              curve: Curves.easeInOut,
              child: showResultsPanel
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                      child: Text(
                        'Discover',
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
            ),

            // ── Search field ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  // Back/collapse button — only visible when focused
                  AnimatedSwitcher(
                    duration: 200.ms,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: _isFocused
                        ? IconButton(
                            key: const ValueKey('back'),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Back',
                            onPressed: _clearAndCollapse,
                          )
                        : const SizedBox(key: ValueKey('spacer'), width: 4),
                  ),

                  // Search text field
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Movies, shows, anime, books, games…',
                        prefixIcon: _isFocused
                            ? null
                            : const Icon(Icons.search_rounded),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Clear',
                                onPressed: () {
                                  _controller.clear();
                                  ref
                                      .read(searchNotifierProvider.notifier)
                                      .clearSearch();
                                  setState(() {});
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
                      onChanged: (q) {
                        setState(() {});
                        ref
                            .read(searchNotifierProvider.notifier)
                            .onQueryChanged(q);
                      },
                    ),
                  ),

                  // Filter button — visible only in results mode
                  AnimatedSwitcher(
                    duration: 200.ms,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: showResultsPanel
                        ? Badge(
                            key: const ValueKey('filter-visible'),
                            isLabelVisible:
                                searchState.activeFilters.isActive,
                            smallSize: 6,
                            child: IconButton(
                              icon: const Icon(Icons.tune_rounded),
                              tooltip: 'Filter',
                              onPressed: () => _showFilterSheet(context),
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('filter-hidden'),
                            width: 4,
                          ),
                  ),
                ],
              ),
            ),

            // ── Body — switches between discovery and results ──
            Expanded(
              child: AnimatedSwitcher(
                duration: 250.ms,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: showResultsPanel
                    ? _ResultsPanel(
                        key: const ValueKey('results'),
                        searchState: searchState,
                      )
                    : const _DiscoveryFeed(key: ValueKey('discovery')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Discovery feed ─────────────────────────────────────────────

class _DiscoveryFeed extends ConsumerWidget {
  const _DiscoveryFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        _CarouselSection(
          title: 'Trending this week',
          provider: trendingThisWeekProvider,
          delay: 0,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _CarouselSection(
          title: 'Popular right now',
          provider: popularRightNowProvider,
          delay: 60,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _CarouselSection(
          title: 'Trending anime',
          provider: trendingAnimeProvider,
          delay: 120,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _CarouselSection(
          title: 'Trending manga',
          provider: trendingMangaProvider,
          delay: 180,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _CarouselSection(
          title: 'Popular games',
          provider: popularGamesProvider,
          delay: 240,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _CarouselSection(
          title: 'Popular books',
          provider: popularBooksProvider,
          delay: 300,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _CarouselSection extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<MediaItem>>> provider;
  final int delay;

  const _CarouselSection({
    required this.title,
    required this.provider,
    required this.delay,
  });

  Future<void> _quickAdd(
    WidgetRef ref,
    BuildContext context,
    MediaItem item,
  ) async {
    try {
      await ref
          .read(bookmarkListProvider.notifier)
          .add(item, BookmarkStatus.wantToWatch);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} added to library'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final libraryKeys = ref.watch(libraryKeySetProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              title,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ).animate().fadeIn(duration: 300.ms, delay: delay.ms),
          SizedBox(
            height: 185,
            child: async.when(
              loading: () => ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (_, _) => _PlaceholderCard(cs: cs),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              data: (items) => ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final inLibrary = libraryKeys
                      .contains('${item.source}:${item.externalId}');
                  return MediaCard(
                    item: item,
                    inLibrary: inLibrary,
                    onTap: () => context.push(
                      AppRoutes.mediaDetail,
                      extra: item,
                    ),
                    onAdd: inLibrary
                        ? null
                        : () => showAddBookmarkSheet(context, item),
                    onDoubleTap: inLibrary
                        ? null
                        : () => _quickAdd(ref, context, item),
                  ).animate().fadeIn(
                    duration: 280.ms,
                    delay: (delay + i * 35).ms,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final ColorScheme cs;
  const _PlaceholderCard({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 100,
              height: 126,
              color: cs.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 90,
            height: 10,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80));
  }
}

// ── Results panel ──────────────────────────────────────────────

class _ResultsPanel extends ConsumerStatefulWidget {
  final SearchState searchState;

  const _ResultsPanel({super.key, required this.searchState});

  @override
  ConsumerState<_ResultsPanel> createState() => _ResultsPanelState();
}

class _ResultsPanelState extends ConsumerState<_ResultsPanel> {
  String _activeTab = 'all';

  static const _tabOrder = <String>['movie', 'tv', 'anime', 'manga', 'book', 'game'];
  static const _tabLabels = <String, String>{
    'movie': 'Movies',
    'tv': 'TV',
    'anime': 'Anime',
    'manga': 'Manga',
    'book': 'Books',
    'game': 'Games',
  };

  @override
  void didUpdateWidget(_ResultsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchState.query != widget.searchState.query) {
      _activeTab = 'all';
    }
  }

  Future<void> _quickAdd(MediaItem item) async {
    try {
      await ref
          .read(bookmarkListProvider.notifier)
          .add(item, BookmarkStatus.wantToWatch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} added to library'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final libraryKeys = ref.watch(libraryKeySetProvider);
    final searchState = widget.searchState;
    final filters = searchState.activeFilters;

    // Empty query — just show a prompt
    if (searchState.query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_rounded, size: 32, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              'What are you looking for?',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Movies, shows, anime,\nmanga, books, and games',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms);
    }

    // Loading
    if (searchState.isSearching) {
      return _SearchGridSkeleton(cs: cs);
    }

    // Error
    if (searchState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Search failed: ${searchState.error}',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.error),
          ),
        ),
      );
    }

    // Apply filter-sheet filters
    final filtered = searchState.results.where((item) {
      if (filters.mediaTypes.isNotEmpty &&
          !filters.mediaTypes.contains(item.mediaType)) {
        return false;
      }
      final inLib = libraryKeys.contains('${item.source}:${item.externalId}');
      return switch (filters.libraryFilter) {
        LibraryFilter.all => true,
        LibraryFilter.inLibrary => inLib,
        LibraryFilter.notInLibrary => !inLib,
      };
    }).toList();

    // No results
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No results for "${searchState.query}"',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (filters.isActive) ...[
              const SizedBox(height: 6),
              Text(
                'Try adjusting your filters',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      );
    }

    // Count by media type
    final typeCounts = <String, int>{};
    for (final item in filtered) {
      typeCounts[item.mediaType] = (typeCounts[item.mediaType] ?? 0) + 1;
    }
    final availableTypes = _tabOrder.where(typeCounts.containsKey).toList();

    // If the active tab no longer has results, fall back to 'all'
    if (_activeTab != 'all' && !availableTypes.contains(_activeTab)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _activeTab = 'all');
      });
    }

    // Apply type-tab filter on top of sheet filters
    final displayed = _activeTab == 'all'
        ? filtered
        : filtered.where((item) => item.mediaType == _activeTab).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Type navigation chips ──────────────────────────
        if (availableTypes.length >= 2) ...[
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              children: [
                _TypeChip(
                  label: 'All',
                  count: filtered.length,
                  selected: _activeTab == 'all',
                  onTap: () => setState(() => _activeTab = 'all'),
                ),
                for (final type in availableTypes)
                  _TypeChip(
                    label: _tabLabels[type]!,
                    count: typeCounts[type]!,
                    selected: _activeTab == type,
                    onTap: () => setState(() => _activeTab = type),
                  ),
              ],
            ),
          ),
        ],

        // ── Filter-active count strip ─────────────────────
        if (filters.isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  '${filtered.length} of ${searchState.results.length} results',
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // ── Results grid ──────────────────────────────────
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.65,
            ),
            itemCount: displayed.length,
            itemBuilder: (context, i) {
              final item = displayed[i];
              final inLibrary =
                  libraryKeys.contains('${item.source}:${item.externalId}');
              return _SearchGridItem(
                item: item,
                inLibrary: inLibrary,
                onAdd: inLibrary
                    ? null
                    : () => showAddBookmarkSheet(context, item),
                onDoubleTap: inLibrary ? null : () => _quickAdd(item),
              ).animate().fadeIn(duration: 220.ms, delay: (i * 30).ms);
            },
          ),
        ),
      ],
    );
  }
}

// ── Type navigation chip ───────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? cs.onPrimary.withAlpha(45)
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: tt.labelSmall?.copyWith(
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
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

// ── Individual result grid card ────────────────────────────────

class _SearchGridItem extends StatelessWidget {
  final MediaItem item;
  final bool inLibrary;
  final VoidCallback? onAdd;
  final VoidCallback? onDoubleTap;

  const _SearchGridItem({
    required this.item,
    required this.inLibrary,
    this.onAdd,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.mediaDetail, extra: item),
      onDoubleTap: onDoubleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster
            item.posterUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.posterUrl!,
                    httpHeaders: item.posterHeaders,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: cs.surfaceContainerHighest),
                    errorWidget: (_, _, _) => _SearchGridFallback(cs: cs),
                  )
                : _SearchGridFallback(cs: cs),

            // Gradient overlay (bottom fade to surface)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 1.0],
                    colors: [
                      Colors.transparent,
                      cs.surface.withAlpha(235),
                    ],
                  ),
                ),
              ),
            ),

            // In-library tint overlay (Mihon-style subtle wash)
            if (inLibrary)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary.withAlpha(38),
                  ),
                ),
              ),

            // Bottom info
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  _MediaTypeBadge(item: item),
                ],
              ),
            ),

            // In-library banner across the top (Mihon-style)
            if (inLibrary)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
      ),
    );
  }
}

class _MediaTypeBadge extends StatelessWidget {
  final MediaItem item;
  const _MediaTypeBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (Color bg, Color fg) = switch (item.mediaType) {
      'movie' => (cs.primaryContainer, cs.onPrimaryContainer),
      'tv' => (cs.secondary, cs.onSecondary),
      'anime' => (cs.tertiaryContainer, cs.onTertiaryContainer),
      'manga' => (cs.errorContainer, cs.onErrorContainer),
      'game' => (cs.inverseSurface, cs.onInverseSurface),
      'book' => (cs.secondaryContainer, cs.onSecondaryContainer),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        item.mediaTypeLabel,
        style: tt.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _SearchGridSkeleton extends StatelessWidget {
  final ColorScheme cs;
  const _SearchGridSkeleton({required this.cs});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.65,
      ),
      itemCount: 12,
      itemBuilder: (_, _) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(color: cs.surfaceContainerHighest),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80)),
    );
  }
}

class _SearchGridFallback extends StatelessWidget {
  final ColorScheme cs;
  const _SearchGridFallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 36),
    );
  }
}
