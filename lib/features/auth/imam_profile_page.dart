import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/constants/app_defaults.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import '../prayer/prayer_stats_page.dart';

class ImamProfilePage extends StatefulWidget {
  const ImamProfilePage({super.key});

  @override
  State<ImamProfilePage> createState() => _ImamProfilePageState();
}

class _ImamProfilePageState extends State<ImamProfilePage> {
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _teachingFeeController = TextEditingController();
  final _teachingNotesController = TextEditingController();

  bool _offersTeaching = false;
  String _teachingAudience = kDefaultTeachingAudience;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fatherNameController.dispose();
    _phoneNumberController.dispose();
    _teachingFeeController.dispose();
    _teachingNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final imamData = data['imamProfile'] as Map<String, dynamic>? ?? {};

        setState(() {
          _fullNameController.text = data['fullName'] ?? imamData['fullName'] ?? '';
          _fatherNameController.text = data['fatherName'] ?? imamData['fatherName'] ?? '';
          _phoneNumberController.text = data['phoneNumber'] ?? imamData['phoneNumber'] ?? '';
          
          _offersTeaching = imamData['offersTeaching'] ?? false;
          _teachingAudience = imamData['teachingAudience'] ?? kDefaultTeachingAudience;
          _teachingFeeController.text = imamData['teachingFee'] ?? '';
          _teachingNotesController.text = imamData['teachingNotes'] ?? '';
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading imam profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final updateData = {
        'fullName': _fullNameController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'imamProfile': {
          'fullName': _fullNameController.text.trim(),
          'fatherName': _fatherNameController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'offersTeaching': _offersTeaching,
          'teachingAudience': _offersTeaching ? _teachingAudience : null,
          'teachingFee': _offersTeaching ? _teachingFeeController.text.trim() : null,
          'teachingNotes': _offersTeaching ? _teachingNotesController.text.trim() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));
      
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileUpdatedSuccess)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorSavingProfile(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _t({required String en, required String ar, required String ur, required String ru}) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'ar': return ar;
      case 'ur': return ur;
      case 'ru': return ru;
      default: return en;
    }
  }

  String _displayText(String value) {
    final locale = Localizations.localeOf(context).languageCode;
    return (locale == 'ar' || locale == 'ur') ? value : value.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? Colors.white70 : MinaretTheme.slate;

    return Scaffold(
      body: AtelierLayout(
        child: Column(
          children: [
            const SizedBox(height: 60),
            _buildHeader(isDark),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  children: [
                    _buildSectionLabel(_t(en: 'Personal Details', ar: 'البيانات الشخصية', ur: 'ذاتی معلومات', ru: 'Личные данные')),
                    const SizedBox(height: 20),
                    _buildModernField(_t(en: 'Full Name', ar: 'الاسم الكامل', ur: 'پورا نام', ru: 'Полное имя'), _fullNameController),
                    const SizedBox(height: 16),
                    _buildModernField(_t(en: "Father's Name", ar: 'اسم الأب', ur: 'والد کا نام', ru: 'Имя отца'), _fatherNameController),
                    const SizedBox(height: 16),
                    _buildModernField(_t(en: 'Phone Number', ar: 'رقم الهاتف', ur: 'فون نمبر', ru: 'Номер телефона'), _phoneNumberController, keyboardType: TextInputType.phone),
                    
                    const SizedBox(height: 40),
                    _buildSectionLabel(_t(en: 'Teaching Profile', ar: 'الملف التعليمي', ur: 'تدریسی پروفائل', ru: 'Профиль обучения')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayText(_t(en: 'Available to teach', ar: 'متاح للتعليم', ur: 'تعلیم کے لیے دستیاب', ru: 'Готов обучать')),
                            style: MinaretTheme.label.copyWith(color: textSecondary, fontSize: 10),
                          ),
                        ),
                        Switch(
                          value: _offersTeaching,
                          onChanged: (v) => setState(() => _offersTeaching = v),
                        ),
                      ],
                    ),
                    if (_offersTeaching) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _teachingAudience,
                        dropdownColor: isDark ? const Color(0xFF1A212B) : Colors.white,
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
                          labelText: _displayText(_t(en: 'Teaching Audience', ar: 'الفئة التعليمية', ur: 'تعلیم کا دائرہ', ru: 'Аудитория')),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModernField(_t(en: 'Teaching Fee', ar: 'رسوم التعليم', ur: 'تدریسی فیس', ru: 'Плата'), _teachingFeeController, keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      _buildModernField(_t(en: 'Subjects / notes', ar: 'ملاحظات', ur: 'نوٹس', ru: 'Заметки'), _teachingNotesController),
                    ],
                    
                    const SizedBox(height: 40),
                    _buildSectionLabel(_t(en: 'Prayer Statistics', ar: 'إحصائيات الصلاة', ur: 'نماز کے اعداد', ru: 'Статистика молитв')),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MinaretTheme.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MinaretTheme.gold.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.analytics_outlined, color: MinaretTheme.gold),
                        title: Text(
                          'View Prayer Analytics',
                          style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600, color: MinaretTheme.gold)
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context)!.trackPrayerHabits,
                          style: GoogleFonts.lato(fontSize: 12, color: MinaretTheme.slate)
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: MinaretTheme.gold),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrayerStatsPage()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 60),
                    _buildActionButton(_isSaving ? 'SAVING...' : 'SAVE CHANGES', _saveProfile),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, 
              color: isDark ? Colors.white : MinaretTheme.onyx, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            _displayText(_t(en: 'Personal Info', ar: 'البيانات الشخصية', ur: 'ذاتی معلومات', ru: 'Профиль')),
            style: MinaretTheme.heading.copyWith(fontSize: 22, letterSpacing: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(_displayText(text), style: MinaretTheme.label.copyWith(color: MinaretTheme.gold));

  Widget _buildModernField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: MinaretTheme.gold,
      style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: _displayText(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback? action) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isSaving ? null : action,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: MinaretTheme.emerald, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: MinaretTheme.emerald,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          _displayText(label),
          style: GoogleFonts.montserrat(fontSize: 9, letterSpacing: 5, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}
