import 'dart:math';
import 'package:flutter/material.dart';

class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GrainPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  // Use a fixed seed so the grain pattern is stable across rebuilds
  final Random _random = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1;

    // Scatter ~1200 tiny dots randomly across the surface
    final int dotCount = ((size.width * size.height) / 400).round().clamp(
      800,
      1500,
    );

    for (int i = 0; i < dotCount; i++) {
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;

      // Vary opacity slightly for a more organic grain feel
      final double opacity = 0.02 + _random.nextDouble() * 0.04;

      paint.color = Colors.black.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}
