import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../repositories/fasting_repository.dart';
import 'ramadan_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RamadanPage — the full interactive surface: today's fast, Taraweeh, the
// month grid, running stats and the Ramadan settings (±day, imsak, theme).
// ─────────────────────────────────────────────────────────────────────────────

class RamadanPage extends StatefulWidget {
  const RamadanPage({super.key});

  @override
  State<RamadanPage> createState() => _RamadanPageState();
}

class _RamadanPageState extends State<RamadanPage> {
  final _repo = FastingRepository();
  RamadanLog _log = const RamadanLog.empty();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final log = await _repo.getLog();
    if (mounted) {
      setState(() {
        _log = log;
        _loading = false;
      });
    }
  }

  String get _todayKey => FastingRepository.dateKey(DateTime.now());

  Future<void> _setFast(FastStatus status) async {
    final ok = await _repo.setFast(DateTime.now(), status);
    if (!ok) _showSaveError();
    await _load();
  }

  Future<void> _toggleTaraweeh(bool v) async {
    final ok = await _repo.setTaraweeh(DateTime.now(), v);
    if (!ok) _showSaveError();
    await _load();
  }

  void _showSaveError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't save — check your connection")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ramadan = context.watch<RamadanService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.ramadanLabel,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context, ramadan, l10n),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
              children: [
                _header(ramadan, l10n, isDark),
                const SizedBox(height: 20),
                _statsRow(l10n, isDark),
                const SizedBox(height: 20),
                _fastControl(l10n, isDark),
                const SizedBox(height: 16),
                _taraweehControl(l10n, isDark),
                const SizedBox(height: 24),
                _monthGrid(ramadan, l10n, isDark),
              ],
            ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _header(RamadanService r, AppLocalizations l10n, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MinaretTheme.ramadanDeep, Color(0xFF0E5238)],
        ),
        borderRadius: BorderRadius.circular(MinaretTheme.cardRadius),
      ),
      child: Column(
        children: [
          Text(
            r.isEid
                ? l10n.eidMubarak
                : l10n.ramadanDayOf(r.dayOfRamadan, r.totalDays),
            style: GoogleFonts.amiri(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (r.isActive) ...[
            const SizedBox(height: 4),
            Text(
              l10n.ramadanTonightNight(r.dayOfRamadan),
              style: GoogleFonts.montserrat(
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: MinaretTheme.ramadanGold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Widget _statsRow(AppLocalizations l10n, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            '${_log.daysFasted}',
            l10n.ramadanDaysFasted,
            Icons.check_circle_outline,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            '${_log.taraweehNights}',
            l10n.ramadanTaraweehNights,
            Icons.mosque_outlined,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _statTile(String value, String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B24) : Colors.white,
        border: Border.all(color: MinaretTheme.dividerColor, width: 0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: MinaretTheme.ramadanGold),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : MinaretTheme.onyx,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 8,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: MinaretTheme.slate,
            ),
          ),
        ],
      ),
    );
  }

  // ── Today's fast ─────────────────────────────────────────────────────────────

  Widget _fastControl(AppLocalizations l10n, bool isDark) {
    final status = _log.statusFor(_todayKey);
    return _panel(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.ramadanDidYouFast,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : MinaretTheme.onyx,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _choiceButton(
                  label: l10n.ramadanFasted,
                  selected: status?.isKept == true,
                  color: MinaretTheme.emerald,
                  onTap: () => _setFast(FastStatus.fasted),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _choiceButton(
                  label: l10n.ramadanMissed,
                  selected: status != null && !status.isKept,
                  color: MinaretTheme.gold,
                  onTap: () => _pickMissedReason(l10n),
                ),
              ),
            ],
          ),
          if (status != null && !status.isKept) ...[
            const SizedBox(height: 8),
            Text(
              _reasonLabel(status, l10n),
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MinaretTheme.slate,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickMissedReason(AppLocalizations l10n) async {
    final reasons = <FastStatus, String>{
      FastStatus.travel: l10n.ramadanReasonTravel,
      FastStatus.illness: l10n.ramadanReasonIllness,
      FastStatus.menstruation: l10n.ramadanReasonMenstruation,
      FastStatus.other: l10n.ramadanReasonOther,
    };
    final picked = await showModalBottomSheet<FastStatus>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.entries
              .map((e) => ListTile(
                    title: Text(e.value),
                    onTap: () => Navigator.pop(ctx, e.key),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked != null) await _setFast(picked);
  }

  String _reasonLabel(FastStatus s, AppLocalizations l10n) {
    switch (s) {
      case FastStatus.travel:
        return l10n.ramadanReasonTravel;
      case FastStatus.illness:
        return l10n.ramadanReasonIllness;
      case FastStatus.menstruation:
        return l10n.ramadanReasonMenstruation;
      default:
        return l10n.ramadanReasonOther;
    }
  }

  // ── Taraweeh ─────────────────────────────────────────────────────────────────

  Widget _taraweehControl(AppLocalizations l10n, bool isDark) {
    final prayed = _log.taraweehFor(_todayKey);
    return _panel(
      isDark,
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.ramadanPrayedTaraweeh,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : MinaretTheme.onyx,
              ),
            ),
          ),
          Switch(value: prayed, onChanged: _toggleTaraweeh),
        ],
      ),
    );
  }

  // ── Month grid ───────────────────────────────────────────────────────────────

  Widget _monthGrid(RamadanService r, AppLocalizations l10n, bool isDark) {
    final total = r.totalDays;
    final today = r.dayOfRamadan;
    // Map day-of-Ramadan → date key by offsetting from today.
    final now = DateTime.now();
    return _panel(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.ramadanFastingLog.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: MinaretTheme.ramadanGold,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(total, (i) {
              final dayNum = i + 1;
              final date = now.add(Duration(days: dayNum - today));
              final key = FastingRepository.dateKey(date);
              final status = _log.statusFor(key);
              final isToday = dayNum == today;
              final isFuture = dayNum > today;

              Color bg;
              Color fg;
              if (status?.isKept == true) {
                bg = MinaretTheme.emerald;
                fg = Colors.white;
              } else if (status != null) {
                bg = MinaretTheme.gold.withValues(alpha: 0.85);
                fg = Colors.white;
              } else {
                bg = isDark ? Colors.white10 : MinaretTheme.background;
                fg = isFuture ? MinaretTheme.slate.withValues(alpha: 0.4) : MinaretTheme.slate;
              }

              return Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(color: MinaretTheme.ramadanGold, width: 1.6)
                      : null,
                ),
                child: Text(
                  '$dayNum',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Settings sheet ───────────────────────────────────────────────────────────

  void _openSettings(
      BuildContext context, RamadanService r, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SettingsSheet(ramadan: r, l10n: l10n),
    );
  }

  // ── Shared shells ────────────────────────────────────────────────────────────

  Widget _panel(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B24) : Colors.white,
        border: Border.all(color: MinaretTheme.dividerColor, width: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _choiceButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ── Settings sheet ─────────────────────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  final RamadanService ramadan;
  final AppLocalizations l10n;
  const _SettingsSheet({required this.ramadan, required this.l10n});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final r = widget.ramadan;
    final l10n = widget.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.ramadanSettings,
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),

          // Day adjustment ±
          Text(l10n.ramadanDayAdjustment,
              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            l10n.ramadanDayAdjustmentHint,
            style: GoogleFonts.cairo(fontSize: 11, color: MinaretTheme.slate),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed: () async {
                  await r.setAdjustment(r.adjustmentDays - 1);
                  setState(() {});
                },
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  r.adjustmentDays > 0 ? '+${r.adjustmentDays}' : '${r.adjustmentDays}',
                  style: GoogleFonts.ibmPlexMono(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton.outlined(
                onPressed: () async {
                  await r.setAdjustment(r.adjustmentDays + 1);
                  setState(() {});
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const Divider(height: 32),

          // Imsak buffer
          Row(
            children: [
              Expanded(
                child: Text(l10n.ramadanImsakBuffer,
                    style:
                        GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text('${r.imsakBufferMin}',
                  style: GoogleFonts.ibmPlexMono(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: r.imsakBufferMin.toDouble(),
            min: 0,
            max: 30,
            divisions: 30,
            label: '${r.imsakBufferMin}',
            onChanged: (v) async {
              await r.setImsakBuffer(v.round());
              setState(() {});
            },
          ),
          const Divider(height: 32),

          // Ramadan theme toggle
          Row(
            children: [
              Expanded(
                child: Text(l10n.ramadanThemeLabel,
                    style:
                        GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Switch(
                value: r.themeEnabled,
                onChanged: (v) async {
                  await r.setThemeEnabled(v);
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
