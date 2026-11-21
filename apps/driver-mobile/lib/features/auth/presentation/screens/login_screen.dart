// Terms/Privacy links still need final document URLs and logo artwork.
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
import '../../../../core/utils/validators.dart';
import '../widgets/phone_input_field.dart';

/// Phone entry screen: enter a +255 phone number and request an OTP.
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

  /// Nine digits after +255 that match Tanzania's mobile numbering plan
  /// (Vodacom, Airtel, Tigo/Yas, Halotel, TTCL, Zantel prefixes).
  bool get _isValid =>
      _digits.length == 9 && Validators.isValidPhone('+255$_digits');

  Future<void> _send() async {
    if (ref.read(authProvider).isLoading) {
      return;
    }
    try {
      await ref.read(authProvider.notifier).sendOtp(_digits);
      if (mounted) {
        context.push('/otp');
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
      backgroundColor: context.colors.surface,
      body: Stack(
        children: [
          // Soft brand tint up top + faint orbs — matches onboarding/ride.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colors.primaryContainer,
                    context.colors.surface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.5],
                ),
              ),
            ),
          ),
          const Positioned(
            left: -60,
            top: -40,
            child: _TintOrb(size: 200, color: Color(0x222E9BFF)),
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
                                  color: context.colors.outlineVariant,
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
                            'SafeShift Driver',
                            textAlign: TextAlign.center,
                            style: TextStyles.headline.copyWith(fontSize: 19),
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            "Sign in to drive with SafeShift",
                            textAlign: TextAlign.center,
                            style: TextStyles.body.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          Text(
                            'Enter your phone number',
                            style: TextStyles.title.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            "We'll send you a verification code",
                            style: TextStyles.body.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: context.colors.outlineVariant,
                              ),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Column(
                              children: [
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
                                          ? context.colors.secondary
                                          : context.colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _isValid
                                            ? 'Valid Tanzanian number — ready to send'
                                            : _digits.length < 9
                                            ? '${9 - _digits.length} more digit${9 - _digits.length == 1 ? '' : 's'} needed'
                                            : 'This is not a Tanzanian mobile number',
                                        style: TextStyles.caption.copyWith(
                                          color: _isValid
                                              ? context.colors.secondary
                                              : context.colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: AppSizes.lg),
                          SizedBox(
                            height: AppSizes.buttonHeight,
                            width: double.infinity,
                            child: PrimaryButton(
                              label: 'Send OTP',
                              icon: Icons.bolt_rounded,
                              isLoading: authState.isLoading,
                              onPressed: _isValid && !authState.isLoading
                                  ? _send
                                  : null,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: authState.isLoading
                                ? null
                                : () async {
                                    final notifier = ref.read(
                                      authProvider.notifier,
                                    );
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
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(
                                double.infinity,
                                AppSizes.buttonHeight,
                              ),
                              backgroundColor: context.colors.primary,
                              foregroundColor: context.colors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Text(
                            'Standard SMS rates may apply',
                            textAlign: TextAlign.center,
                            style: TextStyles.caption.copyWith(
                              color: context.colors.onSurfaceVariant,
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

class _TintOrb extends StatelessWidget {
  const _TintOrb({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    final style = TextStyles.caption.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final linkStyle = TextStyles.caption.copyWith(
      color: context.colors.primary,
    );
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
