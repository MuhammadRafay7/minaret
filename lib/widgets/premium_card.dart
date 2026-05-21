import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/animation_constants.dart';

class PremiumCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final double borderRadius;
  final bool enableHover;
  final bool enableGlow;
  final CardType type;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderRadius = 16.0,
    this.enableHover = true,
    this.enableGlow = false,
    this.type = CardType.glass,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimations.createController(
      this,
      duration: AppAnimations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOutCubic),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    if (!widget.enableHover) return;
    setState(() => _isHovered = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardStyle = _getCardStyle(isDark);

    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value * (_isHovered && widget.enableHover ? 1.02 : 1.0),
            child: Container(
              width: widget.width,
              height: widget.height,
              margin: widget.margin,
              child: Stack(
                children: [
                  // Glow effect
                  if (widget.enableGlow && (_isHovered || _isPressed))
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: _glowAnimation.value,
                        duration: AppAnimations.fast,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.borderRadius),
                            boxShadow: cardStyle.glowShadow,
                          ),
                        ),
                      ),
                    ),
                  // Main card
                  Container(
                    padding: widget.padding ?? EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: cardStyle.backgroundColor,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      border: cardStyle.border,
                      boxShadow: cardStyle.shadow,
                    ),
                    child: widget.child,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _CardStyle _getCardStyle(bool isDark) {
    switch (widget.type) {
      case CardType.glass:
        return _CardStyle(
          backgroundColor: widget.backgroundColor ?? 
              (isDark ? Colors.white.withValues(alpha: 0.07) : MinaretTheme.glassSurface),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.5),
            width: 0.8,
          ),
          shadow: MinaretTheme.cardShadow,
          glowShadow: [
            BoxShadow(
              color: MinaretTheme.gold.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        );
      case CardType.solid:
        return _CardStyle(
          backgroundColor: widget.backgroundColor ?? 
              (isDark ? const Color(0xFF1A1F2E) : Colors.white),
          border: Border.all(
            color: MinaretTheme.gold.withValues(alpha: 0.2),
            width: 1,
          ),
          shadow: MinaretTheme.cardShadow,
          glowShadow: [
            BoxShadow(
              color: MinaretTheme.emerald.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        );
      case CardType.gradient:
        return _CardStyle(
          backgroundColor: widget.backgroundColor ?? 
              (isDark ? const Color(0xFF1A1F2E) : const Color(0xFFF5F5F5)),
          border: null,
          shadow: MinaretTheme.cardShadow,
          glowShadow: [
            BoxShadow(
              color: MinaretTheme.gold.withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        );
    }
  }
}

class _CardStyle {
  final Color backgroundColor;
  final Border? border;
  final List<BoxShadow> shadow;
  final List<BoxShadow> glowShadow;

  _CardStyle({
    required this.backgroundColor,
    this.border,
    required this.shadow,
    required this.glowShadow,
  });
}

enum CardType {
  glass,
  solid,
  gradient,
}

class AnimatedListTile extends StatefulWidget {
  final IconData? leadingIcon;
  final String title;
  final String? subtitle;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showDivider;

  const AnimatedListTile({
    super.key,
    this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailingIcon,
    this.onTap,
    this.iconColor,
    this.showDivider = true,
  });

  @override
  State<AnimatedListTile> createState() => _AnimatedListTileState();
}

class _AnimatedListTileState extends State<AnimatedListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimations.createController(
      this,
      duration: AppAnimations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.easeOutCubic),
    );
    _colorAnimation = AppAnimations.colorTween(
      null,
      MinaretTheme.gold.withValues(alpha: 0.1),
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _controller.reverse();
    widget.onTap!();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = widget.iconColor ?? 
        (isDark ? MinaretTheme.gold : MinaretTheme.emerald);

    return Column(
      children: [
        GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: _colorAnimation.value,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    leading: widget.leadingIcon != null
                        ? Icon(
                            widget.leadingIcon,
                            color: iconColor,
                            size: 24.sp,
                          )
                        : null,
                    title: Text(
                      widget.title,
                      style: GoogleFonts.cairo(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : MinaretTheme.onyx,
                      ),
                    ),
                    subtitle: widget.subtitle != null
                        ? Text(
                            widget.subtitle!,
                            style: GoogleFonts.cairo(
                              fontSize: 12.sp,
                              color: isDark ? Colors.white70 : MinaretTheme.slate,
                            ),
                          )
                        : null,
                    trailing: widget.trailingIcon != null
                        ? Icon(
                            widget.trailingIcon,
                            color: iconColor,
                            size: 20.sp,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark 
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
      ],
    );
  }
}
