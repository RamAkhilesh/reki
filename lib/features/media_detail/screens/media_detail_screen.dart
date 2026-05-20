// ─────────────────────────────────────────────────────────────
// lib/features/media_detail/screens/media_detail_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/tmdb_media_details.dart';
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

  Bookmark? _findBookmark(List<Bookmark> bookmarks) {
    for (final b in bookmarks) {
      if (b.mediaItem.externalId == widget.item.externalId &&
          b.mediaItem.source == widget.item.source) {
        return b;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final providerKey =
        '${widget.item.source}:${widget.item.mediaType}:${widget.item.externalId}';
    final detailsAsync = ref.watch(mediaDetailsProvider(providerKey));
    final relatedAsync = ref.watch(relatedMediaProvider(providerKey));
    final bookmarksAsync = ref.watch(bookmarkListProvider);
    final existingBookmark = _findBookmark(bookmarksAsync.valueOrNull ?? []);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: detailsAsync.when(
        loading: () => _buildBody(
          details: null,
          relatedAsync: relatedAsync,
          isLoading: true,
        ),
        error: (_, _) => _buildBody(
          details: null,
          relatedAsync: relatedAsync,
          hasError: true,
        ),
        data: (details) => _buildBody(
          details: details,
          relatedAsync: relatedAsync,
        ),
      ),
      bottomNavigationBar: _LibraryActionBar(
        item: widget.item,
        bookmark: existingBookmark,
      ),
    );
  }

  Widget _buildBody({
    required TmdbMediaDetails? details,
    required AsyncValue<List<MediaItem>> relatedAsync,
    bool isLoading = false,
    bool hasError = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final item = widget.item;

    final backdropUrl = details?.backdropUrl ?? item.posterUrl;
    final posterUrl = details?.posterUrl ?? item.posterUrl;
    final title = details?.title ?? item.title;
    final overview = details?.overview ?? item.overview;

    return CustomScrollView(
      slivers: [
        // ── Collapsing backdrop ───────────────────────────────
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          snap: false,
          floating: false,
          stretch: true,
          backgroundColor: cs.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: _CircleBackButton(onPressed: () => context.pop()),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: _Backdrop(url: backdropUrl, surfaceColor: cs.surface),
            collapseMode: CollapseMode.parallax,
          ),
        ),

        // ── Content ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster + title
                _PosterTitleRow(
                  item: item,
                  details: details,
                  posterUrl: posterUrl,
                  title: title,
                ),

                const SizedBox(height: 16),

                // Genres
                if (isLoading)
                  _ShimmerBlock(width: 240, height: 26, cs: cs)
                else if (details != null && details.genres.isNotEmpty)
                  _GenreChips(genres: details.genres)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 80.ms),

                // Tagline
                if (details?.tagline != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '"${details!.tagline!}"',
                    style: tt.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: cs.onSurfaceVariant,
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 120.ms),
                ],

                // ── Overview ─────────────────────────────────
                const SizedBox(height: 20),
                _SectionHeader('Overview'),
                const SizedBox(height: 8),
                if (isLoading)
                  _ShimmerLines(count: 4, cs: cs)
                else if (overview != null && overview.isNotEmpty)
                  Text(
                    overview,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withAlpha(220),
                      height: 1.55,
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 160.ms)
                else
                  Text(
                    hasError
                        ? 'Could not load full details.'
                        : 'No overview available.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),

                // ── Cast ─────────────────────────────────────
                if (isLoading) ...[
                  const SizedBox(height: 24),
                  _SectionHeader('Top Cast'),
                  const SizedBox(height: 12),
                  _ShimmerCastRow(cs: cs),
                ],

                if (!isLoading && details != null && details.cast.isNotEmpty)
                  _CastSection(
                    cast: details.cast,
                    expanded: _castExpanded,
                    onToggle: () =>
                        setState(() => _castExpanded = !_castExpanded),
                  ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                // ── Crew ─────────────────────────────────────
                if (!isLoading && details != null && details.crew.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _SectionHeader(details.crewLabel),
                      const SizedBox(height: 8),
                      ...details.crew.map((c) => _CrewTile(member: c)),
                    ],
                  ).animate().fadeIn(duration: 300.ms, delay: 240.ms),

                // ── Seasons (TV only) ─────────────────────────
                if (!isLoading &&
                    details != null &&
                    details.seasons.length > 1)
                  _SeasonsSection(seasons: details.seasons)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 280.ms),

                // ── Similar / Related ─────────────────────────
                _RelatedSection(
                  relatedAsync: relatedAsync,
                  isLoading: isLoading,
                  cs: cs,
                ).animate().fadeIn(duration: 300.ms, delay: 320.ms),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Backdrop ──────────────────────────────────────────────────

class _Backdrop extends StatelessWidget {
  final String? url;
  final Color surfaceColor;

  const _Backdrop({required this.url, required this.surfaceColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                Container(color: Colors.black.withAlpha(30)),
            errorWidget: (_, _, _) =>
                Container(color: Colors.black.withAlpha(30)),
          )
        else
          Container(color: Colors.black.withAlpha(30)),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Colors.black.withAlpha(140), Colors.transparent],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, surfaceColor],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Back button ───────────────────────────────────────────────

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CircleBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(110),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

// ── Poster + title block ──────────────────────────────────────

class _PosterTitleRow extends StatelessWidget {
  final MediaItem item;
  final TmdbMediaDetails? details;
  final String? posterUrl;
  final String title;

  const _PosterTitleRow({
    required this.item,
    required this.details,
    required this.posterUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final metaParts = <String>[
      if (details?.releaseYear != null) details!.releaseYear!,
      item.mediaTypeLabel,
      if (details?.runtimeLabel != null) details!.runtimeLabel!,
      if (details?.episodeLabel != null) details!.episodeLabel!,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 110,
            height: 165,
            child: posterUrl != null
                ? CachedNetworkImage(
                    imageUrl: posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: cs.surfaceContainerHighest),
                    errorWidget: (_, _, _) => _PosterFallback(cs: cs),
                  )
                : _PosterFallback(cs: cs),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                title,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              if (metaParts.isNotEmpty)
                Text(
                  metaParts.join(' · '),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (details?.score != null) ...[
                const SizedBox(height: 8),
                _ScoreRating(
                  score: details!.score!,
                  scoreCount: details!.scoreCount,
                  scoreSource: details!.scoreSource ?? '',
                ),
              ],
              if (details?.status != null &&
                  details!.status != 'Released' &&
                  details!.status != 'Ended') ...[
                const SizedBox(height: 8),
                _StatusPill(status: details!.status!, cs: cs),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PosterFallback extends StatelessWidget {
  final ColorScheme cs;
  const _PosterFallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 40),
    );
  }
}

// ── Score rating (works for TMDB, AniList, Google Books, Metacritic) ─────────

class _ScoreRating extends StatelessWidget {
  final double score;
  final int? scoreCount;
  final String scoreSource;

  const _ScoreRating({
    required this.score,
    required this.scoreSource,
    this.scoreCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          score.toStringAsFixed(1),
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (scoreCount != null)
          Text(
            ' (${_fmt(scoreCount!)})',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        const SizedBox(width: 6),
        Text(
          scoreSource,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

// ── Status pill ───────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  final ColorScheme cs;
  const _StatusPill({required this.status, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Genre chips ───────────────────────────────────────────────

class _GenreChips extends StatelessWidget {
  final List<String> genres;
  const _GenreChips({required this.genres});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: genres
          .map(
            (g) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                g,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Section header ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

// ── Cast section with expand/collapse ─────────────────────────

class _CastSection extends StatelessWidget {
  final List<CastMember> cast;
  final bool expanded;
  final VoidCallback onToggle;

  const _CastSection({
    required this.cast,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Header row with toggle button
        Row(
          children: [
            _SectionHeader('Top Cast'),
            const Spacer(),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                expanded
                    ? 'Show less'
                    : 'See all (${cast.length})',
                style: tt.labelMedium?.copyWith(color: cs.primary),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Collapsed: horizontal scroll row (first 8)
        if (!expanded)
          SizedBox(
            height: 148,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cast.length > 8 ? 8 : cast.length,
              itemBuilder: (_, i) => _CastCard(member: cast[i]),
            ),
          ),

        // Expanded: full vertical list for all cast
        if (expanded)
          Column(
            children: cast.map((m) => _CastListTile(member: m, cs: cs)).toList(),
          ),
      ],
    );
  }
}

// Horizontal scroll card (collapsed view)
class _CastCard extends StatelessWidget {
  final CastMember member;
  const _CastCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(37),
              child: SizedBox(
                width: 74,
                height: 74,
                child: member.profileUrl != null
                    ? CachedNetworkImage(
                        imageUrl: member.profileUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: cs.surfaceContainerHighest),
                        errorWidget: (_, _, _) => _ProfileFallback(cs: cs),
                      )
                    : _ProfileFallback(cs: cs),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              member.name,
              style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (member.character != null)
              Text(
                member.character!,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

// Vertical list tile (expanded view)
class _CastListTile extends StatelessWidget {
  final CastMember member;
  final ColorScheme cs;
  const _CastListTile({required this.member, required this.cs});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              width: 52,
              height: 52,
              child: member.profileUrl != null
                  ? CachedNetworkImage(
                      imageUrl: member.profileUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: cs.surfaceContainerHighest),
                      errorWidget: (_, _, _) => _ProfileFallback(cs: cs),
                    )
                  : _ProfileFallback(cs: cs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (member.character != null)
                  Text(
                    member.character!,
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFallback extends StatelessWidget {
  final ColorScheme cs;
  const _ProfileFallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.person_rounded, color: cs.onSurfaceVariant, size: 28),
    );
  }
}

// ── Crew tile ─────────────────────────────────────────────────

class _CrewTile extends StatelessWidget {
  final CrewMember member;
  const _CrewTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              width: 52,
              height: 52,
              child: member.profileUrl != null
                  ? CachedNetworkImage(
                      imageUrl: member.profileUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: cs.surfaceContainerHighest),
                      errorWidget: (_, _, _) =>
                          Container(color: cs.surfaceContainerHighest),
                    )
                  : Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.person_rounded,
                        color: cs.onSurfaceVariant,
                        size: 24,
                      ),
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
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  member.job,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seasons section (TV only) ─────────────────────────────────

class _SeasonsSection extends StatelessWidget {
  final List<TvSeason> seasons;
  const _SeasonsSection({required this.seasons});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _SectionHeader('Seasons'),
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
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 100,
                          height: 140,
                          child: season.posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: season.posterUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(
                                    color: cs.surfaceContainerHighest,
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    color: cs.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.movie_outlined,
                                      color: cs.onSurfaceVariant,
                                      size: 32,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.movie_outlined,
                                    color: cs.onSurfaceVariant,
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        season.name,
                        style: tt.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (season.episodeCount != null)
                        Text(
                          '${season.episodeCount} ep'
                          '${season.airYear != null ? ' · ${season.airYear}' : ''}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
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

// ── Related / Similar titles section ─────────────────────────

class _RelatedSection extends StatelessWidget {
  final AsyncValue<List<MediaItem>> relatedAsync;
  final bool isLoading;
  final ColorScheme cs;

  const _RelatedSection({
    required this.relatedAsync,
    required this.isLoading,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

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
            _SectionHeader('More Like This'),
            const SizedBox(height: 12),
            SizedBox(
              height: 196,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final related = items[i];
                  return GestureDetector(
                    onTap: () => context.push(
                      AppRoutes.mediaDetail,
                      extra: related,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 110,
                                height: 150,
                                child: related.posterUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: related.posterUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => Container(
                                          color: cs.surfaceContainerHighest,
                                        ),
                                        errorWidget: (_, _, _) =>
                                            _RelatedFallback(cs: cs),
                                      )
                                    : _RelatedFallback(cs: cs),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              related.title,
                              style: tt.labelSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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

class _RelatedFallback extends StatelessWidget {
  final ColorScheme cs;
  const _RelatedFallback({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: cs.onSurfaceVariant, size: 36),
    );
  }
}

// ── Shimmer placeholders ──────────────────────────────────────

class _ShimmerBlock extends StatelessWidget {
  final double width;
  final double height;
  final ColorScheme cs;

  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80));
  }
}

class _ShimmerLines extends StatelessWidget {
  final int count;
  final ColorScheme cs;
  const _ShimmerLines({required this.count, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 14,
            width: i == count - 1 ? 180 : double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80));
  }
}

class _ShimmerCastRow extends StatelessWidget {
  final ColorScheme cs;
  const _ShimmerCastRow({required this.cs});

  @override
  Widget build(BuildContext context) {
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
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 54,
                height: 10,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80));
  }
}

// ── Bottom action bar ─────────────────────────────────────────

class _LibraryActionBar extends ConsumerWidget {
  final MediaItem item;
  final Bookmark? bookmark;

  const _LibraryActionBar({required this.item, this.bookmark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withAlpha(80), width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: bookmark != null
              ? Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Bookmark'),
                        onPressed: () => showEditDeleteSheet(
                          context,
                          bookmark!,
                          onDelete: () => ref
                              .read(bookmarkListProvider.notifier)
                              .remove(bookmark!.id),
                        ),
                      ),
                    ),
                  ],
                )
              : FilledButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Add to Library'),
                  onPressed: () => showAddBookmarkSheet(context, item),
                ),
        ),
      ),
    );
  }
}
