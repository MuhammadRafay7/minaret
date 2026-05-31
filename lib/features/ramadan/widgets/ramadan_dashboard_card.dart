import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../ramadan_service.dart';
import '../ramadan_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RamadanDashboardCard
//
// The single home-screen surface for Ramadan mode. It renders nothing when
// Ramadan is far off (dormant), a slim teaser as it approaches, the live
// countdown + day counter while it's running, and an Eid greeting at the end.
// Tapping the active card opens the full RamadanPage.
// ─────────────────────────────────────────────────────────────────────────────

class RamadanDashboardCard extends StatefulWidget {
  const RamadanDashboardCard({super.key});

  @override
  State<RamadanDashboardCard> createState() => _RamadanDashboardCardState();
}

class _RamadanDashboardCardState extends State<RamadanDashboardCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // One-second tick keeps the countdown live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ramadan = context.watch<RamadanService>();
    final l10n = AppLocalizations.of(context);
    if (l10n == null || !ramadan.isInitialised) return const SizedBox.shrink();

    switch (ramadan.phase) {
      case RamadanPhase.dormant:
        return const SizedBox.shrink();
      case RamadanPhase.teaser:
        return _Teaser(ramadan: ramadan, l10n: l10n);
      case RamadanPhase.eid:
        return _EidCard(l10n: l10n);
      case RamadanPhase.active:
        return _ActiveCard(ramadan: ramadan, l10n: l10n);
    }
  }
}

// ── Countdown phases ───────────────────────────────────────────────────────────

enum _CountdownKind { suhoor, iftar }

class _Countdown {
  final _CountdownKind kind;
  final Duration remaining;
  const _Countdown(this.kind, this.remaining);
}

/// Decides what the single countdown means right now:
///   before Fajr   → "Suhoor ends in" → counts to Imsak
///   Fajr..Maghrib → "Iftar in"       → counts to Maghrib
///   after Maghrib → "Suhoor ends in" → counts to tomorrow's Imsak
_Countdown? _resolveCountdown(RamadanService r) {
  final imsak = r.imsakTime;
  final maghrib = r.iftarTime;
  if (imsak == null || maghrib == null) return null;
  final now = DateTime.now();

  if (now.isBefore(imsak)) {
    return _Countdown(_CountdownKind.suhoor, imsak.difference(now));
  }
  if (now.isBefore(maghrib)) {
    return _Countdown(_CountdownKind.iftar, maghrib.difference(now));
  }
  // After iftar — count to next day's imsak (≈ +24h from today's).
  final nextImsak = imsak.add(const Duration(days: 1));
  return _Countdown(_CountdownKind.suhoor, nextImsak.difference(now));
}

String _fmt(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}

String _clock(DateTime dt) {
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
}

// ── Active card ────────────────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final RamadanService ramadan;
  final AppLocalizations l10n;
  const _ActiveCard({required this.ramadan, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final countdown = _resolveCountdown(ramadan);
    final gold = MinaretTheme.ramadanGold;

    final label = countdown == null
        ? ''
        : (countdown.kind == _CountdownKind.suhoor
            ? l10n.ramadanSuhoorEndsIn
            : l10n.ramadanIftarIn);

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RamadanPage()),
        ),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0A2218), const Color(0xFF071A12)]
                  : [MinaretTheme.ramadanDeep, const Color(0xFF0E5238)],
            ),
            borderRadius: BorderRadius.circular(MinaretTheme.cardRadius),
            boxShadow: MinaretTheme.goldShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.nightlight_round, size: 13.sp, color: gold),
                      SizedBox(width: 6.w),
                      Text(
                        l10n.ramadanLabel,
                        style: GoogleFonts.montserrat(
                          fontSize: 9.sp,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w800,
                          color: gold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l10n.ramadanDayOf(ramadan.dayOfRamadan, ramadan.totalDays),
                    style: GoogleFonts.montserrat(
                      fontSize: 9.sp,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              if (countdown != null) ...[
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 8.sp,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _fmt(countdown.remaining),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ] else
                Text(
                  l10n.ramadanKareem,
                  style: GoogleFonts.amiri(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _TimePill(
                    label: l10n.ramadanImsak,
                    value: ramadan.imsakTime,
                    gold: gold,
                  ),
                  _TimePill(
                    label: l10n.ramadanSuhoor,
                    value: ramadan.suhoorEnd,
                    gold: gold,
                  ),
                  _TimePill(
                    label: l10n.ramadanIftar,
                    value: ramadan.iftarTime,
                    gold: gold,
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.ramadanOpen,
                    style: GoogleFonts.montserrat(
                      fontSize: 8.sp,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: gold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 14.sp, color: gold),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  final String label;
  final DateTime? value;
  final Color gold;
  const _TimePill({required this.label, required this.value, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.montserrat(
            fontSize: 7.sp,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: gold.withValues(alpha: 0.85),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value == null ? '--:--' : _clock(value!),
          style: GoogleFonts.ibmPlexMono(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Teaser ─────────────────────────────────────────────────────────────────────

class _Teaser extends StatelessWidget {
  final RamadanService ramadan;
  final AppLocalizations l10n;
  const _Teaser({required this.ramadan, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = ramadan.daysUntilRamadan ?? 0;
    final text =
        days <= 1 ? l10n.ramadanBeginsTomorrow : l10n.ramadanBeginsInDays(days);

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151B24) : Colors.white,
          border: Border.all(color: MinaretTheme.ramadanGold.withValues(alpha: 0.5), width: 0.8),
          borderRadius: BorderRadius.circular(MinaretTheme.cardRadius),
        ),
        child: Row(
          children: [
            Icon(Icons.nightlight_round, size: 16.sp, color: MinaretTheme.ramadanGold),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.cairo(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : MinaretTheme.ramadanDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Eid ────────────────────────────────────────────────────────────────────────

class _EidCard extends StatelessWidget {
  final AppLocalizations l10n;
  const _EidCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(22.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [MinaretTheme.ramadanGold, Color(0xFFB8860B)],
          ),
          borderRadius: BorderRadius.circular(MinaretTheme.cardRadius),
          boxShadow: MinaretTheme.goldShadow,
        ),
        child: Column(
          children: [
            Icon(Icons.brightness_3_rounded, size: 22.sp, color: Colors.white),
            SizedBox(height: 8.h),
            Text(
              l10n.eidMubarak,
              style: GoogleFonts.amiri(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
