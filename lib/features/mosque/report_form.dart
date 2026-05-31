/// report_form.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/dependency_injection.dart';
import 'package:minaret/repositories/user_repository.dart';
import 'package:minaret/repositories/notification_repository.dart';

import '../../core/theme.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/success_overlay.dart';

enum ReportReason {
  wrongPrayerTime('wrong_prayer_time', 'Wrong Prayer Time'),
  incorrectLocation('incorrect_location', 'Incorrect Location'),
  inappropriateContent('inappropriate_content', 'Inappropriate Content'),
  spam('spam', 'Spam / Duplicate'),
  other('other', 'Other');

  const ReportReason(this.code, this.label);
  final String code;
  final String label;
}

class ReportFormPage extends StatefulWidget {
  final String mosqueId;
  final String mosqueName;

  const ReportFormPage({
    super.key,
    required this.mosqueId,
    required this.mosqueName,
  });

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  ReportReason? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('PLEASE SIGN IN TO REPORT');
      return;
    }
    if (_selectedReason == null) {
      _showError('PLEASE SELECT A REASON');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Ensure user document exists
      await ServiceLocator.get<UserRepository>().ensureExists(user.uid, {
        'followedMosques': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      final mosqueRef =
          FirebaseFirestore.instance.collection('mosques').doc(widget.mosqueId);

      String? adminUid;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final mosqueDoc = await transaction.get(mosqueRef);
        if (!mosqueDoc.exists) {
          throw Exception('Mosque no longer exists');
        }

        final data = mosqueDoc.data() ?? {};
        final currentReportCount = (data['reportCount'] ?? 0) as int;
        final newReportCount = currentReportCount + 1;
        final bool currentlyVerified = data['isVerified'] ?? false;
        adminUid = data['adminUid'] as String?;

        // Prepare update map
        final Map<String, dynamic> mosqueUpdate = {
          'lastReportAt': FieldValue.serverTimestamp(),
          'reportCount': newReportCount,
        };

        // Logic: Hit 7 reports = lose verified status
        if (currentlyVerified && newReportCount >= 7) {
          mosqueUpdate['isVerified'] = false;
        }

        // 1. Create Report Log
        final reportRef =
            FirebaseFirestore.instance.collection('reports').doc();
        transaction.set(reportRef, {
          'userId': user.uid,
          'mosqueId': widget.mosqueId,
          'mosqueName': widget.mosqueName,
          'reportedBy': user.uid,
          // Admin-panel-compatible fields
          'targetId': widget.mosqueId,
          'targetType': 'mosque',
          'description': _detailsController.text.trim(),
          'reason': _selectedReason!.code,
          'details': _detailsController.text.trim(),
          'status': 'pending',
          'resolved': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Update Mosque
        transaction.update(mosqueRef, mosqueUpdate);
      });

      // 3. Send warning notification to mosque admin (best-effort — rules
      // restrict cross-user notification writes, so don't fail the report if this throws)
      if (adminUid != null && adminUid!.isNotEmpty) {
        try {
          await ServiceLocator.get<NotificationRepository>().addNotification({
            'userId': adminUid,
            'type': 'report_warning',
            'title': 'Mosque Report Warning',
            'message':
                'Your mosque "${widget.mosqueName}" has received a report: ${_selectedReason!.label}. Please review and address this issue.',
            'mosqueId': widget.mosqueId,
            'mosqueName': widget.mosqueName,
            'reportReason': _selectedReason!.code,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Report notification skipped: $e');
        }
      }

      if (!mounted) return;

      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        pageBuilder: (ctx, _, __) => const SuccessOverlay(
          title: 'REPORT SUBMITTED',
          message: 'Thank you. We will review this mosque.',
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context); // Close Overlay
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      debugPrint('🔴 Report Error: $e');
      if (e.toString().contains('permission-denied')) {
        _showError('PERMISSION DENIED - PLEASE SIGN IN AGAIN');
      } else {
        _showError('COULD NOT SUBMIT REPORT');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg.toUpperCase())));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: MinaretTheme.background,
      body: AtelierLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 60, 40, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      size: 14, color: MinaretTheme.emerald)),
              const SizedBox(height: 40),
              Text(l10n.reportIssue,
                  style: MinaretTheme.heading
                      .copyWith(fontSize: 28, letterSpacing: 6)),
              const SizedBox(height: 10),
              Text(widget.mosqueName.toUpperCase(),
                  style: GoogleFonts.montserrat(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: MinaretTheme.gold,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              ...ReportReason.values.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.label.toUpperCase(),
                        style: GoogleFonts.montserrat(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                    leading: Radio<ReportReason>(
                      value: r,
                      groupValue: _selectedReason,
                      onChanged: (v) => setState(() => _selectedReason = v),
                      activeColor: MinaretTheme.gold,
                    ),
                  )),
              const SizedBox(height: 30),
              TextField(
                  controller: _detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.detailsOptional,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  )),
              const SizedBox(height: 50),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          side: BorderSide.none),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(l10n.submitReport,
                              style: const TextStyle(color: Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }
}
