// ─────────────────────────────────────────────────────────────
// lib/features/shell/screens/shell_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/sync_result.dart';
import '../../bookmarks/providers/bookmark_providers.dart';
import '../../home/screens/dashboard_screen.dart';
import '../../library/providers/library_providers.dart';
import '../../library/screens/library_screen.dart';
import '../../search/providers/search_providers.dart';
import '../../search/screens/search_screen.dart';
import '../../settings/screens/settings_screen.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(shellTabIndexProvider);

    // Show a snackbar whenever a sync completes with changes.
    ref.listen<SyncResult?>(syncResultProvider, (_, result) {
      if (result == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.snackbarMessage),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      // Clear so a future re-listen doesn't re-show the same result.
      ref.read(syncResultProvider.notifier).state = null;
    });

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          DashboardScreen(),
          SearchScreen(),
          LibraryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          if (i == selectedIndex && i == ShellTab.search) {
            ref.read(searchFocusRequestProvider.notifier).state++;
          } else if (i == selectedIndex && i == ShellTab.library) {
            ref.read(librarySearchFocusRequestProvider.notifier).state++;
          } else {
            if (selectedIndex == ShellTab.search) {
              ref.read(searchResetProvider.notifier).state++;
            }
            ref.read(shellTabIndexProvider.notifier).state = i;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
