// Planned: render the active job from home state in the mock UI phase.
// Placeholder widget only.
import 'package:flutter/material.dart';

class ActiveJobCard extends StatelessWidget {
  const ActiveJobCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('No active job right now'),
    );
  }
}
