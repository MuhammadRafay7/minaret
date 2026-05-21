import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/animation_constants.dart';

class PremiumButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double? height;
  final IconData? icon;
  final bool isLoading;
  final ButtonType type;
  final double borderRadius;

  const PremiumButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height,
    this.icon,
    this.isLoading = false,
    this.type = ButtonType.primary,
    this.borderRadius = 14.0,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimations.createController(
      this,
      duration: AppAnimations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOutCubic),
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.isLoading) return;
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _getButtonColors(isDark);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width ?? double.infinity,
              height: widget.height ?? 54.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors.gradient,
                ),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: colors.shadow,
                border: colors.border != null 
                    ? Border.all(color: colors.border!, width: 1.5)
                    : null,
              ),
              child: Stack(
                children: [
                  // Shimmer effect
                  if (_isPressed && !widget.isLoading)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        child: AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shimmerAnimation.value * 200, 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // Button content
                  Center(
                    child: widget.isLoading
                        ? LoadingSpinner(color: colors.textColor)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: colors.textColor,
                                  size: 20.sp,
                                ),
                                SizedBox(width: 8.w),
                              ],
                              Text(
                                widget.text,
                                style: GoogleFonts.cairo(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _ButtonColors _getButtonColors(bool isDark) {
    switch (widget.type) {
      case ButtonType.primary:
        return _ButtonColors(
          gradient: [
            widget.backgroundColor ?? MinaretTheme.emerald,
            widget.backgroundColor ?? MinaretTheme.emerald.withValues(alpha: 0.8),
          ],
          textColor: widget.textColor ?? Colors.white,
          shadow: MinaretTheme.heroShadow,
          border: null,
        );
      case ButtonType.secondary:
        return _ButtonColors(
          gradient: [
            Colors.transparent,
            Colors.transparent,
          ],
          textColor: widget.textColor ?? 
              (isDark ? Colors.white : MinaretTheme.onyx),
          shadow: [],
          border: widget.backgroundColor ?? MinaretTheme.emerald,
        );
      case ButtonType.gold:
        return _ButtonColors(
          gradient: [
            MinaretTheme.gold,
            MinaretTheme.goldSoft,
          ],
          textColor: widget.textColor ?? MinaretTheme.onyx,
          shadow: MinaretTheme.goldShadow,
          border: null,
        );
    }
  }
}

class _ButtonColors {
  final List<Color> gradient;
  final Color textColor;
  final List<BoxShadow> shadow;
  final Color? border;

  _ButtonColors({
    required this.gradient,
    required this.textColor,
    required this.shadow,
    this.border,
  });
}

enum ButtonType {
  primary,
  secondary,
  gold,
}

class LoadingSpinner extends StatefulWidget {
  final Color color;
  final double size;

  const LoadingSpinner({
    super.key,
    required this.color,
    this.size = 20.0,
  });

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value * 2 * 3.14159,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(widget.color),
            ),
          ),
        );
      },
    );
  }
}
