import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/animation_constants.dart';

class HeroContainer extends StatelessWidget {
  final Widget child;
  final String tag;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const HeroContainer({
    super.key,
    required this.child,
    required this.tag,
    this.backgroundColor,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? 
        (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white);

    return Hero(
      tag: tag,
      flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
        return _buildFlightShuttle(animation, fromContext, toContext);
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius,
            shape: shape,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFlightShuttle(Animation<double> animation, BuildContext fromContext, BuildContext toContext) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curvedValue = Curves.easeInOutCubic.transform(animation.value);
        
        return Transform.scale(
          scale: 1.0 + (0.1 * (1 - curvedValue)),
          child: Opacity(
            opacity: 0.8 + (0.2 * curvedValue),
            child: Container(
              decoration: BoxDecoration(
                color: MinaretTheme.gold.withValues(alpha: 0.1),
                borderRadius: borderRadius,
                shape: shape,
                boxShadow: [
                  BoxShadow(
                    color: MinaretTheme.gold.withValues(alpha: 0.3 * curvedValue),
                    blurRadius: 20 * curvedValue,
                    spreadRadius: 2 * curvedValue,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedPageRoute<T> extends PageRoute<T> {
  final Widget child;
  final Duration transitionDuration;
  final TransitionType transitionType;
  final Curve curve;

  AnimatedPageRoute({
    required this.child,
    this.transitionDuration = AppAnimations.medium,
    this.transitionType = TransitionType.slideAndFade,
    this.curve = AppAnimations.easeOutCubic,
  });

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  bool get fullscreenDialog => false;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    switch (transitionType) {
      case TransitionType.slideAndFade:
        return PageTransitions.combinedTransition(
          context,
          animation,
          secondaryAnimation,
          child,
          slideDirection: SlideDirection.rightToLeft,
        );
      case TransitionType.fade:
        return PageTransitions.fadeTransition(
          context,
          animation,
          secondaryAnimation,
          child,
        );
      case TransitionType.scale:
        return PageTransitions.scaleTransition(
          context,
          animation,
          secondaryAnimation,
          child,
        );
      case TransitionType.slideFromBottom:
        return PageTransitions.slideTransition(
          context,
          animation,
          secondaryAnimation,
          child,
          direction: SlideDirection.bottomToTop,
        );
    }
  }
}

enum TransitionType {
  slideAndFade,
  fade,
  scale,
  slideFromBottom,
}

class AnimatedBottomSheet extends StatefulWidget {
  final Widget child;
  final double? maxHeight;
  final double minHeight;
  final bool isDraggable;
  final bool enableHapticFeedback;
  final Duration animationDuration;

  const AnimatedBottomSheet({
    super.key,
    required this.child,
    this.maxHeight,
    this.minHeight = 200.0,
    this.isDraggable = true,
    this.enableHapticFeedback = true,
    this.animationDuration = AppAnimations.medium,
  });

  @override
  State<AnimatedBottomSheet> createState() => _AnimatedBottomSheetState();
}

class _AnimatedBottomSheetState extends State<AnimatedBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimations.createController(
      this,
      duration: widget.animationDuration,
    );
    
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    _controller.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = widget.maxHeight ?? screenHeight * 0.9;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.3 * _fadeAnimation.value),
            child: Stack(
              children: [
                // Backdrop
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                // Bottom sheet content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Transform.translate(
                    offset: Offset(0, screenHeight * _slideAnimation.value),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: widget.minHeight.h,
                          maxHeight: maxHeight.h,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1A1F2E)
                              : Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20.r),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, -10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Handle bar
                            Container(
                              width: 40.w,
                              height: 4.h,
                              margin: EdgeInsets.symmetric(vertical: 12.h),
                              decoration: BoxDecoration(
                                color: MinaretTheme.gold.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                            // Content
                            Expanded(
                              child: widget.child,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StaggeredAnimationList extends StatefulWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration animationDuration;
  final Curve curve;
  final Axis direction;

  const StaggeredAnimationList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.animationDuration = AppAnimations.medium,
    this.curve = AppAnimations.easeOutCubic,
    this.direction = Axis.vertical,
  });

  @override
  State<StaggeredAnimationList> createState() => _StaggeredAnimationListState();
}

class _StaggeredAnimationListState extends State<StaggeredAnimationList>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (index) => AppAnimations.createController(
        this,
        duration: widget.animationDuration,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: widget.curve),
      );
    }).toList();

    // Start animations with staggered delays
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(widget.staggerDelay * i, () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.direction == Axis.vertical) {
      return Column(
        children: List.generate(widget.children.length, (index) {
          return _buildAnimatedChild(index);
        }),
      );
    } else {
      return Row(
        children: List.generate(widget.children.length, (index) {
          return _buildAnimatedChild(index);
        }),
      );
    }
  }

  Widget _buildAnimatedChild(int index) {
    return AnimatedBuilder(
      animation: _animations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: widget.direction == Axis.vertical
              ? Offset(0, 20 * (1 - _animations[index].value))
              : Offset(20 * (1 - _animations[index].value), 0),
          child: Opacity(
            opacity: _animations[index].value,
            child: widget.children[index],
          ),
        );
      },
    );
  }
}

class PremiumDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget content;
  final DialogType type;

  const PremiumDialog({
    super.key,
    required this.title,
    this.subtitle,
    required this.actions,
    required this.content,
    this.type = DialogType.info,
  });

  @override
  State<PremiumDialog> createState() => _PremiumDialogState();
}

class _PremiumDialogState extends State<PremiumDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimations.createController(
      this,
      duration: AppAnimations.slow,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColors = _getDialogTypeColors();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                constraints: BoxConstraints(maxWidth: 400.w),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: typeColors.borderColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: typeColors.shadowColor.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: typeColors.gradientColors,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18.r),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            typeColors.icon,
                            size: 32.sp,
                            color: Colors.white,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            SizedBox(height: 8.h),
                            Text(
                              widget.subtitle!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 14.sp,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: EdgeInsets.all(24.w),
                      child: widget.content,
                    ),
                    // Actions
                    if (widget.actions.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: widget.actions,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _DialogTypeColors _getDialogTypeColors() {
    switch (widget.type) {
      case DialogType.info:
        return _DialogTypeColors(
          icon: Icons.info_outline,
          gradientColors: [MinaretTheme.gold, MinaretTheme.goldSoft],
          borderColor: MinaretTheme.gold,
          shadowColor: MinaretTheme.gold,
        );
      case DialogType.success:
        return _DialogTypeColors(
          icon: Icons.check_circle_outline,
          gradientColors: [MinaretTheme.emerald, MinaretTheme.emeraldLight],
          borderColor: MinaretTheme.emerald,
          shadowColor: MinaretTheme.emerald,
        );
      case DialogType.warning:
        return _DialogTypeColors(
          icon: Icons.warning_amber_outlined,
          gradientColors: [Colors.orange, Colors.deepOrange],
          borderColor: Colors.orange,
          shadowColor: Colors.orange,
        );
      case DialogType.error:
        return _DialogTypeColors(
          icon: Icons.error_outline,
          gradientColors: [Colors.red, Colors.redAccent],
          borderColor: Colors.red,
          shadowColor: Colors.red,
        );
    }
  }
}

class _DialogTypeColors {
  final IconData icon;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;

  _DialogTypeColors({
    required this.icon,
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
  });
}

enum DialogType {
  info,
  success,
  warning,
  error,
}
