import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:minaret/core/theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final double blur;
  final Color tint;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.blur = 16,
    this.tint = const Color(0x80FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceTint = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.18);
    final resolvedTint = tint == const Color(0x80FFFFFF)
        ? (isDark
              ? const Color(0x33111826)
              : MinaretTheme.glassSurface)
        : tint;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [resolvedTint, surfaceTint],
            ),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.55),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
