import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/app_spacing.dart';
import '../../../core/input_validator.dart';
import '../../../core/locale_text.dart';
import '../../../core/theme.dart';
import '../../../services/system_config_service.dart';
import '../../../widgets/premium_button.dart';
import '../notifiers/auth_notifier.dart';
import '../screens/imam_verification_screen.dart';
import '../services/verification_service.dart';
import 'auth_form_widgets.dart';

/// Two-step signup form (email+city → role+details+password).
///
/// Step 1 collects email and city.
/// Step 2 shows role selector; if imam is chosen it navigates to
/// [ImamVerificationScreen] to collect and OCR-verify documents before
/// returning here for the password and final submit.
class SignupForm extends StatefulWidget {
  /// Called when the form is ready to create the account.
  final Future<void> Function({
    required String email,
    required String password,
    required String displayName,
    required String city,
  }) onSubmitCommon;

  final Future<void> Function({
    required String email,
    required String password,
    required String displayName,
    required String city,
    required ImamRegistrationData imamData,
  }) onSubmitImam;

  final VoidCallback onSwitchToLogin;
  final bool isLoading;
  final String? errorMessage;

  const SignupForm({
    super.key,
    required this.onSubmitCommon,
    required this.onSubmitImam,
    required this.onSwitchToLogin,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<SignupForm> createState() => _SignupFormState();
}

enum _RegStep { details, setup }

class _SignupFormState extends State<SignupForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _cityController = TextEditingController();

  _RegStep _step = _RegStep.details;
  String _role = 'common';
  ImamRegistrationData? _imamData;
  String? _localError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => _isDark ? Colors.white70 : MinaretTheme.slate;
  Color get _lineColor => _isDark ? Colors.white24 : MinaretTheme.dividerColor;

  // ── Step 1 validation ─────────────────────────────────────────────────────

  void _proceedToSetup() {
    final globalSettings =
        context.read<GlobalSettings?>();
    if (globalSettings != null && !globalSettings.allowNewRegistrations) {
      setState(() => _localError = context.localText(
            en: 'New registrations are currently disabled.',
            ar: 'التسجيل الجديد معطل حاليا.',
            ur: 'نئی رجسٹریشن فی الحال معطل ہے۔',
            ru: 'Регистрация новых пользователей отключена.',
          ));
      return;
    }

    final emailCheck = InputValidator.validateEmail(_emailController.text);
    if (!emailCheck.isValid) {
      setState(() => _localError = emailCheck.errorMessage);
      return;
    }

    if (_cityController.text.trim().isEmpty) {
      setState(() => _localError = context.localText(
            en: 'Please enter your city',
            ar: 'يرجى إدخال مدينتك',
            ur: 'براہ کرم اپنا شہر درج کریں',
            ru: 'Введите ваш город',
          ));
      return;
    }

    setState(() {
      _localError = null;
      _step = _RegStep.setup;
    });
  }

  // ── Step 2: navigate to imam verification ────────────────────────────────

  Future<void> _openImamVerification() async {
    final result = await Navigator.push<ImamRegistrationData?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImamVerificationScreen(
          displayName: _displayNameController.text.trim(),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _imamData = result);
    }
  }

  // ── Step 2 submit ─────────────────────────────────────────────────────────

  void _submit() {
    final nameCheck = InputValidator.validateName(_displayNameController.text);
    if (!nameCheck.isValid) {
      setState(() => _localError = nameCheck.errorMessage);
      return;
    }

    final passwordCheck =
        InputValidator.validatePassword(_passwordController.text);
    if (!passwordCheck.isValid) {
      setState(() => _localError = passwordCheck.errorMessage);
      return;
    }

    if (_role == 'imam') {
      if (_imamData == null) {
        setState(() => _localError = context.localText(
              en: 'Please complete imam document verification first.',
              ar: 'يرجى إكمال التحقق من وثائق الإمام أولاً.',
              ur: 'براہ کرم پہلے امام دستاویز کی تصدیق مکمل کریں۔',
              ru: 'Сначала пройдите проверку документов имама.',
            ));
        return;
      }
      if (_imamData!.verificationResult is VerificationFailure) {
        setState(() => _localError = context.localText(
              en: 'Documents do not match. Please re-upload correct documents.',
              ar: 'المستندات غير متطابقة. يرجى إعادة التحميل.',
              ur: 'دستاویزات میل نہیں کھاتیں۔ براہ کرم درست دستاویزات دوبارہ اپلوڈ کریں۔',
              ru: 'Документы не совпадают. Загрузите корректные документы.',
            ));
        return;
      }
      setState(() => _localError = null);
      widget.onSubmitImam(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
        city: _cityController.text.trim(),
        imamData: _imamData!,
      );
      return;
    }

    setState(() => _localError = null);
    widget.onSubmitCommon(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _displayNameController.text.trim(),
      city: _cityController.text.trim(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final displayError = _localError ?? widget.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_step == _RegStep.details) ..._buildDetailsStep(displayError),
        if (_step == _RegStep.setup) ..._buildSetupStep(displayError),
      ],
    );
  }

  List<Widget> _buildDetailsStep(String? displayError) => [
        AuthFormField(
          label: context.localText(
              en: 'Email',
              ar: 'البريد الإلكتروني',
              ur: 'ای میل',
              ru: 'Email'),
          controller: _emailController,
          isObscure: false,
          keyboardType: TextInputType.emailAddress,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
        const SizedBox(height: 36),
        AuthFormField(
          label: context.localText(
              en: 'City', ar: 'المدينة', ur: 'شہر', ru: 'Город'),
          controller: _cityController,
          isObscure: false,
          textCapitalization: TextCapitalization.words,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
        if (displayError != null) AuthErrorBanner(displayError),
        const SizedBox(height: 50),
        PremiumButton(
          text: context.localText(
              en: 'Continue',
              ar: 'متابعة',
              ur: 'جاری رکھیں',
              ru: 'Продолжить'),
          onPressed: _proceedToSetup,
          type: ButtonType.primary,
          borderRadius: 0,
        ),
        const SizedBox(height: 16),
        Center(
          child: AuthTextLink(
            label: context.localText(
              en: 'Already have an account?',
              ar: 'لديك حساب بالفعل؟',
              ur: 'پہلے سے اکاؤنٹ ہے؟',
              ru: 'Уже есть аккаунт?',
            ),
            onTap: widget.onSwitchToLogin,
          ),
        ),
      ];

  List<Widget> _buildSetupStep(String? displayError) => [
        AuthSectionLabel(context.localText(
            en: 'Your Name',
            ar: 'اسمك',
            ur: 'آپ کا نام',
            ru: 'Ваше имя')),
        const SizedBox(height: 16),
        AuthFormField(
          label: context.localText(
              en: 'Display Name',
              ar: 'الاسم الظاهر',
              ur: 'ظاہری نام',
              ru: 'Отображаемое имя'),
          controller: _displayNameController,
          isObscure: false,
          textCapitalization: TextCapitalization.words,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
        const SizedBox(height: 28),
        AuthSectionLabel(context.localText(
            en: 'Designation',
            ar: 'الدور',
            ur: 'عہدہ',
            ru: 'Роль')),
        const SizedBox(height: 16),
        _RoleSelector(
          selected: _role,
          lineColor: _lineColor,
          textSecondary: _textSecondary,
          onChanged: (role) => setState(() {
            _role = role;
            _imamData = null;
          }),
        ),
        if (_role == 'imam') ...[
          const SizedBox(height: 24),
          _ImamDocumentTile(
            imamData: _imamData,
            onTap: _openImamVerification,
            isDark: _isDark,
            textSecondary: _textSecondary,
          ),
        ],
        const SizedBox(height: 28),
        AuthSectionLabel(context.localText(
            en: 'Set Password',
            ar: 'تعيين كلمة المرور',
            ur: 'پاس ورڈ سیٹ کریں',
            ru: 'Задайте пароль')),
        const SizedBox(height: 16),
        AuthFormField(
          label: context.localText(
              en: 'Password',
              ar: 'كلمة المرور',
              ur: 'پاس ورڈ',
              ru: 'Пароль'),
          controller: _passwordController,
          isObscure: true,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
        if (displayError != null) AuthErrorBanner(displayError),
        const SizedBox(height: 50),
        PremiumButton(
          text: context.localText(
              en: 'Create Account',
              ar: 'إنشاء حساب',
              ur: 'اکاؤنٹ بنائیں',
              ru: 'Создать аккаунт'),
          onPressed: widget.isLoading ? null : _submit,
          type: ButtonType.primary,
          isLoading: widget.isLoading,
          borderRadius: 0,
        ),
        const SizedBox(height: 16),
        Center(
          child: AuthTextLink(
            label: context.localText(
              en: 'Back',
              ar: 'رجوع',
              ur: 'واپس',
              ru: 'Назад',
            ),
            onTap: () => setState(() {
              _step = _RegStep.details;
              _localError = null;
            }),
            muted: true,
          ),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Role selector
// ─────────────────────────────────────────────────────────────────────────────

class _RoleSelector extends StatelessWidget {
  final String selected;
  final Color lineColor;
  final Color textSecondary;
  final ValueChanged<String> onChanged;

  const _RoleSelector({
    required this.selected,
    required this.lineColor,
    required this.textSecondary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoleButton(
          label: context.localText(
              en: 'Community Member',
              ar: 'عضو مجتمع',
              ur: 'کمیونٹی ممبر',
              ru: 'Прихожанин'),
          value: 'common',
          groupValue: selected,
          lineColor: lineColor,
          textSecondary: textSecondary,
          onTap: () => onChanged('common'),
        ),
        const SizedBox(width: 12),
        _RoleButton(
          label: context.localText(
              en: 'Imam', ar: 'إمام', ur: 'امام', ru: 'Имам'),
          value: 'imam',
          groupValue: selected,
          lineColor: lineColor,
          textSecondary: textSecondary,
          onTap: () => onChanged('imam'),
        ),
      ],
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final Color lineColor;
  final Color textSecondary;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.lineColor,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding:
              const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? MinaretTheme.emerald : Colors.transparent,
            border: Border.all(
              width: 1.5,
              color: isSelected ? MinaretTheme.emerald : lineColor,
            ),
          ),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 8.5,
                letterSpacing: 2,
                color:
                    isSelected ? Colors.white : textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Imam document status tile (shown in signup form after verification)
// ─────────────────────────────────────────────────────────────────────────────

class _ImamDocumentTile extends StatelessWidget {
  final ImamRegistrationData? imamData;
  final VoidCallback onTap;
  final bool isDark;
  final Color textSecondary;

  const _ImamDocumentTile({
    required this.imamData,
    required this.onTap,
    required this.isDark,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    if (imamData == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
                color: MinaretTheme.gold.withOpacity(0.4), width: 0.8),
            color: MinaretTheme.gold.withOpacity(0.04),
          ),
          child: Row(
            children: [
              Icon(Icons.upload_file_outlined,
                  size: 20, color: MinaretTheme.gold.withOpacity(0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.localText(
                    en: 'Upload & verify identification documents',
                    ar: 'تحميل ووثيقة تعريف',
                    ur: 'شناختی دستاویزات اپلوڈ اور تصدیق کریں',
                    ru: 'Загрузить и проверить документы',
                  ),
                  style: GoogleFonts.montserrat(
                    fontSize: 8.5,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 12, color: MinaretTheme.gold.withOpacity(0.5)),
            ],
          ),
        ),
      );
    }

    final result = imamData!.verificationResult;
    final statusColor = switch (result) {
      VerificationSuccess() => MinaretTheme.emerald,
      VerificationPending() => MinaretTheme.gold,
      VerificationFailure() => Colors.redAccent,
    };
    final statusIcon = switch (result) {
      VerificationSuccess() => Icons.verified_outlined,
      VerificationPending() => Icons.info_outline,
      VerificationFailure() => Icons.cancel_outlined,
    };
    final statusText = switch (result) {
      VerificationSuccess(:final nameMatchConfidence) => context.localText(
          en: 'Verified — $nameMatchConfidence% confidence',
          ar: 'تم التحقق — $nameMatchConfidence٪',
          ur: 'تصدیق شدہ — $nameMatchConfidence٪',
          ru: 'Подтверждено — $nameMatchConfidence%',
        ),
      VerificationPending() => context.localText(
          en: 'Saved for manual review — you may proceed',
          ar: 'محفوظ للمراجعة — يمكنك المتابعة',
          ur: 'دستی جائزے کے لیے محفوظ — آگے بڑھیں',
          ru: 'Сохранено на проверку — можете продолжить',
        ),
      VerificationFailure() => context.localText(
          en: 'Documents do not match — tap to re-upload',
          ar: 'المستندات غير متطابقة — انقر لإعادة التحميل',
          ur: 'دستاویزات میل نہیں کھاتیں — دوبارہ اپلوڈ کریں',
          ru: 'Документы не совпадают — нажмите для повторной загрузки',
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.06),
          border:
              Border.all(color: statusColor.withOpacity(0.35), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(statusIcon, size: 18, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                statusText,
                style: GoogleFonts.montserrat(
                  fontSize: 8.5,
                  color: statusColor,
                  letterSpacing: 0.5,
                  height: 1.5,
                ),
              ),
            ),
            Icon(Icons.edit_outlined,
                size: 14, color: statusColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
