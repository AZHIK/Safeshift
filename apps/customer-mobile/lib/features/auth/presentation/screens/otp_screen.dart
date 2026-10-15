// TODO: add paste-from-SMS autofill (sms_autofill) and haptic feedback in a
// later sprint. Mock OTP UI only — any 6-digit code is accepted.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/inputs/otp_boxes.dart';
import '../../providers/auth_provider.dart';
import '../widgets/phone_input_field.dart';

/// Mock OTP verification screen with 6 digit boxes and a resend timer.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const int _codeLength = 6;
  static const int _resendSeconds = 45;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _timer;
  Timer? _autoSubmit;
  String _code = '';
  int _secondsLeft = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0 && mounted) {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoSubmit?.cancel();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onCodeChanged(String value) {
    _autoSubmit?.cancel();
    setState(() => _code = value);
  }

  void _onCodeCompleted(String value) {
    _autoSubmit?.cancel();
    if (value.length == _codeLength) {
      _autoSubmit = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _verify(_code);
        }
      });
    }
  }

  Future<void> _verify(String value) async {
    if (value.length != _codeLength) {
      return;
    }
    if (ref.read(authProvider).isLoading) {
      return;
    }
    try {
      await ref.read(authProvider.notifier).verifyOtp(value);
      if (mounted) {
        context.go('/home');
      }
    } on ValidationFailure catch (e) {
      _autoSubmit?.cancel();
      _controller.clear();
      if (mounted) {
        setState(() => _code = '');
        AppSnackbar.showError(context, e.message);
        _focusNode.requestFocus();
      }
    }
  }

  void _resend() {
    setState(() => _secondsLeft = _resendSeconds);
    AppSnackbar.showInfo(context, 'OTP resent (mock)');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final phoneLabel = authState.phoneNumber != null
        ? formatPhoneDisplay(authState.phoneNumber!)
        : 'your number';
    final isComplete = _code.length == _codeLength;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: AppSizes.md),
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_chat_read_outlined,
                            size: 34,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),
                      const Text(
                        'Enter verification code',
                        textAlign: TextAlign.center,
                        style: TextStyles.headline,
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        'We sent a 6-digit code to $phoneLabel',
                        textAlign: TextAlign.center,
                        style: TextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Change number',
                          textAlign: TextAlign.center,
                          style: TextStyles.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.xl),
                      OtpBoxes(
                        controller: _controller,
                        focusNode: _focusNode,
                        length: _codeLength,
                        onChanged: _onCodeChanged,
                        onCompleted: _onCodeCompleted,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      Center(
                        child: _secondsLeft > 0
                            ? Text(
                                'Resend code in ${_secondsLeft}s',
                                style: TextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : GestureDetector(
                                onTap: _resend,
                                child: Text(
                                  'Resend code',
                                  style: TextStyles.body.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                      const Spacer(),
                      const SizedBox(height: AppSizes.lg),
                      SizedBox(
                        height: AppSizes.buttonHeight,
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Verify',
                          isLoading: authState.isLoading,
                          onPressed: isComplete && !authState.isLoading
                              ? () => _verify(_code)
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        'Demo build — any 6-digit code works',
                        textAlign: TextAlign.center,
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
