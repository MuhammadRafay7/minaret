import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';
import '../../core/input_validator.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/premium_button.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();

  String _selectedGender = 'male';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    if (mounted) {
      setState(() {
        _nameController.text = data['displayName'] as String? ?? '';
        _phoneController.text = data['phoneNumber'] as String? ?? '';
        _cityController.text = data['city'] as String? ?? '';
        final g = data['gender'] as String?;
        _selectedGender = (g == 'male' || g == 'female' || g == 'other')
            ? g!
            : 'male';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final nameValidation = InputValidator.validateName(name);
    if (!nameValidation.isValid) {
      _showStatus(nameValidation.errorMessage!);
      return;
    }
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'displayName': name,
        'gender': _selectedGender,
        'phoneNumber': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showStatus(_t(
          en: 'Profile updated successfully.',
          ar: 'تم تحديث الملف الشخصي بنجاح.',
          ur: 'پروفائل کامیابی سے اپ ڈیٹ ہو گئی۔',
          ru: 'Профиль обновлён.',
        ));
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        _showStatus(_t(
          en: 'Failed to update profile. Please try again.',
          ar: 'فشل تحديث الملف الشخصي.',
          ur: 'پروفائل اپ ڈیٹ نہیں ہوئی۔ دوبارہ کوشش کریں۔',
          ru: 'Не удалось обновить профиль.',
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showStatus(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(margin: const EdgeInsets.all(24), content: Text(message)),
    );
  }

  String _t({
    required String en,
    required String ar,
    required String ur,
    required String ru,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'ar':
        return ar;
      case 'ur':
        return ur;
      case 'ru':
        return ru;
      default:
        return en;
    }
  }

  String _displayText(String value) {
    final locale = Localizations.localeOf(context).languageCode;
    return (locale == 'ar' || locale == 'ur') ? value : value.toUpperCase();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => _isDark ? Colors.white70 : MinaretTheme.slate;
  Color get _lineColor => _isDark ? Colors.white24 : MinaretTheme.dividerColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AtelierLayout(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: MinaretTheme.gold,
                    strokeWidth: 1,
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back_ios,
                              size: 16,
                              color: _textSecondary,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayText(_t(
                                  en: 'Edit Profile',
                                  ar: 'تعديل الملف الشخصي',
                                  ur: 'پروفائل ترمیم',
                                  ru: 'Редактировать',
                                )),
                                style: MinaretTheme.heading.copyWith(
                                  fontSize: 24,
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _t(
                                  en: 'Update your personal information',
                                  ar: 'تحديث معلوماتك الشخصية',
                                  ur: 'اپنی ذاتی معلومات اپ ڈیٹ کریں',
                                  ru: 'Обновите личные данные',
                                ),
                                style: MinaretTheme.label,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),

                      _buildField(
                        _t(en: 'Full Name', ar: 'الاسم الكامل', ur: 'پورا نام', ru: 'Полное имя'),
                        _nameController,
                        false,
                      ),
                      const SizedBox(height: 28),

                      Text(
                        _displayText(_t(en: 'Gender', ar: 'الجنس', ur: 'جنس', ru: 'Пол')),
                        style: MinaretTheme.label,
                      ),
                      const SizedBox(height: 12),
                      _buildGenderSelector(),
                      const SizedBox(height: 28),

                      _buildField(
                        _t(en: 'Phone Number', ar: 'رقم الهاتف', ur: 'فون نمبر', ru: 'Телефон'),
                        _phoneController,
                        false,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 28),

                      _buildField(
                        _t(en: 'City', ar: 'المدينة', ur: 'شہر', ru: 'Город'),
                        _cityController,
                        false,
                      ),
                      const SizedBox(height: 50),

                      PremiumButton(
                        text: _displayText(_t(
                          en: 'Save Changes',
                          ar: 'حفظ التغييرات',
                          ur: 'تبدیلیاں محفوظ کریں',
                          ru: 'Сохранить',
                        )),
                        onPressed: _isSaving ? null : _saveProfile,
                        type: ButtonType.primary,
                        isLoading: _isSaving,
                        borderRadius: 0,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    bool isObscure, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      cursorColor: MinaretTheme.gold,
      cursorWidth: 1.2,
      style: GoogleFonts.lato(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _textPrimary,
      ),
      decoration: InputDecoration(
        labelText: _displayText(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintStyle: GoogleFonts.lato(
          fontSize: 13,
          color: _textSecondary.withValues(alpha: 0.7),
        ),
      ),
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
}
