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
    'assets/images/Khonology Landing Page Animation Frame 1.jpg',
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
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Background image with dark overlay
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4),
                BlendMode.darken,
              ),
              child: _buildBackgroundLayers(),
            ),
          ),
          // Main content with fixed header
          Positioned.fill(
            child: Column(
              children: [
                // FIXED HEADER SECTION (never scrolls)
                const SizedBox(height: 48), // Top safe area/padding
                Center(
                  child: Image.asset(
                    // LOGO - Fixed position
                    'assets/images/2026.png',
                    height: 160, // Fixed height
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        '✕ Khonology',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24), // Space after logo
                // SCROLLABLE CONTENT SECTION
                Expanded(
                  // Takes remaining space
                  child: SingleChildScrollView(
                    // Scrollable area
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Landing page content that scrolls
                        _buildAnimatedHeadline(isMobile),
                        SizedBox(height: isMobile ? 24 : 40),
                        _buildSubheading(isMobile),
                        SizedBox(height: isMobile ? 40 : 56),
                        _buildCTAButtons(isMobile),
                      ],
                    ),
                  ),
                ),
              ],
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
        // Base background image
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 1200),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: Image.asset(
            _backgroundImages[_currentFrameIndex],
            key: ValueKey<int>(_currentFrameIndex),
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
        ),
        // Pulsing light overlay (dark to light breathing)
        AnimatedBuilder(
          animation: _parallaxController,
          builder: (context, child) {
            // Darkness ranges from 0.6 (darker) to 0.2 (lighter)
            final darkness =
                0.4 - (math.sin(_parallaxController.value * 2 * math.pi) * 0.2);
            return Container(
              color: Colors.black.withOpacity(darkness.clamp(0.0, 1.0)),
            );
          },
        ),
      ],
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
    return FadeTransition(
      opacity: _ctaController,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: _ctaController, curve: Curves.easeOut),
        ),
        child: Wrap(
          spacing: isMobile ? 16 : 32,
          runSpacing: 16,
          children: [
            // Get Started button with gradient
            AnimatedBuilder(
              animation: _parallaxController,
              builder: (context, child) {
                final glowIntensity = 0.6 +
                    (math.sin(_parallaxController.value * 2 * math.pi) * 0.3);
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE9293A), // #E9293A
                        Color(0xFF780A01), // #780A01
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFE9293A).withOpacity(glowIntensity),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 32 : 48,
                        vertical: isMobile ? 16 : 20,
                      ),
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
                );
              },
            ),

            // Learn More button with grey/silver gradient
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFFFF), // #FFFFFF
                    Color(0xFFB0B6BB), // #B0B6BB
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to learn more page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 32 : 48,
                    vertical: isMobile ? 16 : 20,
                  ),
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
