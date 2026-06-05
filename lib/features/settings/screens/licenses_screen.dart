// ─────────────────────────────────────────────────────────────
// lib/features/settings/screens/licenses_screen.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/prism_tokens.dart';
import '../../../shared/widgets/glass_card.dart';

// ── Data model ────────────────────────────────────────────────

class _Pkg {
  final String name;
  final List<LicenseEntry> entries;
  const _Pkg({required this.name, required this.entries});

  String get badge {
    for (final e in entries) {
      final t = e.paragraphs.map((p) => p.text).join(' ').toLowerCase();
      if (t.contains('permission is hereby granted') || t.contains('mit license')) return 'MIT';
      if (t.contains('apache license') || t.contains('apache-2.0')) return 'Apache 2.0';
      if (t.contains('mozilla public license')) return 'MPL 2.0';
      if (t.contains('gnu general public')) return 'GPL';
      if (t.contains('bsd')) return 'BSD';
      if (t.contains('isc ')) return 'ISC';
      if (t.contains('zlib')) return 'zlib';
      if (t.contains('unlicense')) return 'Unlicense';
    }
    return 'OSS';
  }

  String get fullText {
    final buf = StringBuffer();
    bool firstEntry = true;
    for (final entry in entries) {
      if (!firstEntry) buf.write('\n\n────────────────────────────\n\n');
      firstEntry = false;
      bool firstPara = true;
      for (final para in entry.paragraphs) {
        if (!firstPara) buf.write('\n\n');
        if (para.indent > 0) buf.write('  ' * para.indent);
        buf.write(para.text);
        firstPara = false;
      }
    }
    return buf.toString();
  }
}

// ── Screen ────────────────────────────────────────────────────

class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  List<_Pkg>? _all;
  List<_Pkg> _shown = [];
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final map = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final pkg in entry.packages) {
        (map[pkg] ??= []).add(entry);
      }
    }
    final pkgs = map.entries
        .map((e) => _Pkg(name: e.key, entries: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (mounted) setState(() { _all = pkgs; _shown = pkgs; });
  }

  void _filter(String q) {
    final all = _all ?? [];
    setState(() {
      _shown = q.isEmpty
          ? all
          : all.where((p) => p.name.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ink = P.ink(context);
    final inkDimmer = P.inkDimmer(context);
    final loading = _all == null;
    final count = _shown.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        const Positioned.fill(child: PrismBackdrop()),
        CustomScrollView(slivers: [
          // Status bar space
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
          ),

          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Row(children: [
                GlassButton(
                  size: 36,
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: ink),
                ),
                const SizedBox(width: 14),
                Text(
                  'Licenses',
                  style: GoogleFonts.inter(
                    fontSize: 28, fontWeight: FontWeight.w700,
                    color: ink, letterSpacing: -0.035 * 28, height: 1,
                  ),
                ),
              ]),
            ),
          ),

          // App license hero card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: _AppHeroCard(),
            ),
          ),

          // Third-party section header + search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'THIRD-PARTY LIBRARIES',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: inkDimmer, letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  _GlassSearchBar(controller: _ctrl, onChanged: _filter),
                  const SizedBox(height: 10),
                  if (!loading)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Row(children: [
                        Icon(Icons.balance_rounded, size: 12, color: inkDimmer),
                        const SizedBox(width: 5),
                        Text(
                          '$count ${count == 1 ? 'library' : 'libraries'}',
                          style: GoogleFonts.inter(fontSize: 11, color: inkDimmer),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),

          // Loading skeletons
          if (loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverList.builder(
                itemCount: 10,
                itemBuilder: (_, i) => _SkeletonItem(index: i, total: 10),
              ),
            ),

          // Empty search state
          if (!loading && _shown.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.search_off_rounded, size: 36, color: inkDimmer),
                  const SizedBox(height: 10),
                  Text(
                    'No results for "${_ctrl.text}"',
                    style: GoogleFonts.inter(fontSize: 13, color: inkDimmer),
                  ),
                ]),
              ),
            ),

          // Package list
          if (!loading && _shown.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverList.builder(
                itemCount: _shown.length,
                itemBuilder: (_, i) => _PkgItem(
                  pkg: _shown[i],
                  index: i,
                  total: _shown.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ]),
      ]),
    );
  }
}

// ── App hero card ─────────────────────────────────────────────

class _AppHeroCard extends StatelessWidget {
  const _AppHeroCard();

  @override
  Widget build(BuildContext context) {
    final ink = P.ink(context);
    final inkDim = P.inkDim(context);
    final acc = P.accent(context);
    final dark = P.isDark(context);

    return GlassCard(
      radius: 22,
      tint: acc,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App identity — centered
            Column(children: [
              Text('reki', style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: ink, letterSpacing: -0.5,
              )),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: acc.withAlpha(dark ? 50 : 40),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: acc.withAlpha(80), width: 0.5),
                ),
                child: Text('GPL-3.0', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: acc, letterSpacing: 0.4,
                )),
              ),
            ]),
            const SizedBox(height: 16),
            Text(
              'This app is free software licensed under the GNU General Public License v3.0. '
              'You may redistribute and/or modify it under the terms of this license.',
              style: GoogleFonts.inter(fontSize: 12.5, color: inkDim, height: 1.6),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 14),
            Row(children: [
              _HeroAction(
                label: 'View on GitHub',
                icon: Icons.code_rounded,
                onTap: () => _open('https://github.com/RamAkhilesh/reki'),
              ),
              const SizedBox(width: 10),
              _HeroAction(
                label: 'License text',
                icon: Icons.article_outlined,
                onTap: () => _open('https://www.gnu.org/licenses/gpl-3.0.html'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = P.ink(context);
    final dark = P.isDark(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: dark ? Colors.black.withAlpha(51) : Colors.white.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: P.border(context), width: 0.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13, color: ink),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: ink,
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────

class _GlassSearchBar extends StatefulWidget {
  const _GlassSearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<_GlassSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final inkDim = P.inkDim(context);
    final ink = P.ink(context);
    final dark = P.isDark(context);
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withAlpha(20) : Colors.white.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.border(context), width: 0.5),
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        Icon(Icons.search_rounded, size: 16, color: inkDim),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            onChanged: widget.onChanged,
            style: GoogleFonts.inter(fontSize: 13, color: ink),
            decoration: InputDecoration(
              hintText: 'Search libraries',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: inkDim),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (hasText)
          GestureDetector(
            onTap: () {
              widget.controller.clear();
              widget.onChanged('');
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.close_rounded, size: 16, color: inkDim),
            ),
          ),
      ]),
    );
  }
}

// ── Package list item ─────────────────────────────────────────

class _PkgItem extends StatefulWidget {
  const _PkgItem({required this.pkg, required this.index, required this.total});
  final _Pkg pkg;
  final int index;
  final int total;

  @override
  State<_PkgItem> createState() => _PkgItemState();
}

class _PkgItemState extends State<_PkgItem> {
  bool _expanded = false;

  BorderRadius get _radius {
    const r = Radius.circular(20);
    const s = Radius.circular(5);
    final i = widget.index;
    final n = widget.total;
    if (n == 1) return const BorderRadius.all(Radius.circular(20));
    if (i == 0) return BorderRadius.only(topLeft: r, topRight: r, bottomLeft: s, bottomRight: s);
    if (i == n - 1) return BorderRadius.only(topLeft: s, topRight: s, bottomLeft: r, bottomRight: r);
    return const BorderRadius.all(Radius.circular(5));
  }

  Color _avatarColor(BuildContext context) {
    final options = [P.accent(context), P.accent2(context), P.accent3(context)];
    final hash = widget.pkg.name.codeUnits.fold(0, (a, b) => a + b);
    return options[hash % options.length];
  }

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    final ink = P.ink(context);
    final inkDim = P.inkDim(context);
    final glass = dark ? Colors.white.withAlpha(28) : Colors.white.withAlpha(200);
    final radius = _radius;
    final color = _avatarColor(context);
    final isLast = widget.index == widget.total - 1;
    final bdr = P.border(context);
    final bdrSoft = P.borderSoft(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 1.5),
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: glass,
            border: Border(
              left: BorderSide(color: bdr, width: 0.5),
              right: BorderSide(color: bdr, width: 0.5),
              top: BorderSide(color: bdr, width: 0.5),
              bottom: isLast
                  ? BorderSide(color: bdr, width: 0.5)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Collapsed header ────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    // Letter avatar
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withAlpha(dark ? 40 : 30),
                        border: Border.all(color: color.withAlpha(60), width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          widget.pkg.name[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.pkg.name,
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: ink, letterSpacing: -0.01,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _LicenseBadge(label: widget.pkg.badge),
                        ],
                      ),
                    ),
                    // Expand chevron
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18, color: inkDim,
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Expanded content ─────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                child: _expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(height: 0.5, thickness: 0.5, color: bdrSoft),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // License text preview
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: dark
                                        ? Colors.black.withAlpha(40)
                                        : const Color(0xFF14121C).withAlpha(10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: bdrSoft, width: 0.5),
                                  ),
                                  child: Text(
                                    _clip(widget.pkg.fullText, 300),
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                      color: P.inkDimmer(context),
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => _showFull(context),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.open_in_new_rounded, size: 12, color: P.accent(context)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'View full license text',
                                      style: GoogleFonts.inter(
                                        fontSize: 11, fontWeight: FontWeight.w600,
                                        color: P.accent(context),
                                      ),
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _clip(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}…';
  }

  void _showFull(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LicenseSheet(pkg: widget.pkg),
    );
  }
}

// ── License type badge ────────────────────────────────────────

class _LicenseBadge extends StatelessWidget {
  const _LicenseBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withAlpha(18)
            : const Color(0xFF14121C).withAlpha(12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: dark ? P.borderSoft(context) : const Color(0xFF14121C).withAlpha(28),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9, fontWeight: FontWeight.w600,
          color: P.inkDimmer(context), letterSpacing: 0.02,
        ),
      ),
    );
  }
}

// ── Full license bottom sheet ─────────────────────────────────

class _LicenseSheet extends StatelessWidget {
  const _LicenseSheet({required this.pkg});
  final _Pkg pkg;

  @override
  Widget build(BuildContext context) {
    final ink = P.ink(context);
    final inkDim = P.inkDim(context);
    final dark = P.isDark(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: P.bg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: P.border(context), width: 0.5)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        // Drag handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: P.inkDimmer(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        // Sheet header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                pkg.name,
                style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: ink, letterSpacing: -0.02,
                ),
              ),
              Text(
                pkg.badge,
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: P.accent(context),
                ),
              ),
            ])),
            GlassButton(
              size: 32,
              onTap: () => Navigator.of(context).pop(),
              child: Icon(Icons.close_rounded, size: 15, color: ink),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Divider(height: 0.5, thickness: 0.5, color: P.border(context)),
        const SizedBox(height: 12),
        // Scrollable license text
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.black.withAlpha(50)
                    : const Color(0xFF14121C).withAlpha(8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: P.border(context), width: 0.5),
              ),
              child: SingleChildScrollView(
                child: Text(
                  pkg.fullText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: inkDim,
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
      ]),
    );
  }
}

// ── Skeleton loading item ─────────────────────────────────────

class _SkeletonItem extends StatelessWidget {
  const _SkeletonItem({required this.index, required this.total});
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    final glass = dark ? Colors.white.withAlpha(18) : Colors.white.withAlpha(180);
    const r = Radius.circular(20);
    const s = Radius.circular(5);
    final radius = total == 1
        ? const BorderRadius.all(Radius.circular(20))
        : index == 0
            ? BorderRadius.only(topLeft: r, topRight: r, bottomLeft: s, bottomRight: s)
            : index == total - 1
                ? BorderRadius.only(topLeft: s, topRight: s, bottomLeft: r, bottomRight: r)
                : const BorderRadius.all(Radius.circular(5));
    final isLast = index == total - 1;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 1.5),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: glass,
          border: Border.all(color: P.border(context), width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  width: (55 + (index % 3) * 35).toDouble(),
                  decoration: BoxDecoration(
                    color: dark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8, width: 28,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
