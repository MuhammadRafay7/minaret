import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'prayer_scan_service.dart';

class PrayerScanDialog extends StatelessWidget {
  final ScannedPrayerTimes times;
  final VoidCallback onConfirm;

  const PrayerScanDialog({
    super.key,
    required this.times,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isIqamahBoard = times.timeType == 'iqamah';

    final boardLabel = isIqamahBoard
        ? l10n.iqamahBoard
        : times.timeType == 'azan'
            ? l10n.azanBoard
            : l10n.prayerBoard;

    return AlertDialog(
      backgroundColor: MinaretTheme.background,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.prayerTimesDetected,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(boardLabel, MinaretTheme.emerald),
              const SizedBox(width: 8),
              _chip(l10n.confidencePercent(times.confidence), _confidenceColor()),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _tableHeader(l10n),
            const Divider(height: 12),
            _row(l10n.prayerFajr.toUpperCase(),    times.adhanFajr,    times.fajr,    isIqamahBoard),
            _row(l10n.prayerDhuhr.toUpperCase(),   times.adhanDhuhr,   times.dhuhr,   isIqamahBoard),
            _row(l10n.prayerAsr.toUpperCase(),     times.adhanAsr,     times.asr,     isIqamahBoard),
            _row(l10n.prayerMaghrib.toUpperCase(), times.adhanMaghrib, times.maghrib, isIqamahBoard),
            _row(l10n.prayerIsha.toUpperCase(),    times.adhanIsha,    times.isha,    isIqamahBoard),
            if (times.adhanJummah != null || times.jummah != null)
              _row(l10n.eventJummah.toUpperCase(), times.adhanJummah, times.jummah, isIqamahBoard),
            const Divider(height: 16),
            _estimateNote(l10n, isIqamahBoard),
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.retakeAction,
            style: GoogleFonts.montserrat(
              color: Colors.black45,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(
            l10n.applyAllAction,
            style: GoogleFonts.montserrat(
              color: MinaretTheme.emerald,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(AppLocalizations l10n) {
    return Row(
      children: [
        const SizedBox(width: 72),
        Expanded(
          child: Text(l10n.azanLabel, textAlign: TextAlign.center, style: _labelStyle()),
        ),
        Expanded(
          child: Text(l10n.iqamahLabel, textAlign: TextAlign.center, style: _labelStyle()),
        ),
      ],
    );
  }

  Widget _row(
    String prayer,
    String? azan,
    String? iqamah,
    bool isIqamahBoard,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              prayer,
              style: GoogleFonts.montserrat(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: _timeCell(azan, estimated: !isIqamahBoard ? false : true),
          ),
          Expanded(
            child: _timeCell(iqamah, estimated: isIqamahBoard ? false : true),
          ),
        ],
      ),
    );
  }

  Widget _timeCell(String? time, {required bool estimated}) {
    final display = time ?? '--:--';
    return Column(
      children: [
        Text(
          display,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: estimated ? Colors.black38 : MinaretTheme.onyx,
          ),
        ),
        if (estimated && time != null)
          Text(
            'est.',
            style: GoogleFonts.montserrat(
              fontSize: 7,
              color: MinaretTheme.gold,
              letterSpacing: 1,
            ),
          ),
      ],
    );
  }

  Widget _estimateNote(AppLocalizations l10n, bool isIqamahBoard) {
    final msg = isIqamahBoard ? l10n.azanEstimateNote : l10n.iqamahEstimateNote;
    return Text(
      msg,
      style: GoogleFonts.lato(
        fontSize: 10,
        color: Colors.black38,
        fontStyle: FontStyle.italic,
        height: 1.5,
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 7,
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Color _confidenceColor() {
    if (times.confidence >= 80) return MinaretTheme.emerald;
    if (times.confidence >= 60) return MinaretTheme.gold;
    return Colors.redAccent;
  }

  TextStyle _labelStyle() => GoogleFonts.montserrat(
        fontSize: 8,
        letterSpacing: 2,
        color: MinaretTheme.gold,
        fontWeight: FontWeight.bold,
      );
}
