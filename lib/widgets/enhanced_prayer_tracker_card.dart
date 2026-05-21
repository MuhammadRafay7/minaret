import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/services/enhanced_prayer_tracker_service.dart';
import 'package:minaret/widgets/app_loading_indicator.dart';

class EnhancedPrayerTrackerCard extends StatefulWidget {
  const EnhancedPrayerTrackerCard({super.key});

  @override
  State<EnhancedPrayerTrackerCard> createState() => _EnhancedPrayerTrackerCardState();
}

class _DailyPrayer {
  final String name;
  final String key;
  _DailyPrayer(this.name, this.key);
}

class _EnhancedPrayerTrackerCardState extends State<EnhancedPrayerTrackerCard>
    with TickerProviderStateMixin {
  List<String> _completed = [];
  UserPrayerStats? _userStats;
  bool _isLoading = true;
  final Set<String> _syncingKeys = {};

  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  final List<AnimationController> _rippleControllers = [];
  final List<Animation<double>> _rippleAnims = [];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim =
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideAnim = CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutCubic);

    for (int i = 0; i < 5; i++) {
      final ctrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 400));
      final anim = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.88)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.88, end: 1.04)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 45,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.04, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 25,
        ),
      ]).animate(ctrl);
      _rippleControllers.add(ctrl);
      _rippleAnims.add(anim);
    }

    _loadData();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    for (final c in _rippleControllers) c.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Get today's prayers
      final todayPrayers = await EnhancedPrayerTrackerService.getTodayPrayers();
      
      // Get user stats
      final userStats = await EnhancedPrayerTrackerService.getCurrentUserStats();
      
      if (mounted) {
        setState(() {
          _completed = todayPrayers;
          _userStats = userStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading prayer data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Toggles prayer status with optimistic UI and per-button sync guard.
  void _toggle(int index, String key) {
    if (_syncingKeys.contains(key)) return;
    HapticFeedback.lightImpact();
    _rippleControllers[index].forward(from: 0);

    setState(() {
      _syncingKeys.add(key);
      if (_completed.contains(key)) {
        _completed = List.from(_completed)..remove(key);
      } else {
        _completed = List.from(_completed)..add(key);
      }
    });

    _syncToggleWithServer(key);
  }

  Future<void> _syncToggleWithServer(String key) async {
    try {
      await EnhancedPrayerTrackerService.togglePrayer(key);
      final userStats = await EnhancedPrayerTrackerService.getCurrentUserStats();
      if (mounted) {
        setState(() {
          _userStats = userStats;
          _syncingKeys.remove(key);
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Prayer sync error: $e');
      if (mounted) {
        setState(() {
          _syncingKeys.remove(key);
          if (_completed.contains(key)) {
            _completed = List.from(_completed)..remove(key);
          } else {
            _completed = List.from(_completed)..add(key);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.failedToSyncPrayer ??
                'Failed to sync prayer. Check connection.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    if (_isLoading) {
      return Container(
        height: 200.h,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: AppLoadingIndicator()),
      );
    }

    final prayers = [
      _DailyPrayer(l10n.prayerFajr, 'Fajr'),
      _DailyPrayer(l10n.prayerDhuhr, 'Dhuhr'),
      _DailyPrayer(l10n.prayerAsr, 'Asr'),
      _DailyPrayer(l10n.prayerMaghrib, 'Maghrib'),
      _DailyPrayer(l10n.prayerIsha, 'Isha'),
    ];

    final completedCount = _completed.length;
    final allDone = completedCount == prayers.length;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final surfaceColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final labelColor =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
    final primaryText = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return AnimatedBuilder(
      animation: _entranceController,
      builder: (ctx, child) => Opacity(
        opacity: _fadeAnim.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _slideAnim.value)),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dailyPrayerTracker,
                          style: GoogleFonts.dmSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          _todayLabel(),
                          style: GoogleFonts.dmSans(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: labelColor,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _EnhancedStreakPill(
                    currentStreak: _userStats?.currentStreak ?? 0,
                    longestStreak: _userStats?.longestStreak ?? 0,
                    completionRate: _userStats?.overallCompletionRate ?? 0.0,
                    isDark: isDark,
                    surfaceColor: surfaceColor),
                ],
              ),

              SizedBox(height: 16.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(prayers.length, (i) {
                  final p = prayers[i];
                  final isDone = _completed.contains(p.key);
                  return AnimatedBuilder(
                    animation: _rippleAnims[i],
                    builder: (ctx, child) => Transform.scale(
                      scale: _rippleAnims[i].value,
                      child: child,
                    ),
                    child: _PrayerButton(
                      label: _shortLabel(p.key),
                      isDone: isDone,
                      isSyncing: _syncingKeys.contains(p.key),
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      labelColor: labelColor,
                      onTap: () => _toggle(i, p.key),
                    ),
                  );
                }),
              ),

              SizedBox(height: 14.h),

              _EnhancedProgressSection(
                completed: completedCount,
                total: prayers.length,
                allDone: allDone,
                isDark: isDark,
                surfaceColor: surfaceColor,
                labelColor: labelColor,
                userStats: _userStats,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  String _shortLabel(String key) {
    const map = {
      'Fajr': 'Fajr',
      'Dhuhr': 'Dhuhr',
      'Asr': 'Asr',
      'Maghrib': 'Maghr',
      'Isha': 'Isha',
    };
    return map[key] ?? key;
  }
}

class _EnhancedStreakPill extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final double completionRate;
  final bool isDark;
  final Color surfaceColor;

  const _EnhancedStreakPill({
    required this.currentStreak,
    required this.longestStreak,
    required this.completionRate,
    required this.isDark,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '☽',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: MinaretTheme.gold,
                  height: 1.0,
                ),
              ),
              SizedBox(width: 5.w),
              Text(
                '$currentStreak',
                style: GoogleFonts.dmSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: MinaretTheme.gold,
                  height: 1.0,
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                'day',
                style: GoogleFonts.dmSans(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: labelColor,
                  height: 1.0,
                ),
              ),
            ],
          ),
          if (longestStreak > 0)
            Text(
              'Best: $longestStreak',
              style: GoogleFonts.dmSans(
                fontSize: 9.sp,
                fontWeight: FontWeight.w500,
                color: MinaretTheme.gold.withValues(alpha: 0.8),
                height: 1.0,
              ),
            ),
        ],
      ),
    );
  }
}

class _PrayerButton extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isSyncing;
  final bool isDark;
  final Color surfaceColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _PrayerButton({
    required this.label,
    required this.isDone,
    required this.isSyncing,
    required this.isDark,
    required this.surfaceColor,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSyncing ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: isDone ? MinaretTheme.gold : surfaceColor,
              shape: BoxShape.circle,
              boxShadow: isDone
                  ? [
                      BoxShadow(
                        color: MinaretTheme.gold.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: isSyncing
                    ? SizedBox(
                        key: const ValueKey('syncing'),
                        width: 18.sp,
                        height: 18.sp,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDone ? Colors.white : MinaretTheme.gold,
                        ),
                      )
                    : isDone
                        ? Icon(
                            Icons.check_rounded,
                            key: const ValueKey('check'),
                            color: Colors.white,
                            size: 20.sp,
                          )
                        : Icon(
                            Icons.circle_outlined,
                            key: const ValueKey('empty'),
                            color: labelColor.withValues(alpha: 0.5),
                            size: 18.sp,
                          ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: GoogleFonts.dmSans(
              fontSize: 10.sp,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
              color: isDone ? MinaretTheme.gold : labelColor,
              letterSpacing: -0.1,
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _EnhancedProgressSection extends StatelessWidget {
  final int completed;
  final int total;
  final bool allDone;
  final bool isDark;
  final Color surfaceColor;
  final Color labelColor;
  final UserPrayerStats? userStats;

  const _EnhancedProgressSection({
    required this.completed,
    required this.total,
    required this.allDone,
    required this.isDark,
    required this.surfaceColor,
    required this.labelColor,
    required this.userStats,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(total, (i) {
            final filled = i < completed;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: 3.h,
                  decoration: BoxDecoration(
                    color: filled ? MinaretTheme.gold : surfaceColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                key: ValueKey(allDone),
                children: [
                  Text(
                    allDone
                        ? 'All prayers complete'
                        : '$completed of $total completed',
                    style: GoogleFonts.dmSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: allDone ? MinaretTheme.gold : labelColor,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (userStats != null)
                    Text(
                      'Total: ${userStats!.totalPrayers} prayers',
                      style: GoogleFonts.dmSans(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w400,
                        color: labelColor.withValues(alpha: 0.7),
                        letterSpacing: -0.1,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.dmMono(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: allDone ? MinaretTheme.gold : labelColor.withValues(alpha: 0.7),
                  ),
                ),
                if (userStats != null)
                  Text(
                    '${(userStats!.overallCompletionRate * 100).toInt()}% overall',
                    style: GoogleFonts.dmMono(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w400,
                      color: labelColor.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
