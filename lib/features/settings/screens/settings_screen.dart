// ─────────────────────────────────────────────────────────────
// lib/features/settings/screens/settings_screen.dart
// Prism redesign — glass settings screen.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/prism_tokens.dart';
import 'licenses_screen.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_providers.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../../library/providers/library_providers.dart';
import '../../library/screens/library_tab_settings_screen.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      final wasGuest = prev?.value is AuthStateUnauthenticated ||
          prev?.value == null ||
          prev?.value is AuthStateInitial;
      final isNowAuth = next.value is AuthStateAuthenticated;
      if (wasGuest && isNowAuth && mounted) {
        _maybeMigrateLocalData();
      }
    });

    final authAsync  = ref.watch(authProvider);
    final colorTheme = ref.watch(appColorThemeProvider);
    final themeMode  = ref.watch(appThemeModeProvider);
    final isSignedIn = ref.watch(isAuthenticatedProvider);
    final ink        = P.ink(context);

    return Stack(
      children: [
        // ── Backdrop ──────────────────────────────────────
        const Positioned.fill(child: PrismBackdrop()),

        // ── Content ───────────────────────────────────────
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
            ),

            // ── Title ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                child: Text(
                  'Settings',
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

            // ── Profile card ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: authAsync.when(
                  loading: () => GlassCard(
                    radius: 22,
                    child: const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (auth) => auth is AuthStateAuthenticated
                      ? _ProfileCard(user: auth.user)
                      : _GuestCard(),
                ),
              ),
            ),

            // ── Appearance ──────────────────────────────────
            _PSection(label: 'Appearance', children: [
              // Display mode
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display mode',
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SegmentedMode(current: themeMode),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Color theme
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color theme',
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ColorSwatchRow(current: colorTheme),
                  ],
                ),
              ),
            ]),

            // ── Library ─────────────────────────────────────
            _PSection(label: 'Library', children: [
              _PLink(
                label: 'Tab order',
                hint: 'Reorder and show/hide media type tabs',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LibraryTabSettingsScreen(),
                  ),
                ),
              ),
            ]),

            // ── Data & Backup ───────────────────────────────
            _PSection(label: 'Data & Backup', children: [
              _PLink(
                label: 'Export data',
                hint: 'Save bookmarks as JSON',
                onTap: isSignedIn ? _exportData : _showSignInSnackbar,
              ),
              _PLink(
                label: 'Import data',
                hint: 'Restore from JSON backup',
                onTap: isSignedIn ? _importData : _showSignInSnackbar,
                first: false,
              ),
            ]),

            // ── Statistics ──────────────────────────────────
            _PSection(label: 'Statistics', children: [
              _PLink(
                label: 'Statistics',
                trailing: _ComingSoon(),
                onTap: null,
              ),
            ]),

            // ── About ───────────────────────────────────────
            _PSection(label: 'About', children: [
              _PLink(
                label: 'Source code',
                hint: 'View or contribute on GitHub',
                onTap: () => _launch('https://github.com/RamAkhilesh/reki'),
              ),
              _PLink(
                label: 'Report a bug',
                hint: 'Open an issue on GitHub',
                first: false,
                onTap: () => _launch('https://github.com/RamAkhilesh/reki/issues'),
              ),
              _PLink(
                label: 'Open-source licenses',
                first: false,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LicensesScreen(),
                  ),
                ),
              ),
            ]),

            // ── Footer ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 40, 0, 0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'reki',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: P.inkDimmer(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (ref.watch(packageInfoProvider).value case final PackageInfo info)
                        Text(
                          'v${info.version}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: P.inkDimmer(context).withValues(alpha: 0.5),
                            letterSpacing: 0.02,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  void _showSignInSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in to use this feature.')),
    );
  }

  Future<void> _maybeMigrateLocalData() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool('has_migrated_local_data') ?? false) return;
    await prefs.setBool('has_migrated_local_data', true);
  }

  Future<void> _exportData() async {
    final bookmarksAsync = ref.read(bookmarkListProvider);
    final bookmarks = bookmarksAsync.value ?? [];

    final payload = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'bookmarks': bookmarks.map((b) {
        final mi = b.mediaItem;
        return {
          'id': b.id,
          'status': b.status,
          'rating': b.rating,
          'notes': b.notes,
          'start_date': b.startDate?.toIso8601String(),
          'end_date': b.endDate?.toIso8601String(),
          'progress_count': b.progressCount,
          'created_at': b.createdAt.toIso8601String(),
          'updated_at': b.updatedAt.toIso8601String(),
          'media_item': {
            'id': mi.id,
            'external_id': mi.externalId,
            'source': mi.source,
            'media_type': mi.mediaType,
            'title': mi.title,
            'poster_url': mi.posterUrl,
            'genres': mi.genres,
            'runtime_minutes': mi.runtimeMinutes,
            'episode_count': mi.episodeCount,
            'overview': mi.overview,
          },
        };
      }).toList(),
    };

    final json      = const JsonEncoder.withIndent('  ').convert(payload);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName  = 'reki_export_$timestamp.json';

    final tempDir = await getTemporaryDirectory();
    final file    = File('${tempDir.path}/$fileName');
    await file.writeAsString(json);

    await Share.shareXFiles([XFile(file.path)], subject: 'reki Data Export');
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      final content = await File(path).readAsString();
      final data    = jsonDecode(content) as Map<String, dynamic>;
      if ((data['version'] as int?) != 1) {
        _showSnackbar('Unsupported export version. Cannot import.');
        return;
      }

      final rawBookmarks =
          (data['bookmarks'] as List<dynamic>).cast<Map<String, dynamic>>();
      final existing = ref.read(bookmarkListProvider).value ?? [];
      final existingKeys = existing
          .map((b) => '${b.mediaItem.source}:${b.mediaItem.externalId}')
          .toSet();

      final toImport = <Map<String, dynamic>>[];
      int skipped = 0;
      for (final bJson in rawBookmarks) {
        final miJson = bJson['media_item'] as Map<String, dynamic>;
        final key    = '${miJson['source']}:${miJson['external_id']}';
        if (existingKeys.contains(key)) {
          skipped++;
        } else {
          toImport.add(bJson);
        }
      }

      if (toImport.isEmpty) {
        _showSnackbar(
          skipped > 0
              ? 'Nothing new — $skipped already in library.'
              : 'Export file contains no bookmarks.',
        );
        return;
      }

      final repo = ref.read(bookmarkRepositoryProvider);
      await Future.wait(
        toImport.map((bJson) async {
          final miJson   = bJson['media_item'] as Map<String, dynamic>;
          final rawStatus = bJson['status'] as String? ?? BookmarkStatus.wantToWatch;
          final status   = BookmarkStatus.all.contains(rawStatus)
              ? rawStatus
              : BookmarkStatus.wantToWatch;

          final mediaItem = MediaItem(
            externalId: miJson['external_id'] as String,
            source: miJson['source'] as String,
            mediaType: miJson['media_type'] as String,
            title: miJson['title'] as String,
            posterUrl: miJson['poster_url'] as String?,
            genres: (miJson['genres'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
            runtimeMinutes: miJson['runtime_minutes'] as int?,
            episodeCount: miJson['episode_count'] as int?,
            overview: miJson['overview'] as String?,
          );

          await repo.addBookmark(
            mediaItem: mediaItem,
            status: status,
            rating: bJson['rating'] as int?,
            notes: bJson['notes'] as String?,
            startDate: bJson['start_date'] != null
                ? DateTime.tryParse(bJson['start_date'] as String)
                : null,
            endDate: bJson['end_date'] != null
                ? DateTime.tryParse(bJson['end_date'] as String)
                : null,
            progressCount: bJson['progress_count'] as int?,
          );
        }),
      );

      ref.invalidate(bookmarkListProvider);
      final n = toImport.length;
      _showSnackbar(
        'Imported $n item${n == 1 ? '' : 's'}'
        '${skipped > 0 ? ', skipped $skipped duplicate${skipped == 1 ? '' : 's'}' : ''}.',
      );
    } catch (_) {
      _showSnackbar('Failed to parse the import file.');
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Profile card (signed-in) ──────────────────────────────────

class _ProfileCard extends ConsumerWidget {
  final dynamic user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email  = (user.email as String?) ?? 'No email';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    final acc    = P.accent(context);
    final acc2   = P.accent2(context);
    final acc3   = P.accent3(context);

    return GlassCard(
      radius: 22,
      tint: acc,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [acc, acc2],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withAlpha(77),
                        offset: const Offset(0, 0.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.split('@').first,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          letterSpacing: -0.02,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 11, color: inkDim,
                        ),
                      ),
                    ],
                  ),
                ),
                GlassButton(
                  size: 34,
                  onTap: () async {
                    await ref.read(authProvider.notifier).signOut();
                  },
                  child: Icon(Icons.logout_rounded, size: 16, color: ink),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats row
            Consumer(builder: (ctx, ref2, _) {
              final all = ref2.watch(bookmarkListProvider).value ?? [];
              final done = all.where((b) => b.status == 'completed').length;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: P.isDark(ctx)
                      ? Colors.black.withAlpha(51)
                      : const Color(0xFF14121C).withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: P.isDark(ctx)
                        ? P.borderSoft(ctx)
                        : const Color(0xFF14121C).withAlpha(40),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    _StatChip(value: '${all.length}', label: 'Items', color: acc),
                    _StatChip(value: '$done', label: 'Done', color: acc2),
                    _StatChip(value: '—', label: 'Streak', color: acc3),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: P.inkDim(context),
              letterSpacing: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Guest card ────────────────────────────────────────────────

class _GuestCard extends ConsumerWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    final acc    = P.accent(context);

    return GlassCard(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage_rounded, color: acc, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Local storage',
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.01,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your data is stored locally. Sign in to back it up and sync across devices.',
              style: GoogleFonts.inter(fontSize: 13, color: inkDim, height: 1.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push(AppRoutes.login),
                    child: GlassCard(
                      radius: 100,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Sign In',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600, color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push(AppRoutes.register),
                    child: GlassCard(
                      radius: 100,
                      tint: acc,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Sign Up',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings section ──────────────────────────────────────────

class _PSection extends StatelessWidget {
  const _PSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: P.inkDimmer(context),
                  letterSpacing: 0.06 * 10,
                ),
              ),
            ),
            GlassCard(
              radius: 20,
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings link row ─────────────────────────────────────────

class _PLink extends StatelessWidget {
  const _PLink({
    required this.label,
    this.hint,
    this.trailing,
    this.first = true,
    this.onTap,
  });

  final String label;
  final String? hint;
  final Widget? trailing;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: P.borderSoft(context), width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ink,
                      letterSpacing: -0.01,
                    ),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint!,
                      style: GoogleFonts.inter(fontSize: 11, color: inkDim),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: onTap == null ? P.inkDimmer(context) : inkDim,
                ),
          ],
        ),
      ),
    );
  }
}

// ── Segmented mode picker ─────────────────────────────────────

class _SegmentedMode extends ConsumerWidget {
  final ThemeMode current;
  const _SegmentedMode({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);

    final dark = P.isDark(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withAlpha(64)
            : const Color(0xFF14121C).withAlpha(18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: dark
              ? P.borderSoft(context)
              : const Color(0xFF14121C).withAlpha(40),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          for (final (mode, label) in [
            (ThemeMode.light, 'Light'),
            (ThemeMode.system, 'Auto'),
            (ThemeMode.dark, 'Dark'),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => ref.read(appThemeModeProvider.notifier).set(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: current == mode
                        ? (dark ? Colors.white.withAlpha(41) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: current == mode
                          ? (dark
                              ? Colors.white.withAlpha(51)
                              : const Color(0xFF14121C).withAlpha(20))
                          : Colors.transparent,
                      width: 0.5,
                    ),
                    boxShadow: (current == mode && !dark)
                        ? [
                            BoxShadow(
                              color: const Color(0xFF14121C).withAlpha(18),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: current == mode ? ink : inkDim,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Color swatch row ──────────────────────────────────────────

class _ColorSwatchRow extends ConsumerWidget {
  final AppColorTheme current;
  const _ColorSwatchRow({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDynamic = !kIsWeb && Platform.isAndroid;
    final themes = AppColorTheme.values
        .where((t) => t != AppColorTheme.dynamic || showDynamic)
        .toList();
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);

    return SizedBox(
      height: 82,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: themes.length,
        itemBuilder: (ctx, i) {
          final theme      = themes[i];
          final selected   = theme == current;
          final seedColor  = theme.seedColor;

          return GestureDetector(
            onTap: () => ref.read(appColorThemeProvider.notifier).set(theme),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: selected ? 56 : 52,
                    height: selected ? 56 : 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: seedColor,
                      gradient: seedColor == null
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF6750A4),
                                Color(0xFF1A6B8A),
                                Color(0xFF2D6A4F),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: selected
                          ? Border.all(color: ink, width: 2.5)
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    theme.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: selected ? ink : inkDim,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Coming soon badge ─────────────────────────────────────────

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark
            ? P.glass(context)
            : const Color(0xFF14121C).withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark
              ? P.borderSoft(context)
              : const Color(0xFF14121C).withAlpha(40),
          width: 0.5,
        ),
      ),
      child: Text(
        'Coming soon',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: P.inkDim(context),
        ),
      ),
    );
  }
}
