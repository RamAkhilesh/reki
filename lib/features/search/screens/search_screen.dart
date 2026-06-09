// ─────────────────────────────────────────────────────────────
// lib/features/search/screens/search_screen.dart
// Prism redesign — glass Discover / search screen.
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/prism_tokens.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../../bookmarks/widgets/add_edit_bookmark_sheet.dart';
import '../../library/providers/library_providers.dart';
import '../providers/search_providers.dart';
import '../widgets/search_filter_sheet.dart';

Color _mediaTypeBadgeColor(String type) => switch (type) {
  'movie' => const Color(0xFFF97316), // orange
  'tv'    => const Color(0xFF3B82F6), // blue
  'anime' => const Color(0xFF8B5CF6), // purple
  'manga' => const Color(0xFFEC4899), // pink
  'book'  => const Color(0xFF10B981), // emerald
  'game'  => const Color(0xFFEF4444), // red
  _       => const Color(0xFF6B7280), // grey fallback
};

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _focusNode  = FocusNode();
  final _controller = TextEditingController();
  bool _isFocused      = false;
  bool _filterSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() => _isFocused = _focusNode.hasFocus);

  void _clearAndCollapse() {
    _controller.clear();
    _focusNode.unfocus();
    ref.read(searchNotifierProvider.notifier).clearSearch();
  }

  void _showFilterSheet() {
    setState(() => _filterSheetOpen = true);
    final currentFilters = ref.read(searchNotifierProvider).activeFilters;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(100),
      builder: (_) => SearchFilterSheet(
        initialFilters: currentFilters,
        onApply: (filters) =>
            ref.read(searchNotifierProvider.notifier).setFilters(filters),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _filterSheetOpen = false);
    });
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
    ref.listen(searchFocusRequestProvider, (_, _) => _focusNode.requestFocus());
    ref.listen(searchResetProvider, (_, _) => _clearAndCollapse());
    ref.listen<String?>(pendingSearchQueryProvider, (_, query) {
      if (query == null) return;
      _controller.text = query;
      ref.read(searchNotifierProvider.notifier).onQueryChanged(query);
      ref.read(pendingSearchQueryProvider.notifier).state = null;
      setState(() {});
      _focusNode.requestFocus();
    });

    final searchState    = ref.watch(searchNotifierProvider);
    final showResults    = _isFocused || _filterSheetOpen || searchState.showResults;
    final ink            = P.ink(context);
    final inkDim         = P.inkDim(context);

    return PopScope(
      canPop: !showResults,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearAndCollapse();
      },
      child: Stack(
      children: [
        // ── Ambient backdrop ──────────────────────────────
        const Positioned.fill(child: PrismBackdrop(variant: 'cool')),

        // ── Content ───────────────────────────────────────
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header + search bar ───────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title — collapses when searching
                    AnimatedSize(
                      duration: 220.ms,
                      curve: Curves.easeInOut,
                      child: showResults
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Text(
                                'Discover',
                                style: GoogleFonts.inter(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                  letterSpacing: -0.035 * 32,
                                  height: 1,
                                ),
                              ),
                            ),
                    ),

                    // Glass search bar
                    GlassCard(
                      radius: 28,
                      child: Row(
                        children: [
                          // Back / search icon
                          AnimatedSwitcher(
                            duration: 200.ms,
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: _isFocused
                                ? IconButton(
                                    key: const ValueKey('back'),
                                    icon: Icon(Icons.arrow_back_rounded,
                                        color: ink, size: 20),
                                    onPressed: _clearAndCollapse,
                                  )
                                : Padding(
                                    key: const ValueKey('icon'),
                                    padding: const EdgeInsets.only(left: 18),
                                    child: Icon(Icons.search_rounded,
                                        color: inkDim, size: 20),
                                  ),
                          ),
                          // Text field
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode:  _focusNode,
                              textInputAction: TextInputAction.search,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: ink,
                                letterSpacing: -0.015,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Anything across reki…',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: inkDim,
                                  letterSpacing: -0.015,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16,
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
                          // Clear / filter actions
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: inkDim, size: 18),
                              onPressed: () {
                                _controller.clear();
                                ref
                                    .read(searchNotifierProvider.notifier)
                                    .clearSearch();
                                setState(() {});
                              },
                            ),
                          if (showResults) ...[
                            Badge(
                              isLabelVisible: searchState.activeFilters.isActive,
                              smallSize: 6,
                              child: IconButton(
                                icon: Icon(Icons.tune_rounded,
                                    color: inkDim, size: 18),
                                onPressed: _showFilterSheet,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Body — discovery or results ───────────────
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
                  child: showResults
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
      ],
      ),
    );
  }
}

// ── Discovery feed ─────────────────────────────────────────────

class _DiscoveryFeed extends ConsumerWidget {
  const _DiscoveryFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't read discovery providers while this tab is offscreen.
    // FutureProvider.autoDispose keeps them disposed until first read,
    // so the 6 API calls only fire when the user actually opens Search.
    if (ref.watch(shellTabIndexProvider) != ShellTab.search) {
      return const SizedBox.shrink();
    }

    return CustomScrollView(
      slivers: [
        _PrismCarouselSection(
          title: 'Now playing in theatres',
          kicker: 'In Theatres',
          provider: nowPlayingMoviesProvider,
          delay: 0,
        ),
        _PrismCarouselSection(
          title: 'Trending TV shows',
          kicker: 'TV',
          provider: trendingTvShowsProvider,
          delay: 60,
        ),
        _PrismCarouselSection(
          title: 'Trending anime',
          kicker: 'Anime',
          provider: trendingAnimeProvider,
          delay: 120,
        ),
        _PrismCarouselSection(
          title: 'Trending manga',
          kicker: 'Manga',
          provider: trendingMangaProvider,
          delay: 180,
        ),
        _PrismCarouselSection(
          title: 'Popular games',
          kicker: 'Games',
          provider: popularGamesProvider,
          delay: 240,
        ),
        _PrismCarouselSection(
          title: 'Popular books',
          kicker: 'Books',
          provider: popularBooksProvider,
          delay: 300,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

class _PrismCarouselSection extends ConsumerWidget {
  final String title;
  final String kicker;
  final ProviderListenable<AsyncValue<List<MediaItem>>> provider;
  final int delay;

  const _PrismCarouselSection({
    required this.title,
    required this.kicker,
    required this.provider,
    required this.delay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final libraryKeys = ref.watch(libraryKeySetProvider);
    final ink = P.ink(context);
    final inkDimmer = P.inkDimmer(context);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(kicker: kicker, title: title),
          SizedBox(
            height: 228,
            child: async.when(
              loading: () => ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: 5,
                itemBuilder: (_, _) => _CarouselSkeleton(ink: ink),
              ),
              error: (_, _) => Center(
                child: Text(
                  'Failed to load',
                  style: GoogleFonts.inter(fontSize: 13, color: inkDimmer),
                ),
              ),
              data: (items) => ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final inLibrary =
                      libraryKeys.contains('${item.source}:${item.externalId}');
                  return Padding(
                    padding: EdgeInsets.only(right: i < items.length - 1 ? 14 : 0),
                    child: _PrismDiscoverCard(
                      item: item,
                      inLibrary: inLibrary,
                      onTap: () => ctx.push(AppRoutes.mediaDetail, extra: item),
                      onAdd: inLibrary
                          ? null
                          : () => showAddBookmarkSheet(ctx, item),
                    ).animate().fadeIn(
                      duration: 280.ms,
                      delay: (delay + i * 35).ms,
                    ),
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

class _PrismDiscoverCard extends StatelessWidget {
  const _PrismDiscoverCard({
    required this.item,
    required this.inLibrary,
    required this.onTap,
    this.onAdd,
  });

  final MediaItem item;
  final bool inLibrary;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with glass overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: item.posterUrl!,
                          httpHeaders: item.posterHeaders,
                          width: 150,
                          height: 170,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                        )
                      : Container(
                          width: 150,
                          height: 170,
                          color: P.glass(context),
                          child: Icon(Icons.movie_outlined,
                              color: P.inkDimmer(context), size: 36),
                        ),
                ),
                // Gradient overlay
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(179),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Glass ring
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withAlpha(dark ? 46 : 31),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
                // In-library darken overlay
                if (inLibrary)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ColoredBox(
                        color: Colors.black.withAlpha(100),
                      ),
                    ),
                  ),
                // In-library indicator
                if (inLibrary)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        color: P.accent(context),
                        child: Text(
                          'IN LIBRARY',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Add button
                if (!inLibrary && onAdd != null)
                  Positioned(
                    top: 8, right: 8,
                    child: GlassButton(
                      size: 32,
                      onTap: onAdd,
                      child: Icon(Icons.add_rounded,
                          size: 16, color: P.ink(context)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: P.ink(context),
                letterSpacing: -0.01,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.mediaTypeLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: P.accent(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselSkeleton extends StatelessWidget {
  final Color ink;
  const _CarouselSkeleton({required this.ink});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 150,
              height: 170,
              color: P.glass(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 100,
            height: 10,
            decoration: BoxDecoration(
              color: P.glass(context),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: ink.withAlpha(20));
  }
}

// ── Results panel ──────────────────────────────────────────────
// (business logic unchanged, visual style updated to Prism)

class _ResultsPanel extends ConsumerStatefulWidget {
  final SearchState searchState;
  const _ResultsPanel({super.key, required this.searchState});

  @override
  ConsumerState<_ResultsPanel> createState() => _ResultsPanelState();
}

class _ResultsPanelState extends ConsumerState<_ResultsPanel> {
  String _activeTab = 'all';

  static const _tabOrder  = <String>['movie', 'tv', 'anime', 'manga', 'book', 'game'];
  static const _tabLabels = <String, String>{
    'movie': 'Movies', 'tv': 'TV',   'anime': 'Anime',
    'manga': 'Manga',  'book': 'Books', 'game': 'Games',
  };

  @override
  void didUpdateWidget(_ResultsPanel old) {
    super.didUpdateWidget(old);
  }

  Future<void> _quickAdd(MediaItem item) async {
    try {
      await ref.read(bookmarkListProvider.notifier).add(item, BookmarkStatus.wantToWatch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${item.title} added'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final libraryKeys = ref.watch(libraryKeySetProvider);
    final searchState = widget.searchState;
    final filters     = searchState.activeFilters;
    final ink         = P.ink(context);
    final inkDim      = P.inkDim(context);
    final inkDimmer   = P.inkDimmer(context);

    // Empty query — prompt
    if (searchState.query.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassCard(
                radius: 28,
                child: const SizedBox(
                  width: 64, height: 64,
                  child: Center(
                    child: Icon(Icons.search_rounded, size: 28, color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'What are you looking for?',
                style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w700, color: ink,
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Movies · shows · anime\nmanga · books · games',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: inkDim, height: 1.5),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 250.ms);
    }

    // Loading
    if (searchState.isSearching) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.65,
        ),
        itemCount: 9,
        itemBuilder: (_, _) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(color: P.glass(context)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 1200.ms, color: ink.withAlpha(20)),
      );
    }

    // Error
    if (searchState.error != null) {
      return Center(
        child: Text(
          'Search failed',
          style: GoogleFonts.inter(fontSize: 14, color: inkDimmer),
        ),
      );
    }

    // Apply filters
    final filtered = searchState.results.where((item) {
      if (filters.mediaTypes.isNotEmpty &&
          !filters.mediaTypes.contains(item.mediaType)) { return false; }
      final inLib = libraryKeys.contains('${item.source}:${item.externalId}');
      return switch (filters.libraryFilter) {
        LibraryFilter.all          => true,
        LibraryFilter.inLibrary    => inLib,
        LibraryFilter.notInLibrary => !inLib,
      };
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: inkDimmer),
            const SizedBox(height: 12),
            Text(
              'No results for "${searchState.query}"',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: inkDim),
            ),
          ],
        ),
      );
    }

    final typeCounts = <String, int>{};
    for (final item in filtered) {
      typeCounts[item.mediaType] = (typeCounts[item.mediaType] ?? 0) + 1;
    }
    final availableTypes = _tabOrder.where(typeCounts.containsKey).toList();
    if (_activeTab != 'all' && !availableTypes.contains(_activeTab)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { setState(() => _activeTab = 'all'); }
      });
    }

    final displayed = _activeTab == 'all'
        ? filtered
        : filtered.where((item) => item.mediaType == _activeTab).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type filter chips
        if (availableTypes.length >= 2)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
              children: [
                _PrismTypeChip(
                  label: 'All',
                  count: filtered.length,
                  selected: _activeTab == 'all',
                  onTap: () => setState(() => _activeTab = 'all'),
                ),
                for (final type in availableTypes)
                  _PrismTypeChip(
                    label: _tabLabels[type]!,
                    count: typeCounts[type]!,
                    selected: _activeTab == type,
                    onTap: () => setState(() => _activeTab = type),
                  ),
              ],
            ),
          ),

        // Results grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.65,
            ),
            itemCount: displayed.length,
            itemBuilder: (ctx, i) {
              final item     = displayed[i];
              final inLibrary = libraryKeys.contains('${item.source}:${item.externalId}');
              return _SearchGridItem(
                item: item,
                inLibrary: inLibrary,
                onAdd: inLibrary ? null : () => showAddBookmarkSheet(ctx, item),
                onLongPress: inLibrary ? null : () => _quickAdd(item),
              ).animate().fadeIn(duration: 220.ms, delay: (i * 30).ms);
            },
          ),
        ),
      ],
    );
  }
}

// ── Prism type chip ────────────────────────────────────────────

class _PrismTypeChip extends StatelessWidget {
  const _PrismTypeChip({
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
    final dark    = P.isDark(context);
    final ink     = P.ink(context);
    final inkDim  = P.inkDim(context);
    final acc     = P.accent(context);

    final bg  = selected
        ? (dark ? acc.withAlpha(50) : acc)
        : P.glass(context);
    final bdr = selected
        ? (dark ? acc.withAlpha(80) : Colors.transparent)
        : P.borderSoft(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: bdr, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? (dark ? ink : Colors.white)
                      : inkDim,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.black.withAlpha(50)
                      : Colors.white.withAlpha(dark ? 30 : 70),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? (dark ? ink : Colors.white70)
                          : inkDim,
                    ),
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

// ── Search grid item (result card) ────────────────────────────

class _SearchGridItem extends StatelessWidget {
  const _SearchGridItem({
    required this.item,
    required this.inLibrary,
    this.onAdd,
    this.onLongPress,
  });

  final MediaItem item;
  final bool inLibrary;
  final VoidCallback? onAdd;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    final ink  = P.ink(context);
    final acc  = P.accent(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(AppRoutes.mediaDetail, extra: item),
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                        Container(color: P.glass(context)),
                    errorWidget: (_, _, _) => Container(
                      color: P.glass(context),
                      child: Icon(Icons.movie_outlined,
                          color: P.inkDimmer(context), size: 28),
                    ),
                  )
                : Container(
                    color: P.glass(context),
                    child: Icon(Icons.movie_outlined,
                        color: P.inkDimmer(context), size: 28),
                  ),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(220),
                    ],
                  ),
                ),
              ),
            ),

            // In-library darken overlay
            if (inLibrary)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(110),
                  ),
                ),
              ),

            // Glass ring
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha(dark ? 38 : 26),
                    width: 0.5,
                  ),
                ),
              ),
            ),

            // In-library banner
            if (inLibrary)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  color: acc,
                  child: Text(
                    'IN LIBRARY',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

            // Bottom info
            Positioned(
              left: 6, right: 6, bottom: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _mediaTypeBadgeColor(item.mediaType).withAlpha(210),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.mediaTypeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Add button
            if (!inLibrary && onAdd != null)
              Positioned(
                top: inLibrary ? 20 : 6, right: 6,
                child: GlassButton(
                  size: 28,
                  onTap: onAdd,
                  child: Icon(Icons.add_rounded, size: 14, color: ink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
