// TODO: add variants (secondary, danger, sizes) during the mock UI phase.
import 'package:flutter/material.dart';

import '../../constants/app_sizes.dart';
import '../../theme/text_styles.dart';

/// Reusable primary button: full width, rounded, bold label.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF287FC6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          minimumSize: const Size(0, AppSizes.buttonHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: TextStyles.button,
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
