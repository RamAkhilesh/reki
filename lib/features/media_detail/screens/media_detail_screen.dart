// ─────────────────────────────────────────────────────────────
// lib/features/media_detail/screens/media_detail_screen.dart
// Prism redesign — glass/spatial media detail screen.
// ─────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/prism_tokens.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/tmdb_media_details.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../../bookmarks/widgets/add_edit_bookmark_sheet.dart';
import '../providers/media_detail_providers.dart';

class MediaDetailScreen extends ConsumerStatefulWidget {
  final MediaItem item;
  const MediaDetailScreen({super.key, required this.item});

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  bool _castExpanded = false;
  final ScrollController _scrollCtrl = ScrollController();
  bool _showTopBar = true;
  double _lastScrollOffset = 0;
  Color? _ambientColor;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _extractAmbientColor();
  }

  Future<void> _extractAmbientColor() async {
    final url = widget.item.posterUrl;
    if (url == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url),
        size: const Size(100, 150),
        maximumColorCount: 8,
      );
      final color = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
      if (color != null && mounted) setState(() => _ambientColor = color);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset;
    final delta = offset - _lastScrollOffset;
    if (offset <= 0) {
      if (!_showTopBar) setState(() => _showTopBar = true);
    } else if (delta > 4 && _showTopBar) {
      setState(() => _showTopBar = false);
    } else if (delta < -4 && !_showTopBar) {
      setState(() => _showTopBar = true);
    }
    _lastScrollOffset = offset;
  }

  Bookmark? _findBookmark(List<Bookmark> bookmarks) {
    for (final b in bookmarks) {
      if (b.mediaItem.externalId == widget.item.externalId &&
          b.mediaItem.source == widget.item.source) {
        return b;
      }
    }
    return null;
  }

  Color _typeAccent(String type) => switch (type) {
        'movie'  => const Color(0xFFFDA4AF),
        'tv'     => const Color(0xFFA5B4FC),
        'anime'  => const Color(0xFFA78BFA),
        'manga'  => const Color(0xFF7DD3FC),
        'game'   => const Color(0xFF34D399),
        'book'   => const Color(0xFFFBBF24),
        _        => const Color(0xFFA5B4FC),
      };

  @override
  Widget build(BuildContext context) {
    final providerKey =
        '${widget.item.source}:${widget.item.mediaType}:${widget.item.externalId}';
    final detailsAsync    = ref.watch(mediaDetailsProvider(providerKey));
    final relatedAsync    = ref.watch(relatedMediaProvider(providerKey));
    final bookmarksAsync  = ref.watch(bookmarkListProvider);
    final bookmark        = _findBookmark(bookmarksAsync.valueOrNull ?? []);

    final item        = widget.item;
    final typeAccent  = _typeAccent(item.mediaType);
    final isDark      = P.isDark(context);
    // Use extracted poster palette colour for the ambient backdrop; fall back
    // to the static per-type accent while extraction is in progress.
    final ambientColor = _ambientColor ?? typeAccent;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF05050A) : const Color(0xFFF4F1EC),
      bottomNavigationBar: _LibraryActionBar(item: item, bookmark: bookmark),
      body: Stack(
        children: [
          // ── Full-screen gradient backdrop ─────────────────
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ambientColor.withAlpha(isDark ? 60 : 45),
                    isDark ? const Color(0xFF05050A) : const Color(0xFFF4F1EC),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
            ),
          ),

          // ── Scrollable content ────────────────────────────
          CustomScrollView(
            controller: _scrollCtrl,
            slivers: [
              // Space reserved for the floating top bar
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.of(context).padding.top + 60),
              ),

              // ── Hero poster ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Poster
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: ambientColor.withAlpha(90),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: Colors.black.withAlpha(120),
                                blurRadius: 60,
                                offset: const Offset(0, 24),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: item.posterUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: item.posterUrl!,
                                    width: 200,
                                    height: 295,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 200,
                                    height: 295,
                                    color: P.glass(context),
                                    child: Icon(
                                      Icons.movie_outlined,
                                      size: 48,
                                      color: P.inkDimmer(context),
                                    ),
                                  ),
                          ),
                        ),
                        // Floating rating chip
                        detailsAsync.whenOrNull(
                          data: (d) => d.score != null
                              ? Positioned(
                                  top: -10, right: -10,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                                      child: Container(
                                        width: 56, height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha(153),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withAlpha(51),
                                            width: 0.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withAlpha(64),
                                              offset: const Offset(0, 0.5),
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withAlpha(102),
                                              blurRadius: 30,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              d.score!.toStringAsFixed(1),
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                height: 1,
                                                letterSpacing: -0.02,
                                              ),
                                            ),
                                            Text(
                                              'SCORE',
                                              style: GoogleFonts.inter(
                                                fontSize: 7,
                                                color: Colors.white60,
                                                letterSpacing: 0.1,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ) ?? const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Title block ─────────────────────────────────
              SliverToBoxAdapter(
                child: detailsAsync.when(
                  loading: () => _buildTitleBlock(
                    context, item.title, null, item, typeAccent, null, bookmark,
                  ),
                  error: (_, _) => _buildTitleBlock(
                    context, item.title, null, item, typeAccent, null, bookmark,
                  ),
                  data: (d) => _buildTitleBlock(
                    context,
                    d.title,
                    d,
                    item,
                    typeAccent,
                    null,
                    bookmark,
                  ),
                ),
              ),

              // ── Content sections ────────────────────────────
              SliverToBoxAdapter(
                child: detailsAsync.when(
                  loading: () => _buildContentSections(
                    context, null, relatedAsync, true, false, typeAccent,
                  ),
                  error: (_, _) => _buildContentSections(
                    context, null, relatedAsync, false, true, typeAccent,
                  ),
                  data: (d) => _buildContentSections(
                    context, d, relatedAsync, false, false, typeAccent,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),

          // ── Floating top bar ──────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            top: _showTopBar ? 0 : -(MediaQuery.of(context).padding.top + 64),
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Row(
                  children: [
                    GlassButton(
                      onTap: () => context.pop(),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 20, color: P.ink(context)),
                    ),
                    const Spacer(),
                    GlassButton(
                      onTap: () {},
                      child: Icon(Icons.share_outlined,
                          size: 18, color: P.ink(context)),
                    ),
                    const SizedBox(width: 8),
                    GlassButton(
                      tint: bookmark != null ? typeAccent : null,
                      onTap: () {
                        if (bookmark != null) {
                          showEditDeleteSheet(
                            context,
                            bookmark,
                            onDelete: () => ref
                                .read(bookmarkListProvider.notifier)
                                .remove(bookmark.id),
                          );
                        } else {
                          showAddBookmarkSheet(context, item);
                        }
                      },
                      child: Icon(
                        bookmark != null
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        size: 18,
                        color: bookmark != null ? typeAccent : P.ink(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBlock(
    BuildContext context,
    String title,
    TmdbMediaDetails? details,
    MediaItem item,
    Color typeAccent,
    Bookmark? bookmark2,
    Bookmark? bookmark,
  ) {
    final ink     = P.ink(context);
    final inkDim  = P.inkDim(context);
    final isDark  = P.isDark(context);

    final metaParts = <String>[
      if (details?.releaseYear != null) details!.releaseYear!,
      item.mediaTypeLabel,
      if (details?.runtimeLabel != null) details!.runtimeLabel!,
      if (details?.episodeLabel != null) details!.episodeLabel!,
    ];

    // Progress percentage
    final progressPct = bookmark != null &&
            bookmark.progressCount != null &&
            item.episodeCount != null &&
            item.episodeCount! > 0
        ? (bookmark.progressCount! / item.episodeCount!).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        children: [
          // Type badge
          GlassCard(
            radius: 100,
            tint: typeAccent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              child: Text(
                '${item.mediaTypeLabel}${details?.releaseYear != null ? ' · ${details!.releaseYear!}' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: typeAccent,
                  letterSpacing: 0.04,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: ink,
              letterSpacing: -0.035 * 30,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),

          // Meta (creator · runtime)
          if (metaParts.isNotEmpty)
            Text(
              metaParts.join(' · '),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12, color: inkDim, height: 1.4,
              ),
            ),
          const SizedBox(height: 22),

          // Status pill (if in library)
          if (bookmark != null) ...[
            GestureDetector(
              onTap: () => showEditDeleteSheet(
                context, bookmark,
                onDelete: () => ref
                    .read(bookmarkListProvider.notifier)
                    .remove(bookmark.id),
              ),
              child: GlassCard(
                radius: 100,
                tint: P.statusColor(bookmark.status),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: P.statusColor(bookmark.status),
                          boxShadow: [
                            BoxShadow(
                              color: P.statusColor(bookmark.status),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        P.statusLabel(bookmark.status),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· tap to edit',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: inkDim,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Progress card
          if (bookmark != null && progressPct > 0 && progressPct < 1) ...[
            GlassCard(
              radius: 20,
              tint: typeAccent,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IN PROGRESS',
                              style: GoogleFonts.inter(
                                fontSize: 9, fontWeight: FontWeight.w600,
                                color: typeAccent, letterSpacing: 0.06,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bookmark.progressCount != null && item.episodeCount != null
                                  ? '${bookmark.progressCount} / ${item.episodeCount}'
                                  : P.statusLabel(bookmark.status),
                              style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w600,
                                color: ink, letterSpacing: -0.015,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(progressPct * 100).round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 30, fontWeight: FontWeight.w700,
                            color: typeAccent, letterSpacing: -0.035,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        minHeight: 4,
                        backgroundColor: isDark
                            ? Colors.white.withAlpha(26)
                            : Colors.black.withAlpha(20),
                        valueColor: AlwaysStoppedAnimation(typeAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildContentSections(
    BuildContext context,
    TmdbMediaDetails? details,
    AsyncValue<List<MediaItem>> relatedAsync,
    bool isLoading,
    bool hasError,
    Color typeAccent,
  ) {
    final item     = widget.item;
    final ink      = P.ink(context);
    final inkDim   = P.inkDim(context);
    final overview = details?.overview ?? item.overview;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tagline
          if (details?.tagline != null) ...[
            Text(
              '"${details!.tagline!}"',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: inkDim,
                height: 1.5,
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
            const SizedBox(height: 18),
          ],

          // Genres (glass pills)
          if (!isLoading && details != null && details.genres.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: details.genres.map((g) => PrismPill(label: g)).toList(),
            ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
            const SizedBox(height: 22),
          ],
          if (isLoading)
            const _ShimmerGlass(width: 240, height: 28),

          // Synopsis
          _PrismSectionHeader(title: 'Synopsis'),
          const SizedBox(height: 10),
          if (isLoading)
            ..._shimmerLines(context, 4)
          else if (overview != null && overview.isNotEmpty)
            Text(
              overview,
              style: GoogleFonts.inter(
                fontSize: 14, color: ink, height: 1.6,
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 160.ms)
          else
            Text(
              hasError ? 'Could not load full details.' : 'No overview available.',
              style: GoogleFonts.inter(fontSize: 14, color: inkDim),
            ),

          // Cast
          if (isLoading) ...[
            const SizedBox(height: 24),
            _PrismSectionHeader(title: 'Top Cast'),
            const SizedBox(height: 12),
            _ShimmerCastRow(ink: ink),
          ],
          if (!isLoading && details != null && details.cast.isNotEmpty)
            _CastSection(
              cast: details.cast,
              expanded: _castExpanded,
              onToggle: () => setState(() => _castExpanded = !_castExpanded),
              typeAccent: typeAccent,
            ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

          // Crew
          if (!isLoading && details != null && details.crew.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _PrismSectionHeader(title: details.crewLabel),
                const SizedBox(height: 10),
                ...details.crew.map((c) => _CrewTile(member: c, ink: ink, inkDim: inkDim)),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 240.ms),

          // Seasons
          if (!isLoading && details != null && details.seasons.length > 1)
            _SeasonsSection(seasons: details.seasons)
                .animate()
                .fadeIn(duration: 300.ms, delay: 280.ms),

          // Related
          _RelatedSection(
            relatedAsync: relatedAsync,
            isLoading: isLoading,
          ).animate().fadeIn(duration: 300.ms, delay: 320.ms),
        ],
      ),
    );
  }

  List<Widget> _shimmerLines(BuildContext context, int count) {
    final glass = P.glass(context);
    final ink = P.ink(context);
    return List.generate(count, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 14,
        width: i == count - 1 ? 180 : double.infinity,
        decoration: BoxDecoration(color: glass, borderRadius: BorderRadius.circular(4)),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 1200.ms, color: ink.withAlpha(20)),
    ));
  }
}

// ── Prism section header ──────────────────────────────────────

class _PrismSectionHeader extends StatelessWidget {
  const _PrismSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: P.inkDimmer(context),
        letterSpacing: 0.06 * 10,
      ),
    );
  }
}

// ── Cast section ──────────────────────────────────────────────

class _CastSection extends StatelessWidget {
  const _CastSection({
    required this.cast,
    required this.expanded,
    required this.onToggle,
    required this.typeAccent,
  });

  final List<CastMember> cast;
  final bool expanded;
  final VoidCallback onToggle;
  final Color typeAccent;

  @override
  Widget build(BuildContext context) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            _PrismSectionHeader(title: 'Top Cast'),
            const Spacer(),
            GestureDetector(
              onTap: onToggle,
              child: Text(
                expanded ? 'Show less' : 'See all (${cast.length})',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: typeAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!expanded)
          SizedBox(
            height: 148,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cast.length > 8 ? 8 : cast.length,
              itemBuilder: (_, i) => _CastCard(member: cast[i], ink: ink, inkDim: inkDim),
            ),
          ),
        if (expanded)
          Column(
            children: cast
                .map((m) => _CastListTile(member: m, ink: ink, inkDim: inkDim))
                .toList(),
          ),
      ],
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({required this.member, required this.ink, required this.inkDim});
  final CastMember member;
  final Color ink;
  final Color inkDim;

  @override
  Widget build(BuildContext context) {
    final glass = P.glass(context);
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(37),
              child: SizedBox(
                width: 74, height: 74,
                child: member.profileUrl != null
                    ? CachedNetworkImage(
                        imageUrl: member.profileUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: glass),
                        errorWidget: (_, _, _) => Container(
                          color: glass,
                          child: Icon(Icons.person_rounded, color: inkDim, size: 28),
                        ),
                      )
                    : Container(
                        color: glass,
                        child: Icon(Icons.person_rounded, color: inkDim, size: 28),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              member.name,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: ink,
              ),
              maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            ),
            if (member.character != null)
              Text(
                member.character!,
                style: GoogleFonts.inter(fontSize: 10, color: inkDim),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _CastListTile extends StatelessWidget {
  const _CastListTile({required this.member, required this.ink, required this.inkDim});
  final CastMember member;
  final Color ink;
  final Color inkDim;

  @override
  Widget build(BuildContext context) {
    final glass = P.glass(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              width: 52, height: 52,
              child: member.profileUrl != null
                  ? CachedNetworkImage(
                      imageUrl: member.profileUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: glass),
                      errorWidget: (_, _, _) => Container(
                        color: glass,
                        child: Icon(Icons.person_rounded, color: inkDim, size: 22),
                      ),
                    )
                  : Container(
                      color: glass,
                      child: Icon(Icons.person_rounded, color: inkDim, size: 22),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: ink,
                  ),
                ),
                if (member.character != null)
                  Text(
                    member.character!,
                    style: GoogleFonts.inter(fontSize: 12, color: inkDim),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Crew tile ─────────────────────────────────────────────────

class _CrewTile extends StatelessWidget {
  const _CrewTile({required this.member, required this.ink, required this.inkDim});
  final CrewMember member;
  final Color ink;
  final Color inkDim;

  @override
  Widget build(BuildContext context) {
    final glass = P.glass(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              width: 52, height: 52,
              child: member.profileUrl != null
                  ? CachedNetworkImage(
                      imageUrl: member.profileUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: glass),
                      errorWidget: (_, _, _) => Container(
                        color: glass,
                        child: Icon(Icons.person_rounded, color: inkDim, size: 22),
                      ),
                    )
                  : Container(
                      color: glass,
                      child: Icon(Icons.person_rounded, color: inkDim, size: 22),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: ink,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Text(
                  member.job,
                  style: GoogleFonts.inter(fontSize: 12, color: inkDim),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seasons section ───────────────────────────────────────────

class _SeasonsSection extends StatelessWidget {
  final List<TvSeason> seasons;
  const _SeasonsSection({required this.seasons});

  @override
  Widget build(BuildContext context) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    final glass  = P.glass(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _PrismSectionHeader(title: 'Seasons'),
        const SizedBox(height: 12),
        SizedBox(
          height: 182,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            itemBuilder: (_, i) {
              final season = seasons[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 100, height: 140,
                          child: season.posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: season.posterUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(color: glass),
                                  errorWidget: (_, _, _) => Container(
                                    color: glass,
                                    child: Icon(Icons.movie_outlined,
                                        color: inkDim, size: 28),
                                  ),
                                )
                              : Container(
                                  color: glass,
                                  child: Icon(Icons.movie_outlined,
                                      color: inkDim, size: 28),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        season.name,
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600, color: ink,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (season.episodeCount != null)
                        Text(
                          '${season.episodeCount} ep'
                          '${season.airYear != null ? ' · ${season.airYear}' : ''}',
                          style: GoogleFonts.inter(fontSize: 10, color: inkDim),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Related section ───────────────────────────────────────────

class _RelatedSection extends StatelessWidget {
  final AsyncValue<List<MediaItem>> relatedAsync;
  final bool isLoading;

  const _RelatedSection({required this.relatedAsync, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    final glass  = P.glass(context);

    if (isLoading) return const SizedBox.shrink();

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _PrismSectionHeader(title: 'More Like This'),
            const SizedBox(height: 12),
            SizedBox(
              height: 196,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final related = items[i];
                  return GestureDetector(
                    onTap: () => ctx.push(AppRoutes.mediaDetail, extra: related),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 110, height: 150,
                                    child: related.posterUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: related.posterUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (_, _) => Container(color: glass),
                                            errorWidget: (_, _, _) => Container(
                                              color: glass,
                                              child: Icon(Icons.movie_outlined,
                                                  color: inkDim, size: 28),
                                            ),
                                          )
                                        : Container(
                                            color: glass,
                                            child: Icon(Icons.movie_outlined,
                                                color: inkDim, size: 28),
                                          ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(38),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              related.title,
                              style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w500, color: ink,
                              ),
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Shimmer helpers ───────────────────────────────────────────

class _ShimmerGlass extends StatelessWidget {
  const _ShimmerGlass({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ink = P.ink(context);
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: P.glass(context),
        borderRadius: BorderRadius.circular(8),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: ink.withAlpha(20));
  }
}

class _ShimmerCastRow extends StatelessWidget {
  final Color ink;
  const _ShimmerCastRow({required this.ink});

  @override
  Widget build(BuildContext context) {
    final glass = P.glass(context);
    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Column(
            children: [
              Container(
                width: 74, height: 74,
                decoration: BoxDecoration(shape: BoxShape.circle, color: glass),
              ),
              const SizedBox(height: 6),
              Container(
                width: 54, height: 10,
                decoration: BoxDecoration(
                  color: glass, borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: ink.withAlpha(20));
  }
}

// ── Bottom library action bar ─────────────────────────────────

class _LibraryActionBar extends ConsumerWidget {
  final MediaItem item;
  final Bookmark? bookmark;

  const _LibraryActionBar({required this.item, this.bookmark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = P.isDark(context);
    final ink    = P.ink(context);
    final acc    = P.accent(context);
    final acc3   = P.accent3(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14141C).withAlpha(178)
                : Colors.white.withAlpha(204),
            border: Border(
              top: BorderSide(color: P.borderSoft(context), width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: bookmark != null
                  ? GestureDetector(
                      onTap: () => showEditDeleteSheet(
                        context,
                        bookmark!,
                        onDelete: () => ref
                            .read(bookmarkListProvider.notifier)
                            .remove(bookmark!.id),
                      ),
                      child: GlassCard(
                        radius: 100,
                        tint: acc,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_outlined, size: 18,
                                  color: isDark ? ink : Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Edit Bookmark',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? ink : Colors.white,
                                  letterSpacing: -0.015,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => showAddBookmarkSheet(context, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [acc, acc3],
                          ),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: acc.withAlpha(100),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bookmark_add_outlined,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Add to Library',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.015,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
