// ignore_for_file: deprecated_member_use, unused_element
import 'package:flutter/material.dart';
import 'dart:math' as math;

class CinematicSequencePage extends StatefulWidget {
  const CinematicSequencePage({super.key});

  @override
  State<CinematicSequencePage> createState() => _CinematicSequencePageState();
}

class _CinematicSequencePageState extends State<CinematicSequencePage>
    with TickerProviderStateMixin {
  late final AnimationController _textController;
  late final AnimationController _underlineController;
  late final AnimationController _ctaController;
  late final AnimationController _parallaxController;
  late final AnimationController _frameController;

  // Background images for cinematic sequence (clean geometric look)
  final List<String> _backgroundImages = [
    'assets/images/nathi.png',
  ];

  int _currentFrameIndex = 0;

  @override
  void initState() {
    super.initState();

    // Frame transition controller (smooth cycling)
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // 2s per frame
    );

    // Text fade-in + scale animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Underline drawing animation
    _underlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // CTA button animation
    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Parallax floating shapes
    _parallaxController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Precache all frames
    _precacheFrames();

    // Start animation sequence
    _startAnimationSequence();
    _cycleBackgrounds();
  }

  Future<void> _precacheFrames() async {
    for (final imagePath in _backgroundImages) {
      await precacheImage(AssetImage(imagePath), context);
    }
  }

  void _cycleBackgrounds() {
    _frameController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentFrameIndex =
              (_currentFrameIndex + 1) % _backgroundImages.length;
        });
        _frameController.reset();
        _frameController.forward();
      }
    });
    _frameController.forward();
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _underlineController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _ctaController.forward();
  }

  @override
  void dispose() {
    _frameController.dispose();
    _textController.dispose();
    _underlineController.dispose();
    _ctaController.dispose();
    _parallaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Static background layers (no animation)
          _buildBackgroundLayers(),

          // Dark gradient overlay for text contrast
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),

          // Removed floating shapes/animations

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 80,
                  vertical: isMobile ? 40 : 60,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.height - (isMobile ? 80 : 120),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Khonology logo at top, centered
                      Image.asset(
                        'assets/images/khono.png',
                        height: isMobile ? 56 : 72,
                        fit: BoxFit.contain,
                      ),

                      SizedBox(height: isMobile ? 40 : 56),

                      // CTA buttons (static)
                      _buildCTAButtons(isMobile),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayers() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base background image (static)
        Image.asset(
          _backgroundImages[_currentFrameIndex],
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF000000),
              child: const Center(
                child: Icon(Icons.error, color: Colors.white54, size: 48),
              ),
            );
          },
        ),
        // Static dark overlay for contrast
        Container(
          color: Colors.black.withOpacity(0.45),
        ),
      ],
    );
  }

  Widget _buildFloatingShapes() {
    return AnimatedBuilder(
      animation: _parallaxController,
      builder: (context, child) {
        return Stack(
          children: [
            // Triangle 1 - Top Left
            Positioned(
              left: 120 +
                  (math.sin(_parallaxController.value * 2 * math.pi) * 40),
              top: 180 +
                  (math.cos(_parallaxController.value * 2 * math.pi) * 30),
              child: Transform.rotate(
                angle: _parallaxController.value * 2 * math.pi,
                child: CustomPaint(
                  painter:
                      TrianglePainter(color: Colors.white.withOpacity(0.04)),
                  size: const Size(70, 70),
                ),
              ),
            ),

            // Triangle 2 - Top Right
            Positioned(
              right: 140 +
                  (math.sin(_parallaxController.value * 2 * math.pi + 1.5) *
                      50),
              top: 220 +
                  (math.cos(_parallaxController.value * 2 * math.pi + 1.5) *
                      35),
              child: Transform.rotate(
                angle: -_parallaxController.value * 2 * math.pi * 0.8,
                child: CustomPaint(
                  painter:
                      TrianglePainter(color: Colors.white.withOpacity(0.05)),
                  size: const Size(90, 90),
                ),
              ),
            ),

            // Triangle 3 - Bottom Left
            Positioned(
              left: 200 +
                  (math.sin(_parallaxController.value * 2 * math.pi + 3) * 35),
              bottom: 150 +
                  (math.cos(_parallaxController.value * 2 * math.pi + 3) * 25),
              child: Transform.rotate(
                angle: _parallaxController.value * 2 * math.pi * 0.6,
                child: CustomPaint(
                  painter:
                      TrianglePainter(color: Colors.white.withOpacity(0.03)),
                  size: const Size(60, 60),
                ),
              ),
            ),

            // Triangle 4 - Center Right
            Positioned(
              right: 180 +
                  (math.sin(_parallaxController.value * 2 * math.pi + 4) * 45),
              top: 400 +
                  (math.cos(_parallaxController.value * 2 * math.pi + 4) * 40),
              child: Transform.rotate(
                angle: -_parallaxController.value * 2 * math.pi * 0.7,
                child: CustomPaint(
                  painter:
                      TrianglePainter(color: Colors.white.withOpacity(0.04)),
                  size: const Size(80, 80),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedHeadline(bool isMobile) {
    return FadeTransition(
      opacity: _textController,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOut),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeadlineText('BUILD.', isMobile),
            _buildHeadlineText('AUTOMATE.', isMobile),
            _buildHeadlineText('DELIVER.', isMobile),
            const SizedBox(height: 16),
            // Animated red underline
            AnimatedBuilder(
              animation: _underlineController,
              builder: (context, child) {
                return CustomPaint(
                  painter: RedLinePainter(
                    progress: _underlineController.value,
                    color: const Color(0xFFD72638),
                  ),
                  size: Size(isMobile ? 200 : 400, 4),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadlineText(String text, bool isMobile) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: isMobile ? 40 : 80,
        fontWeight: FontWeight.w900,
        height: 0.95,
        letterSpacing: -2,
      ),
    );
  }

  Widget _buildSubheading(bool isMobile) {
    return FadeTransition(
      opacity: _textController,
      child: Text(
        'Smart Proposal & SOW Builder for Digital Teams',
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white.withOpacity(0.95),
          fontSize: isMobile ? 16 : 24,
          fontWeight: FontWeight.w300,
          height: 1.4,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCTAButtons(bool isMobile) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Buttons only (logo moved to top of screen)
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
              minimumSize: Size(isMobile ? 220 : 240, isMobile ? 52 : 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              elevation: 0,
            ),
            child: Text(
              'GET STARTED',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
              minimumSize: Size(isMobile ? 220 : 240, isMobile ? 52 : 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              elevation: 0,
            ),
            child: Text(
              'LEARN MORE',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the red underline
class RedLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  RedLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);

    final pathMetrics = path.computeMetrics().first;
    final extractPath = pathMetrics.extractPath(
      0,
      pathMetrics.length * progress,
    );

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(RedLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Custom painter for triangles
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) => false;
}
