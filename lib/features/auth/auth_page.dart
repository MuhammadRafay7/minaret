import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:minaret/core/constants/app_defaults.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import '../../core/theme.dart';
import '../../core/input_validator.dart';
import '../../core/error_handler.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/location_picker.dart';
import '../mosque/edit_mosque_page.dart';
import '../mosque/create_mosque_page.dart';
import 'settings_page.dart';
import 'document_verification.dart';
import 'google_imam_setup_page.dart';
import '../../services/system_config_service.dart';
import '../../repositories/progress_repository.dart';
import '../../repositories/prayer_repository.dart';
import '../progress/progress_page.dart';
import '../progress/widgets/level_badge.dart';
import '../progress/widgets/coin_counter.dart';
import '../prayer/prayer_stats_page.dart';
import '../prayer/qada_page.dart';
import 'edit_profile_page.dart';
import 'imam_profile_page.dart';
import '../../widgets/language_selector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Auth Page
// ─────────────────────────────────────────────────────────────────────────────

enum AuthStep { phone, setup, otp }

class AuthPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const AuthPage({super.key, required this.onLoginSuccess});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _teachingFeeController = TextEditingController();
  final _teachingNotesController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  Uint8List? _idCardImage;
  Uint8List? _idCardBackImage;
  Uint8List? _sanadImage;
  String? _idCardBase64;
  String? _idCardBackBase64;
  String? _sanadBase64;

  String _selectedCountry = 'PK';

  // Standardized residential location (Country → State → City) chosen via the
  // picker. Stored alongside ISO codes. `_selectedCountry` above is separate —
  // it is the country of the ID document used for imam verification.
  LocationValue _location = const LocationValue();

  ImamVerificationResult? _verificationResult;
  bool _isVerifying = false;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isCheckingVerification = false;
  bool _passwordVisible = false;
  AuthStep _regStep = AuthStep.phone;
  String _selectedRole = kDefaultRole;
  String _selectedGender = 'male';
  bool _offersTeaching = false;
  String _teachingAudience = kDefaultTeachingAudience;

  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _phoneNumberController.dispose();
    _teachingFeeController.dispose();
    _teachingNotesController.dispose();
    super.dispose();
  }

  // ── Theme helpers ─────────────────────────────────────────────────────────

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => _isDark ? Colors.white70 : MinaretTheme.slate;
  Color get _lineColor => _isDark ? Colors.white24 : MinaretTheme.dividerColor;
  Color get _surfaceColor =>
      _isDark ? const Color(0xFF151B24) : Colors.white.withValues(alpha: 0.45);
  Color get _cardColor => _isDark ? const Color(0xFF1C2430) : Colors.white;

  // Picks a sensible leading icon from the field label/type when none is given.
  IconData _fieldIcon(String label, bool isObscure, TextInputType? kt) {
    if (isObscure) return Icons.lock_outline_rounded;
    if (kt == TextInputType.emailAddress) return Icons.mail_outline_rounded;
    if (kt == TextInputType.phone) return Icons.phone_outlined;
    final l = label.toLowerCase();
    if (l.contains('city') || l.contains('مدين') || l.contains('شہر')) return Icons.location_city_outlined;
    if (l.contains('name') || l.contains('اسم') || l.contains('نام')) return Icons.person_outline_rounded;
    return Icons.edit_outlined;
  }

  String _displayText(String value) {
    final locale = Localizations.localeOf(context).languageCode;
    return (locale == 'ar' || locale == 'ur') ? value : value.toUpperCase();
  }

  String _t({
    required String en,
    required String ar,
    required String ur,
    required String ru,
    String? fa,
    String? nl,
    String? zh,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'ar':
        return ar;
      case 'ur':
        return ur;
      case 'ru':
        return ru;
      case 'fa':
        return fa ?? en;
      case 'nl':
        return nl ?? en;
      case 'zh':
        return zh ?? en;
      default:
        return en;
    }
  }

  // ── Document picking ──────────────────────────────────────────────────────

  Future<void> _pickImage(
      {bool isIdCard = false, bool isIdCardBack = false}) async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (isIdCard) {
        _idCardImage = bytes;
        _idCardBase64 = base64Encode(bytes);
      } else if (isIdCardBack) {
        _idCardBackImage = bytes;
        _idCardBackBase64 = base64Encode(bytes);
      } else {
        _sanadImage = bytes;
        _sanadBase64 = base64Encode(bytes);
      }
      _verificationResult = null;
    });
    if (_idCardImage != null &&
        _idCardBackImage != null &&
        _sanadImage != null) {
      await _runVerification();
    }
  }

  Future<void> _runVerification() async {
    if (_idCardImage == null || _idCardBackImage == null || _sanadImage == null)
      return;
    setState(() {
      _isVerifying = true;
      _verificationResult = null;
    });
    try {
      final result = await InternationalDocumentVerificationService.verify(
        idCardBytes: _idCardImage!,
        idCardBackBytes: _idCardBackImage!,
        sanadBytes: _sanadImage!,
        countryCode: _selectedCountry,
      );
      if (mounted) setState(() => _verificationResult = result);
    } catch (e) {
      if (mounted) {
        setState(
          () => _verificationResult = ImamVerificationResult(
            approved: false,
            status: 'needs_review',
            score: 0,
            reason:
                'On-device verification encountered an error. Documents saved for manual review.',
            nameMatchConfidence: 0,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> _handleAuth() async {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showStatus(l10n.authErrorFillFields);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (!cred.user!.emailVerified) {
          await FirebaseAuth.instance.signOut();
          _showStatus(
            _t(
              en: 'Please verify your email before signing in.',
              ar: 'يرجى توثيق بريدك الإلكتروني قبل تسجيل الدخول.',
              ur: 'سائن اِن سے پہلے براہ کرم اپنا ای میل تصدیق کریں۔',
              ru: 'Подтвердите email перед входом.',
            ),
          );
          return;
        }
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();
        final role = userDoc.data()?['role'] ?? kDefaultRole;
        if (!mounted) return;
        await _routeAfterLogin(cred.user!.uid, role);
      } else {
        // ── REGISTRATION TOGGLE CHECK ──
        final globalSettings = Provider.of<GlobalSettings?>(context, listen: false);
        if (globalSettings != null && !globalSettings.allowNewRegistrations) {
           _showStatus(_t(
             en: 'New registrations are currently disabled.',
             ar: 'التسجيل الجديد معطل حاليا.',
             ur: 'نئی رجسٹریشن فی الحال معطل ہے۔',
             ru: 'Регистрация новых пользователей отключена.'
           ));
           setState(() => _isLoading = false);
           return;
        }

        if (_regStep == AuthStep.phone) {
          final emailValidation = InputValidator.validateEmail(email);
          if (!emailValidation.isValid) {
            _showStatus(emailValidation.errorMessage!);
            return;
          }
          if (!_location.isComplete) {
            _showStatus(_t(en: 'Please select your country, state and city', ar: 'يرجى اختيار الدولة والولاية والمدينة', ur: 'براہ کرم اپنا ملک، صوبہ اور شہر منتخب کریں', ru: 'Выберите страну, регион и город'));
            return;
          }
          setState(() => _regStep = AuthStep.setup);
          return;
        }

        final passwordValidation = InputValidator.validatePassword(password);
        if (!passwordValidation.isValid) {
          _showStatus(passwordValidation.errorMessage!);
          return;
        }

        if (_selectedRole == kRoleCommon) {
          final nameValidation =
              InputValidator.validateName(_fullNameController.text);
          if (!nameValidation.isValid) {
            _showStatus(nameValidation.errorMessage!);
            return;
          }
        }

        if (_selectedRole == kRoleImam) {
          final nameValidation =
              InputValidator.validateName(_fullNameController.text);
          if (!nameValidation.isValid) {
            _showStatus(nameValidation.errorMessage!);
            return;
          }

          final fatherNameValidation =
              InputValidator.validateName(_fatherNameController.text);
          if (!fatherNameValidation.isValid) {
            _showStatus(fatherNameValidation.errorMessage!);
            return;
          }

          final phoneValidation =
              InputValidator.validatePhone(_phoneNumberController.text);
          if (!phoneValidation.isValid) {
            _showStatus(phoneValidation.errorMessage!);
            return;
          }
          if (_idCardBase64 == null ||
              _idCardBackBase64 == null ||
              _sanadBase64 == null) {
            _showStatus(
              _t(
                en: 'Please upload both sides of your ID card and your Sanad/Certificate.',
                ar: 'يرجى تحميل كلا الجانبين من بطاقة الهوية والسند/الشهادة.',
                ur: 'براہ کرم اپنے شناختی کارڈ کے دونوں طرف اور سند/سرٹیفکیٹ اپلوڈ کریں۔',
                ru: 'Пожалуйста, загрузите обе стороны удостоверения личности и санад/сертификат.',
              ),
            );
            return;
          }
          if (_verificationResult?.status == 'rejected') {
            _showStatus(
              _t(
                en: 'Documents do not match. Please upload correct documents.',
                ar: 'المستندات غير متطابقة. يرجى تحميل المستندات الصحيحة.',
                ur: 'دستاویزات میل نہیں کھاتیں۔ براہ کرم درست دستاویزات اپلوڈ کریں۔',
                ru: 'Документы не совпадают. Загрузите корректные документы.',
              ),
            );
            return;
          }
          if (_isVerifying) {
            _showStatus(
              _t(
                en: 'Documents are still being verified. Please wait.',
                ar: 'جارٍ التحقق من المستندات. يرجى الانتظار.',
                ur: 'دستاویزات کی تصدیق جاری ہے۔ براہ کرم انتظار کریں۔',
                ru: 'Документы ещё проверяются. Пожалуйста, подождите.',
              ),
            );
            return;
          }
        }

        // ── Create account ──
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await cred.user!.sendEmailVerification();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'email': email,
          'country': _location.countryName,
          'countryCode': _location.countryCode,
          'state': _location.stateName,
          'stateCode': _location.stateCode,
          'city': _location.cityName,
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'favorites': <String>[],
          'followedMosques': <String>[],
          'notificationsEnabled': true,
          'notificationPrefs': {
            'janaza': true,
            'adhan': true,
            'namaz': true,
            'eid': true,
            'taraweeh': true,
          },
          if (_selectedRole == kRoleCommon) ...{
            'displayName': _fullNameController.text.trim(),
            'gender': _selectedGender,
          },
          if (_selectedRole == kRoleImam) ...{
            'fullName': _fullNameController.text.trim(),
            'fatherName': _fatherNameController.text.trim(),
            'phoneNumber': _phoneNumberController.text.trim(),
            'imamProfile': {
              'fullName': _fullNameController.text.trim(),
              'fatherName': _fatherNameController.text.trim(),
              'phoneNumber': _phoneNumberController.text.trim(),
              'offersTeaching': _offersTeaching,
              'teachingAudience': _offersTeaching ? _teachingAudience : null,
              'teachingFee':
                  _offersTeaching ? _teachingFeeController.text.trim() : null,
              'teachingNotes':
                  _offersTeaching ? _teachingNotesController.text.trim() : null,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            'idCardBase64': _idCardBase64,
            'idCardBackBase64': _idCardBackBase64,
            'sanadBase64': _sanadBase64,
            'documentsVerified': _verificationResult?.approved ?? false,
            'verificationStatus': _verificationResult?.status ?? 'needs_review',
            'verificationScore': _verificationResult?.score ?? 0,
            'verificationReason': _verificationResult?.reason ?? '',
            'nameMatchConfidence':
                _verificationResult?.nameMatchConfidence ?? 0,
            'verificationMethod': 'on_device_mlkit',
            'verificationCountry': _selectedCountry,
          },
        });

        // ── FIX: set OTP step BEFORE signing out so StreamBuilder sees the
        //         correct state when it rebuilds on auth change ──
        if (mounted) setState(() => _regStep = AuthStep.otp);
        await FirebaseAuth.instance.signOut();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final errorMessage = SecureErrorHandler.getSafeErrorMessage(e,
            context: 'authentication');
        _showStatus(errorMessage);
      }
      SecureErrorHandler.logError(e, context: 'authentication');
    } catch (e) {
      if (mounted) {
        final errorMessage = SecureErrorHandler.getSafeErrorMessage(e,
            context: 'authentication');
        _showStatus(errorMessage);
      }
      SecureErrorHandler.logError(e, context: 'authentication');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showStatus(
        _t(
          en: 'Enter your email above first.',
          ar: 'أدخل بريدك الإلكتروني أولاً.',
          ur: 'پہلے ای میل درج کریں۔',
          ru: 'Сначала введите email.',
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted)
        _showStatus(
          _t(
            en: 'Password reset email sent.',
            ar: 'تم إرسال رابط إعادة التعيين.',
            ur: 'پاس ورڈ ری سیٹ ای میل بھیج دی گئی۔',
            ru: 'Письмо для сброса пароля отправлено.',
          ),
        );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showStatus(e.message ?? '');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _routeAfterLogin(String uid, String role) async {
    if (!mounted) return;
    if (role == kRoleImam) {
      final q = await FirebaseFirestore.instance
          .collection('mosques')
          .where('adminUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => q.docs.isNotEmpty
              ? EditMosquePage(
                  docId: q.docs.first.id,
                  currentData: q.docs.first.data(),
                )
              : const CreateMosquePage(),
        ),
      );
    } else {
      widget.onLoginSuccess();
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!cred.user!.emailVerified) await cred.user!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      if (mounted)
        _showStatus(
          _t(
            en: 'Verification email resent.',
            ar: 'تمت إعادة الإرسال.',
            ur: 'دوبارہ بھیج دی گئی۔',
            ru: 'Письмо отправлено повторно.',
          ),
        );
    } catch (_) {
      if (mounted)
        _showStatus(
          _t(
            en: 'Could not resend. Try again.',
            ar: 'تعذر الإرسال.',
            ur: 'دوبارہ نہیں بھیجا جا سکا۔',
            ru: 'Не удалось отправить.',
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── CORE FIX: Check verification, sign in fresh, reload, then route ───────

  Future<void> _checkVerification() async {
    if (_isCheckingVerification) return;
    setState(() => _isCheckingVerification = true);
    try {
      // Sign in silently to get a fresh token
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Force-reload so emailVerified reflects the latest state
      await cred.user!.reload();
      final freshUser = FirebaseAuth.instance.currentUser;

      if (freshUser != null && freshUser.emailVerified) {
        // ✅ Verified — fetch role and navigate
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(freshUser.uid)
            .get();
        final role = doc.data()?['role'] ?? kDefaultRole;
        if (!mounted) return;
        await _routeAfterLogin(freshUser.uid, role);
      } else {
        // ❌ Not verified yet — sign back out and tell the user
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          _showStatus(
            _t(
              en: 'Email not verified yet. Please check your inbox and click the link.',
              ar: 'لم يتم التوثيق بعد. يرجى فتح البريد الإلكتروني والنقر على الرابط.',
              ur: 'ابھی تصدیق نہیں ہوا۔ براہ کرم اپنا ای میل چیک کریں اور لنک پر کلک کریں۔',
              ru: 'Email ещё не подтверждён. Проверьте почту и перейдите по ссылке.',
            ),
          );
        }
      }
    } on FirebaseAuthException {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        _showStatus(
          _t(
            en: 'Could not check verification. Please try again.',
            ar: 'تعذر التحقق. حاول مرة أخرى.',
            ur: 'تصدیق چیک نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
            ru: 'Не удалось проверить. Попробуйте ещё раз.',
          ),
        );
      }
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        _showStatus(
          _t(
            en: 'Something went wrong. Please try again.',
            ar: 'حدث خطأ ما. حاول مرة أخرى.',
            ur: 'کچھ غلط ہو گیا۔ دوبارہ کوشش کریں۔',
            ru: 'Что-то пошло не так. Попробуйте ещё раз.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingVerification = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (l10n == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            color: MinaretTheme.gold,
            strokeWidth: 1,
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final showProfile =
            user != null && (_isLogin || _regStep == AuthStep.phone);
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: AtelierLayout(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: showProfile ? 20 : 40),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeInOutQuart,
                switchOutCurve: Curves.easeInOutQuart,
                child: showProfile
                    ? _buildProfileView(user, l10n)
                    : _regStep == AuthStep.otp
                        ? _buildVerificationWaiting(l10n)
                        : _buildAuthForm(l10n),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Verification waiting screen ───────────────────────────────────────────

  Widget _buildVerificationWaiting(AppLocalizations l10n) {
    return Column(
      key: const ValueKey('verification'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBismillah(),
        const SizedBox(height: 30),
        Text(
          _displayText(
            _t(en: 'Verify', ar: 'تحقق', ur: 'تصدیق', ru: 'Подтвердить'),
          ),
          style: MinaretTheme.heading.copyWith(
            fontSize: 32,
            letterSpacing: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _displayText(
            _t(
              en: 'Your Email',
              ar: 'بريدك الإلكتروني',
              ur: 'آپ کا ای میل',
              ru: 'Ваш Email',
            ),
          ),
          style: MinaretTheme.label,
        ),
        const SizedBox(height: 50),

        // ── Envelope icon + email address ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MinaretTheme.gold.withValues(alpha: 0.06),
            border: Border.all(
              color: MinaretTheme.gold.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: MinaretTheme.gold,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _t(
                        en: 'A confirmation link has been sent to:',
                        ar: 'تم إرسال رابط التأكيد إلى:',
                        ur: 'تصدیقی لنک یہاں بھیجا گیا:',
                        ru: 'Ссылка подтверждения отправлена на:',
                      ),
                      style: MinaretTheme.detailHeader.copyWith(
                        fontSize: 8,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  _emailController.text.trim(),
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Instructions ──
        Text(
          _t(
            en: 'Open your email, click the verification link, then come back here and tap the button below.',
            ar: 'افتح بريدك الإلكتروني، انقر على رابط التحقق، ثم عد هنا واضغط على الزر أدناه.',
            ur: 'اپنا ای میل کھولیں، تصدیقی لنک پر کلک کریں، پھر واپس آئیں اور نیچے والا بٹن دبائیں۔',
            ru: 'Откройте почту, нажмите ссылку подтверждения, вернитесь сюда и нажмите кнопку ниже.',
          ),
          style: GoogleFonts.lato(
            fontSize: 12,
            color: _textSecondary,
            height: 1.8,
          ),
        ),

        const SizedBox(height: 50),

        // ── PRIMARY ACTION: I have confirmed my email ──
        _buildActionButton(
          _isCheckingVerification
              ? _t(
                  en: 'Checking…',
                  ar: 'جارٍ التحقق…',
                  ur: 'چیک ہو رہا ہے…',
                  ru: 'Проверка…',
                )
              : _t(
                  en: 'I have confirmed my email',
                  ar: 'لقد أكدت بريدي الإلكتروني',
                  ur: 'میں نے اپنا ای میل تصدیق کر لیا',
                  ru: 'Я подтвердил свой email',
                ),
          _isCheckingVerification ? null : _checkVerification,
        ),

        const SizedBox(height: 20),

        // ── Resend link ──
        Center(
          child: _buildTextLink(
            _displayText(
              _t(
                en: 'Resend confirmation email',
                ar: 'إعادة إرسال',
                ur: 'دوبارہ بھیجیں',
                ru: 'Отправить снова',
              ),
            ),
            _isLoading ? null : _resendVerification,
          ),
        ),

        const SizedBox(height: 16),

        // ── Back to sign in ──
        Center(
          child: _buildTextLink(
            _displayText(
              _t(
                en: 'Back to sign in',
                ar: 'العودة لتسجيل الدخول',
                ur: 'واپس سائن اِن',
                ru: 'Назад ко входу',
              ),
            ),
            () => setState(() {
              _regStep = AuthStep.phone;
              _isLogin = true;
              _emailController.clear();
              _passwordController.clear();
            }),
            muted: true,
          ),
        ),
      ],
    );
  }

  // ── Profile view ──────────────────────────────────────────────────────────

  Widget _buildProfileView(User user, AppLocalizations l10n) {
    return _SocialProfileView(
      key: const ValueKey('profile'),
      user: user,
    );
  }

  // ── Auth form ─────────────────────────────────────────────────────────────

  Widget _buildAuthForm(AppLocalizations l10n) {
    return SingleChildScrollView(
      key: const ValueKey('auth_form'),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      _displayText(
                        _isLogin
                            ? l10n.authLoginGreeting
                            : l10n.authRegisterGreeting,
                      ),
                      style: MinaretTheme.heading.copyWith(
                        fontSize: 32,
                        letterSpacing: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayText(
                        _isLogin
                            ? l10n.authLoginSubtitle
                            : (_regStep == AuthStep.phone
                                ? l10n.authRegStep1
                                : l10n.authRegStep2),
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
          _buildBismillah(),
          const SizedBox(height: 50),
          ..._buildFieldsForCurrentStep(l10n),
          const SizedBox(height: 50),
          _buildActionButton(
            _isLogin
                ? l10n.authActionSignIn
                : (_regStep == AuthStep.phone
                    ? l10n.authActionProceed
                    : l10n.authActionEstablish),
            _handleAuth,
          ),
          if (_isLogin) ...[
            const SizedBox(height: 20),
            Center(
              child: _buildTextLink(
                _displayText(
                  _t(
                    en: 'Forgot password?',
                    ar: 'نسيت كلمة المرور؟',
                    ur: 'پاس ورڈ بھول گئے؟',
                    ru: 'Забыли пароль?',
                  ),
                ),
                _isLoading ? null : _handleForgotPassword,
                accent: true,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(child: Divider(color: _lineColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _displayText(_t(en: 'OR', ar: 'أو', ur: 'یا', ru: 'ИЛИ')),
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: _textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: _lineColor)),
              ],
            ),
            const SizedBox(height: 20),
            _buildGoogleSignInButton(),
          ],
          const SizedBox(height: 16),
          Center(
            child: _buildTextLink(
              _displayText(
                _isLogin ? l10n.authSwitchToRegister : l10n.authSwitchToLogin,
              ),
              () => setState(() {
                _isLogin = !_isLogin;
                _regStep = AuthStep.phone;
                _emailController.clear();
                _passwordController.clear();
                _location = const LocationValue();
              }),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _buildFieldsForCurrentStep(AppLocalizations l10n) {
    if (_isLogin) {
      return [
        _buildModernField(
          l10n.fieldEmail,
          _emailController,
          false,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildModernField(l10n.fieldPassword, _passwordController, true),
      ];
    }
    if (_regStep == AuthStep.phone) {
      return [
        _buildModernField(
          l10n.fieldEmail,
          _emailController,
          false,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        LocationPicker(
          countryLabel: _t(en: 'Country', ar: 'الدولة', ur: 'ملک', ru: 'Страна'),
          stateLabel: _t(en: 'State / Province', ar: 'الولاية / المحافظة', ur: 'صوبہ', ru: 'Регион'),
          cityLabel: _t(en: 'City', ar: 'المدينة', ur: 'شہر', ru: 'Город'),
          onChanged: (loc) => setState(() => _location = loc),
        ),
      ];
    }

    // ── Setup step ──
    return [
      _buildSectionLabel(l10n.sectionDesignation),
      const SizedBox(height: 16),
      _buildRoleSelector(l10n),
      if (_selectedRole == kRoleCommon) ...[
        const SizedBox(height: 28),
        _buildSectionLabel(
          _t(
            en: 'Personal Details',
            ar: 'البيانات الشخصية',
            ur: 'ذاتی معلومات',
            ru: 'Личные данные',
          ),
        ),
        const SizedBox(height: 16),
        _buildModernField(
          _t(en: 'Full Name', ar: 'الاسم الكامل', ur: 'پورا نام', ru: 'Полное имя'),
          _fullNameController,
          false,
        ),
        const SizedBox(height: 16),
        _buildSectionLabel(
          _t(en: 'Gender', ar: 'الجنس', ur: 'جنس', ru: 'Пол'),
        ),
        const SizedBox(height: 12),
        _buildGenderSelector(),
      ],
      if (_selectedRole == kRoleImam) ...[
        const SizedBox(height: 28),
        _buildSectionLabel(
          _t(
            en: 'Personal Details',
            ar: 'البيانات الشخصية',
            ur: 'ذاتی معلومات',
            ru: 'Личные данные',
          ),
        ),
        const SizedBox(height: 16),
        _buildModernField(
          _t(
              en: 'Full Name',
              ar: 'الاسم الكامل',
              ur: 'پورا نام',
              ru: 'Полное имя'),
          _fullNameController,
          false,
        ),
        const SizedBox(height: 16),
        _buildModernField(
          _t(
              en: "Father's Name",
              ar: 'اسم الأب',
              ur: 'والد کا نام',
              ru: 'Имя отца'),
          _fatherNameController,
          false,
        ),
        const SizedBox(height: 16),
        _buildModernField(
          _t(
              en: 'Phone Number',
              ar: 'رقم الهاتف',
              ur: 'فون نمبر',
              ru: 'Номер телефона'),
          _phoneNumberController,
          false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                _displayText(
                  _t(
                    en: 'Available to teach',
                    ar: 'متاح للتعليم',
                    ur: 'تعلیم کے لیے دستیاب',
                    ru: 'Готов обучать',
                  ),
                ),
                style: MinaretTheme.label.copyWith(
                  color: _textSecondary,
                  letterSpacing: 1.4,
                  fontSize: 9,
                ),
              ),
            ),
            Switch(
              value: _offersTeaching,
              onChanged: (v) => setState(() => _offersTeaching = v),
            ),
          ],
        ),
        if (_offersTeaching) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _teachingAudience,
            items: [
              DropdownMenuItem(
                value: kTeachingAudienceNeighbourhood,
                child: Text(
                  _t(
                    en: 'Neighbourhood learners',
                    ar: 'متعلمين من الحي',
                    ur: 'محلے کے سیکھنے والے',
                    ru: 'Ученики из района',
                  ),
                ),
              ),
              DropdownMenuItem(
                value: kTeachingAudienceAnyone,
                child: Text(
                  _t(en: 'Anyone', ar: 'أي شخص', ur: 'کوئی بھی', ru: 'Любой'),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _teachingAudience = v);
            },
            decoration: InputDecoration(
              labelText: _displayText(
                _t(
                  en: 'Teaching Audience',
                  ar: 'الفئة التعليمية',
                  ur: 'تعلیم کا دائرہ',
                  ru: 'Аудитория',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildModernField(
            _t(
                en: 'Teaching Fee',
                ar: 'رسوم التعليم',
                ur: 'تدریسی فیس',
                ru: 'Плата'),
            _teachingFeeController,
            false,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildModernField(
            _t(
              en: 'Subjects / notes (optional)',
              ar: 'ملاحظات (اختياري)',
              ur: 'نوٹس (اختیاری)',
              ru: 'Заметки (необязательно)',
            ),
            _teachingNotesController,
            false,
          ),
        ],

        // ── Document Verification Section ──
        const SizedBox(height: 32),
        _buildSectionLabel(
          _t(
            en: 'Document Verification',
            ar: 'التحقق من المستندات',
            ur: 'دستاویز کی تصدیق',
            ru: 'Проверка документов',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _t(
            en: 'Upload your CNIC/Passport and your Sanad or certificate. '
                'Verification runs on your device — documents stay private.',
            ar: 'قم بتحميل بطاقة الهوية والسند. يتم التحقق على جهازك — وتبقى مستنداتك خاصة.',
            ur: 'اپنا شناختی کارڈ/پاسپورٹ اور سند اپلوڈ کریں۔ '
                'تصدیق آپ کے آلے پر ہوتی ہے — دستاویزات نجی رہتی ہیں۔',
            ru: 'Загрузите удостоверение личности и санад. '
                'Проверка происходит на устройстве — документы остаются конфиденциальными.',
          ),
          style: GoogleFonts.lato(
              fontSize: 11, color: _textSecondary, height: 1.7),
        ),
        const SizedBox(height: 20),
        _buildCountrySelector(),
        const SizedBox(height: 16),
        _buildDocumentField(
          label: _t(
            en: 'CNIC / Passport',
            ar: 'بطاقة الهوية / جواز السفر',
            ur: 'شناختی کارڈ / پاسپورٹ',
            ru: 'Удостоверение / Паспорт',
          ),
          imageBytes: _idCardImage,
          isUploaded: _idCardBase64 != null,
          onPick: () => _pickImage(isIdCard: true),
        ),
        const SizedBox(height: 16),
        _buildDocumentField(
          label: _t(
            en: 'CNIC / Passport (Back Side)',
            ar: 'بطاقة الهوية / جواز السفر (الظهر)',
            ur: 'شناختی کارڈ / پاسپورٹ (پشت)',
            ru: 'Удостоверение / Паспорт (Обратная сторона)',
          ),
          imageBytes: _idCardBackImage,
          isUploaded: _idCardBackBase64 != null,
          onPick: () => _pickImage(isIdCardBack: true),
        ),
        const SizedBox(height: 16),
        _buildDocumentField(
          label: _t(
            en: 'Sanad / Islamic Certificate',
            ar: 'السند / الشهادة الدينية',
            ur: 'سند / اسلامی سرٹیفکیٹ',
            ru: 'Санад / Исламский сертификат',
          ),
          imageBytes: _sanadImage,
          isUploaded: _sanadBase64 != null,
          onPick: () => _pickImage(isIdCard: false),
        ),
        const SizedBox(height: 16),
        _buildVerificationStatus(),
      ],
      const SizedBox(height: 40),
      _buildModernField(l10n.fieldSetPassword, _passwordController, true),
      const SizedBox(height: 16),
      Center(
        child: _buildTextLink(
          _displayText(l10n.authActionReviseEmail),
          () => setState(() => _regStep = AuthStep.phone),
          muted: true,
        ),
      ),
    ];
  }

  // ── Country selector ──────────────────────────────────────────────────────

  Widget _buildCountrySelector() {
    final countries =
        InternationalDocumentVerificationService.getSupportedCountries();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountry,
          isExpanded: true,
          hint: Text(
            _t(
              en: 'Select Country',
              ar: 'اختر الدولة',
              ur: 'ملک منتخب کریں',
              ru: 'Выберите страну',
            ),
            style: GoogleFonts.lato(fontSize: 14, color: Colors.grey[600]),
          ),
          items: countries.map((countryCode) {
            final config =
                InternationalDocumentVerificationService.getCountryConfig(
                    countryCode);
            return DropdownMenuItem<String>(
              value: countryCode,
              child: Row(
                children: [
                  Text(
                    _getCountryFlag(countryCode),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      config.name,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCountry = value;
                _verificationResult = null;
              });
            }
          },
        ),
      ),
    );
  }

  String _getCountryFlag(String countryCode) {
    const flags = {
      'PK': '🇵🇰',
      'US': '🇺🇸',
      'GB': '🇬🇧',
      'SA': '🇸🇦',
      'AE': '🇦🇪',
      'IN': '🇮🇳',
      'EG': '🇪🇬',
      'TR': '🇹🇷',
      'FR': '🇫🇷',
      'DE': '🇩🇪',
      'GENERIC': '🌍',
    };
    return flags[countryCode] ?? '🌍';
  }

  // ── Document upload widget ────────────────────────────────────────────────

  Widget _buildDocumentField({
    required String label,
    required Uint8List? imageBytes,
    required bool isUploaded,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_displayText(label), style: MinaretTheme.label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surfaceColor,
              border: Border.all(
                color: isUploaded
                    ? MinaretTheme.emerald.withValues(alpha: 0.5)
                    : _lineColor,
                width: isUploaded ? 1.2 : 0.8,
              ),
            ),
            child: imageBytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(imageBytes, fit: BoxFit.cover),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          color: Colors.black54,
                          child: Text(
                            _t(
                              en: 'Change',
                              ar: 'تغيير',
                              ur: 'تبدیل کریں',
                              ru: 'Изменить',
                            ),
                            style: GoogleFonts.montserrat(
                              fontSize: 7,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 30,
                        color: MinaretTheme.gold.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          en: 'Tap to upload',
                          ar: 'انقر للتحميل',
                          ur: 'اپلوڈ کرنے کے لیے ٹیپ کریں',
                          ru: 'Нажмите для загрузки',
                        ),
                        style: GoogleFonts.montserrat(
                          fontSize: 8.5,
                          color: _textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── Verification status banner ────────────────────────────────────────────

  Widget _buildVerificationStatus() {
    if (_idCardBase64 == null ||
        _idCardBackBase64 == null ||
        _sanadBase64 == null) {
      return const SizedBox.shrink();
    }

    if (_isVerifying) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MinaretTheme.gold.withValues(alpha: 0.07),
          border: Border.all(color: MinaretTheme.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: MinaretTheme.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t(
                  en: 'Scanning documents on device…',
                  ar: 'جارٍ مسح المستندات على الجهاز…',
                  ur: 'آلے پر دستاویزات اسکین ہو رہی ہیں…',
                  ru: 'Сканирование документов на устройстве…',
                ),
                style: GoogleFonts.montserrat(
                  fontSize: 8.5,
                  color: MinaretTheme.gold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final result = _verificationResult;
    if (result == null) return const SizedBox.shrink();

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (result.status) {
      case 'approved':
        statusColor = MinaretTheme.emerald;
        statusIcon = Icons.verified_outlined;
        statusText = _t(
          en: 'Documents verified — names match (${result.nameMatchConfidence}% confidence)',
          ar: 'تم التحقق من المستندات — الأسماء متطابقة (${result.nameMatchConfidence}٪)',
          ur: 'دستاویزات تصدیق شدہ — نام میل کھاتے ہیں (${result.nameMatchConfidence}٪ اعتماد)',
          ru: 'Документы подтверждены — имена совпадают (${result.nameMatchConfidence}%)',
        );
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel_outlined;
        statusText = _t(
          en: 'Documents do not match. Please upload correct documents.',
          ar: 'المستندات غير متطابقة. يرجى تحميل المستندات الصحيحة.',
          ur: 'دستاویزات میل نہیں کھاتیں۔ براہ کرم درست دستاویزات اپلوڈ کریں۔',
          ru: 'Документы не совпадают. Загрузите корректные документы.',
        );
        break;
      default: // needs_review
        statusColor = MinaretTheme.gold;
        statusIcon = Icons.info_outline;
        statusText = _t(
          en: 'Documents saved for manual review. You can proceed.',
          ar: 'المستندات محفوظة للمراجعة اليدوية. يمكنك المتابعة.',
          ur: 'دستاویزات دستی جائزے کے لیے محفوظ ہو گئیں۔ آگے بڑھیں۔',
          ru: 'Документы сохранены для проверки. Можете продолжить.',
        );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 10),
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
            ],
          ),
          if (result.reason.isNotEmpty && result.status != 'approved') ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                result.reason,
                style: GoogleFonts.lato(
                  fontSize: 11,
                  color: _textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    en: 'Match score',
                    ar: 'درجة التطابق',
                    ur: 'میچ سکور',
                    ru: 'Оценка совпадения',
                  ),
                  style: GoogleFonts.montserrat(
                    fontSize: 7,
                    letterSpacing: 1.5,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: result.score / 100,
                    backgroundColor: _lineColor,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.score}/100',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 8,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (result.status == 'rejected') ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() {
                _idCardImage = null;
                _idCardBackImage = null;
                _idCardBase64 = null;
                _idCardBackBase64 = null;
                _sanadImage = null;
                _sanadBase64 = null;
                _verificationResult = null;
              }),
              child: Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  _displayText(
                    _t(
                      en: 'Clear and re-upload',
                      ar: 'مسح وإعادة التحميل',
                      ur: 'صاف کریں اور دوبارہ اپلوڈ کریں',
                      ru: 'Очистить и загрузить снова',
                    ),
                  ),
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    letterSpacing: 1.5,
                    color: statusColor,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _verificationResult = ImamVerificationResult(
                approved: false,
                status: 'needs_review',
                score: result.score,
                reason: 'Automated check inconclusive — submitted for manual review.',
                nameMatchConfidence: result.nameMatchConfidence,
              )),
              child: Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  _displayText(
                    _t(
                      en: 'Submit for manual review instead',
                      ar: 'إرسال للمراجعة اليدوية',
                      ur: 'دستی جائزے کے لیے بھیجیں',
                      ru: 'Отправить на ручную проверку',
                    ),
                  ),
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    letterSpacing: 1.5,
                    color: MinaretTheme.gold,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────

  Widget _buildBismillah() {
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
                color: MinaretTheme.gold.withValues(alpha: 0.25),
                thickness: 0.5,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '✦',
                style: TextStyle(
                  fontSize: 8,
                  color: MinaretTheme.gold.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: MinaretTheme.gold.withValues(alpha: 0.25),
                thickness: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) =>
      Text(_displayText(text), style: MinaretTheme.label);

  Widget _buildRoleSelector(AppLocalizations l10n) {
    return Row(
      children: [
        _roleButton(l10n.roleCommunity, kRoleCommon),
        const SizedBox(width: 12),
        _roleButton(l10n.roleImam, kRoleImam),
      ],
    );
  }

  Widget _buildGenderSelector() {
    final genders = [
      ('male', _t(en: 'Male', ar: 'ذكر', ur: 'مرد', ru: 'Муж.')),
      ('female', _t(en: 'Female', ar: 'أنثى', ur: 'عورت', ru: 'Жен.')),
      ('other', _t(en: 'Other', ar: 'آخر', ur: 'دیگر', ru: 'Другой')),
    ];
    return Row(
      children: [
        for (int i = 0; i < genders.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedGender = genders[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedGender == genders[i].$1
                      ? MinaretTheme.gold
                      : Colors.transparent,
                  border: Border.all(
                    width: 1.5,
                    color: _selectedGender == genders[i].$1
                        ? MinaretTheme.gold
                        : _lineColor,
                  ),
                ),
                child: Center(
                  child: Text(
                    _displayText(genders[i].$2),
                    style: GoogleFonts.montserrat(
                      fontSize: 8,
                      letterSpacing: 1.5,
                      color: _selectedGender == genders[i].$1
                          ? Colors.white
                          : _textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _roleButton(String label, String role) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? MinaretTheme.emerald : Colors.transparent,
            border: Border.all(
              width: 1.5,
              color: isSelected ? MinaretTheme.emerald : _lineColor,
            ),
          ),
          child: Center(
            child: Text(
              _displayText(label),
              style: GoogleFonts.montserrat(
                fontSize: 8.5,
                letterSpacing: 2,
                color: isSelected ? Colors.white : _textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernField(
    String label,
    TextEditingController controller,
    bool isObscure, {
    TextInputType? keyboardType,
  }) {
    final obscured = isObscure && !_passwordVisible;
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MinaretTheme.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Icon(_fieldIcon(label, isObscure, keyboardType),
              size: 20, color: MinaretTheme.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayText(label),
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: MinaretTheme.gold,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  obscureText: obscured,
                  keyboardType: keyboardType,
                  cursorColor: MinaretTheme.gold,
                  cursorWidth: 1.2,
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          // Password visibility toggle
          if (isObscure)
            GestureDetector(
              onTap: () => setState(() => _passwordVisible = !_passwordVisible),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: _textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _signInWithGoogle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: _lineColor),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/google_logo.png', width: 18, height: 18,
                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 20)),
            const SizedBox(width: 10),
            Text(
              _displayText(_t(
                en: 'Continue with Google',
                ar: 'المتابعة عبر جوجل',
                ur: 'گوگل سے جاری رکھیں',
                ru: 'Войти через Google',
              )),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback? action) {
    return PremiumButton(
      text: _displayText(label),
      onPressed: _isLoading ? null : action,
      type: ButtonType.primary,
      isLoading: _isLoading,
      borderRadius: 0,
    );
  }

  Widget _buildTextLink(
    String label,
    VoidCallback? onTap, {
    bool muted = false,
    bool accent = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 8.5,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w700,
          color: accent
              ? MinaretTheme.gold
              : muted
                  ? _textSecondary.withValues(alpha: 0.5)
                  : _textSecondary,
        ),
      ),
    );
  }

  Future<String?> _showGoogleRoleSheet() {
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1C2430) : const Color(0xFFF8F3E9);
        final textSec = isDark ? Colors.white70 : MinaretTheme.slate;
        final lineColor = isDark ? Colors.white24 : MinaretTheme.dividerColor;

        String t({required String en, required String ar, required String ur, required String ru}) {
          switch (Localizations.localeOf(ctx).languageCode) {
            case 'ar': return ar;
            case 'ur': return ur;
            case 'ru': return ru;
            default: return en;
          }
        }

        String d(String v) {
          final lang = Localizations.localeOf(ctx).languageCode;
          return (lang == 'ar' || lang == 'ur') ? v : v.toUpperCase();
        }

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                d(t(en: 'Who are you?', ar: 'من أنت؟', ur: 'آپ کون ہیں؟', ru: 'Кто вы?')),
                style: MinaretTheme.heading,
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  en: 'Choose how you want to use Minaret.',
                  ar: 'اختر كيف تريد استخدام التطبيق.',
                  ur: 'منتخب کریں آپ مینارت کیسے استعمال کرنا چاہتے ہیں۔',
                  ru: 'Выберите, как вы хотите использовать Minaret.',
                ),
                style: GoogleFonts.lato(fontSize: 13, color: textSec, height: 1.6),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _roleSheetButton(
                      ctx: ctx,
                      label: d(t(en: 'Community\nMember', ar: 'عضو\nالمجتمع', ur: 'کمیونٹی\nممبر', ru: 'Пользователь')),
                      icon: Icons.people_outline,
                      value: kRoleCommon,
                      color: MinaretTheme.emerald,
                      lineColor: lineColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _roleSheetButton(
                      ctx: ctx,
                      label: d(t(en: 'Imam', ar: 'إمام', ur: 'امام', ru: 'Имам')),
                      icon: Icons.mosque_outlined,
                      value: kRoleImam,
                      color: MinaretTheme.gold,
                      lineColor: lineColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roleSheetButton({
    required BuildContext ctx,
    required String label,
    required IconData icon,
    required String value,
    required Color color,
    required Color lineColor,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(ctx).pop(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          color: color.withValues(alpha: 0.05),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleClientId = dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
      final googleUser = await GoogleSignIn(
        clientId: kIsWeb ? googleClientId : null,
        serverClientId: kIsWeb ? null : googleClientId,
      ).signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        if (mounted) {
          _showStatus(_t(
            en: 'Google sign-in failed: could not get ID token. Make sure SHA-1 is added in Firebase Console.',
            ar: 'فشل تسجيل الدخول: تأكد من إضافة SHA-1 في Firebase.',
            ur: 'سائن اِن ناکام: Firebase Console میں SHA-1 شامل کریں۔',
            ru: 'Ошибка: не удалось получить ID токен. Добавьте SHA-1 в Firebase Console.',
          ));
          setState(() => _isLoading = false);
        }
        return;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      setState(() => _isLoading = false);
      final chosenRole = await _showGoogleRoleSheet();
      if (!mounted) return;
      if (chosenRole == null) {
        return;
      }

      setState(() => _isLoading = true);
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final uid = userCred.user!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        if (chosenRole == kRoleImam) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GoogleImamSetupPage(
                uid: uid,
                email: userCred.user!.email ?? '',
                displayName: userCred.user!.displayName ?? '',
                onLoginSuccess: widget.onLoginSuccess,
              ),
            ),
          );
          return;
        }
        // Common user — create doc and proceed
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': userCred.user!.email ?? '',
          'displayName': userCred.user!.displayName ?? '',
          'role': kRoleCommon,
          'city': '',
          'createdAt': FieldValue.serverTimestamp(),
          'favorites': <String>[],
          'followedMosques': <String>[],
          'notificationsEnabled': true,
          'notificationPrefs': {
            'janaza': true,
            'adhan': true,
            'namaz': true,
            'eid': true,
            'taraweeh': true,
          },
        });
        if (!mounted) return;
        await _routeAfterLogin(uid, kRoleCommon);
      } else {
        final role = userDoc.data()?['role'] ?? kDefaultRole;
        if (!mounted) return;
        await _routeAfterLogin(uid, role);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'account-exists-with-different-credential') {
        _showStatus(_t(
          en: 'This email is already registered with a password. Please sign in with your email and password instead.',
          ar: 'هذا البريد الإلكتروني مسجل بكلمة مرور. يرجى تسجيل الدخول بالبريد وكلمة المرور.',
          ur: 'یہ ای میل پاس ورڈ سے رجسٹر ہے۔ براہ کرم ای میل اور پاس ورڈ سے سائن اِن کریں۔',
          ru: 'Этот email уже зарегистрирован с паролем. Войдите через email и пароль.',
        ));
      } else {
        _showStatus(_t(
          en: 'Google sign-in failed. Please try again.',
          ar: 'فشل تسجيل الدخول بجوجل.',
          ur: 'گوگل سائن اِن ناکام ہوا۔',
          ru: 'Ошибка входа через Google.',
        ));
      }
    } catch (e) {
      if (mounted) _showStatus(_t(
        en: 'Google sign-in failed. Please try again.',
        ar: 'فشل تسجيل الدخول بجوجل.',
        ur: 'گوگل سائن اِن ناکام ہوا۔',
        ru: 'Ошибка входа через Google.',
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStatus(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        margin: const EdgeInsets.all(24),
        content: Text(_displayText(message)),
      ),
    );
  }
}

// ── Social-media-style profile view ───────────────────────────────────────────

class _SocialProfileView extends StatefulWidget {
  final User user;
  const _SocialProfileView({super.key, required this.user});

  @override
  State<_SocialProfileView> createState() => _SocialProfileViewState();
}

class _SocialProfileViewState extends State<_SocialProfileView> {
  UserPrayerStats? _stats;
  late final Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    // Cache the stream here so build() never creates a new Firestore listener.
    // Creating snapshots() inline in build() causes a race condition in the
    // Firestore Web SDK where didUpdateWidget cancels the subscription before
    // onSnapshot has fired, triggering LateInitializationError.
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await PrayerRepository().getCurrentUserStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : MinaretTheme.onyx;
    final textSecondary = isDark ? Colors.white54 : MinaretTheme.slate;
    final cardColor = isDark ? const Color(0xFF1C2430) : Colors.white;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // ── Top bar: title + settings gear ────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.profileTitleShort,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                    color: MinaretTheme.gold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: const LanguageSelector(compact: true),
                    ),
                    const SizedBox(width: 8),
                    _circleIconButton(
                      icon: Icons.settings_outlined,
                      isDark: isDark,
                      tooltip: 'Settings',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Identity (centered avatar, name, role) ─────────────────────
          StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              final displayName = data?['displayName'] as String?;
              final userRole = data?['role'] as String?;
              final initial = (displayName?.isNotEmpty == true
                      ? displayName![0]
                      : (widget.user.email?.isNotEmpty == true
                          ? widget.user.email![0]
                          : '?'))
                  .toUpperCase();
              final isImam = userRole == kRoleImam;
              final accent = isImam ? MinaretTheme.emerald : MinaretTheme.gold;

              return Column(
                children: [
                  // Avatar with glow ring + edit pencil badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: 0.18),
                              accent.withValues(alpha: 0.06),
                            ],
                          ),
                          border: Border.all(color: accent.withValues(alpha: 0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.amiri(
                              fontSize: 42,
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // Edit pencil badge
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Material(
                          color: accent,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => isImam
                                    ? const ImamProfilePage()
                                    : const EditProfilePage(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    displayName?.isNotEmpty == true
                        ? displayName!
                        : (widget.user.email ?? 'User'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  if (widget.user.email?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.user.email!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(fontSize: 13, color: textSecondary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Role chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isImam ? Icons.mosque_rounded : Icons.people_alt_rounded,
                            size: 11, color: accent),
                        const SizedBox(width: 5),
                        Text(
                          isImam ? l10n.profileImam : l10n.profileCommunity,
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // ── Stats card ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: MinaretTheme.cardShadow,
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    value: _stats != null ? '${_stats!.totalPrayers}' : '—',
                    label: l10n.statPrayers,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                _statDivider(isDark),
                Expanded(
                  child: _StatColumn(
                    value: _stats != null ? '${_stats!.currentStreak}' : '—',
                    label: l10n.statStreak,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                _statDivider(isDark),
                Expanded(
                  child: _StatColumn(
                    value: _stats != null
                        ? '${(_stats!.overallCompletionRate * 100).round()}%'
                        : '—',
                    label: l10n.statRate,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Progress card ──────────────────────────────────────────────
          _ProfileProgressTile(uid: widget.user.uid),

          const SizedBox(height: 14),

          // ── Quick actions ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: MinaretTheme.cardShadow,
            ),
            child: Column(
              children: [
                _ProfileMenuRow(
                  icon: Icons.analytics_outlined,
                  label: l10n.prayerStatisticsLabel,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrayerStatsPage()),
                  ),
                ),
                _menuDivider(isDark),
                _ProfileMenuRow(
                  icon: Icons.pending_actions_outlined,
                  label: l10n.qadaPrayersTitle,
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QadaPage()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _statDivider(bool isDark) => Container(
        width: 1,
        height: 34,
        color: isDark ? Colors.white12 : MinaretTheme.dividerColor,
      );

  Widget _menuDivider(bool isDark) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 54,
        color: isDark ? Colors.white12 : MinaretTheme.dividerColor,
      );

  Widget _circleIconButton({
    required IconData icon,
    required bool isDark,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: MinaretTheme.gold),
        ),
      ),
    );
  }
}

// ── Profile menu row (quick action) ───────────────────────────────────────────

class _ProfileMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : MinaretTheme.onyx;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: MinaretTheme.gold),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: isDark ? Colors.white38 : MinaretTheme.slate),
          ],
        ),
      ),
    );
  }
}

// ── Stat column (Prayers / Streak / Rate) ─────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color textPrimary;
  final Color textSecondary;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 11,
            color: textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Progress tile shown on the profile screen ─────────────────────────────────
//
// Must be StatefulWidget so the ProgressRepository and its Firestore listener
// are created once and reused across parent rebuilds. Creating a new stream on
// every build() call causes rapid listener open/cancel cycles that trigger
// Firestore Web SDK internal assertion failures.

class _ProfileProgressTile extends StatefulWidget {
  final String uid;
  const _ProfileProgressTile({required this.uid});

  @override
  State<_ProfileProgressTile> createState() => _ProfileProgressTileState();
}

class _ProfileProgressTileState extends State<_ProfileProgressTile> {
  final _repo = ProgressRepository();
  late final Stream<UserProgress> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repo.progressStream();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1C2430) : Colors.white;
    final textPrimary = isDark ? Colors.white : MinaretTheme.onyx;
    final textSecondary = isDark ? Colors.white54 : MinaretTheme.slate;

    return StreamBuilder<UserProgress>(
      stream: _stream,
      builder: (context, snap) {
        final progress = snap.data ?? UserProgress.empty(widget.uid);
        final atMax = progress.level >= 7;

        return Material(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          elevation: 0,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProgressPage()),
            ),
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: MinaretTheme.cardShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      LevelBadge(level: progress.level),
                      const SizedBox(width: 12),
                      Text(
                        l10n.progressMyProgress,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                      CoinCounter(coins: progress.currentCoins, compact: true),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded,
                          color: textSecondary, size: 20),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!atMax) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.levelProgress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: MinaretTheme.gold.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(MinaretTheme.gold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        l10n.progressPointsToNext(progress.coinsToNextLevel, progress.level + 1),
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded,
                            size: 14, color: MinaretTheme.gold),
                        const SizedBox(width: 6),
                        Text(
                          l10n.progressMaxLevel,
                          style: GoogleFonts.cairo(
                            color: MinaretTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
