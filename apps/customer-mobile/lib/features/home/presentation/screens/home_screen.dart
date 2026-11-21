import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MONDAY, 12 OCTOBER',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Karibu back!',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.colors.outlineVariant,
                          ),
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: context.colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _HeroCard(onBook: () => context.go('/home')),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your move',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      TextButton(
                        onPressed: () => context.push('/history'),
                        child: const Text('See history'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ActiveMove(onTap: () => context.push('/tracking')),
                  const SizedBox(height: 27),
                  Text(
                    'Quick access',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.local_shipping_outlined,
                          title: 'Book a move',
                          subtitle: 'Plan a pickup',
                          tint: context.colors.primaryContainer,
                          onTap: () => context.go('/home'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.location_on_outlined,
                          title: 'Track move',
                          subtitle: 'Live updates',
                          tint: context.colors.secondaryContainer,
                          onTap: () => context.push('/tracking'),
                        ),
                      ),
                    ],
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.colors.primaryContainer),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'MOVING MADE SIMPLE',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontSize: 9,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Text(
                'Your next move,\nmade easy.',
                style: TextStyle(
                  color: context.colors.onSurface,
                  fontSize: 19,
                  height: 28 / 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reliable transport for the things that matter.',
                style: TextStyle(
                  color: context.colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onBook,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Book a move'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            color: context.colors.primary,
          ),
        ),
      ],
    ),
  );
}

class _ActiveMove extends StatelessWidget {
  const _ActiveMove({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: context.colors.outlineVariant),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Household delivery',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SS-2048  ·  Today, 10:30 AM',
                        style: TextStyle(
                          color: context.colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Driver on the way',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'IN PROGRESS',
                    style: TextStyle(
                      fontSize: 8,
                      color: context.colors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: .68,
                minHeight: 5,
                backgroundColor: context.colors.surfaceContainerHighest,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: context.colors.outlineVariant),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: context.colors.primary),
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
