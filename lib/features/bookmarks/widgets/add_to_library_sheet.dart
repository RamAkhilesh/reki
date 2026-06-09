// ─────────────────────────────────────────────────────────────
// lib/features/bookmarks/widgets/add_to_library_sheet.dart
//
// Mihon-style compact tracker card shown when the user
// bookmarks a title from search, discovery, or edits an
// existing bookmark via long-press.
// ─────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/prism_tokens.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/media_item.dart';
import '../providers/bookmark_providers.dart';

Future<void> showAddToLibrarySheet(
  BuildContext context,
  MediaItem item,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(100),
    builder: (_) => AddToLibrarySheet(mediaItem: item),
  );
}

// ── Main sheet ────────────────────────────────────────────────

class AddToLibrarySheet extends ConsumerStatefulWidget {
  final MediaItem? mediaItem;
  final Bookmark? existingBookmark;
  final Future<void> Function()? onDelete;

  const AddToLibrarySheet({
    super.key,
    this.mediaItem,
    this.existingBookmark,
    this.onDelete,
  }) : assert(
          mediaItem != null || existingBookmark != null,
          'Provide either mediaItem or existingBookmark',
        );

  @override
  ConsumerState<AddToLibrarySheet> createState() => _AddToLibrarySheetState();
}

class _AddToLibrarySheetState extends ConsumerState<AddToLibrarySheet> {
  late String _status;
  late int _progress;
  int? _score;
  DateTime? _startDate;
  DateTime? _finishDate;
  bool _saving = false;

  static const _noProgressTypes = {'movie', 'game'};
  static const _readTypes = {'manga', 'book'};

  MediaItem get _mediaItem =>
      widget.existingBookmark?.mediaItem ?? widget.mediaItem!;

  bool get _isEditing => widget.existingBookmark != null;

  bool get _hasProgress => !_noProgressTypes.contains(_mediaItem.mediaType);

  bool get _isReadType => _readTypes.contains(_mediaItem.mediaType);

  String get _progressLabel => _isReadType ? 'Chapter' : 'Episode';

  int? get _total => _mediaItem.episodeCount;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final b = widget.existingBookmark!;
      _status = b.status;
      final total = _mediaItem.episodeCount;
      // For completed entries always show the max count.
      if (b.status == BookmarkStatus.completed && total != null) {
        _progress = total;
      } else {
        _progress = b.progressCount ?? 0;
      }
      _score = b.rating;
      _startDate = b.startDate;
      _finishDate = b.endDate;
    } else {
      _status = BookmarkStatus.wantToWatch;
      _progress = 0;
    }
  }

  String _statusLabel(String s) => BookmarkStatus.label(s);

  // ── Sub-sheet openers ────────────────────────────────────────

  Future<void> _openStatusSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusSubSheet(
        current: _status,
        statusLabel: _statusLabel,
      ),
    );
    if (picked != null) {
      setState(() {
        _status = picked;
        if (picked == BookmarkStatus.watching) {
          _startDate ??= DateTime.now();
        }
        if (picked == BookmarkStatus.completed) {
          _finishDate ??= DateTime.now();
          _startDate ??= DateTime.now();
          final total = _total;
          if (total != null) _progress = total;
        }
      });
    }
  }

  Future<void> _openScoreSheet() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScoreSubSheet(current: _score ?? 0),
    );
    // 0 = cleared, 1-10 = score, null = dismissed
    if (picked != null) setState(() => _score = picked == 0 ? null : picked);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startDate : _finishDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _finishDate = picked;
      }
    });
  }

  // ── Progress helpers ─────────────────────────────────────────

  void _increment() {
    final next = _progress + 1;
    final total = _total;
    setState(() {
      _progress = next;
      if (total != null && next >= total) {
        _status = BookmarkStatus.completed;
        _finishDate ??= DateTime.now();
        _startDate ??= DateTime.now();
      }
    });
  }

  void _decrement() {
    if (_progress > 0) setState(() => _progress--);
  }

  // ── Save ─────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notifier = ref.read(bookmarkListProvider.notifier);
      if (_isEditing) {
        await notifier.editBookmark(
          widget.existingBookmark!.id,
          status: _status,
          rating: _score,
          startDate: _startDate,
          endDate: _finishDate,
          progressCount: _hasProgress ? _progress : null,
        );
      } else {
        await notifier.add(
          _mediaItem,
          _status,
          rating: _score,
          startDate: _startDate,
          endDate: _finishDate,
          progressCount: _hasProgress ? _progress : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_mediaItem.title} added to library'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await widget.onDelete!();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: P.bg(context).withAlpha(240),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: P.border(context), width: 0.5),
              ),
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ──────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: P.isDark(context)
                        ? Colors.white.withAlpha(56)
                        : Colors.black.withAlpha(46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // ── Header ──────────────────────────────────
            _buildHeader(cs),
            Divider(height: 1, color: P.border(context)),

            // ── Tracking row (Status | Progress | Score) ─
            _buildTrackingRow(),
            Divider(height: 1, color: P.border(context)),

            // ── Dates row ────────────────────────────────
            _buildDatesRow(),
            Divider(height: 1, color: P.border(context)),

            // ── Action buttons ───────────────────────────
            _buildActions(cs),
          ],
        ),
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Text(
        _mediaItem.title,
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: P.ink(context),
          letterSpacing: -0.02,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Tracking row ─────────────────────────────────────────────

  Widget _buildTrackingRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TrackingCell(
              value: _statusLabel(_status),
              label: 'Status',
              onTap: _openStatusSheet,
            ),
          ),
          VerticalDivider(width: 1, color: P.border(context)),
          Expanded(
            child: _hasProgress
                ? _ProgressCell(
                    count: _progress,
                    label: _progressLabel,
                    total: _total,
                    onDecrement: _progress > 0 ? _decrement : null,
                    onIncrement: _increment,
                  )
                : const SizedBox.shrink(),
          ),
          VerticalDivider(width: 1, color: P.border(context)),
          Expanded(
            child: _TrackingCell(
              value: _score != null ? '$_score / 10' : '–',
              label: 'Score',
              onTap: _openScoreSheet,
            ),
          ),
        ],
      ),
    );
  }

  // ── Dates row ────────────────────────────────────────────────

  Widget _buildDatesRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TrackingCell(
              value: _formatDate(_startDate),
              label: 'Start date',
              onTap: () => _pickDate(isStart: true),
            ),
          ),
          VerticalDivider(width: 1, color: P.border(context)),
          Expanded(
            child: _TrackingCell(
              value: _formatDate(_finishDate),
              label: 'Finish date',
              onTap: () => _pickDate(isStart: false),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────

  Widget _buildActions(ColorScheme cs) {
    final isDark = P.isDark(context);
    final acc    = P.accent(context);
    final ink    = P.ink(context);
    final inkDim = P.inkDim(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Cancel
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _saving ? null : () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withAlpha(12)
                            : Colors.black.withAlpha(8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: P.border(context), width: 0.5),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: inkDim,
                          letterSpacing: -0.01,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Save
              Expanded(
                flex: 2,
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _saving ? null : _save,
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(28) : acc.withAlpha(28),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white.withAlpha(56) : acc.withAlpha(80),
                          width: 0.5,
                        ),
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.white : acc,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Save changes' : 'Add to library',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ink,
                                letterSpacing: -0.01,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isEditing && widget.onDelete != null) ...[
            const SizedBox(height: 8),
            Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _saving ? null : _delete,
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: P.statusDropped.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: P.statusDropped.withAlpha(64), width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 16, color: P.statusDropped),
                      const SizedBox(width: 6),
                      Text(
                        'Remove from Library',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: P.statusDropped,
                          letterSpacing: -0.01,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Date formatter ────────────────────────────────────────────

  static String _formatDate(DateTime? d) {
    if (d == null) return '–';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Tracking cell ─────────────────────────────────────────────

class _TrackingCell extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _TrackingCell({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: P.ink(context),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: P.inkDimmer(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Progress cell ─────────────────────────────────────────────

class _ProgressCell extends StatelessWidget {
  final int count;
  final String label;
  final int? total;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _ProgressCell({
    required this.count,
    required this.label,
    this.total,
    this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: onDecrement,
                filled: false,
              ),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: P.ink(context),
                ),
                textAlign: TextAlign.center,
              ),
              _StepButton(
                icon: Icons.add,
                onTap: onIncrement,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            total != null ? '$label ($count/$total)' : label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: P.inkDimmer(context),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Step button ───────────────────────────────────────────────

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  const _StepButton({
    required this.icon,
    this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: filled && enabled ? P.accent(context) : P.glass(context),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 16,
            color: filled && enabled
                ? Colors.white
                : P.inkDim(context).withAlpha(enabled ? 255 : 80),
          ),
        ),
      ),
    );
  }
}

// ── Status sub-sheet ──────────────────────────────────────────

class _StatusSubSheet extends StatelessWidget {
  final String current;
  final String Function(String) statusLabel;

  const _StatusSubSheet({
    required this.current,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(56)
                          : Colors.black.withAlpha(46),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Status',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: P.inkDimmer(context),
                      letterSpacing: 0.06 * 11,
                    ),
                  ),
                ),
              ),
              for (final s in BookmarkStatus.all)
                ListTile(
                  title: Text(statusLabel(s), style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w500, color: P.ink(context),
                  )),
                  trailing: current == s
                      ? Icon(Icons.check_rounded, color: P.accent(context))
                      : null,
                  onTap: () => Navigator.of(context).pop(s),
                ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Score sub-sheet ───────────────────────────────────────────
// Mihon-style vertical scroll wheel picker (0 = unrated, 1–10 = score).

class _ScoreSubSheet extends StatefulWidget {
  final int current; // 0 = unrated, 1–10 = score

  const _ScoreSubSheet({required this.current});

  @override
  State<_ScoreSubSheet> createState() => _ScoreSubSheetState();
}

class _ScoreSubSheetState extends State<_ScoreSubSheet> {
  late final FixedExtentScrollController _controller;
  late int _selected;

  static const _itemExtent = 48.0;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _controller = FixedExtentScrollController(initialItem: _selected);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = P.isDark(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: P.bg(context).withAlpha(240),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: P.border(context), width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(56)
                        : Colors.black.withAlpha(46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title row + live score display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Score',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: P.ink(context),
                      letterSpacing: -0.015,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Text(
                      _selected == 0 ? '–' : '$_selected / 10',
                      key: ValueKey(_selected),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: P.accent(context),
                        letterSpacing: -0.015,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Scroll wheel
              SizedBox(
                height: _itemExtent * 5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Selection highlight bar
                    Container(
                      height: _itemExtent,
                      decoration: BoxDecoration(
                        color: P.accent(context).withAlpha(isDark ? 48 : 68),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    ListWheelScrollView.useDelegate(
                      controller: _controller,
                      itemExtent: _itemExtent,
                      onSelectedItemChanged: (i) =>
                          setState(() => _selected = i),
                      physics: const FixedExtentScrollPhysics(),
                      perspective: 0.003,
                      diameterRatio: 2.8,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 11, // 0 = unrated, 1–10
                        builder: (context, i) {
                          final isSelected = i == _selected;
                          return Center(
                            child: Text(
                              i == 0 ? '–' : '$i',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? P.ink(context)
                                    : P.inkDimmer(context),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Confirm button
              Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(_selected),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: double.infinity,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(28)
                          : P.accent(context).withAlpha(28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(56)
                            : P.accent(context).withAlpha(80),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      'Confirm',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: P.ink(context),
                        letterSpacing: -0.01,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
        ),
      ),
    );
  }
}
