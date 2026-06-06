// ─────────────────────────────────────────────────────────────
// lib/shared/widgets/glass_card.dart
// Frosted-glass surface and ambient backdrop widgets.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/theme/prism_tokens.dart';

// ── GlassCard ─────────────────────────────────────────────────
// Frosted glass surface — blur(40) + glass tint + 0.5px border.
// Wrap any content; set [radius] and optionally a [tint] colour.

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 22.0,
    this.padding,
    this.tint,
    this.style,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint; // optional colour overlay (uses 30% opacity automatically)
  final BoxDecoration? style; // full override if needed

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    final glass = dark
        ? P.glassStrong(context)       // ~10% white ≈ #323234 on near-black
        : Colors.white.withAlpha(210); // 0.82
    final bdr   = P.border(context);

    final decoration = style ?? BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: tint == null ? glass : null,
      gradient: tint != null
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint!.withAlpha(dark ? 48 : 68),
                glass,
              ],
            )
          : null,
      border: Border.all(color: bdr, width: 0.5),
      boxShadow: dark
          ? [
              BoxShadow(
                color: Colors.white.withAlpha(8),
                offset: const Offset(0, 0.5),
                blurRadius: 0,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withAlpha(64),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.white.withAlpha(178),
                offset: const Offset(0, 0.5),
                blurRadius: 0,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: const Color(0xFF14121C).withAlpha(15),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF14121C).withAlpha(10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
    );

    Widget card = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}

// ── GlassButton ───────────────────────────────────────────────
// Round glass icon button (40×40 by default).

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onTap,
    required this.child,
    this.size = 40,
    this.radius,
    this.tint,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double size;
  final double? radius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size / 2;
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        radius: r,
        tint: tint,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ── PrismBackdrop ─────────────────────────────────────────────
// Iridescent gradient that fills the screen behind content.
// variant: 'default' | 'warm' | 'cool' | 'plain'

class PrismBackdrop extends StatelessWidget {
  const PrismBackdrop({super.key, this.variant = 'default'});

  final String variant;

  @override
  Widget build(BuildContext context) {
    return Container(color: P.bg(context));
  }
}

// ── SectionTitle ──────────────────────────────────────────────
// Kicker + bold title row with optional trailing "See all" action.

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.kicker,
    required this.title,
    this.action,
    this.onAction,
  });

  final String kicker;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final inkDim    = P.inkDim(context);
    final inkDimmer = P.inkDimmer(context);
    final ink       = P.ink(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: inkDimmer,
                    letterSpacing: 0.06 * 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    letterSpacing: -0.025 * 20,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: inkDim,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 14, color: inkDim),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── PrismPill ─────────────────────────────────────────────────
// Pill-shaped glass chip (used for status, type badges, scope filters).

class PrismPill extends StatelessWidget {
  const PrismPill({
    super.key,
    required this.label,
    this.active = false,
    this.dotColor,
    this.onTap,
    this.small = false,
  });

  final String label;
  final bool active;
  final Color? dotColor;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final dark = P.isDark(context);
    final ink  = P.ink(context);
    final inkDim = P.inkDim(context);

    final bg = active
        ? (dark
            ? Colors.white.withAlpha(41) // 0.16
            : Colors.white.withAlpha(41))
        : P.glass(context);
    final bdr = active
        ? (dark
            ? Colors.white.withAlpha(51) // 0.20
            : P.border(context))
        : P.borderSoft(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 14,
          vertical: small ? 5 : 8,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: bdr, width: 0.5),
        ),
        child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: [BoxShadow(color: dotColor!, blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: small ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: active ? ink : inkDim,
                    letterSpacing: -0.01,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
