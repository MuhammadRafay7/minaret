import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';

import '../core/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

void showIslamicCalendar(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _IslamicCalendarSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Event data
// ─────────────────────────────────────────────────────────────────────────────

class _IslamicEvent {
  final String name;
  final String shortLabel; // fits inside a small cell
  final String description;

  const _IslamicEvent(this.name, this.shortLabel, this.description);

  static _IslamicEvent? of(int month, int day) => switch ('$month:$day') {
        '1:1' => const _IslamicEvent(
            'Islamic New Year',
            'NEW YR',
            'First day of Muharram — the Hijri new year begins.',
          ),
        '1:10' => const _IslamicEvent(
            'Ashura',
            'ASHURA',
            'Day of fasting commemorating the salvation of Musa (AS) and his people.',
          ),
        '3:12' => const _IslamicEvent(
            'Mawlid al-Nabi ﷺ',
            'MAWLID',
            'Commemorating the birth of the Prophet Muhammad ﷺ.',
          ),
        '7:27' => const _IslamicEvent(
            "Isra' & Mi'raj",
            "ISRA'",
            "The night journey of the Prophet ﷺ from Makkah to Jerusalem and his ascension to the heavens.",
          ),
        '8:15' => const _IslamicEvent(
            'Shab-e-Barat',
            'SHAB',
            "Night of the 15th of Sha'ban — a night of forgiveness and mercy.",
          ),
        '9:1' => const _IslamicEvent(
            'Ramadan Begins',
            'RAMADAN',
            'The first day of the blessed month of fasting.',
          ),
        '9:27' => const _IslamicEvent(
            'Laylat al-Qadr',
            'AL-QADR',
            'The Night of Power — better than a thousand months (Quran 97:3).',
          ),
        '10:1' => const _IslamicEvent(
            'Eid al-Fitr',
            'EID',
            'Festival of breaking the fast — celebrated on the first day of Shawwal.',
          ),
        '12:9' => const _IslamicEvent(
            'Day of Arafah',
            'ARAFAH',
            'Standing at the plain of Arafah — the pinnacle of Hajj and a day of forgiveness.',
          ),
        '12:10' => const _IslamicEvent(
            'Eid al-Adha',
            'EID',
            "Festival of sacrifice — commemorating Ibrahim's (AS) willingness to sacrifice his son.",
          ),
        _ => null,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _IslamicCalendarSheet extends StatefulWidget {
  const _IslamicCalendarSheet();

  @override
  State<_IslamicCalendarSheet> createState() => _IslamicCalendarSheetState();
}

class _IslamicCalendarSheetState extends State<_IslamicCalendarSheet> {
  late int _hYear;
  late int _hMonth;
  int? _selectedDay;

  final HijriCalendar _now = HijriCalendar.now();
  final HijriCalendar _h = HijriCalendar();

  @override
  void initState() {
    super.initState();
    _hYear = _now.hYear;
    _hMonth = _now.hMonth;
  }

  void _prevMonth() => setState(() {
        _hMonth--;
        if (_hMonth == 0) {
          _hYear--;
          _hMonth = 12;
        }
        _selectedDay = null;
      });

  void _nextMonth() => setState(() {
        _hMonth++;
        if (_hMonth == 13) {
          _hYear++;
          _hMonth = 1;
        }
        _selectedDay = null;
      });

  void _onDayTap(int day) {
    final hasEvent = _IslamicEvent.of(_hMonth, day) != null;
    if (!hasEvent) {
      setState(() => _selectedDay = null);
      return;
    }
    setState(() => _selectedDay = _selectedDay == day ? null : day);
  }

  bool _isToday(int day) =>
      _now.hYear == _hYear && _now.hMonth == _hMonth && _now.hDay == day;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : Colors.white;
    final dimColor = isDark ? Colors.white12 : Colors.black12;

    final int daysInMonth = _h.getDaysInMonth(_hYear, _hMonth);
    final DateTime firstGreg = _h.hijriToGregorian(_hYear, _hMonth, 1);
    final String monthName =
        HijriCalendar.fromDate(firstGreg).longMonthName.toUpperCase();

    // Dart weekday: 1=Mon…7=Sun → 0=Sun…6=Sat
    final int startCol = firstGreg.weekday % 7;
    final int rows = ((startCol + daysInMonth) / 7).ceil();

    final _IslamicEvent? activeEvent = _selectedDay != null
        ? _IslamicEvent.of(_hMonth, _selectedDay!)
        : null;
    final bool viewingCurrentMonth =
        _now.hYear == _hYear && _now.hMonth == _hMonth;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dimColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Month navigation ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  _NavBtn(
                      onTap: _prevMonth,
                      icon: Icons.chevron_left,
                      isDark: isDark),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          monthName,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5,
                            color: MinaretTheme.gold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_hYear AH',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NavBtn(
                      onTap: _nextMonth,
                      icon: Icons.chevron_right,
                      isDark: isDark),
                ],
              ),
            ),

            Divider(height: 1, color: dimColor),

            // ── Day-of-week headers ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .asMap()
                    .entries
                    .map((e) => Expanded(
                          child: Center(
                            child: Text(
                              e.value,
                              style: GoogleFonts.montserrat(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: e.key == 5
                                    ? MinaretTheme.emerald
                                    : (isDark
                                        ? Colors.white38
                                        : Colors.black38),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),

            // ── Calendar grid ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: List.generate(rows, (row) {
                  return Row(
                    children: List.generate(7, (col) {
                      final idx = row * 7 + col;
                      final day = idx - startCol + 1;
                      if (day < 1 || day > daysInMonth) {
                        return const Expanded(child: SizedBox(height: 62));
                      }
                      return Expanded(
                        child: _DayCell(
                          hijriDay: day,
                          gregDay:
                              firstGreg.add(Duration(days: day - 1)).day,
                          isToday: _isToday(day),
                          isSelected: _selectedDay == day,
                          event: _IslamicEvent.of(_hMonth, day),
                          isFriday: col == 5,
                          isDark: isDark,
                          onTap: () => _onDayTap(day),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),

            const SizedBox(height: 10),

            // ── Bottom info strip ────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: activeEvent != null
                  ? _EventStrip(
                      event: activeEvent,
                      isDark: isDark,
                      key: ValueKey(_selectedDay),
                    )
                  : viewingCurrentMonth
                      ? _TodayStrip(
                          now: _now,
                          isDark: isDark,
                          key: const ValueKey('today'),
                        )
                      : const SizedBox(
                          height: 0,
                          key: ValueKey('empty'),
                        ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav button
// ─────────────────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final bool isDark;

  const _NavBtn(
      {required this.onTap, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Icon(icon,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Day cell
// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int hijriDay;
  final int gregDay;
  final bool isToday;
  final bool isSelected;
  final _IslamicEvent? event;
  final bool isFriday;
  final bool isDark;
  final VoidCallback onTap;

  const _DayCell({
    required this.hijriDay,
    required this.gregDay,
    required this.isToday,
    required this.isSelected,
    required this.event,
    required this.isFriday,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasEvent = event != null;

    final Color numColor;
    if (isToday) {
      numColor = Colors.white;
    } else if (isSelected) {
      numColor = MinaretTheme.emerald;
    } else if (isFriday) {
      numColor = MinaretTheme.emerald;
    } else {
      numColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    }

    final subColor = isToday
        ? Colors.white.withValues(alpha: 0.65)
        : (isDark ? Colors.white24 : Colors.black26);

    final labelColor = isToday
        ? Colors.white.withValues(alpha: 0.8)
        : MinaretTheme.emerald;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        margin: const EdgeInsets.all(1.5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Today circle
            if (isToday)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MinaretTheme.gold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: MinaretTheme.gold.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            // Selected event ring
            if (isSelected && !isToday)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MinaretTheme.emerald.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MinaretTheme.emerald.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
              ),

            // Text column
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$hijriDay',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 14,
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w500,
                    color: numColor,
                  ),
                ),
                Text(
                  '$gregDay',
                  style: GoogleFonts.montserrat(
                    fontSize: 7,
                    fontWeight: FontWeight.w500,
                    color: subColor,
                  ),
                ),
                if (hasEvent)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event!.shortLabel,
                      style: GoogleFonts.montserrat(
                        fontSize: 5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: labelColor,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event info strip (shown when a significant day is selected)
// ─────────────────────────────────────────────────────────────────────────────

class _EventStrip extends StatelessWidget {
  final _IslamicEvent event;
  final bool isDark;

  const _EventStrip({required this.event, required this.isDark, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MinaretTheme.emerald.withValues(alpha: isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MinaretTheme.emerald.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: MinaretTheme.emerald,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: MinaretTheme.emerald,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  event.description,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today strip
// ─────────────────────────────────────────────────────────────────────────────

class _TodayStrip extends StatelessWidget {
  final HijriCalendar now;
  final bool isDark;

  const _TodayStrip({required this.now, required this.isDark, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MinaretTheme.gold.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MinaretTheme.gold.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: MinaretTheme.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'TODAY',
            style: GoogleFonts.montserrat(
              fontSize: 7,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: MinaretTheme.gold.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          Text(
            '${now.hDay} ${now.longMonthName} ${now.hYear} AH',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}
