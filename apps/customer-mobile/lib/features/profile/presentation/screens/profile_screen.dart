import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../widgets/profile_header.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in with your phone number.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (shouldSignOut == true) {
      ref.read(authProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    // Bottom inset clears the translucent bottom nav (extendBody:true).
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 28;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          bottomInset,
        ),
        children: <Widget>[
          ProfileHeader(
            profile: profile,
            onEdit: () => AppSnackbar.showInfo(context, 'Edit Profile — TODO'),
          ),
          const SizedBox(height: AppSizes.lg),
          _ProfileSection(
            title: 'Account',
            items: <_ProfileItem>[
              _ProfileItem(
                icon: Icons.payments_outlined,
                title: 'Payment Methods',
                onTap: () =>
                    AppSnackbar.showInfo(context, 'Payment Methods — TODO'),
              ),
              _ProfileItem(
                icon: Icons.bookmark_border_rounded,
                title: 'Saved Addresses',
                onTap: () =>
                    AppSnackbar.showInfo(context, 'Saved Addresses — TODO'),
              ),
              _ProfileItem(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                onTap: () =>
                    AppSnackbar.showInfo(context, 'Notifications — TODO'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          _ProfileSection(
            title: 'Support',
            items: <_ProfileItem>[
              _ProfileItem(
                icon: Icons.help_outline_rounded,
                title: 'Help Center',
                onTap: () =>
                    AppSnackbar.showInfo(context, 'Help Center — TODO'),
              ),
              _ProfileItem(
                icon: Icons.support_agent_rounded,
                title: 'Contact Support',
                onTap: () =>
                    AppSnackbar.showInfo(context, 'Contact Support — TODO'),
              ),
              _ProfileItem(
                icon: Icons.description_outlined,
                title: 'Terms & Privacy',
                onTap: () =>
                    AppSnackbar.showInfo(context, 'Terms & Privacy — TODO'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          const _ProfileSection(
            title: 'About',
            items: <_ProfileItem>[
              _ProfileItem(
                icon: Icons.info_outline_rounded,
                title: 'App Version',
                trailing: 'v1.0.0 (mock)',
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          SizedBox(
            height: AppSizes.buttonHeight,
            child: FilledButton.icon(
              onPressed: () => _signOut(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileItem {
  const _ProfileItem({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.items});
  final String title;
  final List<_ProfileItem> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: AppSizes.xs),
        child: Text(title, style: TextStyles.title),
      ),
      Card(
        child: Column(
          children: <Widget>[
            for (var i = 0; i < items.length; i++) ...<Widget>[
              ListTile(
                leading: Icon(items[i].icon, color: AppColors.primaryDark),
                title: Text(
                  items[i].title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: items[i].trailing == null
                    ? const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      )
                    : Text(
                        items[i].trailing!,
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                onTap: items[i].onTap,
                dense: true,
              ),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 12,
                  endIndent: 12,
                  color: AppColors.divider.withValues(alpha: 0.7),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}
