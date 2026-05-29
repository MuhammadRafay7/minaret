import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_spacing.dart';
import '../../core/theme.dart';

class LegalDocBody extends StatefulWidget {
  const LegalDocBody({super.key, required this.type});

  final String type;

  @override
  State<LegalDocBody> createState() => _LegalDocBodyState();
}

class _LegalDocBodyState extends State<LegalDocBody> {
  Map<String, dynamic>? _doc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('legal_docs')
          .where('type', isEqualTo: widget.type)
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        _doc = snap.docs.isNotEmpty ? snap.docs.first.data() : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_doc == null) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() => _loading = true);
          await _fetch();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._renderContent(_fallbackContent(widget.type)),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      );
    }

    final content = _doc!['content'] as String? ?? '';
    final version = _doc!['version'] as String? ?? '';
    final lastUpdated = _doc!['lastUpdated'];
    final dateStr = _formatDate(lastUpdated);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _fetch();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._renderContent(content),
            const SizedBox(height: 40),
            Center(
              child: Text(
                [
                  if (dateStr.isNotEmpty) 'Last Updated: $dateStr',
                  if (version.isNotEmpty) 'v$version',
                ].join(' · '),
                style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  String _fallbackContent(String type) {
    if (type == 'privacy_policy') return _kPrivacyPolicy;
    if (type == 'terms_of_service') return _kTermsOfService;
    return '';
  }

  List<Widget> _renderContent(String content) {
    final widgets = <Widget>[];
    // Split into blocks by double newline
    final blocks = content.split(RegExp(r'\n{2,}'));
    for (final block in blocks) {
      final text = block.trim();
      if (text.isEmpty) continue;

      if (_isHeading(text)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 6),
            child: Text(
              text.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MinaretTheme.gold,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              text,
              style: GoogleFonts.notoNaskhArabic(fontSize: 14, height: 1.7),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  // A block is a heading if it's a single line, short, and doesn't end with sentence punctuation.
  bool _isHeading(String text) {
    if (text.contains('\n')) return false;
    if (text.length > 80) return false;
    if (text.endsWith('.') || text.endsWith(',') || text.endsWith(':')) return false;
    return true;
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final date = ts is Timestamp ? ts.toDate() : DateTime.parse(ts.toString());
      const months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[date.month]} ${date.year}';
    } catch (_) {
      return '';
    }
  }
}

// ── Fallback legal content ────────────────────────────────────────────────────
// Shown when Firestore has no document for the requested type.
// These are real legal documents for the Minaret app. Update them before
// public release and, once finalised, seed them into Firestore so version
// numbers and last-updated dates are managed server-side.

const _kPrivacyPolicy = '''
Privacy Policy

Effective Date: May 2026

Welcome to Minaret

Minaret ("we", "our", or "us") is an Islamic app providing prayer times, mosque directories, Quran reading, Hadith collections, Janaza announcements, and community notifications. This Privacy Policy explains what information we collect, how we use it, and your rights regarding your data.

Information We Collect

When you create an account we collect your name, email address, and profile photo. Mosque administrators and Imams requesting verification provide additional professional information during that process.

When you use prayer times or the mosque finder we request your device location to calculate accurate prayer times and show nearby mosques. Location data is used only in real time; we do not store your location history.

We collect usage data such as feature interactions and crash reports through Firebase Crashlytics. This data is anonymised where possible and is used solely to fix bugs and improve the app.

How We Use Your Information

Your information is used to calculate and display prayer times for your location, deliver mosque announcements and push notifications, verify mosque administrator and Imam credentials, personalise content in your preferred language, and diagnose and fix technical issues.

We do not sell your personal information to any third party.

Third-Party Services

Minaret uses Firebase (Google LLC) for authentication, cloud database, push notifications, and crash reporting. Google's privacy policy governs data processed by their services. No other third-party analytics or advertising SDKs are used.

Data Security

All data is transmitted over encrypted HTTPS connections. Your account is protected by Firebase Authentication. Firestore security rules restrict each user to their own data. We apply certificate pinning on connections to our own backend to prevent interception.

Data Retention

Account data is retained while your account is active. Notification records are automatically deleted after 90 days. You may request deletion of your account and associated data at any time by contacting us.

Your Rights

You have the right to access, correct, export, or delete your personal data. To exercise any of these rights, contact us at privacy@minaret.app. We will respond within 30 days.

Children's Privacy

Minaret is not directed at children under the age of 13. We do not knowingly collect personal information from children. If you believe a child has provided us information, contact us and we will delete it promptly.

Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of material changes through the app or by email. Continued use of Minaret after changes are posted constitutes acceptance.

Contact Us

For privacy questions or data requests: privacy@minaret.app
''';

const _kTermsOfService = '''
Terms of Service

Effective Date: May 2026

Agreement to Terms

By downloading or using Minaret you agree to these Terms of Service. If you do not agree, please uninstall the app and do not use our services.

Description of Service

Minaret provides prayer time calculations, a global mosque directory, Quran reading with audio, Hadith collections from authenticated canonical sources, Janaza announcements, and push notifications for mosque communities. The app is available on Android and iOS.

User Accounts

You may create a free account to access features such as following mosques, receiving notifications, and requesting Imam verification. You are responsible for keeping your credentials secure and for all activity that occurs under your account.

Mosque administrators and Imams requesting the verified role must provide accurate, truthful information. Submitting false credentials will result in immediate account termination.

Acceptable Use

You agree not to post false, misleading, or harmful content; harass, threaten, or harm other users; use the app to violate any applicable law or regulation; attempt to gain unauthorised access to any part of the service; or use automated tools to scrape or overload our systems.

Religious Content

Quran text and translations are sourced from established, publicly available Islamic data providers. Hadith collections are drawn from verified canonical sources including Sahih al-Bukhari, Sahih Muslim, Jami at-Tirmidhi, Sunan Abi Dawud, Sunan an-Nasa'i, and Sunan Ibn Majah.

While we strive for accuracy, the app does not replace qualified Islamic scholarship. Always consult a knowledgeable scholar for religious rulings.

Prayer Times

Prayer times are calculated using standard astronomical formulas. Calculated times may differ slightly from times announced by your local mosque. Verify with your mosque for confirmed Adhan times, particularly for Fajr and Maghrib.

Mosque Listings

Mosque information is provided by verified administrators. We do not guarantee the accuracy, completeness, or currency of listing details. Contact the mosque directly to confirm times, services, and events.

Intellectual Property

The Minaret app, its design, branding, and original content are owned by us and protected under applicable intellectual property laws. Quran text, translations, and Hadith data are sourced under their respective licences.

Disclaimer of Warranties

Minaret is provided "as is" and "as available" without warranties of any kind, express or implied. We do not guarantee uninterrupted availability, accuracy of prayer times, or completeness of mosque information.

Limitation of Liability

To the maximum extent permitted by applicable law, we shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of, or inability to use, Minaret.

Termination

We reserve the right to suspend or terminate any account that violates these Terms, without prior notice.

Changes to Terms

We may update these Terms at any time. We will notify you of material changes through the app. Continued use after the updated Terms are posted constitutes your acceptance.

Contact Us

For questions about these Terms: legal@minaret.app
''';
