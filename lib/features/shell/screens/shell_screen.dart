// ─────────────────────────────────────────────────────────────
// lib/features/shell/screens/shell_screen.dart
// Prism redesign — floating glass pill nav at the bottom.
// ─────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/prism_tokens.dart';
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

    ref.listen<SyncResult?>(syncResultProvider, (_, result) {
      if (result == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.snackbarMessage),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      ref.read(syncResultProvider.notifier).state = null;
    });

    return Scaffold(
      backgroundColor: P.bg(context),
      body: Stack(
        children: [
          // ── Screens ────────────────────────────────────────
          IndexedStack(
            index: selectedIndex,
            children: const [
              DashboardScreen(),
              SearchScreen(),
              LibraryScreen(),
              SettingsScreen(),
            ],
          ),

          // ── Floating glass nav ─────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: _PrismNav(
              selected: selectedIndex,
              onSelect: (i) {
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
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating glass nav pill ────────────────────────────────────

class _PrismNav extends StatelessWidget {
  const _PrismNav({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const _items = [
    (icon: Icons.home_outlined,          iconFilled: Icons.home_rounded,            label: 'Home'),
    (icon: Icons.search_outlined,        iconFilled: Icons.search_rounded,           label: 'Search'),
    (icon: Icons.video_library_outlined, iconFilled: Icons.video_library_rounded,    label: 'Library'),
    (icon: Icons.settings_outlined,      iconFilled: Icons.settings_rounded,         label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    final acc  = P.accent(context);
    final acc3 = P.accent3(context);
    final bdr  = dark
        ? Colors.white.withAlpha(41)   // 0.16
        : P.border(context);
    final navBg = dark
        ? const Color(0xFF14141C).withAlpha(140)  // 0.55
        : Colors.white.withAlpha(178);             // 0.70

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: bdr, width: 0.5),
              boxShadow: dark
                  ? [
                      BoxShadow(
                        color: Colors.white.withAlpha(10),
                        offset: const Offset(0, 0.5),
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(153),
                        blurRadius: 50,
                        offset: const Offset(0, 18),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.white.withAlpha(217),
                        offset: const Offset(0, 0.5),
                      ),
                      BoxShadow(
                        color: const Color(0xFF14121C).withAlpha(26),
                        blurRadius: 40,
                        offset: const Offset(0, 18),
                      ),
                      BoxShadow(
                        color: const Color(0xFF14121C).withAlpha(13),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_items.length, (i) {
                final item   = _items[i];
                final active = i == selected;
                return _NavItem(
                  icon: active ? item.iconFilled : item.icon,
                  label: item.label,
                  active: active,
                  dark: dark,
                  accent: acc,
                  accent3: acc3,
                  onTap: () => onSelect(i),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.dark,
    required this.accent,
    required this.accent3,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool dark;
  final Color accent;
  final Color accent3;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink      = P.ink(context);
    final inkDimmer = P.inkDimmer(context);

    // Dark and light mode use different decoration strategies.
    // Dark: solid colour ↔ transparent — lerps fine.
    // Light: gradient with full alpha ↔ gradient with zero alpha — lerps fine.
    // Mixing gradient/null or colour/null breaks BoxDecoration.lerp and causes
    // the flash visible during the transition in light mode.
    final BoxDecoration deco;
    if (dark) {
      deco = BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: active ? Colors.white.withAlpha(41) : Colors.transparent,
        border: Border.all(
          color: active ? Colors.white.withAlpha(51) : Colors.transparent,
          width: 0.5,
        ),
      );
    } else {
      deco = BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: active
              ? [accent, accent3]
              : [accent.withAlpha(0), accent3.withAlpha(0)],
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: accent.withAlpha(100),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 20 : 16,
          vertical: 12,
        ),
        decoration: deco,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active
                  ? (dark ? ink : Colors.white)
                  : inkDimmer,
            ),
            if (active) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.01,
                  color: dark ? ink : Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
