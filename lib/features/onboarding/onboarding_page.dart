import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme.dart';
import '../../main_navigation.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<_OnboardingItem> _pages = [
    const _OnboardingItem(
      title: 'PRECISION PRAYER',
      subtitle: 'Accurate timings and notifications based on your exact location and preferred school of thought.',
      icon: Icons.access_time_filled_rounded,
    ),
    const _OnboardingItem(
      title: 'LOCAL MOSQUES',
      subtitle: 'Find nearby mosques, follow them for updates, and stay connected with your local community.',
      icon: Icons.mosque_rounded,
    ),
    const _OnboardingItem(
      title: 'JANAZA ALERTS',
      subtitle: 'Never miss a Namaz-e-Janaza in your city. Instant push notifications for mosques you follow.',
      icon: Icons.notifications_active_rounded,
    ),
    const _OnboardingItem(
      title: 'IMAM OR COMMUNITY?',
      subtitle: 'Join as a community member to stay connected, or register as an Imam to manage your mosque professionally.',
      icon: Icons.people_alt_rounded,
    ),
  ];

  Future<void> _finishOnboarding() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainNavigation(firebaseReady: widget.firebaseReady),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : MinaretTheme.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: -100.h,
            right: -50.w,
            child: Opacity(
              opacity: 0.05,
              child: Icon(Icons.mosque, size: 400.sp, color: MinaretTheme.gold),
            ),
          ),
          
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final item = _pages[index];
              return Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 20.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(30.w),
                          decoration: BoxDecoration(
                            color: MinaretTheme.gold.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon,
                            size: 80.sp,
                            color: MinaretTheme.gold,
                          ),
                        ),
                        SizedBox(height: 60.h),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: MinaretTheme.heading.copyWith(
                            fontSize: 24.sp,
                            letterSpacing: 6.w,
                            color: isDark ? Colors.white : MinaretTheme.onyx,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoNaskhArabic(
                            fontSize: 14.sp,
                            height: 1.8,
                            color: isDark ? Colors.white70 : MinaretTheme.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          Positioned(
            bottom: 60.h,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      height: 4.h,
                      width: _currentIndex == index ? 24.w : 8.w,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? MinaretTheme.gold
                            : MinaretTheme.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        if (_currentIndex == _pages.length - 1) {
                          _finishOnboarding();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOutQuart,
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: MinaretTheme.emerald, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        backgroundColor: MinaretTheme.emerald,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      child: Text(
                        _currentIndex == _pages.length - 1 ? 'GET STARTED' : 'CONTINUE',
                        style: GoogleFonts.montserrat(
                          fontSize: 10.sp,
                          letterSpacing: 4.w,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

class _OnboardingItem {
  final String title;
  final String subtitle;
  final IconData icon;
  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
