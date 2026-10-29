import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../providers/auth_provider.dart';

/// Phase 8 placeholder for drivers who have a profile but no drivers row yet.
///
/// Phase 9 replaces this with vehicle, licence, and document onboarding.
/// Keeping the gate here prevents an unregistered driver from reaching
/// /home, which would otherwise call driver-only RPCs and fail.
class DriverOnboardingPlaceholderScreen extends ConsumerWidget {
  const DriverOnboardingPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final name = auth.currentUser?.fullName.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Text(
                name == null || name.isEmpty
                    ? 'Driver onboarding'
                    : 'Welcome, $name',
                style: TextStyles.headline,
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                'Your phone number is verified. Driver onboarding — vehicle, '
                'licence, and document checks — arrives in the next phase.',
                style: TextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.md),
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_clock_outlined,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        'Home, trips, and earnings unlock after approval.',
                        style: TextStyles.body,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Sign out',
                icon: Icons.logout_rounded,
                isLoading: auth.isLoading,
                onPressed: () => ref.read(authProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
