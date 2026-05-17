/// edit_mosque_page.dart
/// Updated to include Azan times, Taraweeh, and Eid prayer schedules.
/// Added Deletion capability for Mosque Owners.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minaret/core/dependency_injection.dart';
import 'package:minaret/repositories/mosque_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import '../../core/theme.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/success_overlay.dart';
import '../../widgets/fiqh_selector.dart';
import 'package:minaret/core/constants/fiqh_constants.dart';

class EditMosquePage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> currentData;

  const EditMosquePage({
    super.key,
    required this.docId,
    required this.currentData,
  });

  @override
  State<EditMosquePage> createState() => _EditMosquePageState();
}

class _EditMosquePageState extends State<EditMosquePage> {
  final _nameController = TextEditingController();
  final _establishedController = TextEditingController();
  final _areaController = TextEditingController();
  final _imamCountController = TextEditingController();
  final _studentCountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Bank Details
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();

  // Eid ul Fitr
  final _eidAlFitrTimeController = TextEditingController();
  final _eidAlFitrDateController = TextEditingController();

  // Eid ul Adha
  final _eidAlAdhaTimeController = TextEditingController();
  final _eidAlAdhaDateController = TextEditingController();

  final Map<String, TextEditingController> _timeControllers = {};

  bool _isSaving = false;
  String _selectedFiqh = '';

  // Prayer keys: iqamah times + azan times + special prayers
  static const List<String> _iqamahKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];
  static const List<String> _azanKeys = [
    'adhanFajr',
    'adhanDhuhr',
    'adhanAsr',
    'adhanMaghrib',
    'adhanIsha',
  ];
  static const List<String> _specialKeys = [
    'jummah',
    'adhanJummah',
    'taraweeh'
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentData['name'] ?? '';
    _establishedController.text = widget.currentData['established'] ?? '';
    _areaController.text = widget.currentData['area'] ?? '';
    _imamCountController.text = widget.currentData['imamCount'] ?? '';
    _studentCountController.text = widget.currentData['studentCount'] ?? '';
    _descriptionController.text = widget.currentData['description'] ?? '';

    _bankNameController.text = widget.currentData['bankName'] ?? '';
    _accountHolderController.text = widget.currentData['accountHolder'] ?? '';
    _accountNumberController.text = widget.currentData['accountNumber'] ?? '';

    _eidAlFitrTimeController.text =
        widget.currentData['eidAlFitrTime'] ?? '--:--';
    _eidAlFitrDateController.text = widget.currentData['eidAlFitrDate'] ?? '';
    _eidAlAdhaTimeController.text =
        widget.currentData['eidAlAdhaTime'] ?? '--:--';
    _eidAlAdhaDateController.text = widget.currentData['eidAlAdhaDate'] ?? '';

    final savedFiqh = widget.currentData['fiqh'] as String? ?? '';
    _selectedFiqh = FiqhConstants.isValid(savedFiqh) ? savedFiqh : '';

    for (final key in [..._iqamahKeys, ..._azanKeys, ..._specialKeys]) {
      _timeControllers[key] = TextEditingController(
        text: widget.currentData[key] ?? '--:--',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _establishedController.dispose();
    _areaController.dispose();
    _imamCountController.dispose();
    _studentCountController.dispose();
    _descriptionController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _eidAlFitrTimeController.dispose();
    _eidAlFitrDateController.dispose();
    _eidAlAdhaTimeController.dispose();
    _eidAlAdhaDateController.dispose();
    for (final c in _timeControllers.values) c.dispose();
    super.dispose();
  }

  bool _verifyOwnership() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == widget.currentData['adminUid'];
  }

  Future<void> _selectTime(String key, TextEditingController ctrl) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      setState(() => ctrl.text = DateFormat.jm().format(dt));
    }
  }

  Future<void> _selectDate(TextEditingController ctrl) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => ctrl.text = DateFormat('dd MMM yyyy').format(picked));
    }
  }

  Future<void> _saveChanges() async {
    if (!_verifyOwnership()) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{
        'name': newName,
        'name_lowercase': newName.toLowerCase(),
        'established': _establishedController.text.trim(),
        'area': _areaController.text.trim(),
        'imamCount': _imamCountController.text.trim(),
        'studentCount': _studentCountController.text.trim(),
        'description': _descriptionController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountHolder': _accountHolderController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'fiqh': _selectedFiqh,
        'eidAlFitrTime': _eidAlFitrTimeController.text.trim().toUpperCase(),
        'eidAlFitrDate': _eidAlFitrDateController.text.trim(),
        'eidAlAdhaTime': _eidAlAdhaTimeController.text.trim().toUpperCase(),
        'eidAlAdhaDate': _eidAlAdhaDateController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      for (final entry in _timeControllers.entries) {
        updates[entry.key] = entry.value.text.trim().toUpperCase();
      }

      await ServiceLocator.get<MosqueRepository>().updateMosque(widget.docId, updates);

      if (!mounted) return;
      _triggerSuccess();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteMosque() async {
    if (!_verifyOwnership()) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MinaretTheme.background,
        title: Text(l10n.deleteRegistryTitle, style: GoogleFonts.montserrat(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 14)),
        content: Text(
          'This action is permanent and cannot be undone. All data associated with this sanctuary will be removed from the global registry.',
          style: GoogleFonts.lato(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelAction.toUpperCase(), style: GoogleFonts.montserrat(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deletePermanentlyAction, style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      await ServiceLocator.get<MosqueRepository>().deleteMosque(widget.docId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.registryDeletedMessage))
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToDeleteRegistry))
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _triggerSuccess() async {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (ctx, _, __) => const SuccessOverlay(
        title: 'SYNCHRONIZED',
        message: 'Registry updated successfully',
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MinaretTheme.background,
      body: AtelierLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
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
              ),
              const SizedBox(height: 30),
              Text(
                'REGISTRY MANAGEMENT',
                style: MinaretTheme.heading.copyWith(
                  fontSize: 28,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 40),

              _buildField('OFFICIAL NAME', _nameController),

              // ── Donation ──
              _sectionHeader('DONATION SETTINGS'),
              _buildField('BANK NAME', _bankNameController),
              _buildField('ACCOUNT HOLDER', _accountHolderController),
              _buildField('ACCOUNT NUMBER / IBAN', _accountNumberController),

              // ── Fiqh ──
              _sectionHeader('SCHOOL OF THOUGHT (FIQH)'),
              FiqhSelector(
                selectedKey: _selectedFiqh,
                onChanged: (key) => setState(() => _selectedFiqh = key),
              ),

              // ── Azan & Iqamah ──
              const SizedBox(height: 30),
              _sectionHeader('AZAN & IQAMAH TIMES'),
              _prayerPairField('FAJR', 'adhanFajr', 'fajr'),
              _prayerPairField('DHUHR', 'adhanDhuhr', 'dhuhr'),
              _prayerPairField('ASR', 'adhanAsr', 'asr'),
              _prayerPairField('MAGHRIB', 'adhanMaghrib', 'maghrib'),
              _prayerPairField('ISHA', 'adhanIsha', 'isha'),

              // ── Special prayers ──
              const SizedBox(height: 10),
              _sectionHeader('SPECIAL PRAYERS'),
              _prayerPairField('JUMMAH', 'adhanJummah', 'jummah'),
              _timeField('TARAWEEH', 'taraweeh'),

              // ── Eid ──
              const SizedBox(height: 10),
              _sectionHeader('EID PRAYERS'),
              _eidFields(
                'EID UL FITR',
                _eidAlFitrTimeController,
                _eidAlFitrDateController,
              ),
              const SizedBox(height: 20),
              _eidFields(
                'EID UL ADHA',
                _eidAlAdhaTimeController,
                _eidAlAdhaDateController,
              ),

              const SizedBox(height: 50),
              _saveButton(),
              const SizedBox(height: 20),
              _deleteButton(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 14),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 8,
          letterSpacing: 3,
          color: MinaretTheme.gold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
    );
  }

  /// Two side-by-side time pickers: Azan | Iqamah
  Widget _prayerPairField(String label, String azanKey, String iqamahKey) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 8,
              letterSpacing: 2,
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _tapField(l10n.azanLabel, azanKey, _timeControllers[azanKey]!),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tapField(
                  l10n.iqamahLabel,
                  iqamahKey,
                  _timeControllers[iqamahKey]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tapField(String label, String key, TextEditingController ctrl) {
    return GestureDetector(
      onTap: () => _selectTime(key, ctrl),
      child: AbsorbPointer(
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
        ),
      ),
    );
  }

  Widget _timeField(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => _selectTime(key, _timeControllers[key]!),
        child: AbsorbPointer(child: _buildField(label, _timeControllers[key]!)),
      ),
    );
  }

  Widget _eidFields(
    String label,
    TextEditingController timeCtrl,
    TextEditingController dateCtrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 8,
            letterSpacing: 2,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTime(label, timeCtrl),
                child: AbsorbPointer(
                  child: TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'TIME',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(dateCtrl),
                child: AbsorbPointer(
                  child: TextField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'DATE',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _saveButton() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: OutlinedButton.styleFrom(backgroundColor: MinaretTheme.emerald),
        child: _isSaving
            ? const AppLoadingIndicator(size: 18)
            : Text(l10n.saveChangesAction),
      ),
    );
  }

  Widget _deleteButton() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _isSaving ? null : _deleteMosque,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          l10n.deleteRegistryAction,
          style: GoogleFonts.montserrat(
            color: Colors.redAccent,
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
