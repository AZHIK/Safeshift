// TODO: add loading/error/empty variants during the mock UI phase.
import 'package:flutter/material.dart';

/// Reusable flat card with a quiet outline and consistent app spacing.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.padding = 16});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}
