import 'package:flutter/material.dart';
import 'package:minaret/widgets/grain_overlay.dart';
import 'package:minaret/core/theme.dart';

/// Root layout shell — warm ivory background with subtle grain texture.
/// All pages are wrapped in this so the visual language is consistent.
class AtelierLayout extends StatelessWidget {
  final Widget child;
  const AtelierLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [scheme.surface, Theme.of(context).scaffoldBackgroundColor]
                    : const [Color(0xFFF8F3E9), MinaretTheme.background],
              ),
            ),
          ),
          child,
          // Grain texture sits on top but ignores all pointer events
          const IgnorePointer(child: GrainOverlay()),
        ],
      ),
    );
  }
}
