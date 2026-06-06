// ─────────────────────────────────────────────────────────────
// lib/features/search/widgets/search_filter_sheet.dart
// ─────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/prism_tokens.dart';
import '../providers/search_providers.dart';

class SearchFilterSheet extends StatefulWidget {
  final SearchFilters initialFilters;
  final ValueChanged<SearchFilters> onApply;

  const SearchFilterSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  // null = All (no filter)
  String? _selectedMediaType;
  String? _language;
  int _resetKey = 0;

  static const _mediaTypes = <(String?, String)>[
    (null, 'All'),
    ('movie', 'Movies'),
    ('tv', 'TV Shows'),
    ('anime', 'Anime'),
    ('manga', 'Manga'),
    ('book', 'Books'),
    ('game', 'Games'),
  ];

  static const _languages = [
    ('en', 'English'),
    ('ja', 'Japanese'),
    ('ko', 'Korean'),
    ('zh', 'Chinese'),
    ('es', 'Spanish'),
    ('fr', 'French'),
    ('de', 'German'),
    ('pt', 'Portuguese'),
    ('it', 'Italian'),
    ('ru', 'Russian'),
    ('ar', 'Arabic'),
    ('hi', 'Hindi'),
    ('th', 'Thai'),
    ('id', 'Indonesian'),
    ('tr', 'Turkish'),
  ];

  @override
  void initState() {
    super.initState();
    final types = widget.initialFilters.mediaTypes;
    _selectedMediaType = types.isNotEmpty ? types.first : null;
    _language = widget.initialFilters.language;
  }

  bool get _isActive => _selectedMediaType != null || _language != null;

  void _reset() => setState(() {
        _selectedMediaType = null;
        _language = null;
        _resetKey++;
      });

  void _apply() {
    widget.onApply(
      SearchFilters(
        mediaTypes: _selectedMediaType != null ? {_selectedMediaType!} : {},
        language: _language,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);

    final sectionLabel = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: P.inkDimmer(context),
      letterSpacing: 0.08 * 10,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: P.bg(context).withAlpha(240),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: P.border(context), width: 0.5)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(56)
                          : Colors.black.withAlpha(46),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Header row
              Row(
                children: [
                  Text(
                    'Filter',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: P.ink(context),
                      letterSpacing: -0.02,
                    ),
                  ),
                  const Spacer(),
                  _SheetButton(
                    label: 'Reset',
                    onTap: _isActive ? _reset : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Media type ──────────────────────────────────
              Text('MEDIA TYPE', style: sectionLabel),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (code, label) in _mediaTypes)
                    _FilterChip(
                      label: label,
                      selected: _selectedMediaType == code,
                      onTap: () => setState(() => _selectedMediaType = code),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Language ────────────────────────────────────
              Text('LANGUAGE', style: sectionLabel),
              const SizedBox(height: 8),
              _GlassDropdown<String?>(
                key: ValueKey(_resetKey),
                value: _language,
                hint: 'Any language',
                onChanged: (v) => setState(() => _language = v),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any language')),
                  for (final (code, label) in _languages)
                    DropdownMenuItem(value: code, child: Text(label)),
                ],
              ),
              const SizedBox(height: 24),

              // ── Apply button ────────────────────────────────
              _ApplyButton(
                label: _isActive ? 'Apply filters' : 'Apply',
                onTap: _apply,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _FilterChip ───────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);
    final acc    = P.accent(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white.withAlpha(22) : acc.withAlpha(22))
              : (isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white.withAlpha(50) : acc.withAlpha(80))
                : P.borderSoft(context),
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? ink : inkDim,
            letterSpacing: -0.01,
          ),
        ),
      ),
    );
  }
}

// ── _GlassDropdown ────────────────────────────────────────────

class _GlassDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _GlassDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: P.borderSoft(context), width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.inter(fontSize: 13, color: inkDim),
          ),
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.expand_more_rounded, size: 18, color: inkDim),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ink,
          ),
          dropdownColor:
              isDark ? const Color(0xFF16161F) : const Color(0xFFF5F4F0),
          borderRadius: BorderRadius.circular(14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── _SheetButton (inline / small) ─────────────────────────────

class _SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SheetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark   = P.isDark(context);
    final enabled  = onTap != null;
    final inkDim   = P.inkDim(context);
    final dimmer   = P.inkDimmer(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? P.border(context) : P.borderSoft(context),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? inkDim : dimmer,
            letterSpacing: -0.01,
          ),
        ),
      ),
    );
  }
}

// ── _ApplyButton (full-width) ─────────────────────────────────

class _ApplyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ApplyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);
    final ink    = P.ink(context);
    final acc    = P.accent(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(28) : acc.withAlpha(28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(56) : acc.withAlpha(80),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ink,
            letterSpacing: -0.01,
          ),
        ),
      ),
    );
  }
}
