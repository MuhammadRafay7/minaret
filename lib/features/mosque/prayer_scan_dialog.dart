import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';
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
    final isIqamahBoard = times.timeType == 'iqamah';

    return AlertDialog(
      backgroundColor: MinaretTheme.background,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRAYER TIMES DETECTED',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(
                isIqamahBoard
                    ? 'IQAMAH BOARD'
                    : times.timeType == 'azan'
                        ? 'AZAN BOARD'
                        : 'PRAYER BOARD',
                MinaretTheme.emerald,
              ),
              const SizedBox(width: 8),
              _chip('${times.confidence}% CONFIDENCE', _confidenceColor()),
            ],
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _tableHeader(),
            const Divider(height: 12),
            _row('FAJR',    times.adhanFajr,    times.fajr,    isIqamahBoard),
            _row('DHUHR',   times.adhanDhuhr,   times.dhuhr,   isIqamahBoard),
            _row('ASR',     times.adhanAsr,      times.asr,     isIqamahBoard),
            _row('MAGHRIB', times.adhanMaghrib,  times.maghrib, isIqamahBoard),
            _row('ISHA',    times.adhanIsha,     times.isha,    isIqamahBoard),
            if (times.adhanJummah != null || times.jummah != null)
              _row('JUMMAH', times.adhanJummah, times.jummah,  isIqamahBoard),
            const Divider(height: 16),
            _estimateNote(isIqamahBoard),
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'RETAKE',
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
            'APPLY ALL',
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

  Widget _tableHeader() {
    return Row(
      children: [
        const SizedBox(width: 72),
        Expanded(
          child: Text('AZAN', textAlign: TextAlign.center, style: _labelStyle()),
        ),
        Expanded(
          child: Text('IQAMAH', textAlign: TextAlign.center, style: _labelStyle()),
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
          // Azan column — estimated if board was iqamah
          Expanded(
            child: _timeCell(azan, estimated: !isIqamahBoard ? false : true),
          ),
          // Iqamah column — estimated if board was azan
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

  Widget _estimateNote(bool isIqamahBoard) {
    final msg = isIqamahBoard
        ? 'Azan times estimated: Fajr −15m · Dhuhr −10m · Asr −10m · Maghrib −5m · Isha −10m'
        : 'Iqamah times estimated: Fajr +20m · Dhuhr +15m · Asr +15m · Maghrib +10m · Isha +20m';
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
