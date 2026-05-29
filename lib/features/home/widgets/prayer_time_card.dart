import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';

/// Isolated prayer-time countdown card with its own 1-minute timer.
/// Rebuilds only itself — never touches the mosque list state.
class PrayerTimeCard extends StatefulWidget {
  const PrayerTimeCard({
    super.key,
    required this.nextPrayer,
    required this.prayerName,
  });

  final DateTime? nextPrayer;
  final String? prayerName;

  @override
  State<PrayerTimeCard> createState() => _PrayerTimeCardState();
}

class _PrayerTimeCardState extends State<PrayerTimeCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _countdown() {
    if (widget.nextPrayer == null) return '--';
    final remaining = widget.nextPrayer!.difference(DateTime.now());
    if (remaining.isNegative) return '0m';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.prayerName;

    return Container(
      margin: const EdgeInsets.fromLTRB(25, 0, 25, 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? MinaretTheme.emerald.withValues(alpha: 0.08)
            : MinaretTheme.emerald.withValues(alpha: 0.05),
        border: Border.all(color: MinaretTheme.emerald.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            color: MinaretTheme.emerald,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT PRAYER',
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    letterSpacing: 2,
                    color: MinaretTheme.emerald.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name != null ? name.toUpperCase() : '--',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : MinaretTheme.onyx,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _countdown(),
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: MinaretTheme.emerald,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
