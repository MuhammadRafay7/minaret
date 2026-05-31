import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';
import '../../core/input_validator.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/location_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Standardized location (Country → State → City). Initialized from the stored
  // doc; emits canonical names + ISO codes via the picker.
  LocationValue _location = const LocationValue();
  String? _initCountryCode;
  String? _initStateCode;
  String? _initCityName;

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
        _initCountryCode = data['countryCode'] as String?;
        _initStateCode = data['stateCode'] as String?;
        _initCityName = data['city'] as String?;
        _location = LocationValue(
          countryName: data['country'] as String?,
          countryCode: data['countryCode'] as String?,
          stateName: data['state'] as String?,
          stateCode: data['stateCode'] as String?,
          cityName: data['city'] as String?,
        );
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
      final update = <String, dynamic>{
        'displayName': name,
        'gender': _selectedGender,
        'phoneNumber': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Only write location when one is set, so we never blank out a legacy
      // value that the user didn't touch. Stores canonical names + ISO codes.
      if (_location.countryName != null) {
        update['country'] = _location.countryName;
        update['countryCode'] = _location.countryCode;
        update['state'] = _location.stateName;
        update['stateCode'] = _location.stateCode;
        update['city'] = _location.cityName;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(update);
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

  AppLocalizations get _l => AppLocalizations.of(context)!;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => _isDark ? Colors.white70 : MinaretTheme.slate;
  Color get _lineColor => _isDark ? Colors.white24 : MinaretTheme.dividerColor;

  Color get _cardColor => _isDark ? const Color(0xFF1C2430) : Colors.white;

  Widget _backButton() {
    return Material(
      color: _isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.pop(context),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: _isDark ? Colors.white : MinaretTheme.onyx, size: 18),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          title,
          style: GoogleFonts.montserrat(
            color: MinaretTheme.gold,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AtelierLayout(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: MinaretTheme.gold,
                  strokeWidth: 1,
                ),
              )
            : Column(
                children: [
                  const SizedBox(height: 60),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        _backButton(),
                        const SizedBox(width: 12),
                        Text(
_displayText(_l.editProfileTitle),
                          style: MinaretTheme.heading
                              .copyWith(fontSize: 22, letterSpacing: 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
_sectionHeader(_displayText(_l.sectionPersonalDetails)),
                          _buildField(
                            _l.fieldFullName,
                            _nameController,
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            _l.fieldPhone,
                            _phoneController,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            hint: _l.fieldOptional,
                          ),
                          const SizedBox(height: 16),
                          _sectionHeader(_displayText(_l.fieldCountry)),
                          LocationPicker(
                            initialCountryCode: _initCountryCode,
                            initialStateCode: _initStateCode,
                            initialCityName: _initCityName,
                            countryLabel: _l.fieldCountry,
                            cityLabel: _l.fieldCity,
                            stateLabel: _t(
                              en: 'State / Province',
                              ar: 'الولاية / المحافظة',
                              ur: 'صوبہ',
                              ru: 'Регион',
                            ),
                            onChanged: (loc) => setState(() => _location = loc),
                          ),
                          const SizedBox(height: 26),
                          _sectionHeader(_displayText(
_l.genderLabel)),
                          _buildGenderSelector(),
                          const SizedBox(height: 40),
                          PremiumButton(
                            text: _displayText(_l.saveChangesLabel),
                            onPressed: _isSaving ? null : _saveProfile,
                            type: ButtonType.primary,
                            isLoading: _isSaving,
                            borderRadius: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MinaretTheme.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: MinaretTheme.gold),
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
                  keyboardType: keyboardType,
                  cursorColor: MinaretTheme.gold,
                  cursorWidth: 1.2,
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    hintText: hint,
                    hintStyle: GoogleFonts.lato(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    final genders = [
      ('male', _l.maleLabel),
      ('female', _l.femaleLabel),
      ('other', _l.genderOther),
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
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _selectedGender == genders[i].$1
                      ? MinaretTheme.gold
                      : _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    width: 1.5,
                    color: _selectedGender == genders[i].$1
                        ? MinaretTheme.gold
                        : _lineColor,
                  ),
                  boxShadow: _selectedGender == genders[i].$1
                      ? null
                      : MinaretTheme.cardShadow,
                ),
                child: Center(
                  child: Text(
                    _displayText(genders[i].$2),
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
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
