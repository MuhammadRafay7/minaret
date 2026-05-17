import 'package:flutter/material.dart';

/// Inline loading spinner that always uses the theme's primary colour.
/// Use this everywhere a bare [CircularProgressIndicator] would have appeared
/// so that the indicator style stays consistent across the app.
///
/// For full-screen loading, use [PremiumLoadingScreen] instead.
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;

  const AppLoadingIndicator({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
