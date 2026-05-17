import 'package:flutter/material.dart';

class AppAnimations {
  // ── Duration Constants ────────────────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration slower = Duration(milliseconds: 650);
  static const Duration extraSlow = Duration(milliseconds: 900);

  // ── Curve Constants ───────────────────────────────────────────────────────
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve easeOutBack = Curves.easeOutBack;
  static const Curve easeInBack = Curves.easeInBack;
  static const Curve easeInOutBack = Curves.easeInOutBack;
  static const Curve easeOutQuart = Curves.easeOutQuart;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve elasticOut = Curves.elasticOut;

  // ── Common Animation Controllers ───────────────────────────────────────────
  static AnimationController createController(TickerProvider vsync, {Duration? duration}) {
    return AnimationController(
      vsync: vsync,
      duration: duration ?? medium,
    );
  }

  // ── Tween Helpers ─────────────────────────────────────────────────────────
  static Tween<double> scaleTween(double begin, double end) => Tween<double>(begin: begin, end: end);
  static Tween<double> opacityTween(double begin, double end) => Tween<double>(begin: begin, end: end);
  static Tween<Offset> slideTween(Offset begin, Offset end) => Tween<Offset>(begin: begin, end: end);
  static Tween<Color?> colorTween(Color? begin, Color? end) => ColorTween(begin: begin, end: end);

  // ── Common Animations ─────────────────────────────────────────────────────
  static Animation<double> fadeIn(AnimationController controller) => 
      opacityTween(0.0, 1.0).animate(CurvedAnimation(parent: controller, curve: easeOut));

  static Animation<double> fadeOut(AnimationController controller) => 
      opacityTween(1.0, 0.0).animate(CurvedAnimation(parent: controller, curve: easeOut));

  static Animation<double> scaleIn(AnimationController controller) => 
      scaleTween(0.8, 1.0).animate(CurvedAnimation(parent: controller, curve: easeOutBack));

  static Animation<double> scaleOut(AnimationController controller) => 
      scaleTween(1.0, 0.8).animate(CurvedAnimation(parent: controller, curve: easeInBack));

  static Animation<Offset> slideInFromLeft(AnimationController controller) => 
      slideTween(const Offset(-1.0, 0.0), Offset.zero).animate(CurvedAnimation(parent: controller, curve: easeOutCubic));

  static Animation<Offset> slideInFromRight(AnimationController controller) => 
      slideTween(const Offset(1.0, 0.0), Offset.zero).animate(CurvedAnimation(parent: controller, curve: easeOutCubic));

  static Animation<Offset> slideInFromTop(AnimationController controller) => 
      slideTween(const Offset(0.0, -1.0), Offset.zero).animate(CurvedAnimation(parent: controller, curve: easeOutCubic));

  static Animation<Offset> slideInFromBottom(AnimationController controller) => 
      slideTween(const Offset(0.0, 1.0), Offset.zero).animate(CurvedAnimation(parent: controller, curve: easeOutCubic));

  // ── Staggered Animation Delays ───────────────────────────────────────────────
  static Duration staggeredDelay(int index, {Duration baseDelay = const Duration(milliseconds: 100)}) {
    return baseDelay * index;
  }

  // ── Spring Physics ─────────────────────────────────────────────────────────
  static SpringDescription springDescription({
    double mass = 1.0,
    double stiffness = 100.0,
    double damping = 10.0,
  }) {
    return SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
  }
}

class MicroInteractions {
  // ── Button Press Animations ─────────────────────────────────────────────────
  static Widget animatedButton({
    required Widget child,
    required VoidCallback onPressed,
    Duration duration = AppAnimations.fast,
    Curve curve = AppAnimations.easeOutCubic,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _triggerScaleAnimation(),
        onTapUp: (_) {
          _triggerScaleAnimation(reverse: true);
          onPressed();
        },
        onTapCancel: () => _triggerScaleAnimation(reverse: true),
        child: child,
      ),
    );
  }

  static void _triggerScaleAnimation({bool reverse = false}) {
    // This would be implemented with a proper animation controller in the widget
    // For now, it's a placeholder for the concept
  }

  // ── Card Hover Effects ─────────────────────────────────────────────────────
  static Widget animatedCard({
    required Widget child,
    Duration duration = AppAnimations.medium,
    Curve curve = AppAnimations.easeOutCubic,
    double hoverScale = 1.05,
    double pressScale = 0.98,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        duration: duration,
        curve: curve,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: GestureDetector(
          onTapDown: (_) => _triggerScaleAnimation(),
          onTapUp: (_) => _triggerScaleAnimation(reverse: true),
          onTapCancel: () => _triggerScaleAnimation(reverse: true),
          child: child,
        ),
      ),
    );
  }
}

class PageTransitions {
  // ── Custom Page Transition Builders ───────────────────────────────────────────
  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child, {
    SlideDirection direction = SlideDirection.leftToRight,
  }) {
    Offset begin;
    switch (direction) {
      case SlideDirection.leftToRight:
        begin = const Offset(-1.0, 0.0);
        break;
      case SlideDirection.rightToLeft:
        begin = const Offset(1.0, 0.0);
        break;
      case SlideDirection.topToBottom:
        begin = const Offset(0.0, -1.0);
        break;
      case SlideDirection.bottomToTop:
        begin = const Offset(0.0, 1.0);
        break;
    }

    return SlideTransition(
      position: AppAnimations.slideTween(begin, Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: AppAnimations.easeOutCubic)),
      child: child,
    );
  }

  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: AppAnimations.opacityTween(0.0, 1.0)
          .animate(CurvedAnimation(parent: animation, curve: AppAnimations.easeOut)),
      child: child,
    );
  }

  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: AppAnimations.scaleTween(0.8, 1.0)
          .animate(CurvedAnimation(parent: animation, curve: AppAnimations.easeOutBack)),
      child: child,
    );
  }

  static Widget combinedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child, {
    SlideDirection slideDirection = SlideDirection.leftToRight,
  }) {
    return SlideTransition(
      position: AppAnimations.slideTween(
        slideDirection == SlideDirection.leftToRight 
            ? const Offset(-1.0, 0.0)
            : const Offset(1.0, 0.0),
        Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: AppAnimations.easeOutCubic)),
      child: FadeTransition(
        opacity: AppAnimations.opacityTween(0.0, 1.0)
            .animate(CurvedAnimation(parent: animation, curve: AppAnimations.easeOut)),
        child: child,
      ),
    );
  }
}

enum SlideDirection {
  leftToRight,
  rightToLeft,
  topToBottom,
  bottomToTop,
}

class LoadingAnimations {
  // ── Shkeleton Loading ───────────────────────────────────────────────────────
  static Widget skeleton({
    double width = double.infinity,
    double height = 40.0,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            Colors.grey[300]!,
            Colors.grey[100]!,
            Colors.grey[300]!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  // ── Pulsing Loading Indicator ─────────────────────────────────────────────────
  static Widget pulsingIndicator({
    Color color = Colors.blue,
    double size = 20.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
