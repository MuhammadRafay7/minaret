import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/animation_constants.dart';

class PremiumLoadingScreen extends StatefulWidget {
  final String? message;
  final LoadingType type;

  const PremiumLoadingScreen({
    super.key,
    this.message,
    this.type = LoadingType.pulse,
  });

  @override
  State<PremiumLoadingScreen> createState() => _PremiumLoadingScreenState();
}

class _PremiumLoadingScreenState extends State<PremiumLoadingScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _dotControllers;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _dotControllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });
    _dotAnimations = _dotControllers.map((c) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    for (int i = 0; i < _dotControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _dotControllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _dotControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? MinaretTheme.darkBackground : MinaretTheme.background;

    return Container(
      color: bg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'MINARET',
              style: GoogleFonts.montserrat(
                fontSize: 13.sp,
                letterSpacing: 6,
                fontWeight: FontWeight.w900,
                color: MinaretTheme.gold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              widget.message ?? '',
              style: GoogleFonts.montserrat(
                fontSize: 8.sp,
                letterSpacing: 2,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : MinaretTheme.slate,
              ),
            ),
            SizedBox(height: 28.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _dotAnimations[i],
                  builder: (_, __) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    width: 7.w,
                    height: 7.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MinaretTheme.gold
                          .withValues(alpha: _dotAnimations[i].value),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

enum LoadingType { pulse, rotation, shimmer, dots }

class SkeletonCard extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonCard({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
    this.margin,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimations.createController(
      this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white12 : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.white24 : Colors.grey[100]!;

    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: baseColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shimmerAnimation.value * widget.width, 0),
              child: Container(
                width: widget.width * 0.5,
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [baseColor, highlightColor, baseColor],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry? padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        children: List.generate(itemCount, (index) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: SkeletonCard(
              width: double.infinity,
              height: itemHeight.h,
            ),
          );
        }),
      ),
    );
  }
}

class PremiumLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;

  const PremiumLoadingOverlay({
    super.key,
    required this.child,
    this.isLoading = false,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: PremiumLoadingScreen(message: loadingMessage),
            ),
          ),
      ],
    );
  }
}
