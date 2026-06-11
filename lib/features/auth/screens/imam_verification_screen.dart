import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_spacing.dart';
import '../../../core/locale_text.dart';
import '../../../core/theme.dart';
import '../../../widgets/atelier_layout.dart';
import '../notifiers/auth_notifier.dart';
import '../services/verification_service.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/document_upload_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ImamVerificationScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen document upload and on-device OCR verification step.
///
/// Navigated to from [SignupForm] when the user selects the imam role.
/// Pops with an [ImamRegistrationData] on success (or null if cancelled).
class ImamVerificationScreen extends StatefulWidget {
  /// Pre-fill from the signup form so the imam profile can be built.
  final String displayName;

  const ImamVerificationScreen({
    super.key,
    required this.displayName,
  });

  @override
  State<ImamVerificationScreen> createState() =>
      _ImamVerificationScreenState();
}

class _ImamVerificationScreenState extends State<ImamVerificationScreen> {
  final _imagePicker = ImagePicker();
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _teachingFeeController = TextEditingController();
  final _teachingNotesController = TextEditingController();

  Uint8List? _idCardBytes;
  Uint8List? _idCardBackBytes;
  Uint8List? _sanadBytes;

  String _selectedCountry = 'PK';
  bool _offersTeaching = false;
  String _teachingAudience = 'neighbourhood';

  VerificationResult? _verificationResult;
  bool _isVerifying = false;
  String? _error;

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
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => _isDark ? Colors.white70 : MinaretTheme.slate;
  Color get _lineColor => _isDark ? Colors.white24 : MinaretTheme.dividerColor;

  // ── Image picking ─────────────────────────────────────────────────────────

  Future<void> _pickImage({
    required bool isIdFront,
    bool isIdBack = false,
  }) async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 88,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (isIdFront) {
        _idCardBytes = bytes;
      } else if (isIdBack) {
        _idCardBackBytes = bytes;
      } else {
        _sanadBytes = bytes;
      }
      _verificationResult = null;
    });
    if (_idCardBytes != null &&
        _idCardBackBytes != null &&
        _sanadBytes != null) {
      await _runVerification();
    }
  }

  Future<void> _runVerification() async {
    setState(() {
      _isVerifying = true;
      _verificationResult = null;
    });
    try {
      final result = await InternationalVerificationService.verify(
        idCardBytes: _idCardBytes!,
        idCardBackBytes: _idCardBackBytes!,
        sanadBytes: _sanadBytes!,
        countryCode: _selectedCountry,
      );
      if (mounted) setState(() => _verificationResult = result);
    } catch (_) {
      if (mounted) {
        setState(() => _verificationResult = const VerificationPending(
              score: 0,
              reason:
                  'On-device verification encountered an error. Documents saved for manual review.',
            ));
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Confirm & pop ─────────────────────────────────────────────────────────

  void _confirm() {
    if (_fullNameController.text.trim().isEmpty) {
      setState(() => _error = context.localText(
            en: 'Full name is required',
            ar: 'الاسم الكامل مطلوب',
            ur: 'پورا نام ضروری ہے',
            ru: 'Требуется полное имя',
          ));
      return;
    }
    if (_fatherNameController.text.trim().isEmpty) {
      setState(() => _error = context.localText(
            en: "Father's name is required",
            ar: 'اسم الأب مطلوب',
            ur: 'والد کا نام ضروری ہے',
            ru: "Имя отца обязательно",
          ));
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = context.localText(
            en: 'Phone number is required',
            ar: 'رقم الهاتف مطلوب',
            ur: 'فون نمبر ضروری ہے',
            ru: 'Номер телефона обязателен',
          ));
      return;
    }
    if (_idCardBytes == null ||
        _idCardBackBytes == null ||
        _sanadBytes == null) {
      setState(() => _error = context.localText(
            en: 'Please upload all three documents.',
            ar: 'يرجى تحميل الوثائق الثلاثة.',
            ur: 'براہ کرم تینوں دستاویزات اپلوڈ کریں۔',
            ru: 'Пожалуйста, загрузите все три документа.',
          ));
      return;
    }
    if (_isVerifying) {
      setState(() => _error = context.localText(
            en: 'Verification is still running. Please wait.',
            ar: 'جارٍ التحقق. يرجى الانتظار.',
            ur: 'تصدیق جاری ہے۔ انتظار کریں۔',
            ru: 'Проверка ещё идёт. Подождите.',
          ));
      return;
    }
    if (_verificationResult is VerificationFailure) {
      setState(() => _error = context.localText(
            en: 'Documents do not match. Please upload correct documents.',
            ar: 'المستندات غير متطابقة. يرجى تحميل المستندات الصحيحة.',
            ur: 'دستاویزات میل نہیں کھاتیں۔ براہ کرم درست دستاویزات اپلوڈ کریں۔',
            ru: 'Документы не совпадают. Загрузите корректные документы.',
          ));
      return;
    }

    setState(() => _error = null);

    final imamData = ImamRegistrationData(
      idCardBytes: _idCardBytes!,
      idCardBackBytes: _idCardBackBytes!,
      sanadBytes: _sanadBytes!,
      verificationResult:
          _verificationResult ?? const VerificationPending(score: 0, reason: 'Not yet verified'),
      countryCode: _selectedCountry,
      profile: ImamProfileData(
        fullName: _fullNameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        offersTeaching: _offersTeaching,
        teachingAudience: _teachingAudience,
        teachingFee: _offersTeaching
            ? double.tryParse(_teachingFeeController.text.trim())
            : null,
        teachingNotes:
            _offersTeaching ? _teachingNotesController.text.trim() : null,
      ),
    );

    Navigator.pop(context, imamData);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 16, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.localText(
            en: 'Imam Verification',
            ar: 'تحقق الإمام',
            ur: 'امام تصدیق',
            ru: 'Верификация имама',
          ),
          style: GoogleFonts.montserrat(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: AtelierLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildPersonalDetails(),
              const SizedBox(height: 32),
              _buildTeachingSection(),
              const SizedBox(height: 32),
              _buildDocumentSection(),
              const SizedBox(height: 32),
              _buildVerificationStatus(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AuthErrorBanner(_error!),
              ],
              const SizedBox(height: 40),
              _buildConfirmButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Personal details section ──────────────────────────────────────────────

  Widget _buildPersonalDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthSectionLabel(context.localText(
            en: 'Personal Details',
            ar: 'البيانات الشخصية',
            ur: 'ذاتی معلومات',
            ru: 'Личные данные')),
        const SizedBox(height: 16),
        _Field(
          label: context.localText(
              en: 'Full Name',
              ar: 'الاسم الكامل',
              ur: 'پورا نام',
              ru: 'Полное имя'),
          controller: _fullNameController,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
        const SizedBox(height: 16),
        _Field(
          label: context.localText(
              en: "Father's Name",
              ar: 'اسم الأب',
              ur: 'والد کا نام',
              ru: 'Имя отца'),
          controller: _fatherNameController,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
        const SizedBox(height: 16),
        _Field(
          label: context.localText(
              en: 'Phone Number',
              ar: 'رقم الهاتف',
              ur: 'فون نمبر',
              ru: 'Номер телефона'),
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        ),
      ],
    );
  }

  // ── Teaching section ──────────────────────────────────────────────────────

  Widget _buildTeachingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.localText(
                  en: 'Available to teach',
                  ar: 'متاح للتعليم',
                  ur: 'تعلیم کے لیے دستیاب',
                  ru: 'Готов обучать',
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
              activeColor: MinaretTheme.emerald,
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
                value: 'neighbourhood',
                child: Text(context.localText(
                  en: 'Neighbourhood learners',
                  ar: 'متعلمين من الحي',
                  ur: 'محلے کے سیکھنے والے',
                  ru: 'Ученики из района',
                )),
              ),
              DropdownMenuItem(
                value: 'anyone',
                child: Text(context.localText(
                    en: 'Anyone',
                    ar: 'أي شخص',
                    ur: 'کوئی بھی',
                    ru: 'Любой')),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _teachingAudience = v);
            },
            decoration: InputDecoration(
              labelText: context.localText(
                  en: 'Teaching Audience',
                  ar: 'الفئة التعليمية',
                  ur: 'تعلیم کا دائرہ',
                  ru: 'Аудитория'),
            ),
          ),
          const SizedBox(height: 16),
          _Field(
            label: context.localText(
                en: 'Teaching Fee',
                ar: 'رسوم التعليم',
                ur: 'تدریسی فیس',
                ru: 'Плата'),
            controller: _teachingFeeController,
            keyboardType: TextInputType.number,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
          ),
          const SizedBox(height: 16),
          _Field(
            label: context.localText(
              en: 'Subjects / notes (optional)',
              ar: 'ملاحظات (اختياري)',
              ur: 'نوٹس (اختیاری)',
              ru: 'Заметки (необязательно)',
            ),
            controller: _teachingNotesController,
            textPrimary: _textPrimary,
            textSecondary: _textSecondary,
          ),
        ],
      ],
    );
  }

  // ── Document section ──────────────────────────────────────────────────────

  Widget _buildDocumentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthSectionLabel(context.localText(
            en: 'Document Verification',
            ar: 'التحقق من المستندات',
            ur: 'دستاویز کی تصدیق',
            ru: 'Проверка документов')),
        const SizedBox(height: 8),
        Text(
          context.localText(
            en: 'Upload your CNIC/Passport (front & back) and your Sanad or certificate. '
                'Verification runs entirely on your device — documents stay private.',
            ar: 'قم بتحميل بطاقة الهوية والسند. يتم التحقق على جهازك — وتبقى مستنداتك خاصة.',
            ur: 'اپنا شناختی کارڈ/پاسپورٹ (سامنے اور پیچھے) اور سند اپلوڈ کریں۔ '
                'تصدیق آپ کے آلے پر ہوتی ہے — دستاویزات نجی رہتی ہیں۔',
            ru: 'Загрузите удостоверение личности (обе стороны) и санад. '
                'Проверка происходит на устройстве — документы остаются конфиденциальными.',
          ),
          style:
              GoogleFonts.lato(fontSize: 11, color: _textSecondary, height: 1.7),
        ),
        const SizedBox(height: 16),
        _buildCountrySelector(),
        const SizedBox(height: 16),
        DocumentUploadWidget(
          label: context.localText(
            en: 'CNIC / Passport (Front)',
            ar: 'بطاقة الهوية / جواز السفر (الأمام)',
            ur: 'شناختی کارڈ / پاسپورٹ (سامنے)',
            ru: 'Удостоверение / Паспорт (лицевая сторона)',
          ),
          imageBytes: _idCardBytes,
          onPick: () => _pickImage(isIdFront: true),
          isDark: _isDark,
        ),
        const SizedBox(height: 16),
        DocumentUploadWidget(
          label: context.localText(
            en: 'CNIC / Passport (Back)',
            ar: 'بطاقة الهوية / جواز السفر (الظهر)',
            ur: 'شناختی کارڈ / پاسپورٹ (پشت)',
            ru: 'Удостоверение / Паспорт (обратная сторона)',
          ),
          imageBytes: _idCardBackBytes,
          onPick: () => _pickImage(isIdFront: false, isIdBack: true),
          isDark: _isDark,
        ),
        const SizedBox(height: 16),
        DocumentUploadWidget(
          label: context.localText(
            en: 'Sanad / Islamic Certificate',
            ar: 'السند / الشهادة الدينية',
            ur: 'سند / اسلامی سرٹیفکیٹ',
            ru: 'Санад / Исламский сертификат',
          ),
          imageBytes: _sanadBytes,
          onPick: () => _pickImage(isIdFront: false),
          isDark: _isDark,
        ),
      ],
    );
  }

  Widget _buildCountrySelector() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E2630) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isDark ? Colors.white12 : Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountry,
          isExpanded: true,
          dropdownColor:
              _isDark ? const Color(0xFF1E2630) : Colors.white,
          items: InternationalVerificationService.supportedCountries
              .map((code) {
            final config =
                InternationalVerificationService.configFor(code);
            return DropdownMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  Text(_flagEmoji(code),
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text(
                    config.name,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: _isDark ? Colors.white.withOpacity(0.87) : Colors.black87,
                      fontWeight: FontWeight.w500,
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

  String _flagEmoji(String code) {
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
    return flags[code] ?? '🌍';
  }

  // ── Verification status banner ────────────────────────────────────────────

  Widget _buildVerificationStatus() {
    if (_idCardBytes == null ||
        _idCardBackBytes == null ||
        _sanadBytes == null) {
      return const SizedBox.shrink();
    }

    if (_isVerifying) {
      return _StatusBanner(
        icon: null,
        color: MinaretTheme.gold,
        isLoading: true,
        title: context.localText(
          en: 'Scanning documents on device…',
          ar: 'جارٍ مسح المستندات على الجهاز…',
          ur: 'آلے پر دستاویزات اسکین ہو رہی ہیں…',
          ru: 'Сканирование документов на устройстве…',
        ),
      );
    }

    final result = _verificationResult;
    if (result == null) return const SizedBox.shrink();

    final (color, icon, title) = switch (result) {
      VerificationSuccess(:final nameMatchConfidence) => (
          MinaretTheme.emerald,
          Icons.verified_outlined,
          context.localText(
            en: 'Verified — names match ($nameMatchConfidence% confidence)',
            ar: 'تم التحقق — الأسماء متطابقة ($nameMatchConfidence٪)',
            ur: 'تصدیق شدہ — نام میل کھاتے ہیں ($nameMatchConfidence٪)',
            ru: 'Подтверждено — имена совпадают ($nameMatchConfidence%)',
          ),
        ),
      VerificationFailure() => (
          Colors.redAccent,
          Icons.cancel_outlined,
          context.localText(
            en: 'Documents do not match. Please upload correct documents.',
            ar: 'المستندات غير متطابقة. يرجى تحميل الصحيحة.',
            ur: 'دستاویزات میل نہیں کھاتیں۔ درست دستاویزات اپلوڈ کریں۔',
            ru: 'Документы не совпадают. Загрузите корректные.',
          ),
        ),
      VerificationPending() => (
          MinaretTheme.gold,
          Icons.info_outline,
          context.localText(
            en: 'Confidence is low — documents saved for manual review. You may proceed.',
            ar: 'الثقة منخفضة — المستندات محفوظة للمراجعة. يمكنك المتابعة.',
            ur: 'اعتماد کم ہے — دستاویزات دستی جائزے کے لیے محفوظ۔ آگے بڑھ سکتے ہیں۔',
            ru: 'Низкая уверенность — документы сохранены на проверку. Можете продолжить.',
          ),
        ),
    };

    return Column(
      children: [
        _StatusBanner(
          icon: icon,
          color: color,
          isLoading: false,
          title: title,
        ),
        const SizedBox(height: 8),
        _ScoreBar(
          score: result.score,
          color: color,
          isDark: _isDark,
          lineColor: _lineColor,
          textSecondary: _textSecondary,
        ),
        if (result is VerificationFailure) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() {
              _idCardBytes = null;
              _idCardBackBytes = null;
              _sanadBytes = null;
              _verificationResult = null;
            }),
            child: Text(
              context.localText(
                en: 'Clear and re-upload',
                ar: 'مسح وإعادة التحميل',
                ur: 'صاف کریں اور دوبارہ اپلوڈ کریں',
                ru: 'Очистить и загрузить снова',
              ),
              style: GoogleFonts.montserrat(
                fontSize: 8,
                letterSpacing: 1.5,
                color: color,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Confirm button ────────────────────────────────────────────────────────

  Widget _buildConfirmButton() {
    final canProceed = _verificationResult != null &&
        _verificationResult is! VerificationFailure &&
        !_isVerifying;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            canProceed ? MinaretTheme.emerald : Colors.grey[400],
        minimumSize: const Size(double.infinity, 52),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
      onPressed: canProceed ? _confirm : null,
      child: Text(
        context.localText(
          en: 'Continue with Verification',
          ar: 'المتابعة مع التحقق',
          ur: 'تصدیق کے ساتھ جاری رکھیں',
          ru: 'Продолжить с верификацией',
        ),
        style: GoogleFonts.montserrat(
          fontSize: 9,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final Color textPrimary;
  final Color textSecondary;

  const _Field({
    required this.label,
    required this.controller,
    required this.textPrimary,
    required this.textSecondary,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: MinaretTheme.gold,
      cursorWidth: 1.2,
      style: GoogleFonts.lato(
          fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle:
            GoogleFonts.lato(fontSize: 13, color: textSecondary.withOpacity(0.7)),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData? icon;
  final Color color;
  final bool isLoading;
  final String title;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: color),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 8.5,
                color: color,
                letterSpacing: 0.8,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final int score;
  final Color color;
  final bool isDark;
  final Color lineColor;
  final Color textSecondary;

  const _ScoreBar({
    required this.score,
    required this.color,
    required this.isDark,
    required this.lineColor,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.localText(
              en: 'Match score',
              ar: 'درجة التطابق',
              ur: 'میچ سکور',
              ru: 'Оценка совпадения',
            ),
            style: GoogleFonts.montserrat(
                fontSize: 7, letterSpacing: 1.5, color: textSecondary),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: lineColor,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$score/100',
            style: GoogleFonts.ibmPlexMono(fontSize: 8, color: color),
          ),
        ],
      ),
    );
  }
}
