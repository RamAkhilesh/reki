// ─────────────────────────────────────────────────────────────
// lib/features/library/widgets/sort_bottom_sheet.dart
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_providers.dart';

class SortBottomSheet extends ConsumerWidget {
  const SortBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sortOrderProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Sort by',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final order in SortOrder.values)
              ListTile(
                title: Text(order.label),
                trailing: current == order
                    ? Icon(Icons.check_rounded, color: cs.primary)
                    : null,
                onTap: () {
                  ref.read(sortOrderProvider.notifier).state = order;
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
