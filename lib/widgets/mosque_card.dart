import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:minaret/features/mosque/details_page.dart';
import 'package:minaret/features/mosque/edit_mosque_page.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/locale_format.dart';
import 'package:minaret/core/constants/fiqh_constants.dart';
import 'package:minaret/services/mosque_follow_service.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MosqueCard — Andalusian Dark Header style
//
// Header:  Deep forest-green (#0F2D1E) with a subtle gold geometric tile
//          overlay. Mosque name in Amiri serif, fiqh + countdown in Cairo.
// Body:    Prayer times on the app's sandstone background (#F2EDE3 light /
//          #111826 dark), next prayer highlighted in emerald.
// ─────────────────────────────────────────────────────────────────────────────

class MosqueCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String? distance;
  final bool isEditable;
  final bool isFollowing;

  const MosqueCard({
    super.key,
    required this.data,
    required this.docId,
    this.distance,
    this.isEditable = false,
    this.isFollowing = false,
  });

  @override
  State<MosqueCard> createState() => _MosqueCardState();
}

class _MosqueCardState extends State<MosqueCard> {
  StreamSubscription<void>? _tickerSub;

  @override
  void initState() {
    super.initState();
    _tickerSub = Stream.periodic(const Duration(seconds: 1))
        .listen((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tickerSub?.cancel();
    super.dispose();
  }

  // ── prayer helpers ────────────────────────────────────────────────────────

  DateTime _parsePrayerTime(String t) =>
      LocaleFormat.parsePrayerTimeToday(t) ??
      DateTime.now().subtract(const Duration(days: 1));

  String _getNextPrayerStatus(AppLocalizations? l10n) {
    try {
      final now = DateTime.now();
      const keys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
      for (final key in keys) {
        final s = widget.data[key] as String?;
        if (s == null || s == '--:--' || s.isEmpty) continue;
        final t = _parsePrayerTime(s);
        if (t.isAfter(now)) return _fmt(key, t.difference(now), l10n);
      }
      final fajr = widget.data['fajr'] as String?;
      if (fajr != null && fajr != '--:--') {
        final tmr = _parsePrayerTime(fajr).add(const Duration(days: 1));
        return _fmt('fajr', tmr.difference(now), l10n);
      }
      return l10n?.noData ?? 'NO DATA';
    } catch (e) {
      debugPrint('Countdown error: $e');
      return '';
    }
  }

  String _fmt(String label, Duration d, AppLocalizations? l10n) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final t = h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
    return '${label.toUpperCase()} ${l10n?.inLabel ?? 'IN'} $t';
  }

  Future<void> _launchDirections() async {
    final lat = widget.data['lat'];
    final lng = widget.data['lng'];
    if (lat == null || lng == null) return;
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleFollow(bool currently) async => currently
      ? MosqueFollowService.unfollow(widget.docId)
      : MosqueFollowService.follow(widget.docId);

  String _cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = widget.data['adminUid'] == user?.uid;
    final l10n = AppLocalizations.of(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nextStatus = _getNextPrayerStatus(l10n);
    final isSoon = nextStatus.isNotEmpty &&
        nextStatus.contains('M') &&
        !nextStatus.contains('H');

    final status =
        (widget.data['status'] as String? ?? 'approved').toLowerCase();
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    final fiqh = FiqhConstants.labelFor(
        (widget.data['fiqh'] as String? ?? '').trim());
    final hasFiqh = fiqh != FiqhConstants.options[''];

    return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DetailsPage(data: widget.data, docId: widget.docId),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.only(bottom: 18.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151B24) : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSoon
                    ? MinaretTheme.gold.withValues(alpha: 0.45)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.07)),
                width: 0.5,
              ),
              boxShadow:
                  isSoon ? MinaretTheme.goldShadow : MinaretTheme.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    data: widget.data,
                    docId: widget.docId,
                    isOwner: isOwner,
                    isPending: isPending,
                    isRejected: isRejected,
                    hasFiqh: hasFiqh,
                    fiqh: fiqh,
                    nextStatus: nextStatus,
                    isSoon: isSoon,
                    isEditable: widget.isEditable,
                    isFollowing: widget.isFollowing,
                    distance: widget.distance,
                    userId: user?.uid,
                    onFollowToggle: () => _toggleFollow(widget.isFollowing),
                    onDirections: _launchDirections,
                    l10n: l10n,
                  ),
                  _PrayerRow(
                    data: widget.data,
                    parsePrayerTime: _parsePrayerTime,
                    isSoon: isSoon,
                    isDark: isDark,
                    l10n: l10n,
                    cap: _cap,
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Header widget
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isOwner, isPending, isRejected, hasFiqh;
  final bool isEditable, isFollowing;
  final String fiqh, nextStatus;
  final bool isSoon;
  final String? distance, userId;
  final VoidCallback onFollowToggle, onDirections;
  final AppLocalizations? l10n;

  static const _headerBg = Color(0xFF0F2D1E);
  static const _creamText = Color(0xFFF5EDD8);
  static const _goldSoft = Color(0xFFE8C96A);

  const _Header({
    required this.data,
    required this.docId,
    required this.isOwner,
    required this.isPending,
    required this.isRejected,
    required this.hasFiqh,
    required this.fiqh,
    required this.nextStatus,
    required this.isSoon,
    required this.isEditable,
    required this.isFollowing,
    required this.distance,
    required this.userId,
    required this.onFollowToggle,
    required this.onDirections,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // base colour
        Positioned.fill(child: ColoredBox(color: _headerBg)),
        // geometric tile
        const Positioned.fill(child: _GeometricTileOverlay()),
        // content
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 14.w, 15.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _leftCol(context)),
              SizedBox(width: 10.w),
              _rightCol(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leftCol(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // admin + workflow badges
        if (isOwner) ...[
          Wrap(
            spacing: 6.w,
            children: [
              _badge(
                label: l10n?.adminLabel ?? 'ADMIN',
                borderColor: _goldSoft.withValues(alpha: 0.55),
                textColor: _goldSoft,
              ),
              if (isPending || isRejected)
                _badge(
                  label: isPending
                      ? (l10n?.pendingApproval ?? 'PENDING')
                      : (l10n?.rejectedStatus ?? 'REJECTED'),
                  borderColor: (isPending ? Colors.orange : Colors.redAccent)
                      .withValues(alpha: 0.7),
                  textColor: isPending ? Colors.orange : Colors.redAccent,
                ),
            ],
          ),
          SizedBox(height: 6.h),
        ],

        // fiqh sub-label
        if (hasFiqh) ...[
          Text(
            fiqh.toUpperCase(),
            style: GoogleFonts.cairo(
              fontSize: 9.sp,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
              color: _goldSoft.withValues(alpha: 0.60),
            ),
          ),
          SizedBox(height: 4.h),
        ],

        // mosque name — Amiri serif
        Text(
          data['name'] ?? 'Masjid',
          style: GoogleFonts.amiri(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: _creamText,
            height: 1.2,
          ),
          softWrap: true,
        ),

        // countdown pill
        if (nextStatus.isNotEmpty) ...[
          SizedBox(height: 10.h),
          _CountdownPill(status: nextStatus, isSoon: isSoon),
        ],
      ],
    );
  }

  Widget _rightCol(BuildContext context) {
    // edit mode
    if (isEditable) {
      return _IconBtn(
        icon: Icons.edit_note_rounded,
        color: _goldSoft,
        size: 22.sp,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditMosquePage(currentData: data, docId: docId),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // distance chip
        if (distance != null) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: _goldSoft.withValues(alpha: 0.12),
              border: Border.all(
                color: _goldSoft.withValues(alpha: 0.28),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              '${LocaleFormat.decimal(context, double.tryParse(distance ?? '') ?? 0)} km',
              style: GoogleFonts.cairo(
                color: _goldSoft,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 8.h),
        ],

        // follow + directions
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBtn(
              icon: isFollowing
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: isFollowing
                  ? MinaretTheme.emeraldLight
                  : Colors.white.withValues(alpha: 0.35),
              size: 20.sp,
              onTap: userId != null ? onFollowToggle : null,
            ),
            SizedBox(width: 5.w),
            _IconBtn(
              icon: Icons.north_east_rounded,
              color:
                  isSoon ? MinaretTheme.gold : Colors.white.withValues(alpha: 0.35),
              size: 20.sp,
              onTap: onDirections,
            ),
          ],
        ),
      ],
    );
  }

  Widget _badge({
    required String label,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 0.5),
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: textColor,
          fontSize: 7.sp,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CountdownPill
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownPill extends StatelessWidget {
  final String status;
  final bool isSoon;

  const _CountdownPill({required this.status, required this.isSoon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: isSoon
            ? MinaretTheme.gold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: isSoon
              ? MinaretTheme.gold.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.w,
            height: 5.w,
            decoration: BoxDecoration(
              color: isSoon
                  ? MinaretTheme.gold
                  : const Color(0xFFE8C96A).withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            LocaleFormat.localizedDigits(context, status),
            style: GoogleFonts.cairo(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isSoon ? MinaretTheme.gold : const Color(0xFFE8C96A),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PrayerRow
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime Function(String) parsePrayerTime;
  final bool isSoon, isDark;
  final AppLocalizations? l10n;
  final String Function(String) cap;

  const _PrayerRow({
    required this.data,
    required this.parsePrayerTime,
    required this.isSoon,
    required this.isDark,
    required this.l10n,
    required this.cap,
  });

  @override
  Widget build(BuildContext context) {
    const prayers = [
      {'key': 'fajr', 'label': 'FJR'},
      {'key': 'dhuhr', 'label': 'DHR'},
      {'key': 'asr', 'label': 'ASR'},
      {'key': 'maghrib', 'label': 'MGH'},
      {'key': 'isha', 'label': 'ISH'},
    ];

    final now = DateTime.now();
    String? nextKey;
    for (final p in prayers) {
      final s = data[p['key']] as String?;
      if (s == null || s == '--:--' || s.isEmpty) continue;
      if (parsePrayerTime(s).isAfter(now)) {
        nextKey = p['key'];
        break;
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(8.w, 12.h, 8.w, 14.h),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF111826)
            : MinaretTheme.background.withValues(alpha: 0.55),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: prayers.map((p) {
          final isNext = p['key'] == nextKey;
          final namaz = (data[p['key']] ?? '--:--').toString();
          final adhanKey = 'adhan${cap(p['key']!)}';
          final adhan = (data[adhanKey] ?? '--:--').toString();
          return Flexible(
            child: _PrayerCell(
              label: p['label']!,
              namazTime: namaz,
              adhanTime: adhan,
              isNext: isNext,
              isDark: isDark,
              l10n: l10n,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PrayerCell
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerCell extends StatelessWidget {
  final String label, namazTime, adhanTime;
  final bool isNext, isDark;
  final AppLocalizations? l10n;

  const _PrayerCell({
    required this.label,
    required this.namazTime,
    required this.adhanTime,
    required this.isNext,
    required this.isDark,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? Colors.white54 : MinaretTheme.slate;
    final displayN = LocaleFormat.prayerDisplayTime(context, namazTime);
    final displayA = LocaleFormat.prayerDisplayTime(context, adhanTime);
    final pfx = l10n?.adhanPrefix ?? 'A:';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // label
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 7.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isNext ? MinaretTheme.emerald : muted.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 5.h),

        // iqamah / namaz time
        Container(
          padding: isNext
              ? EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h)
              : EdgeInsets.zero,
          decoration: isNext
              ? BoxDecoration(
                  color: MinaretTheme.emerald.withValues(alpha: 0.09),
                  border: Border.all(
                    color: MinaretTheme.emerald.withValues(alpha: 0.22),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(3.r),
                )
              : null,
          child: Text(
            displayN,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.sp,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w400,
              color: isNext ? MinaretTheme.emerald : muted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: 3.h),

        // adhan time
        Text(
          '$pfx $displayA',
          style: GoogleFonts.ibmPlexMono(
            fontSize: 8.sp,
            color: muted.withValues(alpha: 0.6),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _IconBtn — small square button used in header actions
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w,
        height: 32.w,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(8.r),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GeometricTileOverlay — Andalusian hexagonal gold tile pattern
// Rendered via CustomPainter; very low opacity so it reads as texture only.
// ─────────────────────────────────────────────────────────────────────────────

class _GeometricTileOverlay extends StatelessWidget {
  const _GeometricTileOverlay();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _TilePainter());
}

class _TilePainter extends CustomPainter {
  static const _gold = Color(0xFFE8C96A);
  static const _tileSize = 44.0;

  @override
  void paint(Canvas canvas, Size size) {
    final hex = Paint()
      ..color = _gold.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55;

    final inner = Paint()
      ..color = _gold.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.35;

    final cols = (size.width / _tileSize).ceil() + 1;
    final rows = (size.height / _tileSize).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = col * _tileSize + (row.isOdd ? _tileSize / 2 : 0);
        final cy = row * _tileSize * 0.86; // hex row spacing
        _drawHex(canvas, cx, cy, _tileSize / 2.3, hex);
        _drawHex(canvas, cx, cy, _tileSize / 5.0, inner);
      }
    }
  }

  void _drawHex(Canvas canvas, double cx, double cy, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TilePainter old) => false;
}
