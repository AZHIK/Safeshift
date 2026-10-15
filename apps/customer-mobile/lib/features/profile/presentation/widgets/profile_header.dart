import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../domain/entities/profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile, required this.onEdit});
  final Profile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initials = profile.fullName
        .split(' ')
        .take(2)
        .map((name) => name.isEmpty ? '' : name[0])
        .join()
        .toUpperCase();
    final phoneDigits = profile.phone.replaceAll(RegExp(r'\D'), '');
    final localDigits = phoneDigits.startsWith('255')
        ? phoneDigits.substring(3)
        : phoneDigits;
    final phoneLabel = localDigits.length == 9
        ? '+255 ${localDigits.substring(0, 3)} ${localDigits.substring(3, 6)} ${localDigits.substring(6)}'
        : profile.phone;
    return InfoCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: TextStyles.title.copyWith(
                color: AppColors.primaryDark,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.fullName, style: TextStyles.title),
                const SizedBox(height: 3),
                Text(
                  phoneLabel,
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Edit Profile')),
        ],
      ),
    );
  }
}
