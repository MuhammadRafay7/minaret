import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/success_overlay.dart';
import 'package:minaret/services/janaza_service.dart';
import 'package:minaret/core/dependency_injection.dart';
import 'package:minaret/repositories/janaza_repository.dart';

class JanazaEditFormPage extends StatefulWidget {
  final JanazaAnnouncement announcement;

  const JanazaEditFormPage({super.key, required this.announcement});

  @override
  State<JanazaEditFormPage> createState() => _JanazaEditFormPageState();
}

class _JanazaEditFormPageState extends State<JanazaEditFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _ageController;
  late final TextEditingController _fatherController;
  late final TextEditingController _motherController;
  late final TextEditingController _husbandController;
  late final TextEditingController _wifeController;
  late final TextEditingController _brotherController;
  late final TextEditingController _sisterController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _gender = '';
  bool _isSaving = false;
  bool _showFamilyFields = false;

  @override
  void initState() {
    super.initState();
    final a = widget.announcement;
    _nameController = TextEditingController(text: a.deceasedName);
    _locationController = TextEditingController(text: a.locationNote);
    _ageController = TextEditingController(text: a.age);
    _fatherController = TextEditingController(text: a.fatherName);
    _motherController = TextEditingController(text: a.motherName);
    _husbandController = TextEditingController(text: a.husbandName);
    _wifeController = TextEditingController(text: a.wifeName);
    _brotherController = TextEditingController(text: a.brotherName);
    _sisterController = TextEditingController(text: a.sisterName);
    _selectedDate = a.janazaTime;
    _selectedTime = TimeOfDay.fromDateTime(a.janazaTime);
    _gender = a.gender;

    // Auto-expand if any family field already has data
    _showFamilyFields =
        a.fatherName.isNotEmpty ||
        a.motherName.isNotEmpty ||
        a.husbandName.isNotEmpty ||
        a.wifeName.isNotEmpty ||
        a.brotherName.isNotEmpty ||
        a.sisterName.isNotEmpty ||
        a.age.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _fatherController.dispose();
    _motherController.dispose();
    _husbandController.dispose();
    _wifeController.dispose();
    _brotherController.dispose();
    _sisterController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: MinaretTheme.emerald,
            onPrimary: Colors.white,
            onSurface: MinaretTheme.onyx,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: MinaretTheme.gold),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: MinaretTheme.emerald,
            onPrimary: Colors.white,
            onSurface: MinaretTheme.onyx,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: MinaretTheme.gold),
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('YOU MUST BE SIGNED IN.');
      return;
    }

    final deceasedName = _nameController.text.trim();
    if (deceasedName.isEmpty) {
      _showSnack('ENTER THE NAME OF THE DECEASED.');
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      _showSnack('SELECT BOTH DATE AND TIME.');
      return;
    }

    final janazaDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    setState(() => _isSaving = true);

    try {
      // Build update map — always update core fields
      final update = <String, dynamic>{
        'deceasedName': deceasedName,
        'janazaTime': Timestamp.fromDate(janazaDateTime),
        'locationNote': _locationController.text.trim(),
        'gender': _gender,
        'age': _ageController.text.trim(),
        'fatherName': _fatherController.text.trim(),
        'motherName': _motherController.text.trim(),
        'husbandName': _husbandController.text.trim(),
        'wifeName': _wifeController.text.trim(),
        'brotherName': _brotherController.text.trim(),
        'sisterName': _sisterController.text.trim(),
      };

      await ServiceLocator.get<JanazaRepository>()
          .updateAnnouncement(widget.announcement.id, update);

      if (!mounted) return;

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => const SuccessOverlay(
          title: 'ANNOUNCEMENT UPDATED',
          message: 'Changes saved successfully.',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pop();
    } catch (e) {
      _showSnack('COULD NOT UPDATE. TRY AGAIN.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _selectedDate != null
        ? DateFormat('EEE, d MMM yyyy').format(_selectedDate!)
        : 'SELECT DATE';
    final timeLabel = _selectedTime != null
        ? _selectedTime!.format(context)
        : 'SELECT TIME';

    return Scaffold(
      backgroundColor: MinaretTheme.background,
      body: AtelierLayout(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(40, 60, 40, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: MinaretTheme.emerald,
                ),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 30),

              Text(
                'إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ',
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  color: MinaretTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'EDIT JANAZA',
                style: MinaretTheme.heading.copyWith(
                  fontSize: 34,
                  letterSpacing: 8,
                  color: MinaretTheme.onyx,
                ),
              ),
              Text(
                'UPDATE ANNOUNCEMENT DETAILS',
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  letterSpacing: 3,
                  color: MinaretTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 50),

              // ── Deceased name ─────────────────────────────────────────────
              _buildField('NAME OF DECEASED', _nameController),

              // ── Gender selector ───────────────────────────────────────────
              _sectionLabel('GENDER'),
              const SizedBox(height: 12),
              _buildGenderSelector(),
              const SizedBox(height: 30),

              // ── Age ───────────────────────────────────────────────────────
              _buildField(
                'AGE (OPTIONAL)',
                _ageController,
                hint: 'e.g. 65',
                keyboardType: TextInputType.number,
              ),

              // ── Location note ─────────────────────────────────────────────
              _buildField(
                'LOCATION NOTE (OPTIONAL)',
                _locationController,
                hint: 'e.g. Main Prayer Hall, Gate 2',
              ),

              // ── Date + Time ───────────────────────────────────────────────
              _sectionLabel('JANAZA DATE & TIME'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _pickerButton(
                      label: dateLabel,
                      icon: Icons.calendar_today_outlined,
                      onTap: _pickDate,
                      isSet: _selectedDate != null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _pickerButton(
                      label: timeLabel,
                      icon: Icons.access_time_rounded,
                      onTap: _pickTime,
                      isSet: _selectedTime != null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // ── Family details toggle ─────────────────────────────────────
              GestureDetector(
                onTap: () =>
                    setState(() => _showFamilyFields = !_showFamilyFields),
                child: Row(
                  children: [
                    Container(
                      height: 1,
                      width: 16,
                      color: MinaretTheme.gold.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FAMILY DETAILS (OPTIONAL)',
                      style: GoogleFonts.montserrat(
                        fontSize: 7.5,
                        letterSpacing: 3,
                        color: MinaretTheme.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _showFamilyFields
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: MinaretTheme.gold,
                    ),
                  ],
                ),
              ),

              if (_showFamilyFields) ...[
                const SizedBox(height: 20),
                _buildFamilyFields(),
              ],

              const SizedBox(height: 40),

              // ── Submit ────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: MinaretTheme.emerald,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    side: BorderSide.none,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 15,
                          width: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 1,
                            color: MinaretTheme.gold,
                          ),
                        )
                      : Text(
                          'SAVE CHANGES',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            letterSpacing: 5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gender selector ────────────────────────────────────────────────────────

  Widget _buildGenderSelector() {
    return Row(
      children: [
        _genderChip('MALE', 'male', Icons.male_rounded),
        const SizedBox(width: 12),
        _genderChip('FEMALE', 'female', Icons.female_rounded),
        const SizedBox(width: 12),
        _genderChip('NOT SPECIFIED', '', Icons.remove),
      ],
    );
  }

  Widget _genderChip(String label, String value, IconData icon) {
    final isSelected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? MinaretTheme.emerald.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? MinaretTheme.emerald
                  : MinaretTheme.dividerColor,
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? MinaretTheme.emerald
                    : MinaretTheme.slate.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 7.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? MinaretTheme.emerald
                      : MinaretTheme.slate.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Family fields ──────────────────────────────────────────────────────────

  Widget _buildFamilyFields() {
    final showHusband = _gender == 'female' || _gender == '';
    final showWife = _gender == 'male' || _gender == '';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildField(
                'FATHER\'S NAME',
                _fatherController,
                hint: 'Optional',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildField(
                'MOTHER\'S NAME',
                _motherController,
                hint: 'Optional',
              ),
            ),
          ],
        ),
        if (showHusband)
          _buildField('HUSBAND\'S NAME', _husbandController, hint: 'Optional'),
        if (showWife)
          _buildField('WIFE\'S NAME', _wifeController, hint: 'Optional'),
        Row(
          children: [
            Expanded(
              child: _buildField(
                'BROTHER\'S NAME',
                _brotherController,
                hint: 'Optional',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildField(
                'SISTER\'S NAME',
                _sisterController,
                hint: 'Optional',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          height: 1,
          width: 16,
          color: MinaretTheme.gold.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.montserrat(
            fontSize: 7.5,
            letterSpacing: 3,
            color: MinaretTheme.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: MinaretTheme.gold,
        style: GoogleFonts.lato(fontSize: 14, color: MinaretTheme.onyx),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintStyle: GoogleFonts.lato(
            fontSize: 13,
            color: MinaretTheme.slate.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  Widget _pickerButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: isSet
              ? MinaretTheme.emerald.withValues(alpha: 0.06)
              : Colors.transparent,
          border: Border.all(
            color: isSet ? MinaretTheme.emerald : MinaretTheme.dividerColor,
            width: isSet ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSet
                  ? MinaretTheme.gold
                  : MinaretTheme.slate.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.montserrat(
                  fontSize: 8.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: isSet
                      ? MinaretTheme.emerald
                      : MinaretTheme.slate.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
