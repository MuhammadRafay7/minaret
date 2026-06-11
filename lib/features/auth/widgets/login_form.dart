import 'package:flutter/material.dart';

import '../../../core/input_validator.dart';
import '../../../core/locale_text.dart';
import '../../../core/theme.dart';
import '../../../widgets/premium_button.dart';
import 'auth_form_widgets.dart';

/// Stateful login form.
///
/// Validates email format and password presence locally before calling
/// [onSubmit]. The parent owns loading state and surfaced error messages.
class LoginForm extends StatefulWidget {
  final Future<void> Function(String email, String password) onSubmit;
  final Future<void> Function(String email) onForgotPassword;
  final VoidCallback onSwitchToSignup;
  final bool isLoading;
  final String? errorMessage;

  const LoginForm({
    super.key,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onSwitchToSignup,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => _isDark ? Colors.white70 : MinaretTheme.slate;

  void _submit() {
    final emailResult = InputValidator.validateEmail(_emailController.text);
    if (!emailResult.isValid) {
      setState(() => _localError = emailResult.errorMessage);
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _localError = context.localText(
            en: 'Password is required',
            ar: 'كلمة المرور مطلوبة',
            ur: 'پاس ورڈ ضروری ہے',
            ru: 'Требуется пароль',
          ));
      return;
    }
    setState(() => _localError = null);
    widget.onSubmit(_emailController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final displayError = _localError ?? widget.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthFormField(
          label: context.localText(
              en: 'Email', ar: 'البريد الإلكتروني', ur: 'ای میل', ru: 'Email'),
          controller: _emailController,
          isObscure: false,
          keyboardType: TextInputType.emailAddress,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
        const SizedBox(height: 36),
        AuthFormField(
          label: context.localText(
              en: 'Password', ar: 'كلمة المرور', ur: 'پاس ورڈ', ru: 'Пароль'),
          controller: _passwordController,
          isObscure: true,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          onSubmitted: (_) => _submit(),
        ),
        if (displayError != null) AuthErrorBanner(displayError),
        const SizedBox(height: 50),
        PremiumButton(
          text: context.localText(
              en: 'Sign In',
              ar: 'تسجيل الدخول',
              ur: 'سائن اِن',
              ru: 'Войти'),
          onPressed: widget.isLoading ? null : _submit,
          type: ButtonType.primary,
          isLoading: widget.isLoading,
          borderRadius: 0,
        ),
        const SizedBox(height: 20),
        Center(
          child: AuthTextLink(
            label: context.localText(
              en: 'Forgot password?',
              ar: 'نسيت كلمة المرور؟',
              ur: 'پاس ورڈ بھول گئے؟',
              ru: 'Забыли пароль?',
            ),
            onTap: widget.isLoading
                ? null
                : () =>
                    widget.onForgotPassword(_emailController.text.trim()),
            accent: true,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: AuthTextLink(
            label: context.localText(
              en: 'Create an account',
              ar: 'إنشاء حساب',
              ur: 'اکاؤنٹ بنائیں',
              ru: 'Создать аккаунт',
            ),
            onTap: widget.onSwitchToSignup,
          ),
        ),
      ],
    );
  }
}
