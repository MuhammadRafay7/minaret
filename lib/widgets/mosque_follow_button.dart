import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';

class MosqueFollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onToggle;

  const MosqueFollowButton({
    super.key,
    required this.isFollowing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onToggle();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFollowing
                  ? 'YOU WILL NO LONGER RECEIVE JANAZA NOTIFICATIONS'
                  : 'YOU WILL BE NOTIFIED OF JANAZA ANNOUNCEMENTS',
            ),
            backgroundColor: MinaretTheme.gold,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 120,
          maxWidth: 200,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isFollowing
              ? MinaretTheme.emerald.withOpacity(0.08)
              : Colors.transparent,
          border: Border.all(
            color: isFollowing
                ? MinaretTheme.emerald
                : MinaretTheme.gold.withOpacity(0.35),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFollowing
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_outlined,
              size: 14,
              color: isFollowing ? MinaretTheme.emerald : MinaretTheme.gold,
            ),
            const SizedBox(height: 4),
            Text(
              isFollowing ? 'FOLLOWING' : 'FOLLOW',
              style: GoogleFonts.montserrat(
                fontSize: 7.5,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: isFollowing ? MinaretTheme.emerald : MinaretTheme.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
