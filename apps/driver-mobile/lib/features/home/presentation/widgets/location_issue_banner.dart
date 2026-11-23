import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../domain/entities/home_state.dart';
import '../../providers/home_provider.dart';

/// Explains why location is unusable and offers the one action that fixes it.
class LocationIssueBanner extends ConsumerWidget {
  const LocationIssueBanner({
    super.key,
    required this.issue,
    required this.offline,
  });

  final LocationIssue issue;

  /// Offline: going online was blocked. Online/on a job: dispatch and live
  /// tracking are affected right now, so the wording is more urgent.
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, body, action) = switch (issue) {
      LocationIssue.serviceOff => (
        'Location is off',
        offline
            ? 'Turn on location to go online. Jobs are matched to nearby drivers.'
            : 'Customers can’t see where you are. Turn location back on.',
        'Turn on',
      ),
      LocationIssue.permissionDenied => (
        'Location access needed',
        'Allow location so SafeShift can match you with nearby jobs.',
        'Allow',
      ),
      LocationIssue.permissionBlocked => (
        'Location access is blocked',
        'Enable location for SafeShift Driver in Settings.',
        'Settings',
      ),
    };
    final notifier = ref.read(homeProvider.notifier);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: context.colors.surface,
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.location_off_outlined, color: context.colors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyles.body.copyWith(
                        color: context.colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyles.caption.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: notifier.fixLocation,
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: TextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(action),
              ),
              if (offline)
                IconButton(
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  onPressed: notifier.dismissLocationIssue,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
