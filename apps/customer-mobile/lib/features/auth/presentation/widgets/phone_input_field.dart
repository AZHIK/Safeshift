// TODO: add country-code picker and error-text support when the Driver app
// reuses this field. Mock UI phase version: fixed +255 prefix only.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';

/// Groups raw digits as "712 345 678" (3-3-3).
String formatPhoneGroups(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 6) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Full display form: "+255 712 345 678".
String formatPhoneDisplay(String digits) {
  return '+255 ${formatPhoneGroups(digits)}';
}

/// Reusable Tanzanian phone number field with a fixed +255 prefix.
/// Exposes raw digits (no spaces, no prefix) via [onChanged].
class PhoneInputField extends StatelessWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      borderSide: const BorderSide(color: AppColors.divider),
    );
    return SizedBox(
      height: AppSizes.inputHeight,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.phone,
        inputFormatters: <TextInputFormatter>[_PhoneGroupsFormatter()],
        style: TextStyles.title.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: '712 345 678',
          hintStyle: TextStyles.title.copyWith(color: AppColors.textDisabled),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: AppSizes.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '+255',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: TextStyles.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 64,
            maxWidth: 64,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: AppSizes.sm,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
        onChanged: (value) {
          onChanged?.call(value.replaceAll(RegExp(r'\D'), ''));
        },
      ),
    );
  }
}

/// Keeps at most 9 digits and formats them as "712 345 678" while typing.
class _PhoneGroupsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }
    final formatted = formatPhoneGroups(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
