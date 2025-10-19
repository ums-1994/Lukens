import 'package:flutter/material.dart';
import 'dart:math' as math;

class Globe3DWidget extends StatefulWidget {
  final double width;
  final double height;
  final bool autoRotate;
  final double rotationSpeed;

  const Globe3DWidget({
    super.key,
    this.width = 400,
    this.height = 400,
    this.autoRotate = true,
    this.rotationSpeed = 0.5,
  });

  @override
  State<Globe3DWidget> createState() => _Globe3DWidgetState();
}

class _Globe3DWidgetState extends State<Globe3DWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: Duration(seconds: (20 / widget.rotationSpeed).round()),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _ringController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _ringAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _ringController,
      curve: Curves.linear,
    ));

    if (widget.autoRotate) {
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
      _ringController.repeat();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE9293A).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Color(0xFF0A0A0F),
                    Color(0xFF1A1A2E),
                  ],
                ),
              ),
            ),
            
            // Animated Globe
            AnimatedBuilder(
              animation: Listenable.merge([
                _rotationAnimation,
                _pulseAnimation,
                _ringAnimation,
              ]),
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.width, widget.height),
                  painter: GlobePainter(
                    rotation: _rotationAnimation.value,
                    pulse: _pulseAnimation.value,
                    ringRotation: _ringAnimation.value,
                  ),
                );
              },
            ),
            
            // No data points - pure photorealistic Earth
          ],
        ),
      ),
    );
  }
}

class GlobePainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final double ringRotation;

  GlobePainter({
    required this.rotation,
    required this.pulse,
    required this.ringRotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.25 * pulse;

    // Draw 3D sphere using multiple circles with different opacities and sizes
    _draw3DSphere(canvas, center, radius);
    
    // Skip abstract grid lines for more realistic look
    
    // Skip orbital elements for cleaner look
    
    // Skip glow effects for photorealistic look
  }

  void _draw3DSphere(Canvas canvas, Offset center, double radius) {
    // Draw realistic Earth-like sphere
    _drawEarthBase(canvas, center, radius);
    _drawContinents(canvas, center, radius);
    _drawAtmosphere(canvas, center, radius);
    _drawLighting(canvas, center, radius);
  }

  void _drawEarthBase(Canvas canvas, Offset center, double radius) {
    // Real Earth ocean colors from satellite imagery
    final oceanPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.1, -0.1),
        radius: 1.0,
        colors: [
          const Color(0xFF0B1426), // Deep space blue
          const Color(0xFF1E3A8A), // Deep ocean blue
          const Color(0xFF2563EB), // Medium ocean blue
          const Color(0xFF3B82F6), // Bright ocean blue
          const Color(0xFF60A5FA), // Light ocean blue
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, oceanPaint);
  }

  void _drawContinents(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Draw photorealistic continents with proper Earth colors
    _drawPhotorealisticNorthAmerica(canvas, radius);
    _drawPhotorealisticSouthAmerica(canvas, radius);
    _drawPhotorealisticEuropeAfrica(canvas, radius);
    _drawPhotorealisticAsia(canvas, radius);
    _drawPhotorealisticAustralia(canvas, radius);

    canvas.restore();
  }

  void _drawPhotorealisticNorthAmerica(Canvas canvas, double radius) {
    final path = Path();
    // Photorealistic North America shape
    path.moveTo(-radius * 0.5, -radius * 0.4);
    path.lineTo(-radius * 0.6, -radius * 0.2);
    path.lineTo(-radius * 0.7, radius * 0.0);
    path.lineTo(-radius * 0.6, radius * 0.2);
    path.lineTo(-radius * 0.4, radius * 0.1);
    path.lineTo(-radius * 0.3, -radius * 0.1);
    path.lineTo(-radius * 0.4, -radius * 0.5);
    path.close();

    final paint = Paint()
      ..color = const Color(0xFF16A34A) // Real Earth vegetation green
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  void _drawPhotorealisticSouthAmerica(Canvas canvas, double radius) {
    final path = Path();
    // Photorealistic South America shape
    path.moveTo(-radius * 0.4, radius * 0.1);
    path.lineTo(-radius * 0.5, radius * 0.3);
    path.lineTo(-radius * 0.4, radius * 0.5);
    path.lineTo(-radius * 0.3, radius * 0.6);
    path.lineTo(-radius * 0.2, radius * 0.5);
    path.lineTo(-radius * 0.2, radius * 0.3);
    path.lineTo(-radius * 0.3, radius * 0.2);
    path.close();

    final paint = Paint()
      ..color = const Color(0xFF1B4D3E)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  void _drawPhotorealisticEuropeAfrica(Canvas canvas, double radius) {
    // Europe - smaller, more realistic
    final europePath = Path();
    europePath.moveTo(radius * 0.0, -radius * 0.5);
    europePath.lineTo(radius * 0.2, -radius * 0.4);
    europePath.lineTo(radius * 0.3, -radius * 0.3);
    europePath.lineTo(radius * 0.2, -radius * 0.2);
    europePath.lineTo(radius * 0.1, -radius * 0.3);
    europePath.lineTo(-radius * 0.1, -radius * 0.4);
    europePath.close();

    // Africa - more realistic shape
    final africaPath = Path();
    africaPath.moveTo(radius * 0.1, -radius * 0.2);
    africaPath.lineTo(radius * 0.2, radius * 0.0);
    africaPath.lineTo(radius * 0.3, radius * 0.2);
    africaPath.lineTo(radius * 0.2, radius * 0.4);
    africaPath.lineTo(radius * 0.1, radius * 0.5);
    africaPath.lineTo(radius * 0.0, radius * 0.3);
    africaPath.lineTo(radius * 0.0, radius * 0.1);
    africaPath.close();

    final paint = Paint()
      ..color = const Color(0xFF1B4D3E)
      ..style = PaintingStyle.fill;

    canvas.drawPath(europePath, paint);
    canvas.drawPath(africaPath, paint);
  }

  void _drawPhotorealisticAsia(Canvas canvas, double radius) {
    final path = Path();
    // Photorealistic Asia shape
    path.moveTo(radius * 0.2, -radius * 0.3);
    path.lineTo(radius * 0.6, -radius * 0.4);
    path.lineTo(radius * 0.7, -radius * 0.2);
    path.lineTo(radius * 0.8, radius * 0.0);
    path.lineTo(radius * 0.7, radius * 0.2);
    path.lineTo(radius * 0.5, radius * 0.1);
    path.lineTo(radius * 0.3, -radius * 0.2);
    path.close();

    final paint = Paint()
      ..color = const Color(0xFF1B4D3E)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  void _drawPhotorealisticAustralia(Canvas canvas, double radius) {
    final path = Path();
    // Photorealistic Australia shape
    path.moveTo(radius * 0.4, radius * 0.2);
    path.lineTo(radius * 0.5, radius * 0.3);
    path.lineTo(radius * 0.4, radius * 0.4);
    path.lineTo(radius * 0.3, radius * 0.3);
    path.close();

    final paint = Paint()
      ..color = const Color(0xFF1B4D3E)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  void _drawAtmosphere(Canvas canvas, Offset center, double radius) {
    // Subtle atmospheric glow like real Earth
    final atmospherePaint = Paint()
      ..color = const Color(0xFF87CEEB).withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(center, radius * 1.05, atmospherePaint);
  }

  void _drawLighting(Canvas canvas, Offset center, double radius) {
    // Realistic sunlight - warm white like actual Earth
    final sunlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.2),
        radius: 0.8,
        colors: [
          const Color(0xFFFFF8DC).withOpacity(0.9), // Warm white
          const Color(0xFFFFF8DC).withOpacity(0.7),
          const Color(0xFFFFF8DC).withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sunlightPaint);

    // Subtle terminator line (day/night boundary)
    final terminatorPaint = Paint()
      ..color = const Color(0xFF1F2937).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - radius * 0.1, center.dy),
        width: radius * 0.2,
        height: radius * 2,
      ),
      terminatorPaint,
    );

    // Dark side shadow
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, 0.2),
        radius: 0.5,
        colors: [
          Colors.transparent,
          const Color(0xFF111827).withOpacity(0.4),
          const Color(0xFF000000).withOpacity(0.7),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, shadowPaint);
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

