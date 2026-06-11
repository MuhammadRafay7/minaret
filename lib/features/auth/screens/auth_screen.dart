import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/app_spacing.dart';
import '../../../core/locale_text.dart';
import '../../../core/theme.dart';
import '../../../widgets/atelier_layout.dart';
import '../../../widgets/premium_button.dart';
import '../../legal/privacy_policy_page.dart';
import '../../legal/terms_of_service_page.dart';
import '../../mosque/create_mosque_page.dart';
import '../../mosque/edit_mosque_page.dart';
import '../imam_profile_page.dart';
import '../notifiers/auth_notifier.dart';
import '../settings_page.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/login_form.dart';
import '../widgets/signup_form.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Root auth screen. Consumes [AuthNotifier] via [context.watch] and renders
/// the correct sub-view for the current state. Contains no Firebase calls —
/// all business logic is delegated to [AuthNotifier].
class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showingSignup = false;

  // Cached so the email-verification waiting screen can use them for
  // re-sign-in and resend without asking the user to re-type.
  String _lastEmail = '';
  String _lastPassword = '';

  // ── Post-login routing ────────────────────────────────────────────────────

  Future<void> _routeAfterLogin(AuthNotifier notifier) async {
    if (!mounted) return;
    final role = notifier.userRole ?? 'common';
    if (role == 'imam') {
      final uid = notifier.currentUser!.uid;
      final mosqueInfo = await _findImamMosque(uid);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => mosqueInfo != null
              ? EditMosquePage(
                  docId: mosqueInfo['id'] as String,
                  currentData: mosqueInfo['data'] as Map<String, dynamic>,
                )
              : const CreateMosquePage(),
        ),
      );
      return;
    }
    widget.onLoginSuccess();
  }

  Future<Map<String, dynamic>?> _findImamMosque(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('mosques')
          .where('adminUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return {'id': snap.docs.first.id, 'data': snap.docs.first.data()};
      }
    } catch (_) {}
    return null;
  }

  // ── Notifier delegates (passed into the forms) ────────────────────────────

  Future<void> _signIn(String email, String password) async {
    _lastEmail = email;
    _lastPassword = password;
    final notifier = context.read<AuthNotifier>();
    await notifier.signIn(email, password);
    if (!mounted) return;
    if (notifier.state == AuthState.authenticated) {
      await _routeAfterLogin(notifier);
    }
  }

  Future<void> _forgotPassword(String email) async {
    final notifier = context.read<AuthNotifier>();
    await notifier.resetPassword(email);
    if (!mounted) return;
    if (notifier.state != AuthState.error) {
      _showSnack(context.localText(
        en: 'Password reset email sent.',
        ar: 'تم إرسال رابط إعادة التعيين.',
        ur: 'پاس ورڈ ری سیٹ ای میل بھیج دی گئی۔',
        ru: 'Письмо для сброса пароля отправлено.',
      ));
    }
  }

  Future<void> _submitCommon({
    required String email,
    required String password,
    required String displayName,
    required String city,
  }) async {
    _lastEmail = email;
    _lastPassword = password;
    await context
        .read<AuthNotifier>()
        .signUp(email, password, displayName, city: city);
  }

  Future<void> _submitImam({
    required String email,
    required String password,
    required String displayName,
    required String city,
    required ImamRegistrationData imamData,
  }) async {
    _lastEmail = email;
    _lastPassword = password;
    await context.read<AuthNotifier>().signUpAsImam(
          email: email,
          password: password,
          displayName: displayName,
          city: city,
          imamData: imamData,
        );
  }

  Future<void> _checkEmailVerification() async {
    final notifier = context.read<AuthNotifier>();
    final verified =
        await notifier.checkEmailVerification(_lastEmail, _lastPassword);
    if (!mounted) return;
    if (verified) {
      await _routeAfterLogin(notifier);
    } else if (notifier.state != AuthState.error) {
      _showSnack(context.localText(
        en: 'Email not verified yet. Please check your inbox and click the link.',
        ar: 'لم يتم التوثيق بعد. يرجى فتح البريد الإلكتروني والنقر على الرابط.',
        ur: 'ابھی تصدیق نہیں ہوا۔ براہ کرم اپنا ای میل چیک کریں اور لنک پر کلک کریں۔',
        ru: 'Email ещё не подтверждён. Проверьте почту и перейдите по ссылке.',
      ));
    }
  }

  Future<void> _resendVerification() async {
    await context
        .read<AuthNotifier>()
        .resendVerificationEmail(_lastEmail, _lastPassword);
    if (!mounted) return;
    _showSnack(context.localText(
      en: 'Verification email resent.',
      ar: 'تمت إعادة الإرسال.',
      ur: 'دوبارہ بھیج دی گئی۔',
      ru: 'Письмо отправлено повторно.',
    ));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        margin: const EdgeInsets.all(AppSpacing.lg),
        content: Text(message),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AuthNotifier>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AtelierLayout(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeInOutQuart,
            switchOutCurve: Curves.easeInOutQuart,
            child: _buildForState(notifier),
          ),
        ),
      ),
    );
  }

  Widget _buildForState(AuthNotifier notifier) {
    switch (notifier.state) {
      case AuthState.authenticated:
        return _ProfileView(
          key: const ValueKey('profile'),
          email: notifier.currentUser?.email ?? '',
          role: notifier.userRole ?? 'common',
          onSignOut: () async {
            await notifier.signOut();
            if (mounted) setState(() => _showingSignup = false);
          },
        );

      case AuthState.awaitingEmailVerification:
        return _EmailVerificationWaiting(
          key: const ValueKey('email_verification'),
          email: _lastEmail,
          isChecking: notifier.isCheckingEmail,
          isResending: notifier.isResendingEmail,
          onCheck: _checkEmailVerification,
          onResend: _resendVerification,
          onBack: () {
            notifier.clearError();
            setState(() => _showingSignup = false);
          },
        );

      case AuthState.initial:
      case AuthState.unauthenticated:
      case AuthState.loading:
      case AuthState.error:
        return _buildFormView(notifier);
    }
  }

  Widget _buildFormView(AuthNotifier notifier) {
    final isLoading = notifier.state == AuthState.loading;
    final errorMessage =
        notifier.state == AuthState.error ? notifier.errorMessage : null;

    return SingleChildScrollView(
      key: ValueKey(_showingSignup ? 'signup_form' : 'login_form'),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthHeader(
            isSignup: _showingSignup,
            onSettings: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          const SizedBox(height: 20),
          const _BismillahDivider(),
          const SizedBox(height: 50),
          if (_showingSignup)
            SignupForm(
              onSubmitCommon: _submitCommon,
              onSubmitImam: _submitImam,
              onSwitchToLogin: () {
                notifier.clearError();
                setState(() => _showingSignup = false);
              },
              isLoading: isLoading,
              errorMessage: errorMessage,
            )
          else
            LoginForm(
              onSubmit: _signIn,
              onForgotPassword: _forgotPassword,
              onSwitchToSignup: () {
                notifier.clearError();
                setState(() => _showingSignup = true);
              },
              isLoading: isLoading,
              errorMessage: errorMessage,
            ),
          const SizedBox(height: 40),
          const _LegalLinks(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile view (shown when user is already signed in)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileView extends StatelessWidget {
  final String email;
  final String role;
  final VoidCallback onSignOut;

  const _ProfileView({
    super.key,
    required this.email,
    required this.role,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.localText(
                      en: 'PROFILE',
                      ar: 'الملف الشخصي',
                      ur: 'پروفائل',
                      ru: 'ПРОФИЛЬ',
                    ),
                    style: MinaretTheme.heading.copyWith(
                      fontSize: 32,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.localText(
                      en: 'Session active',
                      ar: 'الجلسة نشطة',
                      ur: 'سیشن فعال',
                      ru: 'Сессия активна',
                    ),
                    style: MinaretTheme.label,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
              icon: Icon(Icons.settings_outlined, color: MinaretTheme.gold),
              tooltip: 'Settings',
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _BismillahDivider(),
        const SizedBox(height: 60),
        Text(
          context.localText(
            en: 'IDENTIFIED AS',
            ar: 'مُعرَّف باسم',
            ur: 'شناخت',
            ru: 'ИДЕНТИФИЦИРОВАН КАК',
          ),
          style: MinaretTheme.detailHeader
              .copyWith(fontSize: 7.5, letterSpacing: 3),
        ),
        const SizedBox(height: 10),
        Text(
          email,
          style: GoogleFonts.lato(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 30),
        if (role == 'imam')
          Center(
            child: AuthTextLink(
              label: context.localText(
                en: 'Manage Personal Profile',
                ar: 'إدارة البيانات الشخصية',
                ur: 'ذاتی پروفائل کا انتظام',
                ru: 'Управление профилем',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImamProfilePage()),
              ),
              accent: true,
            ),
          ),
        const SizedBox(height: 80),
        PremiumButton(
          text: context.localText(
            en: 'End Session',
            ar: 'إنهاء الجلسة',
            ur: 'سیشن ختم کریں',
            ru: 'Завершить сессию',
          ),
          onPressed: onSignOut,
          type: ButtonType.primary,
          borderRadius: 0,
        ),
        const SizedBox(height: 40),
        const _LegalLinks(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Email verification waiting view
// ─────────────────────────────────────────────────────────────────────────────

class _EmailVerificationWaiting extends StatelessWidget {
  final String email;
  final bool isChecking;
  final bool isResending;
  final VoidCallback onCheck;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _EmailVerificationWaiting({
    super.key,
    required this.email,
    required this.isChecking,
    required this.isResending,
    required this.onCheck,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? Colors.white70 : MinaretTheme.slate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.localText(
            en: 'VERIFY',
            ar: 'تحقق',
            ur: 'تصدیق',
            ru: 'ПОДТВЕРДИТЬ',
          ),
          style: MinaretTheme.heading.copyWith(
            fontSize: 32,
            letterSpacing: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.localText(
            en: 'Your Email',
            ar: 'بريدك الإلكتروني',
            ur: 'آپ کا ای میل',
            ru: 'Ваш Email',
          ),
          style: MinaretTheme.label,
        ),
        const SizedBox(height: 50),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MinaretTheme.gold.withOpacity(0.06),
            border: Border.all(
              color: MinaretTheme.gold.withOpacity(0.25),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined,
                      color: MinaretTheme.gold, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.localText(
                        en: 'A confirmation link has been sent to:',
                        ar: 'تم إرسال رابط التأكيد إلى:',
                        ur: 'تصدیقی لنک یہاں بھیجا گیا:',
                        ru: 'Ссылка подтверждения отправлена на:',
                      ),
                      style: MinaretTheme.detailHeader
                          .copyWith(fontSize: 8, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  email,
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.localText(
            en: 'Open your email, click the verification link, then come back here and tap the button below.',
            ar: 'افتح بريدك الإلكتروني، انقر على رابط التحقق، ثم عد هنا واضغط على الزر.',
            ur: 'اپنا ای میل کھولیں، تصدیقی لنک پر کلک کریں، پھر واپس آئیں اور نیچے والا بٹن دبائیں۔',
            ru: 'Откройте почту, нажмите ссылку подтверждения, вернитесь сюда и нажмите кнопку ниже.',
          ),
          style: GoogleFonts.lato(
              fontSize: 12, color: textSecondary, height: 1.8),
        ),
        const SizedBox(height: 50),
        PremiumButton(
          text: isChecking
              ? context.localText(
                  en: 'Checking…',
                  ar: 'جارٍ التحقق…',
                  ur: 'چیک ہو رہا ہے…',
                  ru: 'Проверка…')
              : context.localText(
                  en: 'I have confirmed my email',
                  ar: 'لقد أكدت بريدي الإلكتروني',
                  ur: 'میں نے اپنا ای میل تصدیق کر لیا',
                  ru: 'Я подтвердил свой email'),
          onPressed: isChecking ? null : onCheck,
          type: ButtonType.primary,
          isLoading: isChecking,
          borderRadius: 0,
        ),
        const SizedBox(height: 20),
        Center(
          child: AuthTextLink(
            label: context.localText(
              en: 'Resend confirmation email',
              ar: 'إعادة إرسال',
              ur: 'دوبارہ بھیجیں',
              ru: 'Отправить снова',
            ),
            onTap: isResending ? null : onResend,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: AuthTextLink(
            label: context.localText(
              en: 'Back to sign in',
              ar: 'العودة لتسجيل الدخول',
              ur: 'واپس سائن اِن',
              ru: 'Назад ко входу',
            ),
            onTap: onBack,
            muted: true,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AuthHeader extends StatelessWidget {
  final bool isSignup;
  final VoidCallback onSettings;

  const _AuthHeader({required this.isSignup, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSignup
                    ? context.localText(
                        en: 'REGISTER',
                        ar: 'سجّل',
                        ur: 'رجسٹر',
                        ru: 'РЕГИСТРАЦИЯ')
                    : context.localText(
                        en: 'WELCOME',
                        ar: 'أهلاً',
                        ur: 'خوش آمدید',
                        ru: 'ДОБРО ПОЖАЛОВАТЬ'),
                style: MinaretTheme.heading.copyWith(
                  fontSize: 32,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSignup
                    ? context.localText(
                        en: 'Create your account',
                        ar: 'أنشئ حسابك',
                        ur: 'اپنا اکاؤنٹ بنائیں',
                        ru: 'Создайте аккаунт')
                    : context.localText(
                        en: 'Sign in to continue',
                        ar: 'سجّل دخولك للمتابعة',
                        ur: 'جاری رکھنے کے لیے سائن اِن کریں',
                        ru: 'Войдите, чтобы продолжить'),
                style: MinaretTheme.label,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, color: MinaretTheme.gold),
          tooltip: 'Settings',
        ),
      ],
    );
  }
}

class _BismillahDivider extends StatelessWidget {
  const _BismillahDivider();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ',
          style: GoogleFonts.amiri(
            fontSize: 16,
            color: MinaretTheme.gold,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: MinaretTheme.gold.withOpacity(0.25),
                thickness: 0.5,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '✦',
                style: TextStyle(
                  fontSize: 8,
                  color: MinaretTheme.gold.withOpacity(0.5),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: MinaretTheme.gold.withOpacity(0.25),
                thickness: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AuthTextLink(
          label: context.localText(
            en: 'Privacy',
            ar: 'الخصوصية',
            ur: 'رازداری',
            ru: 'ПРИВАТНОСТЬ',
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
          ),
          muted: true,
        ),
        const SizedBox(width: 24),
        AuthTextLink(
          label: context.localText(
            en: 'Terms',
            ar: 'الشروط',
            ur: 'شرائط',
            ru: 'УСЛОВИЯ',
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
          ),
          muted: true,
        ),
      ],
    );
  }
}
