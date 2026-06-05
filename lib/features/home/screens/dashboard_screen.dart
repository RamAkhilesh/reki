// ─────────────────────────────────────────────────────────────
// lib/features/home/screens/dashboard_screen.dart
// Prism redesign — glass/spatial home screen.
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/prism_tokens.dart';
import '../../../data/models/bookmark.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../../library/providers/library_providers.dart';
import '../../../shared/widgets/glass_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _goToLibrary(WidgetRef ref, {String? type}) {
    if (type != null) ref.read(pendingLibraryTabTypeProvider.notifier).state = type;
    ref.read(statusFilterProvider.notifier).state = null;
    ref.read(shellTabIndexProvider.notifier).state = ShellTab.library;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync  = ref.watch(recentlyActiveProvider);
    final categoryAsync = ref.watch(categoryStatsProvider);
    final allAsync     = ref.watch(bookmarkListProvider);

    final allBookmarks    = allAsync.value ?? [];
    final recentItems     = recentAsync.value ?? [];
    final allCategories   = categoryAsync.value ?? [];
    final nonEmptyCats    = allCategories.where((s) => s.total > 0).toList();
    final continueItems   = allBookmarks
        .where((b) => b.status == 'watching' || b.status == 'on_hold')
        .take(8)
        .toList();

    final ink       = P.ink(context);
    final inkDim    = P.inkDim(context);
    final acc       = P.accent(context);
    final acc2      = P.accent2(context);
    final acc3      = P.accent3(context);

    return Stack(
      children: [
        // ── Ambient backdrop ────────────────────────────────
        const Positioned.fill(child: PrismBackdrop(variant: 'default')),

        // ── Scrollable content ──────────────────────────────
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 8)),

            // ── Header ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                child: Row(
                  children: [
                    // Wordmark
                    ShaderMask(
                      shaderCallback: (r) => LinearGradient(
                        colors: [acc, acc2, acc3],
                        stops: const [0, 0.5, 1],
                      ).createShader(r),
                      child: Text(
                        'reki',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.04 * 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Greeting ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Welcome back',
                            style: GoogleFonts.inter(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: ink,
                              letterSpacing: -0.035 * 34,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Continue watching ────────────────────────────
            if (continueItems.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionTitle(
                  kicker: 'Continue',
                  title: 'Pick up where you left off',
                  action: 'Library',
                  onAction: () => _goToLibrary(ref),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 128,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    itemCount: continueItems.length,
                    itemBuilder: (ctx, i) {
                      final b = continueItems[i];
                      return Padding(
                        padding: EdgeInsets.only(right: i < continueItems.length - 1 ? 12 : 0),
                        child: _ContinueCard(
                          bookmark: b,
                          onTap: () => ctx.push(
                            AppRoutes.mediaDetail,
                            extra: b.mediaItem,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Recently added ───────────────────────────────
            if (recentItems.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionTitle(
                  kicker: 'Library',
                  title: 'Recently added',
                  action: 'See all',
                  onAction: () => _goToLibrary(ref),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    itemCount: recentItems.take(8).length,
                    itemBuilder: (ctx, i) {
                      final b = recentItems[i];
                      return Padding(
                        padding: EdgeInsets.only(right: i < 7 ? 12 : 0),
                        child: _PosterCard(
                          bookmark: b,
                          onTap: () => ctx.push(
                            AppRoutes.mediaDetail,
                            extra: b.mediaItem,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // ── Empty state ──────────────────────────────────
            if (recentItems.isEmpty && continueItems.isEmpty && !recentAsync.isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  inkDim: inkDim,
                  ink: ink,
                  acc: acc,
                  acc2: acc2,
                  onSearch: () => ref.read(shellTabIndexProvider.notifier).state = ShellTab.search,
                ),
              ),

            // ── Categories ───────────────────────────────────
            if (nonEmptyCats.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionTitle(
                  kicker: 'Browse',
                  title: 'By category',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 170,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _CategoryGlassCard(
                      stats: nonEmptyCats[i],
                      fallbackTint: _catTint(nonEmptyCats[i].mediaType, acc, acc2, acc3),
                      onTap: () => _goToLibrary(ref, type: nonEmptyCats[i].mediaType),
                    ),
                    childCount: nonEmptyCats.length,
                  ),
                ),
              ),
            ],

            // ── Bottom padding for nav bar ───────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ],
    );
  }

  static Color _catTint(String type, Color acc, Color acc2, Color acc3) =>
      switch (type) {
        'movie'  => acc2,
        'tv'     => acc,
        'anime'  => const Color(0xFFA78BFA),
        'manga'  => acc3,
        'game'   => const Color(0xFF34D399),
        'book'   => const Color(0xFFFBBF24),
        _        => acc,
      };
}

// ── Continue card ─────────────────────────────────────────────

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.bookmark, required this.onTap});

  final Bookmark bookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b   = bookmark;
    final mi  = b.mediaItem;
    final ink = P.ink(context);
    final inkDim = P.inkDim(context);
    final inkDimmer = P.inkDimmer(context);
    final pct = (b.progressCount != null && mi.episodeCount != null && mi.episodeCount! > 0)
        ? (b.progressCount! / mi.episodeCount!).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        radius: 22,
        child: SizedBox(
          width: 220,
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                ),
                child: mi.posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: mi.posterUrl!,
                        width: 70,
                        height: 128,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 70,
                        height: 128,
                        color: P.glass(context),
                        child: Icon(Icons.movie_outlined, color: inkDimmer, size: 24),
                      ),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mi.mediaType.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: inkDimmer,
                          letterSpacing: 0.06 * 9,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mi.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ink,
                          letterSpacing: -0.015,
                          height: 1.15,
                        ),
                      ),
                      const Spacer(),
                      if (pct > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 3,
                            backgroundColor: P.isDark(context)
                                ? Colors.white.withAlpha(20)
                                : Colors.black.withAlpha(15),
                            valueColor: AlwaysStoppedAnimation(P.accent(context)),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        b.progressCount != null && mi.episodeCount != null
                            ? '${b.progressCount} / ${mi.episodeCount}'
                            : P.statusLabel(b.status),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: inkDim,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

// ── Poster card ───────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.bookmark, required this.onTap});

  final Bookmark bookmark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mi   = bookmark.mediaItem;
    final dark = P.isDark(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Poster
              mi.posterUrl != null
                  ? CachedNetworkImage(
                      imageUrl: mi.posterUrl!,
                      width: 130,
                      height: 200,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 130,
                      height: 200,
                      color: P.glass(context),
                      child: Icon(Icons.movie_outlined, color: P.inkDimmer(context), size: 32),
                    ),
              // Bottom gradient for title
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(210),
                      ],
                    ),
                  ),
                ),
              ),
              // Glass ring
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withAlpha(dark ? 46 : 31),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              // Title overlay
              Positioned(
                left: 8, right: 8, bottom: 8,
                child: Text(
                  mi.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
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

// ── Category glass card ───────────────────────────────────────

class _CategoryGlassCard extends StatefulWidget {
  const _CategoryGlassCard({
    required this.stats,
    required this.fallbackTint,
    required this.onTap,
  });

  final CategoryStats stats;
  final Color fallbackTint;
  final VoidCallback onTap;

  @override
  State<_CategoryGlassCard> createState() => _CategoryGlassCardState();
}

class _CategoryGlassCardState extends State<_CategoryGlassCard> {
  Color? _extractedColor;
  bool _extracting = false;
  String? _lastExtractedUrl;

  @override
  void initState() {
    super.initState();
    _extractColor();
  }

  @override
  void didUpdateWidget(_CategoryGlassCard old) {
    super.didUpdateWidget(old);
    final newUrl = widget.stats.recentFour.firstOrNull?.mediaItem.posterUrl;
    if (newUrl != _lastExtractedUrl) {
      _extractedColor = null;
      _extractColor();
    }
  }

  Future<void> _extractColor() async {
    if (_extracting) return;
    final url = widget.stats.recentFour.firstOrNull?.mediaItem.posterUrl;
    if (url == null) return;
    _extracting = true;
    _lastExtractedUrl = url;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url),
        size: const Size(80, 120),
        maximumColorCount: 16,
      );
      final color = palette.dominantColor?.color
          ?? palette.mutedColor?.color
          ?? palette.vibrantColor?.color;
      if (color != null && mounted) {
        setState(() => _extractedColor = color);
      }
    } catch (_) {
      // fall back to fallbackTint silently
    } finally {
      _extracting = false;
    }
  }

  static (Color, Color) _typeBadge(String type, ColorScheme cs) =>
      switch (type) {
        'movie' => (cs.primaryContainer,   cs.onPrimaryContainer),
        'tv'    => (cs.secondaryContainer, cs.onSecondaryContainer),
        'anime' => (cs.tertiaryContainer,  cs.onTertiaryContainer),
        'manga' => (cs.errorContainer,     cs.onErrorContainer),
        'game'  => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
        'book'  => (cs.secondaryContainer, cs.onSecondaryContainer),
        _       => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      };

  static String _typeLabel(String t) => switch (t) {
    'movie' => 'Movies',
    'tv'    => 'TV Shows',
    'anime' => 'Anime',
    'manga' => 'Manga',
    'game'  => 'Games',
    'book'  => 'Books',
    _       => t,
  };

  static IconData _typeIcon(String t) => switch (t) {
    'movie' => Icons.movie_rounded,
    'tv'    => Icons.tv_rounded,
    'anime' => Icons.animation_rounded,
    'manga' => Icons.menu_book_rounded,
    'game'  => Icons.sports_esports_rounded,
    'book'  => Icons.auto_stories_rounded,
    _       => Icons.bookmark_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final tint   = _extractedColor ?? widget.fallbackTint;
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    final cs     = Theme.of(context).colorScheme;
    final (iconBg, iconFg) = _typeBadge(widget.stats.mediaType, cs);
    final coverUrl = widget.stats.recentFour.firstOrNull?.mediaItem.posterUrl;

    return GestureDetector(
      onTap: widget.onTap,
      child: GlassCard(
        radius: 20,
        tint: null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Accent bar ────────────────────────────────
            Container(width: 4, color: iconFg.withAlpha(200)),

            // ── Inner column: header + mosaic below ───────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row: icon → label → count
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
                          child: Icon(_typeIcon(widget.stats.mediaType), color: iconFg, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _typeLabel(widget.stats.mediaType),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ink,
                              letterSpacing: -0.01,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.stats.total}',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: iconFg,
                            height: 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Mosaic / cover image fills remaining space
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: coverUrl != null
                            ? CachedNetworkImage(
                                imageUrl: coverUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => ColoredBox(color: tint.withAlpha(30)),
                                errorWidget: (_, _, _) => ColoredBox(color: tint.withAlpha(30)),
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bookmark_add_outlined,
                                        color: inkDim.withAlpha(120), size: 20),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Nothing yet',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: inkDim.withAlpha(160),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Empty state ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.inkDim,
    required this.ink,
    required this.acc,
    required this.acc2,
    required this.onSearch,
  });

  final Color inkDim;
  final Color ink;
  final Color acc;
  final Color acc2;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassCard(
              radius: 28,
              tint: acc,
              child: const SizedBox(
                width: 72, height: 72,
                child: Center(
                  child: Icon(Icons.bookmark_border_rounded, size: 32, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your library is empty',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -0.025,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for movies, shows, anime, manga,\nbooks or games to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: inkDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onSearch,
              child: GlassCard(
                radius: 100,
                tint: acc,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Text(
                    'Discover something',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

