// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class AnimatedLandingPage extends StatefulWidget {
  const AnimatedLandingPage({super.key});

  @override
  State<AnimatedLandingPage> createState() => _AnimatedLandingPageState();
}

class _AnimatedLandingPageState extends State<AnimatedLandingPage>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _textController;
  late AnimationController _subtextController;
  late AnimationController _buttonController;
  // Removed unused controllers
  // late AnimationController _tubeController;
  // late AnimationController _floatController;

  // Animations
  late Animation<double> _buildOpacity;
  late Animation<double> _buildSlide;
  late Animation<double> _automateOpacity;
  late Animation<double> _automateSlide;
  late Animation<double> _deliverOpacity;
  late Animation<double> _deliverSlide;
  // Removed unused animations
  // late Animation<double> _lineProgress;
  late Animation<double> _subtextOpacity;
  late Animation<double> _buttonScale;
  late Animation<double> _buttonOpacity;
  // Removed unused animations
  // late Animation<double> _tubeProgress;
  // late Animation<double> _tubeRotation;
  // late Animation<double> _floatOffset;
  // late Animation<double> _glowIntensity;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimationSequence();
  }

  void _setupAnimations() {
    // Background (0-0.5s)
    // _backgroundController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 500),
    // );
    // _backgroundOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    // );

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
    // _lineController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 1500),
    // );
    // _lineProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(parent: _lineController, curve: Curves.easeInOut),
    // );

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

    // Continuous glow (5.5s+)
    // _glowController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 3000),
    // );
    // _glowIntensity = Tween<double>(begin: 0.3, end: 0.6).animate(
    //   CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    // );
  }

  void _startAnimationSequence() async {
    // 1. Background fade in (0-0.5s)
    // _backgroundController.forward();

    // 2. Text animations (0.5-2.5s)
    await Future.delayed(const Duration(milliseconds: 500));
    _textController.forward();
    // _lineController.forward();

    // 3. Secondary elements (2.5-3.5s)
    await Future.delayed(const Duration(milliseconds: 2000));
    _subtextController.forward();
    _buttonController.forward();

    // 4. 3D tube (3.5-5.5s)
    await Future.delayed(const Duration(milliseconds: 1000));

    // 5. Continuous animations (5.5s+)
    await Future.delayed(const Duration(milliseconds: 2000));
    // _floatController.repeat(reverse: true);
    // _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    // _backgroundController.dispose();
    _textController.dispose();
    // _lineController.dispose();
    _subtextController.dispose();
    _buttonController.dispose();
    // Removed unused controllers
    // _tubeController.dispose();
    // _floatController.dispose();
    // _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          // _backgroundController,
          _textController,
          // _lineController,
          _subtextController,
          _buttonController,
          // Removed _glowController
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
                    child: _buildMainContent(),
                  ),

                  // Removed Right side - 3D Tube
                  // Expanded(
                  //   flex: 5,
                  //   child: _build3DTube(),
                  // ),
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
      opacity: 1.0, // Ensure full opacity
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/nathi.png',
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay for contrast
          Container(
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
          ),
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
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/khono.png',
              height: 120, // Increased size
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            // Main headline with animations
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                        fontSize: 80, // Reduced font size
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
                        fontSize: 80, // Reduced font size
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
                            fontSize: 80, // Reduced font size
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                            letterSpacing: -3,
                          ),
                        ),
                      ),
                    ),

                    // Animated red underline
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
                  fontSize: 24, // Reduced font size
                  fontWeight: FontWeight.w300,
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(height: 56),

            // CTA Buttons
            Opacity(
              opacity: _buttonOpacity.value,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    Transform.scale(
                      scale: _buttonScale.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC10D00),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(240, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'GET STARTED',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Transform.scale(
                      scale: _buttonScale.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC10D00),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(240, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'LEARN MORE',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
