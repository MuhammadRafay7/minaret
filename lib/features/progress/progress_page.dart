import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../repositories/progress_repository.dart';
import '../ramadan/ramadan_service.dart';
import 'widgets/level_badge.dart';
import 'widgets/coin_counter.dart';

const int _maxLevel = 7;

// Localized feature unlocks per level.
List<String> _unlocksFor(AppLocalizations l, int lvl) {
  switch (lvl) {
    case 1:
      return [l.unlockBasicTracking, l.unlock7DayHistory];
    case 2:
      return [l.unlock30DayHistory, l.unlockProfileBadge];
    case 3:
      return [l.unlockMultiplier15, l.unlock60DayHistory];
    case 4:
      return [l.unlockQadaAnalytics];
    case 5:
      return [l.unlock90DayHistory, l.unlockMultiplier2];
    case 6:
      return [l.unlockWeeklyReport];
    case 7:
      return [l.unlockMultiplier25, l.unlockGoldBadge];
    default:
      return [];
  }
}

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final _repo = ProgressRepository();
  late final Stream<UserProgress> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repo.progressStream();
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
        title: Text(
          l.progressMyProgress,
          style: GoogleFonts.cairo(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: StreamBuilder<UserProgress>(
        stream: _stream,
        builder: (context, snapshot) {
          final progress = snapshot.data ?? UserProgress.empty('');

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _LevelCard(progress: progress, surface: surface, textPrimary: textPrimary, textSecondary: textSecondary),
              const SizedBox(height: 16),
              _CoinsCard(progress: progress, surface: surface, textPrimary: textPrimary, textSecondary: textSecondary),
              const SizedBox(height: 24),
              Text(
                l.progressHowToEarn,
                style: GoogleFonts.cairo(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              _EarnCard(surface: surface, textPrimary: textPrimary, textSecondary: textSecondary),
              const SizedBox(height: 24),
              Text(
                l.progressAllLevels,
                style: GoogleFonts.cairo(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              _LevelsBreakdown(currentLevel: progress.level, surface: surface, textPrimary: textPrimary, textSecondary: textSecondary),
            ],
          );
        },
      ),
    );
  }
}

// ── Level Card ────────────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final UserProgress progress;
  final Color surface, textPrimary, textSecondary;

  const _LevelCard({
    required this.progress,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isMax = progress.level >= _maxLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: MinaretTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LevelBadge(level: progress.level, large: true),
              const Spacer(),
              if (progress.multiplier > 1.0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: MinaretTheme.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.progressMultiplier(progress.multiplier),
                    style: GoogleFonts.cairo(
                      color: MinaretTheme.emerald,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isMax) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l.progressPointsEarned(progress.totalCoinsEarned),
                    style: GoogleFonts.cairo(color: textSecondary, fontSize: 12),
                  ),
                ),
                Text(
                  l.progressPointsToNext(progress.coinsToNextLevel, progress.level + 1),
                  style: GoogleFonts.cairo(
                    color: MinaretTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.levelProgress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: MinaretTheme.gold.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(MinaretTheme.gold),
              ),
            ),
          ] else
            Text(
              l.progressMaxLevel,
              style: GoogleFonts.cairo(
                color: MinaretTheme.gold,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l.progressUnlockedAtLevel,
            style: GoogleFonts.cairo(
              color: textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(progress.level, (i) {
            final lvl = i + 1;
            return Column(
              children: [
                for (final unlock in _unlocksFor(l, lvl))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: MinaretTheme.emerald, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            unlock,
                            style: GoogleFonts.cairo(color: textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Coins Card ────────────────────────────────────────────────────────────────

class _CoinsCard extends StatelessWidget {
  final UserProgress progress;
  final Color surface, textPrimary, textSecondary;

  const _CoinsCard({
    required this.progress,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: MinaretTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.progressCurrentBalance,
                  style: GoogleFonts.cairo(
                    color: textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                CoinCounter(coins: progress.currentCoins),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: MinaretTheme.dividerColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.progressLifetimeEarned,
                    style: GoogleFonts.cairo(
                      color: textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: MinaretTheme.gold, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${progress.totalCoinsEarned}',
                        style: GoogleFonts.cairo(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Earn Card ─────────────────────────────────────────────────────────────────

class _EarnCard extends StatelessWidget {
  final Color surface, textPrimary, textSecondary;

  const _EarnCard({
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Show Ramadan rewards only while Ramadan mode is active.
    final ramadanActive =
        context.watch<RamadanService?>()?.isActive ?? false;
    final rows = <List<String>>[
      [l.earnPrayerCompleted, l.earnPrayerValue],
      [l.earnFajrBonus, l.earnFajrValue],
      [l.earnFullDay, l.earnFullDayValue],
      [l.earnQada, l.earnQadaValue],
      [l.earnHadith, l.earnHadithValue],
      [l.earnLogin, l.earnLoginValue],
    ];
    final ramadanRows = <List<String>>[
      [l.earnFast, l.earnFastValue],
      [l.earnTaraweeh, l.earnTaraweehValue],
    ];
    final milestones = <List<String>>[
      [l.milestone7, l.milestone7Value],
      [l.milestone40, l.milestone40Value],
      [l.milestone100, l.milestone100Value],
      [l.milestoneFirstQada, l.milestoneFirstQadaValue],
      [l.milestoneFirstFullDay, l.milestoneFirstFullDayValue],
      if (ramadanActive) ...[
        [l.milestoneRamadan10, l.milestoneRamadan10Value],
        [l.milestoneRamadan20, l.milestoneRamadan20Value],
        [l.milestoneRamadanMonth, l.milestoneRamadanMonthValue],
        [l.milestoneTaraweeh10, l.milestoneTaraweeh10Value],
        [l.milestoneTaraweeh27, l.milestoneTaraweeh27Value],
      ],
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: MinaretTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.progressDailyPoints,
            style: GoogleFonts.cairo(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => _buildRow(r[0], r[1])),
          if (ramadanActive) ...[
            const SizedBox(height: 14),
            Divider(color: MinaretTheme.dividerColor),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.nightlight_round, size: 14, color: MinaretTheme.gold),
                const SizedBox(width: 6),
                Text(
                  l.progressRamadanRewards,
                  style: GoogleFonts.cairo(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...ramadanRows.map((r) => _buildRow(r[0], r[1])),
          ],
          const SizedBox(height: 14),
          Divider(color: MinaretTheme.dividerColor),
          const SizedBox(height: 10),
          Text(
            l.progressMilestoneBonuses,
            style: GoogleFonts.cairo(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...milestones.map((r) => _buildRow(r[0], r[1])),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.cairo(color: textPrimary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: MinaretTheme.gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Levels Breakdown ──────────────────────────────────────────────────────────

class _LevelsBreakdown extends StatelessWidget {
  final int currentLevel;
  final Color surface, textPrimary, textSecondary;

  const _LevelsBreakdown({
    required this.currentLevel,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: MinaretTheme.cardShadow,
      ),
      child: Column(
        children: List.generate(_maxLevel, (i) {
          final lvl = i + 1;
          final isUnlocked = lvl <= currentLevel;
          final isCurrent = lvl == currentLevel;
          final threshold = kLevelThresholds[i];
          final unlocks = _unlocksFor(l, lvl);

          return Container(
            decoration: BoxDecoration(
              border: i < _maxLevel - 1
                  ? Border(bottom: BorderSide(color: MinaretTheme.dividerColor))
                  : null,
              color: isCurrent
                  ? MinaretTheme.gold.withValues(alpha: 0.06)
                  : null,
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(20))
                  : i == _maxLevel - 1
                      ? const BorderRadius.vertical(bottom: Radius.circular(20))
                      : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LevelBadge(level: lvl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        threshold == 0
                            ? l.progressStartingLevel
                            : l.progressPointsEarned(threshold),
                        style: GoogleFonts.cairo(
                          color: textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...unlocks.map(
                        (u) => Text(
                          u,
                          style: GoogleFonts.cairo(
                            color: isUnlocked ? textPrimary : textSecondary.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  Icon(
                    isCurrent ? Icons.radio_button_checked : Icons.check_circle,
                    color: isCurrent ? MinaretTheme.gold : MinaretTheme.emerald,
                    size: 18,
                  )
                else
                  Icon(Icons.lock_outline, color: textSecondary.withValues(alpha: 0.3), size: 16),
              ],
            ),
          );
        }),
      ),
    );
  }
}
