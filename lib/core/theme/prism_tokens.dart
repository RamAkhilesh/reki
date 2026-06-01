// ─────────────────────────────────────────────────────────────
// lib/core/theme/prism_tokens.dart
// Prism design tokens — glass/spatial direction.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class P {
  P._();

  // ── Dark palette ──────────────────────────────────────────
  static const Color _dBg   = Color(0xFF1C1C1E);
  static const Color _dBg2  = Color(0xFF242428);
  static const Color _dInk  = Color(0xFFF8F8FA);

  static Color get _dGlass       => Colors.white.withAlpha(15);  // 0.06
  static Color get _dGlassStrong => Colors.white.withAlpha(26);  // 0.10
  static Color get _dBorder      => Colors.white.withAlpha(31);  // 0.12
  static Color get _dBorderSoft  => Colors.white.withAlpha(15);  // 0.06
  static Color get _dInkDim      => _dInk.withAlpha(166);        // 0.65
  static Color get _dInkDimmer   => _dInk.withAlpha(107);        // 0.42

  // ── Light palette ─────────────────────────────────────────
  static const Color _lBg   = Color(0xFFEFECE6);
  static const Color _lBg2  = Color(0xFFE6E2D8);
  static const Color _lInk  = Color(0xFF0C0C14);

  static Color get _lGlass       => Colors.white.withAlpha(140); // 0.55
  static Color get _lGlassStrong => Colors.white.withAlpha(199); // 0.78
  static Color get _lBorder      => const Color(0xFF14121C).withAlpha(26);  // 0.10
  static Color get _lBorderSoft  => const Color(0xFF14121C).withAlpha(15);  // 0.06
  static Color get _lInkDim      => const Color(0xFF14121C).withAlpha(158); // 0.62
  static Color get _lInkDimmer   => const Color(0xFF14121C).withAlpha(102); // 0.40

  // ── Accessors ─────────────────────────────────────────────
  static bool isDark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;

  static Color bg(BuildContext ctx)          => isDark(ctx) ? _dBg          : _lBg;
  static Color bg2(BuildContext ctx)         => isDark(ctx) ? _dBg2         : _lBg2;
  static Color glass(BuildContext ctx)       => isDark(ctx) ? _dGlass       : _lGlass;
  static Color glassStrong(BuildContext ctx) => isDark(ctx) ? _dGlassStrong : _lGlassStrong;
  static Color border(BuildContext ctx)      => isDark(ctx) ? _dBorder      : _lBorder;
  static Color borderSoft(BuildContext ctx)  => isDark(ctx) ? _dBorderSoft  : _lBorderSoft;
  static Color ink(BuildContext ctx)         => isDark(ctx) ? _dInk         : _lInk;
  static Color inkDim(BuildContext ctx)      => isDark(ctx) ? _dInkDim      : _lInkDim;
  static Color inkDimmer(BuildContext ctx)   => isDark(ctx) ? _dInkDimmer   : _lInkDimmer;

  // Accent colours follow the app's selected seed via Material 3 colorScheme.
  static Color accent(BuildContext ctx)  => Theme.of(ctx).colorScheme.primary;
  static Color accent2(BuildContext ctx) => Theme.of(ctx).colorScheme.secondary;
  static Color accent3(BuildContext ctx) => Theme.of(ctx).colorScheme.tertiary;

  // ── Status colours (consistent across modes) ──────────────
  static const Color statusWatching  = Color(0xFF7DD3FC); // sky
  static const Color statusCompleted = Color(0xFF86EFAC); // green
  static const Color statusPlan      = Color(0xFFA5B4FC); // periwinkle
  static const Color statusDropped   = Color(0xFFFDA4AF); // coral/rose
  static const Color statusOnHold    = Color(0xFFFCD34D); // amber

  static Color statusColor(String status) {
    switch (status) {
      case 'watching': return statusWatching;
      case 'completed': return statusCompleted;
      case 'want_to_watch': return statusPlan;
      case 'dropped': return statusDropped;
      case 'on_hold': return statusOnHold;
      default: return statusPlan;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'watching': return 'In Progress';
      case 'completed': return 'Completed';
      case 'want_to_watch': return 'Plan to Start';
      case 'dropped': return 'Dropped';
      case 'on_hold': return 'On Hold';
      default: return status;
    }
  }
}
