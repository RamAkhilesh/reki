// ─────────────────────────────────────────────────────────────
// lib/features/home/screens/dashboard_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/bookmarks/providers/bookmark_providers.dart';
import '../../../features/library/providers/library_providers.dart';
import '../widgets/category_card_widget.dart';
import '../widgets/recently_active_shelf.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _goToLibraryWithType(WidgetRef ref, String? type) {
    // type != null → jump to that media-type tab; null (See All) → no tab change.
    if (type != null) {
      ref.read(pendingLibraryTabTypeProvider.notifier).state = type;
    }
    ref.read(statusFilterProvider.notifier).state = null;
    ref.read(shellTabIndexProvider.notifier).state = ShellTab.library;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final recentAsync = ref.watch(recentlyActiveProvider);
    final categoryAsync = ref.watch(categoryStatsProvider);

    final recentItems = recentAsync.value ?? [];
    final allCategories = categoryAsync.value ?? [];
    final nonEmptyCategories =
        allCategories.where((s) => s.total > 0).toList();
    final isCategoryLoading = categoryAsync.isLoading;
    final isRecentLoading = recentAsync.isLoading;
    final allEmpty = !isCategoryLoading &&
        !isRecentLoading &&
        recentItems.isEmpty &&
        nonEmptyCategories.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'reki',
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            // ── All-empty state ───────────────────────────────
            if (allEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyDashboard(cs: cs, tt: tt),
              )
            else ...[
              // ── Recently Added ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recently Added',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (recentItems.isNotEmpty)
                        GestureDetector(
                          onTap: () => _goToLibraryWithType(ref, null),
                          child: Text(
                            'See all',
                            style: tt.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 80.ms),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: isRecentLoading
                      ? const _ShelfSkeleton()
                      : RecentlyActiveShelf(
                          onSeeAll: () => _goToLibraryWithType(ref, null),
                        ),
                ),
              ),

              // ── Browse by Category ────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Browse by Category',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 120.ms),
              ),

              if (isCategoryLoading)
                // ── Category skeleton grid ──────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 190,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (_, _) => _CategorySkeleton(cs: cs),
                      childCount: 4,
                    ),
                  ),
                )
              else
                // ── Category grid ───────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 190,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final stats = nonEmptyCategories[i];
                        return CategoryCardWidget(
                          stats: stats,
                          onTap: () =>
                              _goToLibraryWithType(ref, stats.mediaType),
                        )
                            .animate()
                            .fadeIn(
                              duration: 350.ms,
                              delay: (120 + i * 60).ms,
                            )
                            .slideY(begin: 0.05, end: 0, duration: 350.ms);
                      },
                      childCount: nonEmptyCategories.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty dashboard ───────────────────────────────────────────

class _EmptyDashboard extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;
  const _EmptyDashboard({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_border_rounded,
              size: 40,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your library is empty',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for movies, shows, anime,\nmanga, books, or games to get started.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.05, end: 0, duration: 400.ms);
  }
}

// ── Category skeleton card ────────────────────────────────────

class _CategorySkeleton extends StatelessWidget {
  final ColorScheme cs;
  const _CategorySkeleton({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 20,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(color: cs.surfaceContainerHighest),
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80));
  }
}

// ── Recently active shelf loading skeleton ────────────────────

class _ShelfSkeleton extends StatelessWidget {
  const _ShelfSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 84,
              color: cs.surfaceContainerHighest,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(duration: 1200.ms, color: cs.surface.withAlpha(80)),
        ),
      ),
    );
  }
}
