import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/enhanced_prayer_tracker_service.dart';

const _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class WeeklyReportPage extends StatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  List<PrayerRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    try {
      final startDate = DateTime.now().subtract(const Duration(days: 6));
      final records = await EnhancedPrayerTrackerService.getPrayerRecords(
        startDate: DateTime(startDate.year, startDate.month, startDate.day),
        endDate: DateTime.now(),
      );
      if (mounted) setState(() { _records = records; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Build a map of day-key → completed prayers list for the past 7 days.
  Map<String, List<String>> _buildDayMap() {
    final map = <String, List<String>>{};
    for (final r in _records) {
      final key = _dayKey(r.date);
      map[key] = r.completedPrayers;
    }
    return map;
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Overall completion rate for the week.
  double _weekRate(Map<String, List<String>> dayMap) {
    if (dayMap.isEmpty) return 0.0;
    final total = dayMap.values.fold<int>(0, (s, p) => s + p.length);
    return total / (7 * 5);
  }

  // Per-prayer completion rate.
  double _prayerRate(Map<String, List<String>> dayMap, String prayer) {
    final done = dayMap.values.where((p) => p.contains(prayer)).length;
    return done / 7;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MinaretTheme.darkBackground : MinaretTheme.background;
    final surface = isDark ? MinaretTheme.darkSurface : Colors.white;
    final textPrimary = isDark ? Colors.white : MinaretTheme.onyx;
    final textSecondary = isDark ? Colors.white60 : MinaretTheme.slate;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
        ),
        title: Text(
          l.weeklyReportTitle,
          style: GoogleFonts.cairo(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                l.weeklyLast7Days,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: MinaretTheme.gold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: MinaretTheme.gold, strokeWidth: 1.5))
          : _buildReport(context, surface, textPrimary, textSecondary, isDark),
    );
  }

  Widget _buildReport(BuildContext context, Color surface, Color textPrimary, Color textSecondary, bool isDark) {
    final l = AppLocalizations.of(context)!;
    final dayMap = _buildDayMap();
    final weekRate = _weekRate(dayMap);

    // Generate the last 7 days in order (oldest → newest).
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Overall score card ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: MinaretTheme.cardShadow,
          ),
          child: Column(
            children: [
              Text(
                '${(weekRate * 100).round()}%',
                style: GoogleFonts.montserrat(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: _rateColor(weekRate),
                ),
              ),
              Text(
                l.weeklyCompletion,
                style: GoogleFonts.cairo(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: weekRate.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: MinaretTheme.gold.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(_rateColor(weekRate)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.weeklyPrayersCount(dayMap.values.fold<int>(0, (s, p) => s + p.length)),
                    style: GoogleFonts.lato(color: textSecondary, fontSize: 12),
                  ),
                  Text(
                    dayMap.length == 7 ? l.weeklyPerfectAttendance : l.weeklyDaysActive(dayMap.length),
                    style: GoogleFonts.lato(
                      color: dayMap.length == 7 ? MinaretTheme.emerald : textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Day-by-day grid ─────────────────────────────────────────────────
        Text(
          l.weeklyDayByDay,
          style: GoogleFonts.cairo(
            color: textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: MinaretTheme.cardShadow,
          ),
          child: Column(
            children: days.asMap().entries.map((entry) {
              final i = entry.key;
              final day = entry.value;
              final key = _dayKey(day);
              final completed = dayMap[key] ?? [];
              final isToday = _dayKey(today) == key;

              return Container(
                decoration: BoxDecoration(
                  border: i < 6
                      ? Border(bottom: BorderSide(color: MinaretTheme.dividerColor))
                      : null,
                  borderRadius: i == 0
                      ? const BorderRadius.vertical(top: Radius.circular(16))
                      : i == 6
                          ? const BorderRadius.vertical(bottom: Radius.circular(16))
                          : null,
                  color: isToday ? MinaretTheme.gold.withValues(alpha: 0.05) : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Day name + date
                    SizedBox(
                      width: 56,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isToday ? l.weeklyToday : DateFormat('EEE').format(day),
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isToday ? MinaretTheme.gold : textPrimary,
                            ),
                          ),
                          Text(
                            DateFormat('d MMM').format(day),
                            style: GoogleFonts.lato(
                              fontSize: 10,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Prayer dots
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _prayers.map((prayer) {
                          final done = completed.contains(prayer);
                          return Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? MinaretTheme.emerald.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: isDark ? 0.15 : 0.08),
                                  border: Border.all(
                                    color: done
                                        ? MinaretTheme.emerald.withValues(alpha: 0.5)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Center(
                                  child: done
                                      ? Icon(Icons.check, size: 14, color: MinaretTheme.emerald)
                                      : const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                prayer[0], // F, D, A, M, I
                                style: GoogleFonts.montserrat(
                                  fontSize: 8,
                                  color: done ? MinaretTheme.emerald : textSecondary.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    // Count
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${completed.length}/5',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: completed.length == 5
                              ? MinaretTheme.emerald
                              : completed.isEmpty
                                  ? Colors.red.withValues(alpha: 0.6)
                                  : MinaretTheme.gold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // ── Per-prayer breakdown ────────────────────────────────────────────
        Text(
          l.weeklyPerPrayer,
          style: GoogleFonts.cairo(
            color: textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: MinaretTheme.cardShadow,
          ),
          child: Column(
            children: _prayers.map((prayer) {
              final rate = _prayerRate(dayMap, prayer);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        prayer,
                        style: GoogleFonts.cairo(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rate.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: MinaretTheme.emerald.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(_rateColor(rate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${(rate * 100).round()}%',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _rateColor(rate),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 0.8) return MinaretTheme.emerald;
    if (rate >= 0.5) return MinaretTheme.gold;
    return Colors.redAccent;
  }
}
