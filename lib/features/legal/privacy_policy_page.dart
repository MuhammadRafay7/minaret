import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_spacing.dart';
import '../../core/theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PRIVACY POLICY',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Introduction'),
            _bodyText(
              'Welcome to Minaret, a comprehensive prayer management application. We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you about how we look after your personal data when you use our app and tell you about your privacy rights.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('Data We Collect'),
            _bodyText(
              '• Authentication Data: Phone number and profile information for account creation and sign-in.\n'
              '• Location Data: Your current location (with permission) to provide accurate prayer times, find nearby mosques, and location-based services.\n'
              '• Usage Data: Information about how you interact with the app, including prayer times viewed, mosques followed, and features used.\n'
              '• Device Information: Device type, operating system, and unique device identifiers for app functionality and analytics.\n'
              '• Notification Data: FCM tokens for sending prayer time reminders and important updates.\n'
              '• User-Generated Content: Mosque information, prayer times, janaza announcements, and user reports.\n'
              '• Storage Data: Profile images and documents uploaded through the app.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('How We Use Your Data'),
            _bodyText(
              '• Provide core app functionality: Calculate accurate prayer times, find nearby mosques, and manage prayer schedules.\n'
              '• Account Management: Authenticate users and maintain user profiles and preferences.\n'
              '• Notifications: Send prayer time reminders, mosque updates, and important notifications.\n'
              '• Service Improvement: Analyze usage patterns to enhance app performance and user experience.\n'
              '• Community Features: Enable mosque following, sharing, and community engagement.\n'
              '• Support: Provide customer support and respond to user inquiries and reports.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('Data Storage and Security'),
            _bodyText(
              '• Firebase Services: Your data is stored securely using Firebase (Firestore, Authentication, Storage).\n'
              '• Encryption: Data transmission is encrypted using industry-standard protocols.\n'
              '• Access Control: Only authorized personnel can access your data for maintenance and support.\n'
              '• Local Storage: Some data is stored locally on your device using SharedPreferences and Hive for offline functionality.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('Third-Party Services'),
            _bodyText(
              '• Google Mobile Ads: For displaying relevant advertisements within the app.\n'
              '• Firebase Analytics: For collecting anonymous usage statistics and crash reports.\n'
              '• Google Fonts: For providing typography and font services.\n'
              '• Geolocator: For accessing device location services.\n'
              '• Image Picker: For accessing device camera and photo library.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('Your Rights'),
            _bodyText(
              '• Access: Request access to your personal data we hold.\n'
              '• Correction: Request correction of inaccurate personal data.\n'
              '• Deletion: Request deletion of your account and associated data.\n'
              '• Portability: Request a copy of your data in a portable format.\n'
              '• Opt-out: Disable location services and notifications through device settings.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('Data Retention'),
            _bodyText(
              'We retain your personal data only as long as necessary to provide our services and comply with legal obligations. When you delete your account, we will delete your personal data within 30 days, except where required to retain for legal or security purposes.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('Children\'s Privacy'),
            _bodyText(
              'Our service is not directed to children under 13. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from children under 13, we will take steps to delete such information.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('International Data Transfers'),
            _bodyText(
              'Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your data in accordance with applicable data protection laws.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('Changes to This Policy'),
            _bodyText(
              'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy in the app and updating the "Last Updated" date.',
            ),
            const SizedBox(height: 20),
            _sectionTitle('Contact Us'),
            _bodyText(
              'If you have any questions about this privacy policy or our data practices, please contact us through the app\'s support features.',
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Last Updated: May 2024',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: MinaretTheme.gold,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Text(
      text,
      style: GoogleFonts.notoNaskhArabic(
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}
