// Planned: build the OTP digit boxes with auto-focus in the mock UI phase.
// Placeholder widget only.
import 'package:flutter/material.dart';

class OtpInput extends StatelessWidget {
  const OtpInput({super.key, this.onCompleted});

  final void Function(String)? onCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('Delivery code entry coming soon'),
    );
  }
}
