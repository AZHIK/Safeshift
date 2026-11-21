import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';

/// Large animated online/offline toggle (Bolt-style).
/// The thumb position and color indicate availability.
class OnlineToggle extends StatelessWidget {
  const OnlineToggle({super.key, required this.isOnline, required this.onTap});

  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? context.colors.secondary : context.colors.outline;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 64,
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: context.colors.secondary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: isOnline
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isOnline
                      ? context.colors.onSecondary
                      : context.colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline
                      ? Icons.bolt_rounded
                      : Icons.power_settings_new_rounded,
                  size: 17,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "You're online" : "You're offline",
                  style: TextStyles.title.copyWith(fontSize: 15),
                ),
                Text(
                  isOnline ? 'Looking for jobs…' : 'Go online to receive jobs',
                  style: TextStyles.body.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
