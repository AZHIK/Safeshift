import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/cards/glass_card.dart';
import '../../providers/ride_provider.dart';
import '../widgets/ride_sheet.dart';
import '../widgets/shiny_map_view.dart';

/// Bolt-style single-screen: map fills the screen, everything else
/// (search, vehicles, quote, searching, tracking, done) lives in one
/// draggable glass sheet. No more /booking -> /quote -> /matching pushes.
class RideScreen extends ConsumerStatefulWidget {
  const RideScreen({super.key});

  @override
  ConsumerState<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends ConsumerState<RideScreen> {
  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(rideProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Full-screen shiny map.
          Positioned.fill(child: ShinyMapView(state: ride)),

          // 2. Top floating bar: avatar + SafeShift + notifications.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: AppColors.glowShadow,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'AZ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: GlassCard(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        radius: 999,
                        child: Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: AppColors.primaryDark,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'safeshift',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Spacer(),
                            Text(
                              'Dar es Salaam',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RoundIcon(
                      icon: Icons.notifications_none_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Map side controls — pinned near the top so the sheet
          // and bottom nav can never cover them.
          Positioned(
            right: 16,
            top: 132,
            child: Column(
              children: [
                _RoundIcon(icon: Icons.my_location_rounded, onTap: () {}),
                const SizedBox(height: 10),
                _RoundIcon(
                  icon: Icons.swap_vert_rounded,
                  onTap: () => ref.read(rideProvider.notifier).swap(),
                ),
              ],
            ),
          ),

          // 4. Draggable glass sheet — the whole funnel lives here.
          // No explicit controller: lets Flutter own the sheet lifecycle
          // and avoids "controller is already attached" crashes on rebuilds.
          DraggableScrollableSheet(
            initialChildSize: 0.52,
            minChildSize: 0.32,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.32, 0.52, 0.92],
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 1.2,
                ),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x334E5E73),
                    blurRadius: 40,
                    offset: Offset(0, -12),
                  ),
                ],
              ),
              child: RideSheetBody(scrollController: scrollController),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.92),
    shape: const CircleBorder(),
    elevation: 6,
    shadowColor: const Color(0x334E5E73),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    ),
  );
}
