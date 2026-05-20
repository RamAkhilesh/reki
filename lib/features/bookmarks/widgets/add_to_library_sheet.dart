// ─────────────────────────────────────────────────────────────
// lib/features/bookmarks/widgets/add_to_library_sheet.dart
//
// Mihon-style compact tracker card shown when the user
// bookmarks a title from search, discovery, or edits an
// existing bookmark via long-press.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // Status label adapted to media type.
  String _statusLabel(String s) => switch (s) {
        BookmarkStatus.wantToWatch =>
          _isReadType ? 'Plan to read' : 'Plan to watch',
        BookmarkStatus.watching => _isReadType ? 'Reading' : 'Watching',
        BookmarkStatus.completed => 'Completed',
        BookmarkStatus.onHold => 'On hold',
        BookmarkStatus.dropped => 'Dropped',
        _ => s,
      };

  // ── Sub-sheet openers ────────────────────────────────────────

  Future<void> _openStatusSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusSubSheet(
        current: _status,
        isReadType: _isReadType,
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
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ──────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // ── Header ──────────────────────────────────
            _buildHeader(cs),
            const Divider(height: 1),

            // ── Tracking row (Status | Progress | Score) ─
            _buildTrackingRow(),
            const Divider(height: 1),

            // ── Dates row ────────────────────────────────
            _buildDatesRow(),
            const Divider(height: 1),

            // ── Action buttons ───────────────────────────
            _buildActions(cs),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Text(
        _mediaItem.title,
        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
          const VerticalDivider(width: 1),
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
          const VerticalDivider(width: 1),
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
          const VerticalDivider(width: 1),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditing ? 'Save changes' : 'Add to library',
                        ),
                ),
              ),
            ],
          ),
          if (_isEditing && widget.onDelete != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: cs.error,
                ),
                label: Text(
                  'Remove from Library',
                  style: TextStyle(color: cs.error),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
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
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: filled && enabled ? cs.primary : cs.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled && enabled
              ? cs.onPrimary
              : cs.onSurfaceVariant.withAlpha(enabled ? 255 : 80),
        ),
      ),
    );
  }
}

// ── Status sub-sheet ──────────────────────────────────────────

class _StatusSubSheet extends StatelessWidget {
  final String current;
  final bool isReadType;
  final String Function(String) statusLabel;

  const _StatusSubSheet({
    required this.current,
    required this.isReadType,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Status',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          for (final s in BookmarkStatus.all)
            ListTile(
              title: Text(statusLabel(s)),
              trailing: current == s
                  ? Icon(Icons.check_rounded, color: cs.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(s),
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withAlpha(100),
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
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Text(
                  _selected == 0 ? '–' : '$_selected / 10',
                  key: ValueKey(_selected),
                  style: tt.titleMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
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
                    color: cs.primaryContainer,
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
                          style: tt.titleLarge?.copyWith(
                            color: isSelected
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Confirm'),
            ),
          ),

          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
