// ─────────────────────────────────────────────────────────────
// lib/features/shell/screens/shell_screen.dart
// Prism redesign — floating glass pill nav at the bottom.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    (icon: Icons.home_outlined,          iconFilled: Icons.home_rounded,         label: 'Home'),
    (icon: Icons.search_outlined,        iconFilled: Icons.search_rounded,        label: 'Search'),
    (icon: Icons.video_library_outlined, iconFilled: Icons.video_library_rounded, label: 'Library'),
    (icon: Icons.settings_outlined,      iconFilled: Icons.settings_rounded,      label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark  = P.isDark(context);
    final acc   = P.accent(context);
    final acc3  = P.accent3(context);
    final bdr   = dark ? Colors.white.withAlpha(41) : P.border(context);
    final navBg = dark
        ? const Color(0xFF14141C)
        : Colors.white.withAlpha(235);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: navBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: bdr, width: 0.5),
          boxShadow: dark
              ? [
                  BoxShadow(color: Colors.white.withAlpha(10), offset: const Offset(0, 0.5)),
                  BoxShadow(color: Colors.black.withAlpha(153), blurRadius: 50, offset: const Offset(0, 18)),
                ]
              : [
                  BoxShadow(color: Colors.white.withAlpha(217), offset: const Offset(0, 0.5)),
                  BoxShadow(color: const Color(0xFF14121C).withAlpha(26), blurRadius: 40, offset: const Offset(0, 18)),
                  BoxShadow(color: const Color(0xFF14121C).withAlpha(13), blurRadius: 12, offset: const Offset(0, 4)),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            return _NavItem(
              icon: item.icon,
              iconFilled: item.iconFilled,
              label: item.label,
              active: i == selected,
              dark: dark,
              accent: acc,
              accent3: acc3,
              onTap: () => onSelect(i),
            );
          }),
        ),
      ),
    );
  }
}

// ── Nav item — stateful for scale punch + label animations ─────

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.iconFilled,
    required this.label,
    required this.active,
    required this.dark,
    required this.accent,
    required this.accent3,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconFilled;
  final String label;
  final bool active;
  final bool dark;
  final Color accent;
  final Color accent3;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with TickerProviderStateMixin {
  // Scale punch: 1.0 → 1.22 (easeOut, 32%) → 1.0 (elasticOut, 68%)
  late final AnimationController _punchCtrl;
  late final Animation<double> _punchAnim;

  // Label slide-in / fade-in driven by the same activation signal
  late final AnimationController _labelCtrl;
  late final Animation<double> _labelAnim;

  @override
  void initState() {
    super.initState();

    _punchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _punchAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.22).chain(CurveTween(curve: Curves.easeOut)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 68,
      ),
    ]).animate(_punchCtrl);

    _labelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 120),
      // Start at final state — no intro animation on first frame
      value: widget.active ? 1.0 : 0.0,
    );
    _labelAnim = CurvedAnimation(parent: _labelCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active) {
      _punchCtrl.forward(from: 0);
      _labelCtrl.forward();
    } else if (old.active && !widget.active) {
      _labelCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _punchCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

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
    if (widget.dark) {
      deco = BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: widget.active ? widget.accent.withAlpha(50) : Colors.transparent,
        border: Border.all(
          color: widget.active ? widget.accent.withAlpha(80) : Colors.transparent,
          width: 0.5,
        ),
      );
    } else {
      deco = BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.active
              ? [widget.accent, widget.accent3]
              : [widget.accent.withAlpha(0), widget.accent3.withAlpha(0)],
        ),
        boxShadow: widget.active
            ? [
                BoxShadow(
                  color: widget.accent.withAlpha(100),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: widget.active ? 26 : 22,
          vertical: 18,
        ),
        decoration: deco,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon: scale punch on activation + crossfade between outlined/filled
            ScaleTransition(
              scale: _punchAnim,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Icon(
                  widget.active ? widget.iconFilled : widget.icon,
                  key: ValueKey(widget.active),
                  size: 24,
                  color: widget.active
                      ? (widget.dark ? ink : Colors.white)
                      : inkDimmer,
                ),
              ),
            ),

            // Label: SizeTransition collapses width, FadeTransition fades text.
            // Both driven by _labelAnim so they move together.
            SizeTransition(
              sizeFactor: _labelAnim,
              axis: Axis.horizontal,
              axisAlignment: -1,
              child: FadeTransition(
                opacity: _labelAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(_labelAnim),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.01,
                          color: widget.dark ? ink : Colors.white,
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
    );
  }
}
