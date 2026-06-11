import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';

/// Minimal TextField styled to match the Minaret auth aesthetic.
class AuthFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isObscure;
  final TextInputType? keyboardType;
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  const AuthFormField({
    super.key,
    required this.label,
    required this.controller,
    required this.isObscure,
    required this.textPrimary,
    required this.textSecondary,
    this.keyboardType,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onSubmitted: onSubmitted,
      cursorColor: MinaretTheme.gold,
      cursorWidth: 1.2,
      style: GoogleFonts.lato(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: GoogleFonts.lato(
          fontSize: 13,
          color: textSecondary.withOpacity(0.7),
        ),
      ),
    );
  }
}

/// Small uppercase letter-spaced text link used throughout the auth flow.
class AuthTextLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool muted;
  final bool accent;

  const AuthTextLink({
    super.key,
    required this.label,
    this.onTap,
    this.muted = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white70 : MinaretTheme.slate;
    final color = accent
        ? MinaretTheme.gold
        : muted
            ? base.withOpacity(0.5)
            : base;
    final locale = Localizations.localeOf(context).languageCode;
    final shouldUpperCase = locale != 'ar' && locale != 'ur';

    return GestureDetector(
      onTap: onTap,
      child: Text(
        shouldUpperCase ? label.toUpperCase() : label,
        style: GoogleFonts.montserrat(
          fontSize: 8.5,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Section label with consistent spacing and typography.
class AuthSectionLabel extends StatelessWidget {
  final String text;
  const AuthSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final label = (locale == 'ar' || locale == 'ur') ? text : text.toUpperCase();
    return Text(label, style: MinaretTheme.label);
  }
}

/// Inline error message bar.
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: GoogleFonts.lato(
          fontSize: 11,
          color: Colors.redAccent,
          height: 1.5,
        ),
      ),
    );
  }
}
