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
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BioAccessTheme.primaryBlue,
                Color(0xFF1E3D56),
                Color(0xFF152F45),
              ],
            ),
          ),
        ),
        
        // Subtle pattern overlay
        Opacity(
          opacity: 0.04,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/pattern.png'),
                repeat: ImageRepeat.repeat,
                scale: 5.0,
              ),
            ),
          ),
        ),
        
        // Animated waves
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: BackgroundPainter(_controller.value),
              size: Size.infinite,
            );
          },
        ),
        
        // Light glows
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -50,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BioAccessTheme.accentGold.withOpacity(0.03),
            ),
          ),
        ),
      ],
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final double animationValue;

  BackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = Color(0xFF4A7797).withOpacity(0.1)
      ..style = PaintingStyle.fill;
      
    final paint2 = Paint()
      ..color = Color(0xFF9FB1BC).withOpacity(0.08)
      ..style = PaintingStyle.fill;
      
    final paint3 = Paint()
      ..color = Color(0xFF6E8898).withOpacity(0.05)
      ..style = PaintingStyle.fill;

    // First wave - slower, larger amplitude
    final wave1 = _createWave(
      size,
      amplitude: 60,
      frequency: 0.4,
      phase: animationValue * math.pi,
      verticalOffset: size.height * 0.7,
    );
    
    // Second wave - medium speed, medium amplitude
    final wave2 = _createWave(
      size,
      amplitude: 40,
      frequency: 0.6,
      phase: -animationValue * 1.5 * math.pi,
      verticalOffset: size.height * 0.8,
    );
    
    // Third wave - fastest, smallest amplitude
    final wave3 = _createWave(
      size,
      amplitude: 25,
      frequency: 0.9,
      phase: animationValue * 2 * math.pi,
      verticalOffset: size.height * 0.85,
    );

    canvas.drawPath(wave1, paint1);
    canvas.drawPath(wave2, paint2);
    canvas.drawPath(wave3, paint3);
  }

  Path _createWave(Size size,
      {required double amplitude,
      required double frequency,
      required double phase,
      required double verticalOffset}) {
    final path = Path();
    
    // Start at bottom left
    path.moveTo(0, size.height);
    
    // Create smooth wave using cubic bezier curves instead of straight lines
    final segmentWidth = 20.0; // width of each segment
    final segments = (size.width / segmentWidth).ceil();
    
    for (var i = 0; i <= segments; i++) {
      final x = i * segmentWidth;
      final nextX = (i + 1) * segmentWidth;
      
      if (nextX > size.width) break;
      
      // Calculate current and next y positions based on sine wave
      final y = verticalOffset + 
          amplitude * math.sin((x * frequency + phase) / size.width * 2 * math.pi);
      final nextY = verticalOffset + 
          amplitude * math.sin((nextX * frequency + phase) / size.width * 2 * math.pi);
      
      // Calculate control points for cubic bezier curve
      final controlX1 = x + segmentWidth * 0.4;
      final controlY1 = y;
      final controlX2 = x + segmentWidth * 0.6;
      final controlY2 = nextY;
      
      // Add cubic bezier curve
      path.cubicTo(controlX1, controlY1, controlX2, controlY2, nextX, nextY);
    }
    
    // Complete the path back to bottom right then bottom left
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    return path;
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}