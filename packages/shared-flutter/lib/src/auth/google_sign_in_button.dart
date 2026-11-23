import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Google's official multicolour "G" mark (Sign in with Google branding).
const String _googleLogoSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
    '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
    '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
    '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
    '</svg>';

/// The Google "G" logo at [size] logical pixels.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    _googleLogoSvg,
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

/// "Continue with Google" button following Google's branding guidelines:
/// the unmodified colour logo, a neutral fill with a 1px outline, and the
/// prescribed light/dark colours. Adapts to the ambient theme brightness.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
    this.height = 52,
    this.borderRadius = 12,
  });

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final double height;
  final double borderRadius;

  // Google branding palette.
  static const Color _lightFill = Color(0xFFFFFFFF);
  static const Color _lightStroke = Color(0xFF747775);
  static const Color _lightText = Color(0xFF1F1F1F);
  static const Color _darkFill = Color(0xFF131314);
  static const Color _darkStroke = Color(0xFF8E918F);
  static const Color _darkText = Color(0xFFE3E3E3);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null && !isLoading;
    final text = dark ? _darkText : _lightText;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        // Google asks for a lighter, still-recognisable disabled state.
        opacity: enabled || isLoading ? 1 : 0.38,
        duration: const Duration(milliseconds: 150),
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size.fromHeight(height)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16),
            ),
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(
              dark ? _darkFill : _lightFill,
            ),
            foregroundColor: WidgetStatePropertyAll(text),
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? text.withValues(alpha: 0.12)
                  : states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                  ? text.withValues(alpha: 0.08)
                  : null,
            ),
            side: WidgetStatePropertyAll(
              BorderSide(color: dark ? _darkStroke : _lightStroke),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox.square(
                dimension: 20,
                child: isLoading
                    ? CircularProgressIndicator(strokeWidth: 2, color: text)
                    : const GoogleLogo(),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // Roboto Medium per the guidelines; platform fallback on iOS.
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.25,
                    color: text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
