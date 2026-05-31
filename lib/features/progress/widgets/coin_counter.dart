import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

class CoinCounter extends StatelessWidget {
  final int coins;
  final bool compact;

  const CoinCounter({super.key, required this.coins, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pointIcon(16),
          const SizedBox(width: 4),
          Text(
            _format(coins),
            style: GoogleFonts.cairo(
              color: MinaretTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MinaretTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MinaretTheme.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pointIcon(22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)?.progressPoints ?? 'Points',
                style: GoogleFonts.cairo(
                  color: MinaretTheme.slate,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                _format(coins),
                style: GoogleFonts.cairo(
                  color: MinaretTheme.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _pointIcon(double size) => Icon(
        Icons.star_rounded,
        color: MinaretTheme.gold,
        size: size,
      );

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
