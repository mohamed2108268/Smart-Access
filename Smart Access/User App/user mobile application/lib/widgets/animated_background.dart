// lib/widgets/animated_background.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/theme.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = BioAccessTheme.primaryColor;
    final infoColor = BioAccessTheme.infoColor;
    final secondaryColor = BioAccessTheme.secondaryColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: BackgroundPainter(
            animation: _controller,
            isDarkMode: isDarkMode,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            accentColor: infoColor,
          ),
          child: Container(),
        );
      },
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isDarkMode;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  BackgroundPainter({
    required this.animation,
    required this.isDarkMode,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // Create gradient background
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDarkMode
            ? [
                const Color(0xFF1A1A1A),
                const Color(0xFF131313),
              ]
            : [
                const Color(0xFFF0F2F6),
                const Color(0xFFE6E9F0),
              ],
      ).createShader(rect);

    canvas.drawRect(rect, backgroundPaint);

    // Draw animated gradient blobs
    _drawAnimatedBlobs(canvas, size);
  }

  void _drawAnimatedBlobs(Canvas canvas, Size size) {
    final blobPaint1 = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 0.8,
        colors: [
          primaryColor.withOpacity(0.3),
          primaryColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.8, size.height * 0.8));

    final blobPaint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomRight,
        radius: 0.8,
        colors: [
          secondaryColor.withOpacity(0.3),
          secondaryColor.withOpacity(0.0),
        ],
      ).createShader(
          Rect.fromLTWH(size.width * 0.2, size.height * 0.2, size.width * 0.8, size.height * 0.8));

    final blobPaint3 = Paint()
      ..shader = RadialGradient(
        center: Alignment.topRight,
        radius: 0.8,
        colors: [
          accentColor.withOpacity(0.3),
          accentColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.7, size.height * 0.7));

    // Animate blob positions
    final offset1 = Offset(
      size.width * 0.1 + size.width * 0.1 * math.sin(animation.value * 2 * math.pi),
      size.height * 0.1 + size.height * 0.1 * math.cos(animation.value * 2 * math.pi),
    );

    final offset2 = Offset(
      size.width * 0.5 + size.width * 0.15 * math.cos(animation.value * 2 * math.pi),
      size.height * 0.5 + size.height * 0.15 * math.sin(animation.value * 2 * math.pi),
    );

    final offset3 = Offset(
      size.width * 0.8 + size.width * 0.1 * math.sin(animation.value * 2 * math.pi + math.pi),
      size.height * 0.2 + size.height * 0.1 * math.cos(animation.value * 2 * math.pi + math.pi),
    );

    // Draw the blobs
    canvas.drawCircle(offset1, size.width * 0.5, blobPaint1);
    canvas.drawCircle(offset2, size.width * 0.4, blobPaint2);
    canvas.drawCircle(offset3, size.width * 0.3, blobPaint3);
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) =>
      animation != oldDelegate.animation ||
      isDarkMode != oldDelegate.isDarkMode;
}