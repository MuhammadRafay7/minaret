import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/dependency_injection.dart';
import '../../repositories/mosque_repository.dart';
import '../../repositories/janaza_repository.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/janaza_announcement_card.dart';
import '../../widgets/mosque_follow_button.dart';
import 'mosque_details_notifier.dart';
import 'edit_mosque_page.dart';
import 'janaza_form.dart';
import 'report_form.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class DetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;

  const DetailsPage({super.key, required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MosqueDetailsNotifier(
        mosqueRepository: ServiceLocator.get<MosqueRepository>(),
        janazaRepository: ServiceLocator.get<JanazaRepository>(),
      )..init(docId, data),
      child: _DetailsView(docId: docId, initialData: data),
    );
  }
}

// ── View ──────────────────────────────────────────────────────────────────────

class _DetailsView extends StatelessWidget {
  const _DetailsView({required this.docId, required this.initialData});

  final String docId;
  final Map<String, dynamic> initialData;

  @override
  Widget build(BuildContext context) {
    final n = context.watch<MosqueDetailsNotifier>();
    final docData = n.mosque?.raw ?? initialData;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final textPrimary = isDark ? Colors.white : MinaretTheme.onyx;
    final textSecondary =
        isDark ? Colors.white70 : const Color(0xFF6B6B6B);
    final textMuted = isDark ? Colors.white38 : Colors.black38;
    final dividerColor =
        isDark ? const Color(0x1AFFFFFF) : MinaretTheme.dividerColor;
    final bgColor =
        isDark ? const Color(0xFF0D1117) : MinaretTheme.background;

    if (n.hasError && n.mosque == null) {
      return _buildErrorState(context, isDark, l10n);
    }

    return AtelierLayout(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 320.h,
              pinned: true,
              backgroundColor: MinaretTheme.emerald,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 14, color: Colors.white),
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    n.isFollowing
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    color: MinaretTheme.gold,
                  ),
                  onPressed: () => context
                      .read<MosqueDetailsNotifier>()
                      .toggleFollow(),
                ),
                if (n.canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_note_outlined,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditMosquePage(docId: docId, currentData: docData),
                      ),
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [MinaretTheme.emerald, Color(0xFF0D2B1E)],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(36.w, 0, 36.w, 20.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'SANCTUARY PROFILE',
                              style: GoogleFonts.montserrat(
                                fontSize: 7.5.sp,
                                letterSpacing: 4,
                                color: MinaretTheme.gold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (docData['isVerified'] == true) ...[
                              SizedBox(width: 8.w),
                              Icon(Icons.verified,
                                  color: MinaretTheme.gold, size: 14.sp),
                            ],
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          (docData['name'] ?? 'MASJID')
                              .toString()
                              .toUpperCase(),
                          style: MinaretTheme.heading.copyWith(
                            fontSize: 28.sp,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Icon(Icons.people_outline_rounded,
                                color: Colors.white60, size: 14.sp),
                            SizedBox(width: 6.w),
                            Text(
                              '${docData['followerCount'] ?? 0} FOLLOWERS',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 10.sp,
                                color: Colors.white60,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            MosqueFollowButton(
                              isFollowing: n.isFollowing,
                              onToggle: () { n.toggleFollow(); },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: bgColor,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 30.w, vertical: 40.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAnnouncementsSection(
                          docData, textPrimary, textSecondary, dividerColor),
                      SizedBox(height: 40.h),
                      _buildJanazaSection(
                          context, n, docData, textPrimary, textMuted),
                      SizedBox(height: 40.h),
                      _sectionTitle('DAILY CONGREGATION'),
                      _prayerColumnHeaders(context, textMuted, l10n),
                      _prayerRow('FAJR', docData['adhanFajr'] ?? '--:--',
                          docData['fajr'] ?? '--:--', textPrimary, textSecondary, dividerColor),
                      _prayerRow('DHUHR', docData['adhanDhuhr'] ?? '--:--',
                          docData['dhuhr'] ?? '--:--', textPrimary, textSecondary, dividerColor),
                      _prayerRow('ASR', docData['adhanAsr'] ?? '--:--',
                          docData['asr'] ?? '--:--', textPrimary, textSecondary, dividerColor),
                      _prayerRow('MAGHRIB', docData['adhanMaghrib'] ?? '--:--',
                          docData['maghrib'] ?? '--:--', textPrimary, textSecondary, dividerColor),
                      _prayerRow('ISHA', docData['adhanIsha'] ?? '--:--',
                          docData['isha'] ?? '--:--', textPrimary, textSecondary, dividerColor),
                      SizedBox(height: 40.h),
                      _sectionTitle('JUMMAH'),
                      _prayerRow('JUMMAH', docData['adhanJummah'] ?? '--:--',
                          docData['jummah'] ?? '--:--', textPrimary, textSecondary, dividerColor),
                      SizedBox(height: 40.h),
                      _sectionTitle('TARAWEEH'),
                      _singleTimeRow('TARAWEEH PRAYER',
                          docData['taraweeh'] ?? '--:--', textPrimary, dividerColor),
                      const SizedBox(height: 60),
                      _sectionTitle('CHRONICLE'),
                      const SizedBox(height: 16),
                      Text(
                        docData['description'] ??
                            'No historical details available.',
                        style: GoogleFonts.lato(
                            fontSize: 14.sp,
                            height: 2,
                            color: textSecondary,
                            fontWeight: FontWeight.w300),
                      ),
                      const SizedBox(height: 50),
                      _actionButton(
                        'REPORT MOSQUE',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportFormPage(
                                mosqueId: docId,
                                mosqueName: docData['name'] ?? ''),
                          ),
                        ),
                        Colors.redAccent.withOpacity(0.7),
                      ),
                      _actionButton(
                        'SUPPORT MOSQUE',
                        () => _showDonationDialog(context, docData, l10n),
                        MinaretTheme.gold.withOpacity(0.8),
                      ),
                      _actionButton(
                        'GET DIRECTIONS',
                        () => _launchGoogleMaps(context, docData),
                        MinaretTheme.emerald.withOpacity(0.8),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section builders ────────────────────────────────────────────────────────

  Widget _buildAnnouncementsSection(Map<String, dynamic> docData,
      Color textPrimary, Color textSecondary, Color dividerColor) {
    final text = docData['lastAnnouncement'] as String?;
    final time = docData['lastAnnouncementAt'];
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('LATEST ANNOUNCEMENT'),
        const SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: MinaretTheme.emerald.withOpacity(0.05),
            border: Border.all(color: MinaretTheme.emerald.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text,
                  style: GoogleFonts.lato(
                      fontSize: 14.sp, color: textPrimary, height: 1.6)),
              if (time != null) ...[
                const SizedBox(height: 12),
                Text(
                  DateFormat('MMM d, h:mm a')
                      .format(time.toDate())
                      .toUpperCase(),
                  style: GoogleFonts.montserrat(
                      fontSize: 8.sp,
                      color: MinaretTheme.emerald,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJanazaSection(
    BuildContext context,
    MosqueDetailsNotifier n,
    Map<String, dynamic> docData,
    Color textPrimary,
    Color textMuted,
  ) {
    final announcements = n.janazaAnnouncements;
    if (announcements.isEmpty && !n.canEdit) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('JANAZA ANNOUNCEMENTS'),
        const SizedBox(height: 16),
        ...announcements.map((a) => JanazaAnnouncementCard(announcement: a)),
        if (n.canEdit)
          _actionButton(
            '+ POST JANAZA',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JanazaFormPage(
                  mosqueId: docId,
                  mosqueName: docData['name'] ?? '',
                  mosqueFiqh: docData['fiqh'] ?? '',
                  mosqueCity: docData['city'] ?? '',
                ),
              ),
            ),
            MinaretTheme.emerald,
          ),
      ],
    );
  }

  // ── Shared UI helpers ───────────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
            height: 1,
            width: 16.w,
            color: MinaretTheme.gold.withOpacity(0.5)),
        SizedBox(width: 8.w),
        Text(
          title,
          style: GoogleFonts.montserrat(
              fontSize: 7.5.sp,
              letterSpacing: 4,
              color: MinaretTheme.gold,
              fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _prayerColumnHeaders(
      BuildContext context, Color textMuted, AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 4.h),
      child: Row(
        children: [
          const Expanded(flex: 3, child: SizedBox()),
          Expanded(
            flex: 2,
            child: Text(l10n.azanLabel,
                style: GoogleFonts.montserrat(
                    fontSize: 7.sp,
                    letterSpacing: 2,
                    color: textMuted,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(l10n.iqamahLabel,
                style: GoogleFonts.montserrat(
                    fontSize: 7.sp,
                    letterSpacing: 2,
                    color: textMuted,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _prayerRow(String label, String azanTime, String iqamahTime,
      Color textPrimary, Color textSecondary, Color dividerColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 15.h),
      decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: dividerColor, width: 0.5))),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(label,
                  style: GoogleFonts.montserrat(
                      fontSize: 9.sp,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                      color: textPrimary))),
          Expanded(
              flex: 2,
              child: Text(azanTime,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 16.sp, color: textSecondary),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text(iqamahTime,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: textPrimary),
                  textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _singleTimeRow(
      String label, String time, Color textPrimary, Color dividerColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h),
      decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: dividerColor, width: 0.5))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.montserrat(
                  fontSize: 9.sp,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                  color: textPrimary)),
          Text(time,
              style: GoogleFonts.playfairDisplay(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                  color: textPrimary)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: 10.h),
        padding: EdgeInsets.symmetric(vertical: 18.h),
        decoration: BoxDecoration(
            border: Border.all(color: color, width: 0.8),
            color: color.withOpacity(0.04)),
        child: Center(
            child: Text(label,
                style: GoogleFonts.montserrat(
                    fontSize: 9.sp,
                    letterSpacing: 3,
                    color: color,
                    fontWeight: FontWeight.w700))),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : MinaretTheme.onyx.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : MinaretTheme.onyx.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.montserrat(
                  fontSize: 7.sp,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: MinaretTheme.gold.withOpacity(0.8))),
          SizedBox(height: 6.h),
          Text(value,
              style: GoogleFonts.ibmPlexMono(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : MinaretTheme.onyx)),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, bool isDark, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : MinaretTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: isDark ? Colors.white38 : Colors.black26, size: 36.sp),
            const SizedBox(height: 16),
            Text(l10n.unableToLoadMosque,
                style: GoogleFonts.montserrat(
                    fontSize: 9.sp,
                    letterSpacing: 2.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _showDonationDialog(BuildContext context, Map<String, dynamic> docData,
      AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bankName = docData['bankName'] as String?;
    final accountHolder = docData['accountHolder'] as String?;
    final accountNumber = docData['accountNumber'] as String?;
    final mosqueName = docData['name'] as String? ?? 'Mosque';

    if (bankName == null || accountHolder == null || accountNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Donation information not available for this mosque.',
            style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
        backgroundColor: MinaretTheme.gold,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1F2E), const Color(0xFF151B24)]
                  : [const Color(0xFFFAFAFA), const Color(0xFFF5F5F5)],
            ),
            borderRadius: BorderRadius.circular(20.r),
            border:
                Border.all(color: MinaretTheme.gold.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      MinaretTheme.gold.withOpacity(0.15),
                      MinaretTheme.gold.withOpacity(0.05),
                    ]),
                    borderRadius: BorderRadius.circular(15.r),
                    border: Border.all(
                        color: MinaretTheme.gold.withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                            color: MinaretTheme.gold.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: Icon(Icons.account_balance_rounded,
                            color: MinaretTheme.gold, size: 20.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DONATION DETAILS',
                                style: GoogleFonts.montserrat(
                                    fontSize: 8.sp,
                                    letterSpacing: 3,
                                    fontWeight: FontWeight.w800,
                                    color: MinaretTheme.gold)),
                            Text(mosqueName.toUpperCase(),
                                style: GoogleFonts.ibmPlexMono(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : MinaretTheme.onyx)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                _buildDetailRow('BANK', bankName, isDark),
                _buildDetailRow('ACCOUNT HOLDER', accountHolder, isDark),
                _buildDetailRow('ACCOUNT NUMBER', accountNumber, isDark),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final details =
                              'Bank: $bankName\nAccount Holder: $accountHolder\nAccount Number: $accountNumber';
                          await Clipboard.setData(
                              ClipboardData(text: details));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('Account details copied to clipboard',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 12, color: Colors.white)),
                              backgroundColor: MinaretTheme.emerald,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              MinaretTheme.emerald.withOpacity(0.8),
                              MinaretTheme.emerald.withOpacity(0.6),
                            ]),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                              child: Text('COPY DETAILS',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 9.sp,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: MinaretTheme.gold.withOpacity(0.6),
                                width: 1.5),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                              child: Text('CLOSE',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 9.sp,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w700,
                                      color: MinaretTheme.gold))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchGoogleMaps(
      BuildContext context, Map<String, dynamic> docData) async {
    final latitude = docData['lat'] as double?;
    final longitude = docData['lng'] as double?;
    final mosqueName = docData['name'] as String? ?? 'Mosque';

    if (latitude == null || longitude == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Location coordinates not available for this mosque.',
              style:
                  GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude'
        '&destination_place_name=${Uri.encodeComponent(mosqueName)}';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not launch Google Maps.',
                style: GoogleFonts.montserrat(
                    fontSize: 12, color: Colors.white)),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error launching directions: $e',
              style:
                  GoogleFonts.montserrat(fontSize: 12, color: Colors.white)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
