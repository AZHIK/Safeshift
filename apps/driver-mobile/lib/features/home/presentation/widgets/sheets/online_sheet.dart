import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../providers/home_provider.dart';
import '../online_toggle.dart';
import 'sheet_handle.dart';

/// Brief online-idle sheet shown during the 2s transition.
class OnlineSheet extends ConsumerWidget {
  const OnlineSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          isOnline: true,
          onTap: () => ref.read(homeProvider.notifier).goOffline(),
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Going online…',
              style: TextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
