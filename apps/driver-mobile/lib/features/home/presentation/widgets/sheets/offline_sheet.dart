import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_sizes.dart';
import '../../../providers/home_provider.dart';
import '../online_toggle.dart';
import 'sheet_handle.dart';

String _tzs(num amount) => 'TZS ${NumberFormat('#,##0').format(amount)}';

/// Offline sheet: toggle + today's stats row.
class OfflineSheet extends ConsumerWidget {
  const OfflineSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.lg,
      ),
      children: [
        const SheetHandle(),
        OnlineToggle(
          isOnline: false,
          onTap: () => _goOnline(context, ref),
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            SheetStat(
              value: '${home.completedToday}',
              label: "Today's trips",
            ),
            SheetStat(
              value: _tzs(home.todayEarnings),
              label: 'Earnings',
            ),
            SheetStat(
              value: '${(home.acceptanceRate * 100).round()}%',
              label: 'Acceptance',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _goOnline(BuildContext context, WidgetRef ref) async {
    final asked = ref.read(homePermissionsProvider);
    if (!asked) {
      final location = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow location access?'),
          content: const Text(
            'SafeShift Driver needs your location to match you with nearby jobs (mock).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      if (location != true) return;
      if (!context.mounted) return;
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow notifications?'),
          content: const Text(
            'Get notified instantly about new job requests (mock).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      ref.read(homePermissionsProvider.notifier).markAsked();
    }
    ref.read(homeProvider.notifier).goOnline();
  }
}
