import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/app_spacing.dart';
import '../../core/theme.dart';
import '../../services/enhanced_prayer_tracker_service.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/premium_loading.dart';
import '../../l10n/generated/app_localizations.dart';

class PrayerStatsPage extends StatefulWidget {
  const PrayerStatsPage({super.key});

  @override
  State<PrayerStatsPage> createState() => _PrayerStatsPageState();
}

class _PrayerStatsPageState extends State<PrayerStatsPage> {
  UserPrayerStats? _userStats;
  List<PrayerRecord>? _recentRecords;
  bool _isLoading = true;
  String _selectedPeriod = '30'; // 7, 30, 90 days

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userStats = await EnhancedPrayerTrackerService.getCurrentUserStats();
      
      // Get recent records based on selected period
      final days = int.parse(_selectedPeriod);
      final startDate = DateTime.now().subtract(Duration(days: days));
      final recentRecords = await EnhancedPrayerTrackerService.getPrayerRecords(
        startDate: startDate,
        endDate: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _userStats = userStats;
          _recentRecords = recentRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading prayer stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context)!;

    if (user == null) {
      return Scaffold(
        backgroundColor: MinaretTheme.background,
        body: Center(
          child: Text(l10n.signInForPrayerStats),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MinaretTheme.background,
      appBar: AppBar(
        backgroundColor: MinaretTheme.emerald,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 14, color: Colors.white),
        ),
        title: Text(
          l10n.prayerStatisticsTitle,
          style: MinaretTheme.heading.copyWith(
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
              _loadData();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: '7', child: Text(l10n.last7Days)),
              PopupMenuItem(value: '30', child: Text(l10n.last30Days)),
              PopupMenuItem(value: '90', child: Text(l10n.last90Days)),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MinaretTheme.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
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
                  color: MinaretTheme.slate,
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
            color: MinaretTheme.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MinaretTheme.emerald.withOpacity(0.3),
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
                        color: MinaretTheme.slate,
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
                color: MinaretTheme.dividerColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.longestStreakLabel,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: MinaretTheme.slate,
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
            color: MinaretTheme.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MinaretTheme.emeraldLight.withOpacity(0.3),
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
                        color: MinaretTheme.onyx,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l10n.prayersCountUnit(count),
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: MinaretTheme.slate,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: MinaretTheme.dividerColor,
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
        Container(
          decoration: BoxDecoration(
            color: MinaretTheme.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: MinaretTheme.gold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: _recentRecords!.take(10).map((record) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MinaretTheme.gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          '${record.completedPrayers.length}',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MinaretTheme.gold,
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
                              color: MinaretTheme.slate,
                            ),
                          ),
                          Text(
                            '${record.completedPrayers.length} ${l10n.ofFivePrayers}',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MinaretTheme.onyx,
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
                        color: MinaretTheme.gold,
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
}
