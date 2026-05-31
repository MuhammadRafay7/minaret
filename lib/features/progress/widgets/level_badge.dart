import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

class LevelBadge extends StatelessWidget {
  final int level;
  final bool large;

  const LevelBadge({super.key, required this.level, this.large = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = _badgeColor(isDark);
    final textColor = _textColor();
    final label = AppLocalizations.of(context)?.progressLevelLabel(level) ?? 'Level $level';

    if (large) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: MinaretTheme.gold.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Color _badgeColor(bool isDark) {
    if (level >= 7) return const Color(0xFFFFD700).withValues(alpha: 0.25);
    if (level >= 5) return MinaretTheme.emerald.withValues(alpha: 0.15);
    if (level >= 3) return MinaretTheme.gold.withValues(alpha: 0.15);
    return Colors.grey.withValues(alpha: isDark ? 0.2 : 0.12);
  }

  Color _textColor() {
    if (level >= 7) return const Color(0xFFB8860B);
    if (level >= 5) return MinaretTheme.emerald;
    if (level >= 3) return MinaretTheme.gold;
    return MinaretTheme.slate;
  }
}
