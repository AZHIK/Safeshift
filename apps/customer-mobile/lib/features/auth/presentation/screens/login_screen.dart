// Terms/Privacy links still need final document URLs and logo artwork.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../widgets/phone_input_field.dart';

// Authentication mode selection
enum LoginMode { phone, email }

/// Login screen with phone and email OTP authentication options.
///
/// Phone is the default method. User can switch between modes using the
/// mode toggle buttons at the top.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.loginMode = LoginMode.phone,
  });

  final LoginMode loginMode;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _controller;
  String _digits = '';
  LoginMode _currentMode = LoginMode.phone;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.loginMode;
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
      if (_currentMode == LoginMode.phone) {
        await ref.read(authProvider.notifier).sendOtp(_digits);
      } else if (_currentMode == LoginMode.email) {
        final email = _controller.text.trim();
        await ref.read(authProvider.notifier).sendEmailOtp(email);
      }
      if (mounted) {
        context.go('/otp');
      }
    } on Failure catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEAF3FD), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5],
                ),
              ),
            ),
          ),
          Positioned(
            left: -60,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x222E9BFF),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: 20),
                          Center(
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(24),
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: AppColors.cardShadow,
                              ),
                              child: const Icon(
                                Icons.local_shipping_rounded,
                                size: 38,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          Text(
                            'safeshift',
                            textAlign: TextAlign.center,
                            style: TextStyles.headline.copyWith(fontSize: 19),
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            "Moving people's property safely",
                            textAlign: TextAlign.center,
                            style: TextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          // Mode toggle
                          _ModeToggle(
                            currentMode: _currentMode,
                            onModeChanged: (mode) {
                              setState(() => _currentMode = mode);
                            },
                          ),
                          const SizedBox(height: AppSizes.md),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.divider),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Column(
                              children: [
                                // Phone input section
                                if (_currentMode == LoginMode.phone) ...[
                                  PhoneInputField(
                                    controller: _controller,
                                    onChanged: (raw) =>
                                        setState(() => _digits = raw),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        _isValid
                                            ? Icons.check_circle_rounded
                                            : Icons.info_outline_rounded,
                                        size: 15,
                                        color: _isValid
                                            ? AppColors.success
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _isValid
                                              ? 'Valid Tanzanian number — ready to send'
                                              : '${9 - _digits.length} more digit${9 - _digits.length == 1 ? '' : 's'} needed',
                                          style: TextStyles.caption.copyWith(
                                            color: _isValid
                                                ? AppColors.success
                                                : AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ]
                                // Email input section
                                else ...[
                                  TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Email address',
                                      hintText: 'example@domain.com',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'We\'ll send a 6-digit code to your email',
                                    style: TextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed:
                                _isValid && !authState.isLoading ? _send : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity,
                                  AppSizes.buttonHeight),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                            ),
                            child: _currentMode == LoginMode.email
                                ? const Text(
                                    'Send OTP to Email',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : const Text(
                                        'Send OTP',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                          ),
                          ElevatedButton.icon(
                            onPressed: authState.isLoading
                                ? null
                                : () async {
                                      final notifier = ref.read(authProvider.notifier);
                                      await notifier.signInWithGoogle();
                                      if (!context.mounted) return;
                                      AppSnackbar.showInfo(
                                        context,
                                        'Opening Google sign‑in…',
                                      );
                                    },
                             icon: const Icon(Icons.gesture, size: 20),
                             label: const Text(
                               'Continue with Google',
                               style: TextStyle(
                                 color: Colors.white,
                                 fontWeight: FontWeight.w600,
                               ),
                             ),
                             style: ElevatedButton.styleFrom(
                               minimumSize: const Size(double.infinity,
                                   AppSizes.buttonHeight),
                               backgroundColor: AppColors.primary,
                               shape: RoundedRectangleBorder(
                                 borderRadius:
                                     BorderRadius.circular(20),
                               ),
                             ),
                           ),
                          const SizedBox(height: AppSizes.sm),
                          Text(
                            'Standard SMS rates may apply',
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
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.currentMode,
    required this.onModeChanged,
  });

  final LoginMode currentMode;
  final void Function(LoginMode) onModeChanged;

  @override
  Widget build(BuildContext context) {
    final isPhone = currentMode == LoginMode.phone;
    final isEmail = currentMode == LoginMode.email;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModeButton(
            label: 'Phone',
            isActive: isPhone,
            onTap: () => onModeChanged(LoginMode.phone),
          ),
          _ModeButton(label: 'Email', isActive: isEmail, onTap: () => onModeChanged(LoginMode.email)),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyles.caption.copyWith(
      color: isActive ? AppColors.primary : AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(label, style: style),
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
    void showTermsNotice() {
      AppSnackbar.showInfo(
        context,
        'Terms and privacy pages are not available yet',
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('By continuing, you agree to our ', style: style),
        GestureDetector(
          onTap: showTermsNotice,
          child: Text('Terms of Service', style: linkStyle),
        ),
        Text(' and ', style: style),
        GestureDetector(
          onTap: showTermsNotice,
          child: Text('Privacy Policy', style: linkStyle),
        ),
      ],
    );
  }

}