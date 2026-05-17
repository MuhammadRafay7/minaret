/// create_mosque_page.dart
/// Updated to include facilities, Imam details, and verification document fields.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minaret/core/dependency_injection.dart';
import 'package:minaret/repositories/mosque_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import 'package:minaret/core/theme.dart';
import 'package:minaret/core/location_service.dart';
import 'package:minaret/core/input_validator.dart';
import 'package:minaret/core/errors/app_error.dart';
import 'package:minaret/core/errors/error_extensions.dart';
import 'package:minaret/widgets/success_overlay.dart';
import 'package:minaret/widgets/fiqh_selector.dart';
import 'package:minaret/core/constants/fiqh_constants.dart';
import 'package:minaret/widgets/atelier_layout.dart';

class CreateMosquePage extends StatefulWidget {
  const CreateMosquePage({super.key});

  @override
  State<CreateMosquePage> createState() => _CreateMosquePageState();
}

class _CreateMosquePageState extends State<CreateMosquePage> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _imageUrlController = TextEditingController();

  // Bank Details
  final _bankNameController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();

  // Imam Info (Optional if different from admin)
  final _imamNameController = TextEditingController();
  final _imamEmailController = TextEditingController();
  final _imamPhoneController = TextEditingController();

  // Eid
  final _eidAlFitrTimeController = TextEditingController(text: '--:--');
  final _eidAlFitrDateController = TextEditingController();
  final _eidAlAdhaTimeController = TextEditingController(text: '--:--');
  final _eidAlAdhaDateController = TextEditingController();

  // Jummah + Taraweeh
  final _jummahController = TextEditingController(text: '01:30 PM');
  final _jummahAdhanController = TextEditingController(text: '--:--');
  final _taraweehController = TextEditingController(text: '--:--');

  // Azan times
  final _adhanFajrController = TextEditingController(text: '--:--');
  final _adhanDhuhrController = TextEditingController(text: '--:--');
  final _adhanAsrController = TextEditingController(text: '--:--');
  final _adhanMaghribController = TextEditingController(text: '--:--');
  final _adhanIshaController = TextEditingController(text: '--:--');

  // Iqamah times
  final _fajrController = TextEditingController(text: '--:--');
  final _dhuhrController = TextEditingController(text: '--:--');
  final _asrController = TextEditingController(text: '--:--');
  final _maghribController = TextEditingController(text: '--:--');
  final _ishaController = TextEditingController(text: '--:--');

  // Facilities
  final Map<String, bool> _facilities = {
    'womensArea': false,
    'parking': false,
    'wheelchairAccess': false,
    'wuduFacilities': false,
    'kidsArea': false,
    'library': false,
    'funeralServices': false,
    'educationalClasses': false,
  };

  double? _lat;
  double? _lng;
  bool _isLocating = false;
  bool _isSaving = false;
  String _selectedFiqh = '';

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _imageUrlController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _imamNameController.dispose();
    _imamEmailController.dispose();
    _imamPhoneController.dispose();
    _eidAlFitrTimeController.dispose();
    _eidAlFitrDateController.dispose();
    _eidAlAdhaTimeController.dispose();
    _eidAlAdhaDateController.dispose();
    _jummahController.dispose();
    _jummahAdhanController.dispose();
    _taraweehController.dispose();
    _adhanFajrController.dispose();
    _adhanDhuhrController.dispose();
    _adhanAsrController.dispose();
    _adhanMaghribController.dispose();
    _adhanIshaController.dispose();
    _fajrController.dispose();
    _dhuhrController.dispose();
    _asrController.dispose();
    _maghribController.dispose();
    _ishaController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController ctrl) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
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
    if (picked != null && mounted) {
      setState(() => ctrl.text = DateFormat('dd MMM yyyy').format(picked));
    }
  }

  Future<void> _getCurrentLocation() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLocating = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
        });
      }
    } catch (_) {
      _showError(l10n.errorLocationDenied);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _saveMosque() async {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameController.text.trim();
    final nameValidation = InputValidator.validateMosqueName(name);
    if (!nameValidation.isValid) {
      _showError(nameValidation.errorMessage!);
      return;
    }

    final addressValidation = InputValidator.validateMosqueAddress(_addressController.text);
    if (!addressValidation.isValid) {
      _showError(addressValidation.errorMessage!);
      return;
    }

    if (_lat == null) {
      _showError(l10n.errorRequiredFields);
      return;
    }

    setState(() => _isSaving = true);

    try {
      String cityName = 'Unknown City';
      String countryName = 'Unknown Country';

      try {
        final placemarks = await placemarkFromCoordinates(_lat!, _lng!);
        if (placemarks.isNotEmpty) {
          cityName = placemarks.first.locality ?? 'Unknown';
          countryName = placemarks.first.country ?? 'Unknown';
        }
      } catch (_) {}

      await ServiceLocator.get<MosqueRepository>().addMosque({
        'name': name,
        'name_lowercase': name.toLowerCase(),
        'address': _addressController.text.trim(),
        'lat': _lat,
        'lng': _lng,
        'city': cityName,
        'country': countryName,
        'adminUid': user.uid,
        'imageUrl': _imageUrlController.text.trim(),

        // Bank details
        'bankName': _bankNameController.text.trim(),
        'accountHolder': _accountHolderController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),

        // Imam Info
        'imamName': _imamNameController.text.trim(),
        'imamEmail': _imamEmailController.text.trim(),
        'imamPhone': _imamPhoneController.text.trim(),

        // Fiqh
        'fiqh': _selectedFiqh,

        // Azan times
        'adhanFajr': _adhanFajrController.text.trim(),
        'adhanDhuhr': _adhanDhuhrController.text.trim(),
        'adhanAsr': _adhanAsrController.text.trim(),
        'adhanMaghrib': _adhanMaghribController.text.trim(),
        'adhanIsha': _adhanIshaController.text.trim(),

        // Iqamah times
        'fajr': _fajrController.text.trim(),
        'dhuhr': _dhuhrController.text.trim(),
        'asr': _asrController.text.trim(),
        'maghrib': _maghribController.text.trim(),
        'isha': _ishaController.text.trim(),

        // Special prayers
        'jummah': _jummahController.text.trim(),
        'adhanJummah': _jummahAdhanController.text.trim(),
        'taraweeh': _taraweehController.text.trim(),

        // Eid
        'eidAlFitrTime': _eidAlFitrTimeController.text.trim(),
        'eidAlFitrDate': _eidAlFitrDateController.text.trim(),
        'eidAlAdhaTime': _eidAlAdhaTimeController.text.trim(),
        'eidAlAdhaDate': _eidAlAdhaDateController.text.trim(),

        // Facilities (Sync with Admin)
        'features': _facilities,

        'followerCount': 0,
        'status': 'pending',
        'isVerified': false,
        'lastReportAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) _triggerSuccessEffect();
    } catch (e, st) {
      final appError = e.toAppError(st);
      appError.logToCrashlyticsSync();
      if (mounted) {
        _showError(appError.userMessage);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _triggerSuccessEffect() async {
    final l10n = AppLocalizations.of(context)!;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (ctx, _, __) => SuccessOverlay(
        title: l10n.successRegistryTitle,
        message: l10n.successRegistryMessage,
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg.toUpperCase())));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              ),
              const SizedBox(height: 30),
              Text(
                l10n.establishRegistryAction.toUpperCase(),
                style: MinaretTheme.heading.copyWith(
                  fontSize: 28,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 40),
              _buildField('MOSQUE NAME', _nameController),

              // ── Donation ──
              _buildSectionTitle('DONATION BANK DETAILS'),
              _buildField('BANK NAME', _bankNameController),
              _buildField('ACCOUNT HOLDER NAME', _accountHolderController),
              _buildField('ACCOUNT NUMBER / IBAN', _accountNumberController),

              // ── Imam Info ──
              _buildSectionTitle('IMAM / OFFICIAL CONTACT'),
              _buildField('FULL NAME', _imamNameController),
              _buildField('EMAIL ADDRESS', _imamEmailController),
              _buildField('PHONE NUMBER', _imamPhoneController),

              // ── Facilities ──
              _buildSectionTitle('MOSQUE FACILITIES'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _facilities.keys.map((key) {
                  return FilterChip(
                    label: Text(
                      key.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}').toUpperCase(),
                      style: GoogleFonts.montserrat(fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    selected: _facilities[key]!,
                    onSelected: (val) => setState(() => _facilities[key] = val),
                    selectedColor: MinaretTheme.emerald.withOpacity(0.2),
                    checkmarkColor: MinaretTheme.emerald,
                  );
                }).toList(),
              ),

              // ── Fiqh ──
              _buildSectionTitle('SCHOOL OF THOUGHT'),
              FiqhSelector(
                selectedKey: _selectedFiqh,
                onChanged: (key) => setState(() => _selectedFiqh = key),
              ),

              // ── Azan & Iqamah ──
              const SizedBox(height: 30),
              _buildSectionTitle('AZAN & IQAMAH TIMES'),
              _prayerPairField('FAJR', _adhanFajrController, _fajrController),
              _prayerPairField(
                'DHUHR',
                _adhanDhuhrController,
                _dhuhrController,
              ),
              _prayerPairField('ASR', _adhanAsrController, _asrController),
              _prayerPairField(
                'MAGHRIB',
                _adhanMaghribController,
                _maghribController,
              ),
              _prayerPairField('ISHA', _adhanIshaController, _ishaController),

              // ── Special prayers ──
              _buildSectionTitle('SPECIAL PRAYERS'),
              _prayerPairField(
                  'JUMMAH', _jummahAdhanController, _jummahController),
              _tapTimeField('TARAWEEH', _taraweehController),

              // ── Eid ──
              _buildSectionTitle('EID PRAYERS'),
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

              const SizedBox(height: 40),
              _buildLocationButton(l10n),
              const SizedBox(height: 50),
              _buildSubmitButton(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
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

  Widget _prayerPairField(
    String label,
    TextEditingController azanCtrl,
    TextEditingController iqamahCtrl,
  ) {
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
              Expanded(child: _tapTimeField(l10n.azanLabel, azanCtrl, showLabel: true)),
              const SizedBox(width: 12),
              Expanded(
                child: _tapTimeField(l10n.iqamahLabel, iqamahCtrl, showLabel: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tapTimeField(
    String label,
    TextEditingController ctrl, {
    bool showLabel = false,
  }) {
    return Padding(
      padding: showLabel ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => _selectTime(ctrl),
        child: AbsorbPointer(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
        ),
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
                onTap: () => _selectTime(timeCtrl),
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

  Widget _buildLocationButton(AppLocalizations l10n) {
    final secured = _lat != null;
    return GestureDetector(
      onTap: _isLocating ? null : _getCurrentLocation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          border: Border.all(
            color: secured ? MinaretTheme.emerald : MinaretTheme.dividerColor,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            _isLocating
                ? 'IDENTIFYING...'
                : (secured ? 'LOCATION SECURED' : 'PIN CURRENT LOCATION'),
            style: GoogleFonts.montserrat(
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isSaving ? null : _saveMosque,
        style: OutlinedButton.styleFrom(backgroundColor: MinaretTheme.emerald),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(l10n.establishRegistryAction.toUpperCase()),
      ),
    );
  }
}
