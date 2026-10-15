import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/driver_avatar_card.dart';
import '../../../../core/widgets/loading/loading_radar.dart';
import '../../providers/matching_provider.dart';

class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(matchingProvider.notifier).findDriver();
    });
  }

  Future<void> _cancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text('Your driver search will be stopped.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep searching'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (shouldCancel == true && mounted) {
      ref.read(matchingProvider.notifier).reset();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final matching = ref.watch(matchingProvider);
    final driver = matching.driver;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: driver == null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const LoadingRadar(),
                            const SizedBox(height: AppSizes.lg),
                            Text(
                              'Finding nearby drivers…',
                              textAlign: TextAlign.center,
                              style: TextStyles.title.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: AppSizes.sm),
                            Text(
                              'Looking for verified vehicles within 5 km',
                              textAlign: TextAlign.center,
                              style: TextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: AppColors.success,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: AppSizes.md),
                            Text(
                              'Driver found',
                              style: TextStyles.headline.copyWith(fontSize: 21),
                            ),
                            const SizedBox(height: AppSizes.md),
                            DriverAvatarCard(driver: driver),
                            Text(
                              'Arriving in 7 min',
                              style: TextStyles.title.copyWith(
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              'Your driver is on the way to your pickup location.',
                              textAlign: TextAlign.center,
                              style: TextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                AppSizes.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PrimaryButton(
                    label: 'Track Driver',
                    onPressed: driver == null
                        ? null
                        : () => context.push('/tracking'),
                  ),
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('Cancel Request'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
