// TODO: wire the Terms/Privacy links to real documents and add final logo
// artwork in a later sprint. Mock login UI only — no backend calls.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../widgets/phone_input_field.dart';

/// Mock login screen: enter a +255 phone number, request an OTP.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _controller;
  String _digits = '';

  @override
  void initState() {
    super.initState();
    final saved = ref.read(authProvider).phoneNumber;
    _digits = saved ?? '';
    _controller = TextEditingController(
      text: saved != null ? formatPhoneGroups(saved) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => _digits.length == 9;

  Future<void> _send() async {
    if (ref.read(authProvider).isLoading) {
      return;
    }
    try {
      await ref.read(authProvider.notifier).sendOtp(_digits);
      if (mounted) {
        context.push('/otp');
      }
    } on ValidationFailure catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
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
                      const SizedBox(height: 28),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F4FD),
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: const Icon(
                            Icons.local_shipping_outlined,
                            size: 32,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.lg),
                      Text(
                        'SafeShift',
                        textAlign: TextAlign.center,
                        style: TextStyles.headline.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        "Moving people's property safely",
                        textAlign: TextAlign.center,
                        style: TextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Enter your phone number',
                        style: TextStyles.title.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        "We'll send you a verification code",
                        style: TextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      PhoneInputField(
                        controller: _controller,
                        onChanged: (raw) => setState(() => _digits = raw),
                      ),
                      const Spacer(),
                      const SizedBox(height: AppSizes.lg),
                      SizedBox(
                        height: AppSizes.buttonHeight,
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Send OTP',
                          isLoading: authState.isLoading,
                          onPressed: _isValid && !authState.isLoading
                              ? _send
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        'Demo build — any 9-digit number works',
                        textAlign: TextAlign.center,
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textDisabled,
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      const _TermsText(),
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

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    final style = TextStyles.caption.copyWith(color: AppColors.textSecondary);
    final linkStyle = TextStyles.caption.copyWith(color: AppColors.primary);
    void showTodo() {
      AppSnackbar.showInfo(context, 'Terms — TODO');
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('By continuing, you agree to our ', style: style),
        GestureDetector(
          onTap: showTodo,
          child: Text('Terms of Service', style: linkStyle),
        ),
        Text(' and ', style: style),
        GestureDetector(
          onTap: showTodo,
          child: Text('Privacy Policy', style: linkStyle),
        ),
      ],
    );
  }
}
