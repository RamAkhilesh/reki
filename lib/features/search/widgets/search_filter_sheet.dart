// ─────────────────────────────────────────────────────────────
// lib/features/search/widgets/search_filter_sheet.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

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
  late LibraryFilter _libraryFilter;
  String? _language;
  int _resetKey = 0;

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
    _libraryFilter = widget.initialFilters.libraryFilter;
    _language = widget.initialFilters.language;
  }

  bool get _isActive => SearchFilters(
        libraryFilter: _libraryFilter,
        language: _language,
      ).isActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final sectionLabelStyle = tt.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header row
          Row(
            children: [
              Text(
                'Filter',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _libraryFilter = LibraryFilter.all;
                  _language = null;
                  _resetKey++;
                }),
                child: const Text('Reset all'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Language ───────────────────────────────────────
          Text('LANGUAGE', style: sectionLabelStyle),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            key: ValueKey(_resetKey),
            initialValue: _language,
            decoration: InputDecoration(
              hintText: 'Any language',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withAlpha(80),
            ),
            icon: const Icon(Icons.expand_more_rounded),
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Any language'),
              ),
              for (final (code, label) in _languages)
                DropdownMenuItem(
                  value: code,
                  child: Text(label),
                ),
            ],
            onChanged: (v) => setState(() => _language = v),
          ),
          const SizedBox(height: 20),

          // ── Library status ─────────────────────────────────
          Text('LIBRARY STATUS', style: sectionLabelStyle),
          const SizedBox(height: 8),
          SegmentedButton<LibraryFilter>(
            segments: const [
              ButtonSegment(
                value: LibraryFilter.all,
                label: Text('All'),
              ),
              ButtonSegment(
                value: LibraryFilter.inLibrary,
                icon: Icon(Icons.bookmark_rounded, size: 15),
                label: Text('Saved'),
              ),
              ButtonSegment(
                value: LibraryFilter.notInLibrary,
                icon: Icon(Icons.bookmark_border_rounded, size: 15),
                label: Text('New'),
              ),
            ],
            selected: {_libraryFilter},
            onSelectionChanged: (v) =>
                setState(() => _libraryFilter = v.first),
          ),
          const SizedBox(height: 28),

          // ── Apply button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onApply(
                  SearchFilters(
                    libraryFilter: _libraryFilter,
                    language: _language,
                  ),
                );
                Navigator.of(context).pop();
              },
              child: Text(_isActive ? 'Apply filters' : 'Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
