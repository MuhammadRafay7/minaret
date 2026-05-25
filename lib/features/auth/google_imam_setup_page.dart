import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:minaret/core/constants/app_defaults.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/widgets/premium_button.dart';
import '../mosque/create_mosque_page.dart';
import 'document_verification.dart';

class GoogleImamSetupPage extends StatefulWidget {
  final String uid;
  final String email;
  final String displayName;
  final VoidCallback onLoginSuccess;

  const GoogleImamSetupPage({
    super.key,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.onLoginSuccess,
  });

  @override
  State<GoogleImamSetupPage> createState() => _GoogleImamSetupPageState();
}

class _GoogleImamSetupPageState extends State<GoogleImamSetupPage> {
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _teachingFeeController = TextEditingController();
  final _teachingNotesController = TextEditingController();
  final _cityController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _offersTeaching = false;
  String _teachingAudience = kDefaultTeachingAudience;
  String _selectedCountry = 'PK';

  Uint8List? _idCardImage;
  Uint8List? _idCardBackImage;
  Uint8List? _sanadImage;
  String? _idCardBase64;
  String? _idCardBackBase64;
  String? _sanadBase64;

  ImamVerificationResult? _verificationResult;
  bool _isVerifying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.displayName;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _phoneController.dispose();
    _teachingFeeController.dispose();
    _teachingNotesController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => _isDark ? Colors.white70 : MinaretTheme.slate;
  Color get _lineColor => _isDark ? Colors.white24 : MinaretTheme.dividerColor;
  Color get _surfaceColor =>
      _isDark ? const Color(0xFF151B24) : Colors.white.withValues(alpha: 0.45);

  String _t({required String en, required String ar, required String ur, required String ru}) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'ar': return ar;
      case 'ur': return ur;
      case 'ru': return ru;
      default: return en;
    }
  }

  String _d(String value) {
    final lang = Localizations.localeOf(context).languageCode;
    return (lang == 'ar' || lang == 'ur') ? value : value.toUpperCase();
  }

  Future<void> _pickImage({bool isIdCard = false, bool isIdCardBack = false}) async {
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
    if (_idCardImage != null && _idCardBackImage != null && _sanadImage != null) {
      await _runVerification();
    }
  }

  Future<void> _runVerification() async {
    if (_idCardImage == null || _idCardBackImage == null || _sanadImage == null) return;
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
    } catch (_) {
      if (mounted) {
        setState(() => _verificationResult = const ImamVerificationResult(
          approved: false,
          status: 'needs_review',
          score: 0,
          reason: 'On-device verification encountered an error. Documents saved for manual review.',
          nameMatchConfidence: 0,
        ));
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _submit() async {
    final fullName = _fullNameController.text.trim();
    final fatherName = _fatherNameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();

    if (fullName.isEmpty) {
      _showStatus(_t(en: 'Please enter your full name', ar: 'أدخل اسمك الكامل', ur: 'اپنا پورا نام درج کریں', ru: 'Введите полное имя'));
      return;
    }
    if (fatherName.isEmpty) {
      _showStatus(_t(en: "Please enter your father's name", ar: 'أدخل اسم الأب', ur: 'والد کا نام درج کریں', ru: "Введите имя отца"));
      return;
    }
    if (phone.isEmpty) {
      _showStatus(_t(en: 'Please enter your phone number', ar: 'أدخل رقم هاتفك', ur: 'فون نمبر درج کریں', ru: 'Введите номер телефона'));
      return;
    }
    if (city.isEmpty) {
      _showStatus(_t(en: 'Please enter your city', ar: 'أدخل مدينتك', ur: 'اپنا شہر درج کریں', ru: 'Введите ваш город'));
      return;
    }
    if (_idCardBase64 == null || _idCardBackBase64 == null || _sanadBase64 == null) {
      _showStatus(_t(
        en: 'Please upload both sides of your ID card and your Sanad/Certificate.',
        ar: 'يرجى تحميل كلا الجانبين من بطاقة الهوية والسند/الشهادة.',
        ur: 'براہ کرم اپنے شناختی کارڈ کے دونوں طرف اور سند/سرٹیفکیٹ اپلوڈ کریں۔',
        ru: 'Загрузите обе стороны удостоверения личности и санад/сертификат.',
      ));
      return;
    }
    if (_verificationResult?.status == 'rejected') {
      _showStatus(_t(
        en: 'Documents do not match. Please upload correct documents.',
        ar: 'المستندات غير متطابقة. يرجى تحميل المستندات الصحيحة.',
        ur: 'دستاویزات میل نہیں کھاتیں۔ درست دستاویزات اپلوڈ کریں۔',
        ru: 'Документы не совпадают. Загрузите корректные документы.',
      ));
      return;
    }
    if (_isVerifying) {
      _showStatus(_t(
        en: 'Documents are still being verified. Please wait.',
        ar: 'جارٍ التحقق من المستندات. يرجى الانتظار.',
        ur: 'دستاویزات کی تصدیق جاری ہے۔ انتظار کریں۔',
        ru: 'Документы ещё проверяются. Подождите.',
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'email': widget.email,
        'displayName': widget.displayName,
        'role': kRoleImam,
        'city': city,
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
        'fullName': fullName,
        'fatherName': fatherName,
        'phoneNumber': phone,
        'imamProfile': {
          'fullName': fullName,
          'fatherName': fatherName,
          'phoneNumber': phone,
          'offersTeaching': _offersTeaching,
          'teachingAudience': _offersTeaching ? _teachingAudience : null,
          'teachingFee': _offersTeaching ? _teachingFeeController.text.trim() : null,
          'teachingNotes': _offersTeaching ? _teachingNotesController.text.trim() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'idCardBase64': _idCardBase64,
        'idCardBackBase64': _idCardBackBase64,
        'sanadBase64': _sanadBase64,
        'documentsVerified': _verificationResult?.approved ?? false,
        'verificationStatus': _verificationResult?.status ?? 'needs_review',
        'verificationScore': _verificationResult?.score ?? 0,
        'verificationReason': _verificationResult?.reason ?? '',
        'nameMatchConfidence': _verificationResult?.nameMatchConfidence ?? 0,
        'verificationMethod': 'on_device_mlkit',
        'verificationCountry': _selectedCountry,
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateMosquePage()),
      ).then((_) {
        if (mounted) widget.onLoginSuccess();
      });
    } catch (e) {
      if (mounted) {
        _showStatus(_t(
          en: 'Registration failed. Please try again.',
          ar: 'فشل التسجيل. يرجى المحاولة مرة أخرى.',
          ur: 'رجسٹریشن ناکام ہوئی۔ دوبارہ کوشش کریں۔',
          ru: 'Ошибка регистрации. Попробуйте снова.',
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStatus(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(margin: const EdgeInsets.all(24), content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        await FirebaseAuth.instance.signOut();
      },
      child: AtelierLayout(
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ',
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  color: MinaretTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                _d(_t(
                  en: 'Imam Registration',
                  ar: 'تسجيل الإمام',
                  ur: 'امام رجسٹریشن',
                  ru: 'Регистрация имама',
                )),
                style: MinaretTheme.heading,
              ),
              const SizedBox(height: 6),
              Text(
                _t(
                  en: 'Complete your profile to set up your mosque.',
                  ar: 'أكمل ملفك الشخصي لإعداد مسجدك.',
                  ur: 'اپنی مسجد ترتیب دینے کے لیے پروفائل مکمل کریں۔',
                  ru: 'Заполните профиль для настройки мечети.',
                ),
                style: GoogleFonts.lato(fontSize: 13, color: _textSecondary, height: 1.6),
              ),
              const SizedBox(height: 32),

              // Personal Details
              _sectionLabel(_t(en: 'Personal Details', ar: 'البيانات الشخصية', ur: 'ذاتی معلومات', ru: 'Личные данные')),
              const SizedBox(height: 16),
              _field(_t(en: 'Full Name', ar: 'الاسم الكامل', ur: 'پورا نام', ru: 'Полное имя'), _fullNameController),
              const SizedBox(height: 16),
              _field(_t(en: "Father's Name", ar: 'اسم الأب', ur: 'والد کا نام', ru: 'Имя отца'), _fatherNameController),
              const SizedBox(height: 16),
              _field(_t(en: 'Phone Number', ar: 'رقم الهاتف', ur: 'فون نمبر', ru: 'Номер телефона'), _phoneController,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _field(_t(en: 'City', ar: 'المدينة', ur: 'شہر', ru: 'Город'), _cityController),
              const SizedBox(height: 18),

              // Teaching toggle
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _t(en: 'Available to teach', ar: 'متاح للتعليم', ur: 'تعلیم کے لیے دستیاب', ru: 'Готов обучать'),
                      style: MinaretTheme.label.copyWith(color: _textSecondary, letterSpacing: 1.4, fontSize: 9),
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
                      child: Text(_t(en: 'Neighbourhood learners', ar: 'متعلمين من الحي', ur: 'محلے کے سیکھنے والے', ru: 'Ученики из района')),
                    ),
                    DropdownMenuItem(
                      value: kTeachingAudienceAnyone,
                      child: Text(_t(en: 'Anyone', ar: 'أي شخص', ur: 'کوئی بھی', ru: 'Любой')),
                    ),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _teachingAudience = v); },
                  decoration: InputDecoration(
                    labelText: _t(en: 'Teaching Audience', ar: 'الفئة التعليمية', ur: 'تعلیم کا دائرہ', ru: 'Аудитория'),
                  ),
                ),
                const SizedBox(height: 16),
                _field(_t(en: 'Teaching Fee', ar: 'رسوم التعليم', ur: 'تدریسی فیس', ru: 'Плата'), _teachingFeeController,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _field(_t(en: 'Subjects / notes (optional)', ar: 'ملاحظات (اختياري)', ur: 'نوٹس (اختیاری)', ru: 'Заметки (необязательно)'),
                    _teachingNotesController),
              ],

              // Document Verification
              const SizedBox(height: 32),
              _sectionLabel(_t(en: 'Document Verification', ar: 'التحقق من المستندات', ur: 'دستاویز کی تصدیق', ru: 'Проверка документов')),
              const SizedBox(height: 6),
              Text(
                _t(
                  en: 'Upload your CNIC/Passport and your Sanad or certificate. Verification runs on your device — documents stay private.',
                  ar: 'قم بتحميل بطاقة الهوية والسند. يتم التحقق على جهازك — وتبقى مستنداتك خاصة.',
                  ur: 'اپنا شناختی کارڈ/پاسپورٹ اور سند اپلوڈ کریں۔ تصدیق آپ کے آلے پر ہوتی ہے — دستاویزات نجی رہتی ہیں۔',
                  ru: 'Загрузите удостоверение личности и санад. Проверка происходит на устройстве — документы остаются конфиденциальными.',
                ),
                style: GoogleFonts.lato(fontSize: 11, color: _textSecondary, height: 1.7),
              ),
              const SizedBox(height: 20),
              _countrySelector(),
              const SizedBox(height: 16),
              _documentField(
                label: _t(en: 'CNIC / Passport', ar: 'بطاقة الهوية / جواز السفر', ur: 'شناختی کارڈ / پاسپورٹ', ru: 'Удостоверение / Паспорт'),
                imageBytes: _idCardImage,
                isUploaded: _idCardBase64 != null,
                onPick: () => _pickImage(isIdCard: true),
              ),
              const SizedBox(height: 16),
              _documentField(
                label: _t(en: 'CNIC / Passport (Back Side)', ar: 'بطاقة الهوية / جواز السفر (الظهر)', ur: 'شناختی کارڈ / پاسپورٹ (پشت)', ru: 'Удостоверение / Паспорт (Обратная сторона)'),
                imageBytes: _idCardBackImage,
                isUploaded: _idCardBackBase64 != null,
                onPick: () => _pickImage(isIdCardBack: true),
              ),
              const SizedBox(height: 16),
              _documentField(
                label: _t(en: 'Sanad / Islamic Certificate', ar: 'السند / الشهادة الدينية', ur: 'سند / اسلامی سرٹیفکیٹ', ru: 'Санад / Исламский сертификат'),
                imageBytes: _sanadImage,
                isUploaded: _sanadBase64 != null,
                onPick: () => _pickImage(),
              ),
              const SizedBox(height: 16),
              _verificationStatus(),
              const SizedBox(height: 40),

              // Submit
              PremiumButton(
                text: _d(_t(en: 'Complete Registration', ar: 'إتمام التسجيل', ur: 'رجسٹریشن مکمل کریں', ru: 'Завершить регистрацию')),
                onPressed: _isLoading ? null : _submit,
                type: ButtonType.primary,
                isLoading: _isLoading,
                borderRadius: 0,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _sectionLabel(String text) => Text(_d(text), style: MinaretTheme.label);

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: MinaretTheme.gold,
      cursorWidth: 1.2,
      style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
      decoration: InputDecoration(
        labelText: _d(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: GoogleFonts.lato(fontSize: 13, color: _textSecondary.withValues(alpha: 0.7)),
      ),
    );
  }

  Widget _countrySelector() {
    final countries = InternationalDocumentVerificationService.getSupportedCountries();
    const flags = {
      'PK': '🇵🇰', 'US': '🇺🇸', 'GB': '🇬🇧', 'SA': '🇸🇦', 'AE': '🇦🇪',
      'IN': '🇮🇳', 'EG': '🇪🇬', 'TR': '🇹🇷', 'FR': '🇫🇷', 'DE': '🇩🇪', 'GENERIC': '🌍',
    };
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
          items: countries.map((code) {
            final config = InternationalDocumentVerificationService.getCountryConfig(code);
            return DropdownMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Text(flags[code] ?? '🌍', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(config.name,
                        style: GoogleFonts.lato(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() { _selectedCountry = value; _verificationResult = null; });
          },
        ),
      ),
    );
  }

  Widget _documentField({
    required String label,
    required Uint8List? imageBytes,
    required bool isUploaded,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_d(label), style: MinaretTheme.label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surfaceColor,
              border: Border.all(
                color: isUploaded ? MinaretTheme.emerald.withValues(alpha: 0.5) : _lineColor,
                width: isUploaded ? 1.2 : 0.8,
              ),
            ),
            child: imageBytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(imageBytes, fit: BoxFit.cover),
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          color: Colors.black54,
                          child: Text(
                            _t(en: 'Change', ar: 'تغيير', ur: 'تبدیل کریں', ru: 'Изменить'),
                            style: GoogleFonts.montserrat(fontSize: 7, color: Colors.white, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 30, color: MinaretTheme.gold.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        _t(en: 'Tap to upload', ar: 'انقر للتحميل', ur: 'اپلوڈ کرنے کے لیے ٹیپ کریں', ru: 'Нажмите для загрузки'),
                        style: GoogleFonts.montserrat(fontSize: 8.5, color: _textSecondary, letterSpacing: 1),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _verificationStatus() {
    if (_idCardBase64 == null || _idCardBackBase64 == null || _sanadBase64 == null) {
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
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: MinaretTheme.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t(en: 'Scanning documents on device…', ar: 'جارٍ مسح المستندات على الجهاز…', ur: 'آلے پر دستاویزات اسکین ہو رہی ہیں…', ru: 'Сканирование документов на устройстве…'),
                style: GoogleFonts.montserrat(fontSize: 8.5, color: MinaretTheme.gold, letterSpacing: 0.8),
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
          ur: 'دستاویزات میل نہیں کھاتیں۔ درست دستاویزات اپلوڈ کریں۔',
          ru: 'Документы не совпадают. Загрузите корректные документы.',
        );
        break;
      default:
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
                child: Text(statusText,
                    style: GoogleFonts.montserrat(fontSize: 8.5, color: statusColor, letterSpacing: 0.5, height: 1.5)),
              ),
            ],
          ),
          if (result.reason.isNotEmpty && result.status != 'approved') ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(result.reason, style: GoogleFonts.lato(fontSize: 11, color: _textSecondary, height: 1.6)),
            ),
          ],
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(en: 'Match score', ar: 'درجة التطابق', ur: 'میچ سکور', ru: 'Оценка совпадения'),
                  style: GoogleFonts.montserrat(fontSize: 7, letterSpacing: 1.5, color: _textSecondary),
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
                Text('${result.score}/100',
                    style: GoogleFonts.ibmPlexMono(fontSize: 8, color: statusColor)),
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
                  _d(_t(en: 'Clear and re-upload', ar: 'مسح وإعادة التحميل', ur: 'صاف کریں اور دوبارہ اپلوڈ کریں', ru: 'Очистить и загрузить снова')),
                  style: GoogleFonts.montserrat(
                    fontSize: 8, letterSpacing: 1.5, color: statusColor,
                    decoration: TextDecoration.underline, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
