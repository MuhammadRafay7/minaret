import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../repositories/progress_repository.dart';

import '../../core/app_spacing.dart';
import '../../core/theme.dart';
import '../../services/enhanced_prayer_tracker_service.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/premium_loading.dart';
import '../../l10n/generated/app_localizations.dart';
import 'weekly_report_page.dart';

class PrayerStatsPage extends StatefulWidget {
  const PrayerStatsPage({super.key});

  @override
  State<PrayerStatsPage> createState() => _PrayerStatsPageState();
}

class _PrayerStatsPageState extends State<PrayerStatsPage> {
  UserPrayerStats? _userStats;
  List<PrayerRecord>? _recentRecords;
  bool _isLoading = true;
  String _selectedPeriod = '7'; // default; unlocked periods depend on level
  int _userLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Returns the max history days this level is allowed to view.
  static int _maxDaysForLevel(int level) {
    if (level >= 5) return 90;
    if (level >= 3) return 60;
    if (level >= 2) return 30;
    return 7;
  }

  // Minimum level required to select a period string.
  static int _requiredLevelForPeriod(String period) {
    if (period == '90') return 5;
    if (period == '60') return 3;
    if (period == '30') return 2;
    return 1;
  }

  Future<void> _loadData() async {
    // Fetch level separately — a missing/inaccessible progress doc must
    // never prevent prayer data from loading.
    int level = 1;
    try {
      final progress = await ProgressRepository().getProgress();
      level = progress.level;
    } catch (_) {
      // No progress doc yet or permission issue — default to level 1.
    }

    // Cap the selected period to what this level allows.
    final maxDays = _maxDaysForLevel(level);
    final requestedDays = int.parse(_selectedPeriod);
    final effectiveDays = requestedDays > maxDays ? maxDays : requestedDays;

    try {
      final userStats = await EnhancedPrayerTrackerService.getCurrentUserStats();
      final startDate = DateTime.now().subtract(Duration(days: effectiveDays));
      final recentRecords = await EnhancedPrayerTrackerService.getPrayerRecords(
        startDate: startDate,
        endDate: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _userLevel = level;
          _selectedPeriod = effectiveDays.toString();
          _userStats = userStats;
          _recentRecords = recentRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading prayer stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static PopupMenuItem<String> _periodItem(String value, String label, int userLevel) {
    final locked = userLevel < _requiredLevelForPeriod(value);
    final required = _requiredLevelForPeriod(value);
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (locked) ...[
            const SizedBox(width: 8),
            Text(
              'Lv.$required',
              style: const TextStyle(fontSize: 10, color: MinaretTheme.gold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.lock_outline, size: 14, color: MinaretTheme.gold),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(l10n.signInForPrayerStats),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MinaretTheme.darkBackground : MinaretTheme.background;
    final titleColor = isDark ? Colors.white : MinaretTheme.onyx;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: titleColor),
        ),
        title: Text(
          l10n.prayerStatisticsTitle,
          style: MinaretTheme.heading.copyWith(
            fontSize: 20,
            color: titleColor,
            letterSpacing: 2,
          ),
        ),
        actions: [
          // Weekly report — Level 6+ only.
          if (_userLevel >= 6)
            IconButton(
              tooltip: l10n.weeklyReportTooltip,
              icon: const Icon(Icons.bar_chart_rounded, color: MinaretTheme.gold),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeeklyReportPage()),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today, color: MinaretTheme.gold),
            onSelected: (value) {
              final required = _requiredLevelForPeriod(value);
              if (_userLevel < required) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l10n.unlockLevelMsg(required, value)),
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              setState(() => _selectedPeriod = value);
              _loadData();
            },
            itemBuilder: (context) => [
              _periodItem('7', l10n.last7Days, _userLevel),
              _periodItem('30', l10n.last30Days, _userLevel),
              _periodItem('60', l10n.last60Days, _userLevel),
              _periodItem('90', l10n.last90Days, _userLevel),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: _isLoading
                ? const PremiumLoadingScreen()
                : _userStats == null
              ? Center(
                  child: Text(l10n.noPrayerDataYet),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCards(l10n),
                      const SizedBox(height: 24),
                      _buildStreakSection(l10n),
                      const SizedBox(height: 24),
                      _buildPrayerCountsSection(l10n),
                      const SizedBox(height: 24),
                      _buildRecentActivity(l10n),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.overviewSection,
          style: MinaretTheme.detailHeader.copyWith(
            color: MinaretTheme.gold,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                l10n.totalPrayersLabel,
                '${_userStats!.totalPrayers}',
                Icons.access_time,
                MinaretTheme.emerald,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                l10n.daysPrayedLabel,
                '${_userStats!.totalDaysPrayed}',
                Icons.calendar_today,
                MinaretTheme.emeraldLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                l10n.completionRateLabel,
                '${(_userStats!.overallCompletionRate * 100).toInt()}%',
                Icons.trending_up,
                MinaretTheme.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                l10n.lastPrayerLabel,
                DateFormat('MMM d').format(_userStats!.lastPrayerDate),
                Icons.access_time,
                MinaretTheme.gold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B24) : MinaretTheme.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : MinaretTheme.slate,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakSection(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF151B24) : MinaretTheme.background.withValues(alpha: 0.5);
    final mutedText = isDark ? Colors.white54 : MinaretTheme.slate;
    final dividerColor = isDark ? Colors.white12 : MinaretTheme.dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.streaksSection,
          style: MinaretTheme.detailHeader.copyWith(
            color: MinaretTheme.gold,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MinaretTheme.emerald.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentStreakLabel,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department,
                            color: MinaretTheme.emerald, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_userStats!.currentStreak} ${l10n.daysUnit}',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: MinaretTheme.emerald,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: dividerColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.longestStreakLabel,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.emoji_events,
                            color: MinaretTheme.gold, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_userStats!.longestStreak} ${l10n.daysUnit}',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: MinaretTheme.gold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerCountsSection(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF151B24) : MinaretTheme.background.withValues(alpha: 0.5);
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final mutedText = isDark ? Colors.white54 : MinaretTheme.slate;
    final trackColor = isDark ? Colors.white12 : MinaretTheme.dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.prayerBreakdownSection,
          style: MinaretTheme.detailHeader.copyWith(
            color: MinaretTheme.gold,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MinaretTheme.emeraldLight.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: _userStats!.prayerCounts.entries.map((entry) {
              final prayer = entry.key;
              final count = entry.value;
              final rate = _userStats!.prayerCompletionRates[prayer] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Text(
                      prayer,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l10n.prayersCountUnit(count),
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: trackColor,
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: rate,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: MinaretTheme.emeraldLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(rate * 100).toInt()}%',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MinaretTheme.emeraldLight,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(AppLocalizations l10n) {
    if (_recentRecords == null || _recentRecords!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentActivitySection,
          style: MinaretTheme.detailHeader.copyWith(
            color: MinaretTheme.gold,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Builder(builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardColor = isDark ? const Color(0xFF151B24) : MinaretTheme.background.withValues(alpha: 0.5);
          final textPrimary = Theme.of(context).colorScheme.onSurface;
          final mutedText = isDark ? Colors.white54 : MinaretTheme.slate;
          final dividerColor = isDark ? Colors.white12 : MinaretTheme.dividerColor;

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MinaretTheme.gold.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: _recentRecords!.take(10).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final record = entry.value;
                  final isLast = index == (_recentRecords!.take(10).length - 1);
                  final allDone = record.completedPrayers.length == 5;

                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _showDayDetailSheet(record),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: (allDone ? MinaretTheme.emerald : MinaretTheme.gold)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    '${record.completedPrayers.length}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: allDone ? MinaretTheme.emerald : MinaretTheme.gold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEEE, MMM d').format(record.date),
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        color: mutedText,
                                      ),
                                    ),
                                    Text(
                                      '${record.completedPrayers.length} ${l10n.ofFivePrayers}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(record.completionRate * 100).toInt()}%',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: allDone ? MinaretTheme.emerald : MinaretTheme.gold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: mutedText.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: AppSpacing.md,
                          endIndent: AppSpacing.md,
                          color: dividerColor,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showDayDetailSheet(PrayerRecord record) {
    const allPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final missed = allPrayers
        .where((p) => !record.completedPrayers.contains(p))
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = Theme.of(ctx).colorScheme.onSurface;
        final mutedText = isDark ? Colors.white54 : MinaretTheme.slate;
        final dragHandle = isDark ? Colors.white24 : MinaretTheme.dividerColor;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dragHandle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  DateFormat('EEEE, MMMM d').format(record.date),
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  missed.isEmpty
                      ? 'All prayers completed'
                      : '${missed.length} prayer${missed.length == 1 ? '' : 's'} missed',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: missed.isEmpty ? MinaretTheme.emerald : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 20),
                ...allPrayers.map((prayer) {
                  final isDone = record.completedPrayers.contains(prayer);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.cancel_outlined,
                          color: isDone ? MinaretTheme.emerald : Colors.redAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          prayer,
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDone ? textPrimary : mutedText,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isDone ? 'Prayed' : 'Missed',
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDone ? MinaretTheme.emerald : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
