import 'package:flutter/material.dart';

/// Khonology Landing Page with Precise Animation Timeline
/// Total Duration: 5.0 seconds with staggered element reveals
class AnimatedLandingPageV2 extends StatefulWidget {
  const AnimatedLandingPageV2({super.key});

  @override
  State<AnimatedLandingPageV2> createState() => _AnimatedLandingPageV2State();
}

class _AnimatedLandingPageV2State extends State<AnimatedLandingPageV2>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  // Individual animations with precise timing intervals
  late Animation<double> _backgroundAnim;
  late Animation<double> _buildTextAnim;
  late Animation<double> _buildSlideAnim;
  late Animation<double> _automateTextAnim;
  late Animation<double> _automateSlideAnim;
  late Animation<double> _deliverTextAnim;
  late Animation<double> _deliverSlideAnim;
  late Animation<double> _lineAnim;
  late Animation<double> _tubularAnim;
  late Animation<double> _tubularSlideAnim;
  late Animation<double> _subheadingAnim;
  late Animation<double> _buttonsAnim;

  // Continuous animations
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    // Main timeline controller (5 seconds)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );

    // Phase 1: Background Fade-In (0.0s - 0.5s) -> Interval(0.0, 0.1)
    _backgroundAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.1, curve: Curves.easeOut),
    );

    // Phase 2: "BUILD." Text (0.5s - 1.0s) -> Interval(0.1, 0.2)
    _buildTextAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.2, curve: Curves.easeOut),
    );
    _buildSlideAnim = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.2, curve: Curves.easeOut),
      ),
    );

    // Phase 3: "AUTOMATE." Text (1.0s - 1.5s) -> Interval(0.2, 0.3)
    _automateTextAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.3, curve: Curves.easeOut),
    );
    _automateSlideAnim = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.3, curve: Curves.easeOut),
      ),
    );

    // Phase 4: "DELIVER." Text (1.5s - 2.0s) -> Interval(0.3, 0.4)
    _deliverTextAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.4, curve: Curves.easeOut),
    );
    _deliverSlideAnim = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.4, curve: Curves.easeOut),
      ),
    );

    // Phase 5: Red Line Drawing (2.0s - 3.0s) -> Interval(0.4, 0.6)
    _lineAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.6, curve: Curves.easeInOut),
    );

    // Phase 6: 3D Tubular Element (2.5s - 4.5s) -> Interval(0.5, 0.9)
    _tubularAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
    );
    _tubularSlideAnim = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    // Phase 7: Subheading Text (3.0s - 3.5s) -> Interval(0.6, 0.7)
    _subheadingAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 0.7, curve: Curves.easeOut),
    );

    // Phase 8: Buttons (3.5s - 4.0s) -> Interval(0.7, 0.8)
    _buttonsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 0.8, curve: Curves.easeOut),
    );

    // Continuous glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start the main animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _glowController]),
        builder: (context, child) {
          return Stack(
            children: [
              // Layer 1: Background with fade-in
              _buildBackground(),

              // Layer 2: Responsive layout
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth >= 900;
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(flex: 5, child: _buildTextContent()),
                        Expanded(flex: 5, child: _build3DElement()),
                      ],
                    );
                  }
                  // Narrow screens: stack vertically and allow scroll
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextContent(),
                        const SizedBox(height: 28),
                        SizedBox(height: 360, child: _build3DElement()),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Opacity(
      opacity: _backgroundAnim.value,
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
            // Geometric accent
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2C3E50).withValues(alpha: 0.15),
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

  Widget _buildTextContent() {
    return RepaintBoundary(
      child: Padding(
        padding:
            const EdgeInsets.only(left: 80, top: 60, bottom: 60, right: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxWidth = constraints.maxWidth;
            final double headlineSize = (maxWidth * 0.12).clamp(72.0, 140.0);
            final double subheadingSize = (maxWidth * 0.035).clamp(20.0, 36.0);
            final double underlineWidth = (maxWidth * 0.7);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main headline - Staggered animation
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BUILD.
                    Opacity(
                      opacity: _buildTextAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, _buildSlideAnim.value),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'BUILD.',
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: headlineSize,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                              letterSpacing: -3,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // AUTOMATE.
                    Opacity(
                      opacity: _automateTextAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, _automateSlideAnim.value),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'AUTOMATE.',
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: headlineSize,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                              letterSpacing: -3,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // DELIVER. with animated underline
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Opacity(
                          opacity: _deliverTextAnim.value,
                          child: Transform.translate(
                            offset: Offset(0, _deliverSlideAnim.value),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'DELIVER.',
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: headlineSize,
                                  fontWeight: FontWeight.w900,
                                  height: 0.95,
                                  letterSpacing: -3,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Animated red line (draws from left to right)
                        Positioned(
                          left: 0,
                          bottom: 2,
                          child: CustomPaint(
                            size: Size(underlineWidth, 14),
                            painter: RedLinePainter(
                              progress: _lineAnim.value,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Subheading
                Opacity(
                  opacity: _subheadingAnim.value,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Text(
                      'Smart Proposal & SOW\nBuilder for Digital Teams',
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: subheadingSize,
                        fontWeight: FontWeight.w300,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                // CTA Buttons
                Opacity(
                  opacity: _buttonsAnim.value,
                  child: Row(
                    children: [
                      // Get Started button with glow
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD72638)
                                  .withValues(alpha: _glowAnim.value),
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

                      const SizedBox(width: 40),

                      // Learn More button
                      TextButton(
                        onPressed: () {
                          // Navigate or scroll to features
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
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _build3DElement() {
    return RepaintBoundary(
      child: Transform.translate(
        offset: Offset(_tubularSlideAnim.value, 0),
        child: Opacity(
          opacity: _tubularAnim.value,
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/Khonology Landing Page - Frame 6.png'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the animated red underline
class RedLinePainter extends CustomPainter {
  final double progress;

  RedLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Colors tuned to reference
    const Color lineColor = Color(0xFFE9293A);

    // Very subtle glow underpaint
    final glow = Paint()
      ..color = lineColor.withValues(alpha: 0.15)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Main stroke
    final stroke = Paint()
      ..color = lineColor
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Curved underline path across available width
    final double w = size.width;
    final double baselineY = size.height * 0.5; // closer to baseline
    final double amp = 8.0; // slightly gentler wave

    final path = Path()
      ..moveTo(0, baselineY)
      ..cubicTo(
        w * 0.20,
        baselineY - amp,
        w * 0.35,
        baselineY + amp,
        w * 0.55,
        baselineY,
      )
      ..cubicTo(
        w * 0.72,
        baselineY - amp * 0.6,
        w * 0.88,
        baselineY + amp * 0.8,
        w,
        baselineY,
      );

    // Draw only up to progress
    final metric = path.computeMetrics().first;
    final len = metric.length * progress.clamp(0.0, 1.0);
    final partial = metric.extractPath(0, len);

    canvas.drawPath(partial, glow);
    canvas.drawPath(partial, stroke);
  }

  @override
  bool shouldRepaint(covariant RedLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
