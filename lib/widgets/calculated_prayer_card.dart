import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:provider/provider.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/services/prayer_manager.dart';
import 'package:minaret/services/system_config_service.dart';

class CalculatedPrayerCard extends StatefulWidget {
  final Position? position;
  const CalculatedPrayerCard({super.key, this.position});

  @override
  State<CalculatedPrayerCard> createState() => _CalculatedPrayerCardState();
}

class _CalculatedPrayerCardState extends State<CalculatedPrayerCard> {
  final PrayerManager _manager = PrayerManager();
  PrayerTimes? _times;
  Timer? _nextPrayerTimer;

  @override
  void initState() {
    super.initState();
    _loadTimes();
    // Rebuild every minute so the "next prayer" highlight stays current
    // without depending on the parent page's rebuild cycle.
    _nextPrayerTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _nextPrayerTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(CalculatedPrayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when position changes — GlobalSettings changes handled via Consumer above
    if (widget.position != oldWidget.position) {
      _loadTimes();
    }
  }

  Future<void> _loadTimes() async {
    if (widget.position == null) return;
    
    // We get global settings from the context
    final globalSettings = Provider.of<GlobalSettings?>(context, listen: false);
    
    final t = await _manager.getTodayTimes(
      widget.position!.latitude, 
      widget.position!.longitude,
      globalSettings: globalSettings,
    );
    if (mounted) setState(() => _times = t);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in global settings; didUpdateWidget handles reload
    Provider.of<GlobalSettings?>(context);

    if (_times == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    
    final h = HijriCalendar.now();
    final hijriStr = '${h.hDay} ${h.longMonthName} ${h.hYear} AH';

    final prayers = [
      {'label': l10n?.prayerFajr ?? 'FAJR', 'key': Prayer.fajr, 'time': _times!.fajr},
      {'label': l10n?.prayerDhuhr ?? 'DHUHR', 'key': Prayer.dhuhr, 'time': _times!.dhuhr},
      {'label': l10n?.prayerAsr ?? 'ASR', 'key': Prayer.asr, 'time': _times!.asr},
      {'label': l10n?.prayerMaghrib ?? 'MAGHRIB', 'key': Prayer.maghrib, 'time': _times!.maghrib},
      {'label': l10n?.prayerIsha ?? 'ISHA', 'key': Prayer.isha, 'time': _times!.isha},
    ];

    return Container(
      constraints: BoxConstraints(
        minWidth: 300.w,
        maxWidth: 600.w,
      ),
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B24) : Colors.white,
        border: Border.all(color: MinaretTheme.dividerColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (l10n?.localCalculatedTimes ?? 'LOCAL CALCULATED TIMES').toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 8.sp,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: MinaretTheme.gold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    hijriStr.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 7.sp,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: MinaretTheme.gold.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Icon(Icons.auto_awesome_mosaic_outlined, size: 14.sp, color: MinaretTheme.gold),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: prayers.map((p) {
              final time = p['time'] as DateTime;
              final isNext = _times!.nextPrayer() == p['key'];
              
              return Column(
                children: [
                  Text(
                    (p['label'] as String).toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 7.sp,
                      color: isNext ? MinaretTheme.emerald : MinaretTheme.slate,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    _formatTime(time),
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10.sp,
                      fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                      color: isNext ? MinaretTheme.emerald : (isDark ? Colors.white70 : MinaretTheme.onyx),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
