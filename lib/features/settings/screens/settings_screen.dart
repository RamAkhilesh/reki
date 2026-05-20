// ─────────────────────────────────────────────────────────────
// lib/features/settings/screens/settings_screen.dart
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
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
    // Detect first sign-in to trigger local-data migration
    ref.listen(authProvider, (prev, next) {
      final wasGuest = prev?.value is AuthStateUnauthenticated ||
          prev?.value == null ||
          prev?.value is AuthStateInitial;
      final isNowAuth = next.value is AuthStateAuthenticated;
      if (wasGuest && isNowAuth && mounted) {
        _maybeMigrateLocalData();
      }
    });

    final authAsync = ref.watch(authProvider);
    final colorTheme = ref.watch(appColorThemeProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final isSignedIn = ref.watch(isAuthenticatedProvider);

    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
          // ── Title ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(
              'Settings',
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // ── 1. Account ─────────────────────────────────
          _SectionHeader('Account'),
          authAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => const SizedBox.shrink(),
              data: (auth) => auth is AuthStateAuthenticated
                  ? _SignedInAccountTile(user: auth.user)
                  : _GuestAccountCard(),
            ),

          // ── 2. Appearance ──────────────────────────────
          _SectionHeader('Appearance'),
          _SettingsGroup(children: [
            const SizedBox(height: 10),
            _ThemeModeSegment(current: themeMode),
            const SizedBox(height: 10),
            _ColorSwatchRow(current: colorTheme),
            const SizedBox(height: 10),
          ]),

          // ── 3. Library ─────────────────────────────────
          _SectionHeader('Library'),
          _SettingsGroup(children: [
            ListTile(
              leading: const Icon(Icons.tab_outlined),
              title: const Text('Tab order'),
              subtitle: const Text('Reorder and show/hide media type tabs'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LibraryTabSettingsScreen(),
                ),
              ),
            ),
          ]),

          // ── 4. Data & Backup ───────────────────────────
          _SectionHeader('Data & Backup'),
          _SettingsGroup(children: [
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Export data'),
              subtitle: const Text('Save bookmarks as JSON'),
              onTap: isSignedIn ? _exportData : _showSignInSnackbar,
            ),
            const Divider(height: 1, indent: 56, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Import data'),
              subtitle: const Text('Restore from JSON backup'),
              onTap: isSignedIn ? _importData : _showSignInSnackbar,
            ),
          ]),

          // ── 5. Statistics ──────────────────────────────
          _SectionHeader('Statistics'),
          _SettingsGroup(children: [
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Statistics'),
              trailing: _ComingSoonBadge(),
              onTap: null,
            ),
          ]),

          // ── 6. About ───────────────────────────────────
          _SectionHeader('About'),
          const _AboutCard(),

          const SizedBox(height: 8),
        ],
      ),
      ),
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

    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'reki_export_$timestamp.json';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'reki Data Export',
    );
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
      final data = jsonDecode(content) as Map<String, dynamic>;
      final version = data['version'] as int?;
      if (version != 1) {
        _showSnackbar('Unsupported export version. Cannot import.');
        return;
      }

      final rawBookmarks =
          (data['bookmarks'] as List<dynamic>).cast<Map<String, dynamic>>();
      final existing = ref.read(bookmarkListProvider).value ?? [];

      // Use composite source:externalId key — avoids false-positive dedup when
      // different sources happen to share the same numeric ID.
      final existingKeys = existing
          .map((b) => '${b.mediaItem.source}:${b.mediaItem.externalId}')
          .toSet();

      final toImport = <Map<String, dynamic>>[];
      int skipped = 0;
      for (final bJson in rawBookmarks) {
        final miJson = bJson['media_item'] as Map<String, dynamic>;
        final key = '${miJson['source']}:${miJson['external_id']}';
        if (existingKeys.contains(key)) {
          skipped++;
        } else {
          toImport.add(bJson);
        }
      }

      if (toImport.isEmpty) {
        _showSnackbar(
          skipped > 0
              ? 'Nothing new — $skipped item${skipped == 1 ? '' : 's'} already in library.'
              : 'Export file contains no bookmarks.',
        );
        return;
      }

      // Run all upserts in parallel — one network round trip per item instead of N serial calls.
      final repo = ref.read(bookmarkRepositoryProvider);
      await Future.wait(
        toImport.map((bJson) async {
          final miJson = bJson['media_item'] as Map<String, dynamic>;
          // Validate status — fall back to wantToWatch for unknown values.
          final rawStatus = bJson['status'] as String? ?? BookmarkStatus.wantToWatch;
          final status = BookmarkStatus.all.contains(rawStatus)
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

      // Refresh the list from the server now that all rows are written.
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

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Section header ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.primary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

// ── Settings group (elevated surface background) ───────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: Column(children: children),
      ),
    );
  }
}

// ── Account: guest card ────────────────────────────────────────

class _GuestAccountCard extends ConsumerWidget {
  const _GuestAccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: cs.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.storage_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Local storage',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Your data is stored locally. Sign in to back it up and sync across devices.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push(AppRoutes.login),
                      child: const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: () => context.push(AppRoutes.register),
                      child: const Text('Sign Up'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Account: signed-in tile ────────────────────────────────────

class _SignedInAccountTile extends ConsumerWidget {
  final dynamic user; // supabase_flutter User

  const _SignedInAccountTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final email = user.email as String? ?? 'No email';

    Future<void> confirmDelete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign out and delete account?'),
          content: const Text(
            'This will sign you out. Your data on the server is not removed automatically — '
            'contact support to permanently delete your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(authProvider.notifier).deleteAccount();
      }
    }

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text(
              email.isNotEmpty ? email[0].toUpperCase() : '?',
              style: TextStyle(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: const Text('Signed in as'),
          subtitle: Text(email),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).signOut();
                  },
                  child: const Text('Sign Out'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    side: BorderSide.none,
                  ),
                  onPressed: confirmDelete,
                  child: const Text('Delete Account'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Color swatch row ───────────────────────────────────────────

class _ColorSwatchRow extends ConsumerWidget {
  final AppColorTheme current;
  const _ColorSwatchRow({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide Dynamic on non-Android platforms
    final showDynamic = !kIsWeb && Platform.isAndroid;
    final themes = AppColorTheme.values
        .where((t) => t != AppColorTheme.dynamic || showDynamic)
        .toList();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Color theme',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 82,
            child: Stack(
              children: [
                ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: themes.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(width: 16),
                  padding: const EdgeInsets.only(right: 16),
                  itemBuilder: (context, i) {
                    final theme = themes[i];
                    return _ColorSwatch(
                      theme: theme,
                      isSelected: theme == current,
                      onTap: () =>
                          ref.read(appColorThemeProvider.notifier).set(theme),
                    );
                  },
                ),
                // Right-edge fade — hints there are more themes to scroll to
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            cs.surfaceContainerHigh.withAlpha(0),
                            cs.surfaceContainerHigh,
                          ],
                        ),
                      ),
                    ),
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

class _ColorSwatch extends StatelessWidget {
  final AppColorTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final seedColor = theme.seedColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer selection ring
              if (isSelected)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.onSurface, width: 2.5),
                  ),
                ),
              // Swatch circle
              Container(
                width: 52,
                height: 52,
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
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 22)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            theme.label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ── Theme mode segmented button ────────────────────────────────

class _ThemeModeSegment extends ConsumerWidget {
  final ThemeMode current;
  const _ThemeModeSegment({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Display mode',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {current},
              onSelectionChanged: (set) =>
                  ref.read(appThemeModeProvider.notifier).set(set.first),
            ),
          ),
        ],
      ),
    );
  }
}


// ── About card ────────────────────────────────────────────────

class _AboutCard extends ConsumerWidget {
  const _AboutCard();

  Future<void> _launch(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pkgAsync = ref.watch(packageInfoProvider);

    final version = pkgAsync.when(
      data: (info) => 'v${info.version}',
      loading: () => '',
      error: (_, _) => '',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App identity ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.movie_filter_rounded,
                      size: 30,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'reki',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your personal media library',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (version.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            version,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Links ─────────────────────────────────────
            Divider(
              height: 1,
              color: cs.outlineVariant.withAlpha(80),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('Source code'),
              subtitle: const Text('View, star, or contribute on GitHub'),
              trailing: Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => _launch(context, 'https://github.com/ramakhilesh22/reki'),
            ),
            Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: cs.outlineVariant.withAlpha(80),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Report a bug'),
              subtitle: const Text('Open an issue on GitHub'),
              trailing: Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => _launch(context, 'https://github.com/ramakhilesh22/reki/issues'),
            ),
            Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: cs.outlineVariant.withAlpha(80),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: const Text('Open-source licenses'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'reki',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Coming soon badge ──────────────────────────────────────────

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Coming soon',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSecondaryContainer,
            ),
      ),
    );
  }
}
