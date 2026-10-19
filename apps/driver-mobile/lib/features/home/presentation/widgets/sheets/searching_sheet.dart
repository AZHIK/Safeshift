import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../providers/home_provider.dart';
import '../online_toggle.dart';
import 'sheet_handle.dart';

/// Searching sheet: online toggle + pulsing "searching" indicator.
class SearchingSheet extends ConsumerWidget {
  const SearchingSheet({super.key});

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
            const _PulsingDot(),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Searching for jobs nearby…',
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

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_controller),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppColors.onlineGreen,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
