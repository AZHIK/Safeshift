// Terms/Privacy links still need final document URLs.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safeshift_shared/safeshift_shared.dart' show GoogleSignInButton;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../widgets/phone_input_field.dart';

/// Sign-in: phone number + SMS OTP, or Google.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const String _brand = 'SafeShift Driver';

  late final TextEditingController _controller;
  String _digits = '';
  bool _googlePending = false;

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

  /// Nine digits after +255 that match Tanzania's mobile numbering plan.
  bool get _isValid =>
      _digits.length == 9 && Validators.isValidPhone('+255$_digits');

  bool get _showInvalid => _digits.length == 9 && !_isValid;

  Future<void> _send() async {
    if (!_isValid || ref.read(authProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    try {
      await ref.read(authProvider.notifier).sendOtp(_digits);
      if (mounted) context.push('/otp');
    } on Failure catch (e) {
      if (mounted) AppSnackbar.showError(context, e.message);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (ref.read(authProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _googlePending = true);
    try {
      // Completes in the browser; the router moves on once the session lands.
      await ref.read(authProvider.notifier).signInWithGoogle();
    } on Failure catch (e) {
      if (mounted) AppSnackbar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _googlePending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final muted = context.colors.onSurfaceVariant;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSizes.xl),
                    Text(
                      _brand,
                      style: TextStyles.body.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xxl),
                    Text(
                      'Enter your phone number',
                      style: TextStyles.headline.copyWith(
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      "We'll text you a 6-digit code to sign in.",
                      style: TextStyles.body.copyWith(color: muted),
                    ),
                    const SizedBox(height: AppSizes.xl),
                    PhoneInputField(
                      controller: _controller,
                      autofocus: _digits.isEmpty,
                      hasError: _showInvalid,
                      onChanged: (raw) => setState(() => _digits = raw),
                      onSubmitted: _send,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    SizedBox(
                      height: 18,
                      child: _showInvalid
                          ? Text(
                              'Enter a valid Tanzanian mobile number',
                              style: TextStyles.caption.copyWith(
                                color: context.colors.error,
                              ),
                            )
                          : null,
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSizes.lg),
                    FilledButton(
                      onPressed: _isValid && !isLoading ? _send : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadius,
                          ),
                        ),
                        textStyle: TextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: isLoading && !_googlePending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.onPrimary,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                    const SizedBox(height: AppSizes.lg),
                    const _OrDivider(),
                    const SizedBox(height: AppSizes.lg),
                    GoogleSignInButton(
                      isLoading: _googlePending,
                      onPressed: isLoading ? null : _signInWithGoogle,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    const _TermsText(),
                    const SizedBox(height: AppSizes.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Divider(height: 1, color: context.colors.outlineVariant),
    );
    return Row(
      children: <Widget>[
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Text(
            'or',
            style: TextStyles.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

class _TermsText extends StatefulWidget {
  const _TermsText();

  @override
  State<_TermsText> createState() => _TermsTextState();
}

class _TermsTextState extends State<_TermsText> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = _showNotice;
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = _showNotice;

  void _showNotice() {
    AppSnackbar.showInfo(
      context,
      'Terms and privacy pages are not available yet',
    );
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyles.caption.copyWith(
      color: context.colors.onSurfaceVariant,
      height: 1.5,
    );
    final linkStyle = style.copyWith(
      color: context.colors.onSurface,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(text: 'Terms', style: linkStyle, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacy,
          ),
          const TextSpan(text: '. SMS rates may apply.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
