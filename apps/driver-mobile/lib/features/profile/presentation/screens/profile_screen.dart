import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

/// Pushed route: driver profile with links to vehicle/documents/ratings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(driverProfileStateProvider);
    if (driver == null) {
      // Should rarely be visible (router forces /complete-profile), but
      // handle it gracefully instead of crashing on null.
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 64, color: AppColors.textDisabled),
              const SizedBox(height: AppSizes.md),
              const Text(
                'No profile yet',
                textAlign: TextAlign.center,
                style: TextStyles.headline,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                'Complete your profile to start driving.',
                textAlign: TextAlign.center,
                style: TextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.md),
              FilledButton.icon(
                onPressed: () => context.go('/complete-profile'),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Complete profile'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          InfoCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    driver.initials,
                    style: TextStyles.headline.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              driver.fullName,
                              style: TextStyles.title.copyWith(fontSize: 16),
                            ),
                          ),
                          if (driver.verified)
                            const Tooltip(
                              message: 'Verified driver',
                              child: Icon(
                                Icons.verified_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFFFB300),
                          ),
                          Text(
                            ' ${driver.rating.toStringAsFixed(1)} · ${driver.completedTrips} trips',
                            style: TextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        driver.zone,
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          const _SectionTitle('Driver'),
          _Tile(
            icon: Icons.phone_outlined,
            label: driver.phone,
            onTap: () => AppSnackbar.showInfo(context, 'Phone (mock)'),
          ),
          _Tile(
            icon: Icons.local_shipping_outlined,
            label: 'Vehicle',
            onTap: () => context.push('/vehicle'),
          ),
          _Tile(
            icon: Icons.badge_outlined,
            label: 'Documents',
            onTap: () => context.push('/documents'),
          ),
          _Tile(
            icon: Icons.star_outline_rounded,
            label: 'Ratings',
            onTap: () => context.push('/ratings'),
          ),
          const SizedBox(height: AppSizes.sm),
          const _SectionTitle('Support'),
          _Tile(
            icon: Icons.help_outline_rounded,
            label: 'Help Center',
            onTap: () => AppSnackbar.showInfo(context, 'Help Center (mock)'),
          ),
          _Tile(
            icon: Icons.headset_mic_outlined,
            label: 'Contact Support',
            onTap: () =>
                AppSnackbar.showInfo(context, 'Contact Support (mock)'),
          ),
          _Tile(
            icon: Icons.description_outlined,
            label: 'Terms & Privacy',
            onTap: () =>
                AppSnackbar.showInfo(context, 'Terms & Privacy (mock)'),
          ),
          const SizedBox(height: AppSizes.sm),
          const _SectionTitle('About'),
          const _TileStatic(label: 'App version', value: 'v1.0.0 (mock)'),
          const SizedBox(height: AppSizes.lg),
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text(
                    'You will need to sign in again to drive.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).signOut();
                ref.read(driverProfileStateProvider.notifier).clearProfile();
                if (context.mounted) context.go('/login');
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log Out'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label,
        style: TextStyles.title.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: TextStyles.title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _TileStatic extends StatelessWidget {
  const _TileStatic({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: TextStyles.title),
        trailing: Text(value, style: TextStyles.caption),
      ),
    );
  }
}
