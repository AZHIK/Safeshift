import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../theme/text_styles.dart';

class OtpBoxes extends StatefulWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.length = 6,
    this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final int length;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool get _ownsFocusNode => widget.focusNode == null;

  @override
  void dispose() {
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Column(
      children: <Widget>[
        SizedBox(
          width: 1,
          height: 1,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            showCursor: false,
            enableInteractiveSelection: false,
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              widget.onChanged?.call(value);
              if (value.length == widget.length) widget.onCompleted(value);
              setState(() {});
            },
          ),
        ),
        GestureDetector(
          onTap: _focusNode.requestFocus,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: <Widget>[
              for (var i = 0; i < widget.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSizes.sm),
                Expanded(child: _OtpBox(digit: i < code.length ? code[i] : '')),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit});
  final String digit;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: digit.isNotEmpty
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider, width: 1),
    ),
    child: Text(
      digit,
      style: TextStyles.title.copyWith(
        color: AppColors.textPrimary,
        fontSize: 19,
      ),
    ),
  );
}
