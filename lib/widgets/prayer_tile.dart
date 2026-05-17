import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme.dart';

/// Single prayer time row — label on the left, time on the right.
/// Used inside mosque detail pages.
class PrayerTile extends StatelessWidget {
  final String label;
  final String time;

  /// Highlight this tile as the next upcoming prayer
  final bool isNext;

  const PrayerTile({
    super.key,
    required this.label,
    required this.time,
    this.isNext = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        vertical: 14.h,
        horizontal: isNext ? 10.w : 0,
      ),
      decoration: isNext
          ? BoxDecoration(
              color: MinaretTheme.gold.withOpacity(0.06),
              border: Border.all(
                color: MinaretTheme.gold.withOpacity(0.2),
                width: 0.6,
              ),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Prayer label — gold when next, slate otherwise
          Text(
            label.toUpperCase(),
            style: GoogleFonts.montserrat(
              letterSpacing: 2.5,
              fontSize: 10.sp,
              color: isNext ? MinaretTheme.gold : MinaretTheme.slate,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          // Time — larger and bolder for at-a-glance reading
          Text(
            time,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 17.sp,
              color: isNext ? MinaretTheme.gold : MinaretTheme.onyx,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
