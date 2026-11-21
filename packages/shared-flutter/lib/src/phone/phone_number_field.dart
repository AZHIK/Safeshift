import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'phone_validation.dart';

/// Phone input that validates against the country's numbering plan.
///
/// Accepts local numbers (read as Tanzanian) or any country with a `+`
/// prefix; the detected country's flag is shown in front. The error appears
/// once the person has typed enough to judge, not on the first digit.
/// [onChanged] reports the [PhoneCheck]; use `check.e164` to save.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    this.label = 'Phone number',
    this.hint = '0712 345 678 or +254…',
    this.kind = PhoneKind.mobile,
    this.required = true,
    this.onChanged,
    this.textInputAction,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final PhoneKind kind;

  /// When false an empty field is valid (optional phone).
  final bool required;
  final ValueChanged<PhoneCheck>? onChanged;
  final TextInputAction? textInputAction;
  final bool autofocus;

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  late PhoneCheck _check = checkPhone(
    widget.controller.text,
    kind: widget.kind,
  );
  bool _touched = false;

  void _onChanged(String value) {
    final check = checkPhone(value, kind: widget.kind);
    setState(() {
      _check = check;
      // Judge only once a full-length number could have been typed.
      _touched = _touched || value.replaceAll(RegExp(r'\D'), '').length >= 9;
    });
    widget.onChanged?.call(check);
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.controller.text.trim().isEmpty;
    final showError =
        _touched && !_check.isValid && !(empty && !widget.required);
    final flag = _check.flag;
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.telephoneNumber],
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s()-]')),
        LengthLimitingTextInputFormatter(20),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: flag == null
            ? const Icon(Icons.phone_outlined)
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(flag, style: const TextStyle(fontSize: 20)),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        suffixIcon: _check.isValid
            ? Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.secondary,
              )
            : null,
        errorText: showError ? _check.error : null,
        errorMaxLines: 2,
      ),
      onChanged: _onChanged,
      onEditingComplete: () {
        setState(() => _touched = true);
        FocusScope.of(context).nextFocus();
      },
    );
  }
}
