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

/// Tanzanian phone number field with a fixed +255 prefix.
///
/// Outlined on all sides with a divider between the country code and the
/// number. The outline stays grey (thicker on focus) and turns error-coloured
/// when [hasError]. Exposes raw digits (no spaces, no prefix) via [onChanged].
class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.hasError = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final bool autofocus;
  final bool hasError;

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    // Grey in both states; focus is shown by the thicker stroke.
    final borderColor = widget.hasError
        ? context.colors.error
        : context.colors.outline;
    final borderWidth = focused || widget.hasError ? 1.5 : 1.0;
    final textStyle = TextStyles.title.copyWith(
      color: context.colors.onSurface,
      fontSize: 18,
      letterSpacing: 0.5,
    );

    return GestureDetector(
      // Tapping the +255 side still focuses the number.
      onTap: _focusNode.requestFocus,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Center(
                child: Text(
                  '+255',
                  style: textStyle.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: borderWidth,
              color: borderColor,
            ),
            Expanded(
              child: Center(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[
                    AutofillHints.telephoneNumberNational,
                  ],
                  inputFormatters: <TextInputFormatter>[
                    _PhoneGroupsFormatter(),
                  ],
                  style: textStyle,
                  cursorColor: context.colors.primary,
                  decoration: InputDecoration(
                    hintText: '712 345 678',
                    hintStyle: textStyle.copyWith(
                      color: context.colors.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                    ),
                  ),
                  onChanged: (value) {
                    widget.onChanged?.call(value.replaceAll(RegExp(r'\D'), ''));
                  },
                  onSubmitted: (_) => widget.onSubmitted?.call(),
                ),
              ),
            ),
          ],
        ),
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
    // People type the national form (0712...) or paste +255 712...; the
    // field holds only the 9 digits after +255.
    if (digits.length > 9 && digits.startsWith('255')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
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
