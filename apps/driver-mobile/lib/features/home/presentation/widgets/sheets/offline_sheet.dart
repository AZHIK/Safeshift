import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../auth/providers/auth_provider.dart';
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
    final auth = ref.watch(authProvider);
    final verified = auth.canGoOnline;
    final status = auth.driverVerificationStatus ?? 'pending';
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
        if (!verified) ...[
          Card(
            color: AppColors.warning.withValues(alpha: 0.1),
            child: ListTile(
              leading: const Icon(
                Icons.verified_user_outlined,
                color: AppColors.warning,
              ),
              title: Text(
                status == 'rejected'
                    ? 'Verification needs attention'
                    : 'Verification in review',
                style: TextStyles.title.copyWith(fontSize: 14),
              ),
              subtitle: Text(
                status == 'rejected'
                    ? 'Re-upload the requested documents to apply again.'
                    : 'You can go online after SafeShift approves your documents.',
                style: TextStyles.caption,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(
                status == 'rejected' ? '/documents' : '/verification',
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
        ],
        OnlineToggle(
          isOnline: false,
          onTap: () => _goOnline(context, ref),
        ),
        if (!verified) ...[
          const SizedBox(height: AppSizes.xs),
          Text(
            'Going online is locked until verification is complete.',
            textAlign: TextAlign.center,
            style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            SheetStat(value: '${home.completedToday}', label: "Today's trips"),
            SheetStat(value: _tzs(home.todayEarnings), label: 'Earnings'),
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
    if (!ref.read(authProvider).canGoOnline) {
      final status = ref.read(authProvider).driverVerificationStatus ?? 'pending';
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verification required'),
          content: Text(
            status == 'rejected'
                ? 'Your verification was rejected. Re-upload the requested documents before going online.'
                : 'SafeShift is still reviewing your documents. You can go online once approved.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final asked = ref.read(homePermissionsProvider);
    if (!asked) {
      final location = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow location access?'),
          content: const Text(
            'SafeShift Driver needs your location to match you with nearby jobs.',
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
          content: const Text('Get notified instantly about new job requests.'),
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
