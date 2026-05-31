import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_spacing.dart';
import '../../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../repositories/prayer_repository.dart';
import '../../repositories/qada_repository.dart';
import '../../repositories/progress_repository.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/premium_loading.dart';

const _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class QadaPage extends StatefulWidget {
  const QadaPage({super.key});

  @override
  State<QadaPage> createState() => _QadaPageState();
}

class _QadaPageState extends State<QadaPage> {
  final _repo = QadaRepository();
  final _prayerRepo = PrayerRepository();

  QadaData? _data;
  bool _isLoading = true;
  int _userLevel = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      int level = 1;
      try {
        final progress = await ProgressRepository().getProgress();
        level = progress.level;
      } catch (_) {}

      final records = await _prayerRepo.getPrayerRecords();
      final data = await _repo.getQadaData(records);
      if (mounted) {
        setState(() {
          _userLevel = level;
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('QadaPage load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markMadeUp(String prayer) async {
    await _repo.logMakeUp(prayer);
    await _load();
  }

  Future<void> _showAddDebtDialog(String prayer) async {
    int count = 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary = Theme.of(ctx).colorScheme.onSurface;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1C2330) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppLocalizations.of(ctx)!.addQadaDebtTitle,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(ctx)!.addQadaDebtQuestion(prayer),
                style: GoogleFonts.lato(color: isDark ? Colors.white70 : MinaretTheme.slate),
              ),
              const SizedBox(height: 16),
              _DebtCounter(
                onChanged: (v) => count = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(ctx)!.cancelAction, style: GoogleFonts.lato(color: MinaretTheme.slate)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: MinaretTheme.emerald,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(ctx)!.saveLabel, style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _repo.addManualDebt(prayer, count);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MinaretTheme.darkBackground : MinaretTheme.background;

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _appBar(),
        body: Center(child: Text(AppLocalizations.of(context)!.signInForQada)),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: _appBar(),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: _isLoading
                ? const PremiumLoadingScreen()
                : _data == null
                    ? Center(child: Text(AppLocalizations.of(context)!.failedToLoadQada))
                    : RefreshIndicator(
                        color: MinaretTheme.emerald,
                        onRefresh: _load,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoBanner(),
                              const SizedBox(height: 16),
                              _buildSummaryRow(),
                              const SizedBox(height: 24),
                              _userLevel >= 4
                                  ? _buildPrayerList()
                                  : _buildLockedBreakdown(),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MinaretTheme.darkBackground : MinaretTheme.background;
    final titleColor = isDark ? Colors.white : MinaretTheme.onyx;
    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: titleColor),
      ),
      title: Text(
        AppLocalizations.of(context)!.qadaPrayersTitle,
        style: MinaretTheme.heading.copyWith(
          fontSize: 20,
          color: titleColor,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MinaretTheme.gold.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MinaretTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MinaretTheme.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.qadaInfoBanner,
              style: GoogleFonts.lato(
                fontSize: 12,
                color: isDark ? Colors.white70 : MinaretTheme.slate,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF151B24) : MinaretTheme.background.withValues(alpha: 0.5);
    final pending = _data!.totalPending;
    final completed = _data!.totalCompleted;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MinaretTheme.emerald.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(child: _summaryItem(
            label: AppLocalizations.of(context)!.totalPendingLabel,
            value: '$pending',
            color: pending > 0 ? Colors.redAccent : MinaretTheme.emerald,
            icon: Icons.pending_actions,
          )),
          Container(width: 1, height: 40, color: isDark ? Colors.white12 : MinaretTheme.dividerColor),
          Expanded(child: _summaryItem(
            label: AppLocalizations.of(context)!.madeUpLabel,
            value: '$completed',
            color: MinaretTheme.emerald,
            icon: Icons.check_circle_outline,
          )),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : MinaretTheme.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBreakdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B24) : MinaretTheme.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MinaretTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded, color: MinaretTheme.gold, size: 32),
          const SizedBox(height: 12),
          Text(
            'Prayer Breakdown',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : MinaretTheme.onyx,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'See which prayers you miss most and track each one individually. Unlocks at Level 4.',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: isDark ? Colors.white54 : MinaretTheme.slate,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: MinaretTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MinaretTheme.gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Level $_userLevel → Level 4 required',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MinaretTheme.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.prayerBreakdownSection,
          style: MinaretTheme.detailHeader.copyWith(
            color: MinaretTheme.gold,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ..._prayers.map((prayer) => _buildPrayerTile(prayer, isDark)),
      ],
    );
  }

  Widget _buildPrayerTile(String prayer, bool isDark) {
    final pending = _data!.pendingFor(prayer);
    final completed = _data!.completedQada[prayer] ?? 0;
    final allClear = pending == 0;

    final cardColor = isDark ? const Color(0xFF151B24) : MinaretTheme.background.withValues(alpha: 0.5);
    final borderColor = allClear
        ? MinaretTheme.emerald.withValues(alpha: 0.3)
        : Colors.redAccent.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Prayer name + counts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayer,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _badge(
                            AppLocalizations.of(context)!.pendingCountBadge(pending),
                            allClear ? MinaretTheme.emerald : Colors.redAccent,
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          if (completed > 0)
                            _badge(
                              AppLocalizations.of(context)!.madeUpCountBadge(completed),
                              MinaretTheme.emerald,
                              isDark,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Add debt button
                IconButton(
                  tooltip: AppLocalizations.of(context)!.addQadaDebtTooltip,
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: isDark ? Colors.white38 : MinaretTheme.slate,
                    size: 22,
                  ),
                  onPressed: () => _showAddDebtDialog(prayer),
                ),
              ],
            ),
            if (pending > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MinaretTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.markAsMadeUp,
                    style: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onPressed: () => _markMadeUp(prayer),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: MinaretTheme.emerald, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.allCaughtUp,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: MinaretTheme.emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// Simple +/- counter widget for the add debt dialog
class _DebtCounter extends StatefulWidget {
  final ValueChanged<int> onChanged;
  const _DebtCounter({required this.onChanged});

  @override
  State<_DebtCounter> createState() => _DebtCounterState();
}

class _DebtCounterState extends State<_DebtCounter> {
  int _value = 1;

  void _change(int delta) {
    final next = (_value + delta).clamp(1, 999);
    setState(() => _value = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(Icons.remove, () => _change(-1), isDark),
        const SizedBox(width: 24),
        Text(
          '$_value',
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: MinaretTheme.emerald,
          ),
        ),
        const SizedBox(width: 24),
        _circleButton(Icons.add, () => _change(1), isDark),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MinaretTheme.emerald.withValues(alpha: 0.12),
          border: Border.all(color: MinaretTheme.emerald.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 20, color: MinaretTheme.emerald),
      ),
    );
  }
}
