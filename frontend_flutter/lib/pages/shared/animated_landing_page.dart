import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedLandingPage extends StatefulWidget {
  const AnimatedLandingPage({super.key});

  @override
  State<AnimatedLandingPage> createState() => _AnimatedLandingPageState();
}

class _AnimatedLandingPageState extends State<AnimatedLandingPage>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _textController;
  late AnimationController _lineController;
  late AnimationController _subtextController;
  late AnimationController _buttonController;
  late AnimationController _tubeController;
  late AnimationController _floatController;
  late AnimationController _glowController;

  // Animations
  late Animation<double> _backgroundOpacity;
  late Animation<double> _buildOpacity;
  late Animation<double> _buildSlide;
  late Animation<double> _automateOpacity;
  late Animation<double> _automateSlide;
  late Animation<double> _deliverOpacity;
  late Animation<double> _deliverSlide;
  late Animation<double> _lineProgress;
  late Animation<double> _subtextOpacity;
  late Animation<double> _buttonScale;
  late Animation<double> _buttonOpacity;
  late Animation<double> _tubeProgress;
  late Animation<double> _tubeRotation;
  late Animation<double> _floatOffset;
  late Animation<double> _glowIntensity;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
  }

  void _setupAnimations() {
    // Background (0-0.5s)
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _backgroundOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );

    // Text animations (0.5-2.5s)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _buildOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _buildSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _automateOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _automateSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    _deliverOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );
    _deliverSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );

    // Line drawing (0.5-2.5s)
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _lineProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _lineController, curve: Curves.easeInOut),
    );

    // Subtext (2.5-3.5s)
    _subtextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _subtextOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtextController, curve: Curves.easeOut),
    );

    // Button (2.5-3.5s)
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _buttonScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );
    _buttonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );

    // 3D Tube (3.5-5.5s)
    _tubeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _tubeProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tubeController, curve: Curves.easeInOut),
    );
    _tubeRotation = Tween<double>(begin: -0.3, end: 0.1).animate(
      CurvedAnimation(parent: _tubeController, curve: Curves.easeInOut),
    );

    // Continuous float (5.5s+)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );
    _floatOffset = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Continuous glow (5.5s+)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _glowIntensity = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  void _startAnimationSequence() async {
    // 1. Background fade in (0-0.5s)
    _backgroundController.forward();

    // 2. Text animations (0.5-2.5s)
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();
    _lineController.forward();

    // 3. Secondary elements (2.5-3.5s)
    await Future.delayed(const Duration(milliseconds: 2000));
    _subtextController.forward();
    _buttonController.forward();

    // 4. 3D tube (3.5-5.5s)
    await Future.delayed(const Duration(milliseconds: 1000));
    _tubeController.forward();

    // 5. Continuous animations (5.5s+)
    await Future.delayed(const Duration(milliseconds: 2000));
    _floatController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _textController.dispose();
    _lineController.dispose();
    _subtextController.dispose();
    _buttonController.dispose();
    _tubeController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _backgroundController,
          _textController,
          _lineController,
          _subtextController,
          _buttonController,
          _tubeController,
          _floatController,
          _glowController,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              // Dark background with geometric shapes
              _buildBackground(),

              // Layout: Left content, Right 3D scene
              Row(
                children: [
                  // Left side - Text content
                  Expanded(
                    flex: 5,
                    child: _buildMainContent(),
                  ),
                  
                  // Right side - 3D Tube
                  Expanded(
                    flex: 5,
                    child: _build3DTube(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Opacity(
      opacity: _backgroundOpacity.value,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF000000),
              Color(0xFF0B0B0C),
              Color(0xFF1A1A1B),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Geometric shapes
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2C3E50).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DTube() {
    return Transform.translate(
      offset: Offset(
        100 - (_tubeProgress.value * 100), 
        _floatController.isAnimating ? _floatOffset.value : 0
      ),
      child: Transform.rotate(
        angle: _tubeRotation.value,
        child: Opacity(
          opacity: _tubeProgress.value,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/Khonology Landing Page - Frame 6.png'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                opacity: _tubeProgress.value,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.only(left: 80, top: 60, bottom: 60, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Main headline with animations
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BUILD.
              Opacity(
                opacity: _buildOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _buildSlide.value),
                  child: const Text(
                    'BUILD.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 110,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                      letterSpacing: -3,
                    ),
                  ),
                ),
              ),

              // AUTOMATE.
              Opacity(
                opacity: _automateOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _automateSlide.value),
                  child: const Text(
                    'AUTOMATE.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 110,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                      letterSpacing: -3,
                    ),
                  ),
                ),
              ),

              // DELIVER. with animated underline
              Stack(
                children: [
                  Opacity(
                    opacity: _deliverOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _deliverSlide.value),
                      child: const Text(
                        'DELIVER.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 110,
                          fontWeight: FontWeight.w900,
                          height: 0.95,
                          letterSpacing: -3,
                        ),
                      ),
                    ),
                  ),

                  // Animated red underline
                  Positioned(
                    left: 0,
                    bottom: 15,
                    child: CustomPaint(
                      size: Size(550 * _lineProgress.value, 8),
                      painter: RedLinePainter(
                        progress: _lineProgress.value,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Subtext
          Opacity(
            opacity: _subtextOpacity.value,
            child: const Text(
              'Smart Proposal & SOW\nBuilder for Digital Teams',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w300,
                height: 1.3,
              ),
            ),
          ),

          const SizedBox(height: 56),

          // CTA Buttons
          Row(
            children: [
              // Get Started button with glow
              Opacity(
                opacity: _buttonOpacity.value,
                child: Transform.scale(
                  scale: _buttonScale.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD72638).withOpacity(
                            _glowController.isAnimating ? _glowIntensity.value : 0.4,
                          ),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD72638),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 56,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 40),

              // Learn More text button
              Opacity(
                opacity: _buttonOpacity.value,
                child: TextButton(
                  onPressed: () {
                    // Scroll to features or show modal
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                  ),
                  child: const Text(
                    'Learn More',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom painter for the red underline
class RedLinePainter extends CustomPainter {
  final double progress;

  RedLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD72638)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Curved underline path
    final startX = 0.0;
    final endX = size.width;
    final y = size.height / 2;

    path.moveTo(startX, y + 10);
    path.quadraticBezierTo(
      endX * 0.3,
      y - 5,
      endX * 0.5,
      y + 5,
    );
    path.quadraticBezierTo(
      endX * 0.7,
      y + 15,
      endX,
      y,
    );

    final pathMetrics = path.computeMetrics().first;
    final extractPath = pathMetrics.extractPath(
      0,
      pathMetrics.length * progress,
    );

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant RedLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

