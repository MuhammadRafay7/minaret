import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/animation_constants.dart';

class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onTap;
  final double threshold;
  final bool enableHapticFeedback;
  final Duration animationDuration;

  const SwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onTap,
    this.threshold = 50.0,
    this.enableHapticFeedback = true,
    this.animationDuration = AppAnimations.medium,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  Offset _dragStart = Offset.zero;
  Offset _dragCurrent = Offset.zero;
  bool _isDragging = false;
  SwipeDirection? _detectedSwipe;

  @override
  void initState() {
    super.initState();
    _slideController = AppAnimations.createController(
      this,
      duration: widget.animationDuration,
    );
    _scaleController = AppAnimations.createController(
      this,
      duration: AppAnimations.fast,
    );
    
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: AppAnimations.easeOutCubic));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _scaleController, curve: AppAnimations.easeOutCubic));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
      _detectedSwipe = null;
    });
    _scaleController.forward();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragCurrent = details.localPosition;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    final offset = _dragCurrent - _dragStart;
    final swipeDirection = _determineSwipeDirection(offset);
    
    if (swipeDirection != null) {
      _executeSwipe(swipeDirection, offset);
    } else {
      _resetAnimation();
    }
    
    setState(() {
      _isDragging = false;
    });
    _scaleController.reverse();
  }

  void _handleTap() {
    if (widget.onTap != null && !_isDragging) {
      if (widget.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }
      widget.onTap!();
    }
  }

  SwipeDirection? _determineSwipeDirection(Offset offset) {
    final dx = offset.dx.abs();
    final dy = offset.dy.abs();
    
    if (dx < widget.threshold && dy < widget.threshold) {
      return null;
    }
    
    if (dx > dy) {
      return offset.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else {
      return offset.dy > 0 ? SwipeDirection.down : SwipeDirection.up;
    }
  }

  void _executeSwipe(SwipeDirection direction, Offset offset) {
    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }
    
    setState(() {
      _detectedSwipe = direction;
    });
    
    // Animate the swipe
    final targetOffset = _getSwipeOffset(direction);
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: targetOffset)
        .animate(CurvedAnimation(parent: _slideController, curve: AppAnimations.easeOutCubic));
    
    _slideController.forward().then((_) {
      // Execute callback
      switch (direction) {
        case SwipeDirection.left:
          widget.onSwipeLeft?.call();
          break;
        case SwipeDirection.right:
          widget.onSwipeRight?.call();
          break;
        case SwipeDirection.up:
          widget.onSwipeUp?.call();
          break;
        case SwipeDirection.down:
          widget.onSwipeDown?.call();
          break;
      }
      
      // Reset animation
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _resetAnimation();
        }
      });
    });
  }

  Offset _getSwipeOffset(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.left:
        return const Offset(-0.3, 0);
      case SwipeDirection.right:
        return const Offset(0.3, 0);
      case SwipeDirection.up:
        return const Offset(0, -0.3);
      case SwipeDirection.down:
        return const Offset(0, 0.3);
    }
  }

  void _resetAnimation() {
    setState(() {
      _detectedSwipe = null;
    });
    _slideController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_slideController, _scaleController]),
        builder: (context, child) {
          Offset slideOffset = Offset.zero;
          double scale = 1.0;
          
          if (_isDragging) {
            slideOffset = (_dragCurrent - _dragStart) / 300;
            scale = _scaleAnimation.value;
          } else {
            slideOffset = _slideAnimation.value;
            scale = _scaleAnimation.value;
          }
          
          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(slideOffset.dx * 300, slideOffset.dy * 300),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: _isDragging || _detectedSwipe != null
                      ? [
                          BoxShadow(
                            color: _getSwipeColor(_detectedSwipe).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getSwipeColor(SwipeDirection? direction) {
    switch (direction) {
      case SwipeDirection.left:
        return Colors.red;
      case SwipeDirection.right:
        return Colors.green;
      case SwipeDirection.up:
        return Colors.blue;
      case SwipeDirection.down:
        return Colors.orange;
      default:
        return MinaretTheme.gold;
    }
  }
}

enum SwipeDirection {
  left,
  right,
  up,
  down,
}

class SwipeableListTile extends StatelessWidget {
  final IconData? leadingIcon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final Color? iconColor;
  final bool showSwipeHint;

  const SwipeableListTile({
    super.key,
    this.leadingIcon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.iconColor,
    this.showSwipeHint = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalIconColor = iconColor ?? 
        (isDark ? MinaretTheme.gold : MinaretTheme.emerald);

    return SwipeableCard(
      onSwipeLeft: onSwipeLeft,
      onSwipeRight: onSwipeRight,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          leading: leadingIcon != null
              ? Icon(
                  leadingIcon,
                  color: finalIconColor,
                  size: 24.sp,
                )
              : null,
          title: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : MinaretTheme.onyx,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white70 : MinaretTheme.slate,
                  ),
                )
              : null,
          trailing: showSwipeHint
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (onSwipeLeft != null)
                      Text(
                        '← Swipe',
                        style: GoogleFonts.cairo(
                          fontSize: 8.sp,
                          color: Colors.red.withValues(alpha: 0.6),
                        ),
                      ),
                    if (onSwipeRight != null)
                      Text(
                        'Swipe →',
                        style: GoogleFonts.cairo(
                          fontSize: 8.sp,
                          color: Colors.green.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

class PullToRefreshContainer extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double refreshThreshold;
  final Widget? refreshIndicator;

  const PullToRefreshContainer({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshThreshold = 80.0,
    this.refreshIndicator,
  });

  @override
  State<PullToRefreshContainer> createState() => _PullToRefreshContainerState();
}

class _PullToRefreshContainerState extends State<PullToRefreshContainer>
    with TickerProviderStateMixin {
  late AnimationController _refreshController;
  double _dragOffset = 0.0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AppAnimations.createController(
      this,
      duration: AppAnimations.slow,
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isRefreshing) return;
    
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, widget.refreshThreshold * 1.5);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isRefreshing) return;
    
    if (_dragOffset >= widget.refreshThreshold) {
      _triggerRefresh();
    } else {
      _resetOffset();
    }
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    
    HapticFeedback.mediumImpact();
    _refreshController.forward();
    
    try {
      await widget.onRefresh();
    } catch (e) {
      // Handle error if needed
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _resetOffset();
      setState(() {
        _isRefreshing = false;
      });
      _refreshController.reset();
    }
  }

  void _resetOffset() {
    setState(() {
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _resetOffset();
        }
        return false;
      },
      child: GestureDetector(
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: Stack(
          children: [
            // Refresh indicator
            if (_dragOffset > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _dragOffset,
                child: Container(
                  alignment: Alignment.center,
                  child: widget.refreshIndicator ?? 
                      RefreshProgressIndicator(
                        value: _dragOffset / widget.refreshThreshold,
                        color: MinaretTheme.gold,
                      ),
                ),
              ),
            // Main content
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}
