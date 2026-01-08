import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum _InfoPanelType {
  product,
  howItWorks,
}

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
  late final AnimationController _infoPanelController;

  bool _didPrecacheFrames = false;

  _InfoPanelType? _activeInfoPanel;

  // Background images for cinematic sequence (clean geometric look)
  final List<String> _backgroundImages = [
    'assets/images/Khonology Landing Page Animation Frame 1.jpg',
  ];

  int _currentFrameIndex = 0;

  void _openLearnMoreCurtain() {
    _openInfoPanel(_InfoPanelType.product);
  }

  void _openHowItWorksPanel() {
    _openInfoPanel(_InfoPanelType.howItWorks);
  }

  void _openInfoPanel(_InfoPanelType type) {
    setState(() {
      _activeInfoPanel = type;
    });
    _infoPanelController.forward();
  }

  void _closeInfoPanel() {
    _infoPanelController.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _activeInfoPanel = null;
      });
    });
  }

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

    _infoPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // Start animation sequence
    _startAnimationSequence();
    _cycleBackgrounds();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didPrecacheFrames) return;
    _didPrecacheFrames = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheFrames();
    });
  }

  Future<void> _precacheFrames() async {
    for (final imagePath in _backgroundImages) {
      if (!mounted) return;
      await precacheImage(AssetImage(imagePath), context);
    }
  }

  void _cycleBackgrounds() {
    _frameController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentFrameIndex = (_currentFrameIndex + 1) % _backgroundImages.length;
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
    _infoPanelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;
    final double horizontalPadding = isMobile ? 24 : 80;
    const double navBarHeight = 56;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated background layers with crossfade
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

          // Floating geometric shapes (parallax) - desktop only
          if (!isMobile) _buildFloatingShapes(),

          // Main content
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 24 : 80,
                      vertical: (isMobile ? 40 : 36) + (isMobile ? 0 : navBarHeight),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: size.height - (isMobile ? 80 : 120),
                      ),
                      child: Transform.translate(
                        offset: Offset(0, isMobile ? 0 : -48),
                        child: Column(
                          crossAxisAlignment:
                              isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated headline
                            _buildAnimatedHeadline(isMobile),

                            SizedBox(height: isMobile ? 24 : 40),

                            // Subheading
                            _buildSubheading(isMobile),

                            SizedBox(height: isMobile ? 40 : 56),

                            // CTA buttons
                            _buildCTAButtons(isMobile),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                    child: _buildSocialLinksRow(isMobile: isMobile),
                  ),
                ),
                if (!isMobile)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildTopNavBar(
                      context,
                      horizontalPadding: horizontalPadding,
                      height: navBarHeight,
                    ),
                  ),

                if (_activeInfoPanel != null || _infoPanelController.isAnimating)
                  Positioned.fill(
                    child: _buildInfoPanelOverlay(
                      context,
                      isMobile: isMobile,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildTopNavBar(
    BuildContext context, {
    required double horizontalPadding,
    required double height,
  }) {
    final TextStyle linkStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.88),
              fontWeight: FontWeight.w500,
            ) ??
        TextStyle(
          color: Colors.white.withOpacity(0.88),
          fontWeight: FontWeight.w500,
        );

    TextButton buildLink(String label, VoidCallback onPressed) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          textStyle: linkStyle,
        ),
        child: Text(label),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.70),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: [
            buildLink('Product', _openLearnMoreCurtain),
            buildLink('How It Works', _openHowItWorksPanel),
            buildLink('About', () => _openExternalUrl('https://www.khonology.com/')),
            const Spacer(),
            buildLink('Sign In', () => Navigator.pushNamed(context, '/login')),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanelOverlay(
    BuildContext context, {
    required bool isMobile,
  }) {
    final CurvedAnimation curved = CurvedAnimation(
      parent: _infoPanelController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              height: 1.35,
              color: Colors.white,
              fontFamily: 'Poppins',
            ) ??
        const TextStyle(
          fontSize: 16,
          height: 1.35,
          color: Colors.white,
          fontFamily: 'Poppins',
        );

    String title = 'Proposal & SOW Builder';
    String subtitle = 'Built for digital teams that need speed, consistency, and governance.';
    List<_TourStep> steps = <_TourStep>[
      _TourStep(
        number: 1,
        title: 'Structured proposals & SOWs',
        body: 'Start from templates or build from scratch to produce client-ready documents.',
        textStyle: textStyle,
      ),
      _TourStep(
        number: 2,
        title: 'Collaboration built-in',
        body: 'Work with teams, comments, workspaces, and notifications to stay aligned.',
        textStyle: textStyle,
      ),
      _TourStep(
        number: 3,
        title: 'Governance + AI Risk Gate',
        body: 'Spot issues early and reduce compliance and delivery surprises.',
        textStyle: textStyle,
      ),
      _TourStep(
        number: 4,
        title: 'Secure sharing',
        body: 'Send via links and move faster through review, sign-off, and delivery.',
        textStyle: textStyle,
      ),
    ];

    if (_activeInfoPanel == _InfoPanelType.howItWorks) {
      title = 'How It Works';
      subtitle = 'Compose → Govern → AI Risk Gate → Preview → Internal Sign-off';
      steps = <_TourStep>[
        _TourStep(
          number: 1,
          title: 'Compose',
          body: 'Draft your proposal or SOW using structured sections and templates.',
          textStyle: textStyle,
        ),
        _TourStep(
          number: 2,
          title: 'Govern',
          body: 'Run governance checks to ensure clarity, completeness, and consistency.',
          textStyle: textStyle,
        ),
        _TourStep(
          number: 3,
          title: 'AI Risk Gate',
          body: 'Identify risk areas early and get recommended fixes before sending.',
          textStyle: textStyle,
        ),
        _TourStep(
          number: 4,
          title: 'Preview',
          body: 'Review formatting and client readiness before approval or share.',
          textStyle: textStyle,
        ),
        _TourStep(
          number: 5,
          title: 'Internal Sign-off',
          body: 'Route for review and get alignment before you send to a client.',
          textStyle: textStyle,
        ),
      ];
    }

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final double t = curved.value;
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeInfoPanel,
              child: Container(
                color: Colors.black.withOpacity(0.45 * t),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.88,
                child: Transform.translate(
                  offset: Offset((1 - t) * MediaQuery.of(context).size.width * 0.88, 0),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0B0B).withOpacity(0.96),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          bottomLeft: Radius.circular(18),
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.75),
                            blurRadius: 36,
                            spreadRadius: 6,
                            offset: const Offset(-16, 0),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 22,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    bottomLeft: Radius.circular(18),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.white.withOpacity(0.10),
                                      Colors.white.withOpacity(0.04),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                            child: SafeArea(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _closeInfoPanel,
                                        icon: const Icon(Icons.close, color: Colors.white70),
                                        tooltip: 'Close',
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ) ??
                                              const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    subtitle,
                                    style: textStyle.copyWith(
                                      color: Colors.white.withOpacity(0.86),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          for (int i = 0; i < steps.length; i++) ...[
                                            if (i != 0) const SizedBox(height: 10),
                                            steps[i],
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.pushNamed(context, '/login'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: BorderSide(
                                              color: Colors.white.withOpacity(0.65),
                                              width: 1.1,
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          child: const Text('Sign In'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pushNamed(context, '/register'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFD72638),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          child: const Text('Get Started'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSocialLinksRow({required bool isMobile}) {
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFB0B6BB),
      ],
    );

    const double scale = 0.75 * 1.25;
    final double buttonSize = (isMobile ? 40 : 44) * scale;
    final double iconSize = (isMobile ? 18 : 20) * scale;

    return Wrap(
      spacing: 12 * 1.25,
      runSpacing: 10 * 1.25,
      alignment: WrapAlignment.center,
      children: [
        _SocialCircleButton(
          size: buttonSize,
          iconSize: iconSize,
          gradient: gradient,
          icon: FontAwesomeIcons.linkedinIn,
          tooltip: 'LinkedIn',
          onTap: () => _openExternalUrl(
            'https://www.linkedin.com/company/4999221/admin/',
          ),
        ),
        _SocialCircleButton(
          size: buttonSize,
          iconSize: iconSize,
          gradient: gradient,
          icon: FontAwesomeIcons.xTwitter,
          tooltip: 'X',
          onTap: () => _openExternalUrl('https://x.com/khonology'),
        ),
        _SocialCircleButton(
          size: buttonSize,
          iconSize: iconSize,
          gradient: gradient,
          icon: FontAwesomeIcons.instagram,
          tooltip: 'Instagram',
          onTap: () => _openExternalUrl('https://www.instagram.com/khonology/'),
        ),
        _SocialCircleButton(
          size: buttonSize,
          iconSize: iconSize,
          gradient: gradient,
          icon: FontAwesomeIcons.facebookF,
          tooltip: 'Facebook',
          onTap: () => _openExternalUrl('https://www.facebook.com/Khonology'),
        ),
        _SocialCircleButton(
          size: buttonSize,
          iconSize: iconSize,
          gradient: gradient,
          icon: FontAwesomeIcons.youtube,
          tooltip: 'YouTube',
          onTap: () => _openExternalUrl(
            'https://www.youtube.com/channel/UC3RtwRe_VBC1mi9UTVbpRHQ',
          ),
        ),
        _SocialCircleButton(
          size: buttonSize,
          iconSize: iconSize,
          gradient: gradient,
          icon: FontAwesomeIcons.globe,
          tooltip: 'Website',
          onTap: () => _openExternalUrl('https://www.khonology.com/'),
        ),
      ],
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
            final darkness = 0.4 - (math.sin(_parallaxController.value * 2 * math.pi) * 0.2);
            return Container(
              color: Colors.black.withOpacity(darkness.clamp(0.0, 1.0)),
            );
          },
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
              left: 120 + (math.sin(_parallaxController.value * 2 * math.pi) * 40),
              top: 180 + (math.cos(_parallaxController.value * 2 * math.pi) * 30),
              child: Transform.rotate(
                angle: _parallaxController.value * 2 * math.pi,
                child: CustomPaint(
                  painter: TrianglePainter(color: Colors.white.withOpacity(0.04)),
                  size: const Size(70, 70),
                ),
              ),
            ),

            // Triangle 2 - Top Right
            Positioned(
              right: 140 + (math.sin(_parallaxController.value * 2 * math.pi + 1.5) * 50),
              top: 220 + (math.cos(_parallaxController.value * 2 * math.pi + 1.5) * 35),
              child: Transform.rotate(
                angle: -_parallaxController.value * 2 * math.pi * 0.8,
                child: CustomPaint(
                  painter: TrianglePainter(color: Colors.white.withOpacity(0.05)),
                  size: const Size(90, 90),
                ),
              ),
            ),

            // Triangle 3 - Bottom Left
            Positioned(
              left: 200 + (math.sin(_parallaxController.value * 2 * math.pi + 3) * 35),
              bottom: 150 + (math.cos(_parallaxController.value * 2 * math.pi + 3) * 25),
              child: Transform.rotate(
                angle: _parallaxController.value * 2 * math.pi * 0.6,
                child: CustomPaint(
                  painter: TrianglePainter(color: Colors.white.withOpacity(0.03)),
                  size: const Size(60, 60),
                ),
              ),
            ),

            // Triangle 4 - Center Right
            Positioned(
              right: 180 + (math.sin(_parallaxController.value * 2 * math.pi + 4) * 45),
              top: 400 + (math.cos(_parallaxController.value * 2 * math.pi + 4) * 40),
              child: Transform.rotate(
                angle: -_parallaxController.value * 2 * math.pi * 0.7,
                child: CustomPaint(
                  painter: TrianglePainter(color: Colors.white.withOpacity(0.04)),
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
          crossAxisAlignment:
              isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
      textAlign: isMobile ? TextAlign.start : TextAlign.center,
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
      child: Align(
        alignment: isMobile ? Alignment.centerLeft : Alignment.center,
        child: Text(
          'Smart Proposal & SOW Builder for Digital Teams',
          textAlign: isMobile ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.95),
            fontSize: isMobile ? 16 : 24,
            fontWeight: FontWeight.w300,
            height: 1.4,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildCTAButtons(bool isMobile) {
    final Alignment alignment = isMobile ? Alignment.centerLeft : Alignment.center;
    return FadeTransition(
      opacity: _ctaController,
      child: Align(
        alignment: alignment,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: _ctaController, curve: Curves.easeOut),
          ),
          child: AnimatedBuilder(
            animation: _parallaxController,
            builder: (context, child) {
              final glowIntensity = 0.6 + (math.sin(_parallaxController.value * 2 * math.pi) * 0.3);
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE9293A),
                      Color(0xFF780A01),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE9293A).withOpacity(glowIntensity),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 32 : 56,
                      vertical: isMobile ? 16 : 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Get Started',
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
        ),
      ),
    );
  }
}

class CinematicLearnMoreCurtainPage extends StatelessWidget {
  const CinematicLearnMoreCurtainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              height: 1.35,
              color: Colors.white,
            ) ??
        const TextStyle(
          fontSize: 16,
          height: 1.35,
          color: Colors.white,
        );

    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.88,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B0B0B).withOpacity(0.96),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.75),
                    blurRadius: 36,
                    spreadRadius: 6,
                    offset: const Offset(-16, 0),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 22,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, color: Colors.white70),
                              tooltip: 'Close',
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Proposal & SOW Builder',
                                style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ) ??
                                    const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Khonology is the parent company. Khonobuzz is the product: a Proposal & SOW Builder designed for digital teams that need speed, consistency, and governance.',
                          style: textStyle.copyWith(color: Colors.white.withOpacity(0.86)),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'What you get',
                                  style: textStyle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _TourStep(
                                  number: 1,
                                  title: 'Structured proposals & SOWs',
                                  body: 'Start from templates or build from scratch to produce clean, client-ready documents.',
                                  textStyle: textStyle,
                                ),
                                const SizedBox(height: 10),
                                _TourStep(
                                  number: 2,
                                  title: 'Collaboration built-in',
                                  body: 'Work with teams, comments, workspaces, and notifications to keep everyone aligned.',
                                  textStyle: textStyle,
                                ),
                                const SizedBox(height: 10),
                                _TourStep(
                                  number: 3,
                                  title: 'Governance and quality checks',
                                  body: 'Run governance analysis before anything goes out the door.',
                                  textStyle: textStyle,
                                ),
                                const SizedBox(height: 10),
                                _TourStep(
                                  number: 4,
                                  title: 'AI Risk Gate',
                                  body: 'Automated risk assessment and recommendations to reduce compliance and delivery surprises.',
                                  textStyle: textStyle,
                                ),
                                const SizedBox(height: 10),
                                _TourStep(
                                  number: 5,
                                  title: 'Share with clients',
                                  body: 'Send via secure links and move faster through review, sign-off, and delivery.',
                                  textStyle: textStyle,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Typical workflow',
                                  style: textStyle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Compose → Govern → AI Risk Gate → Preview → Internal Sign-off',
                                  style: textStyle.copyWith(
                                    color: Colors.white.withOpacity(0.86),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Built for',
                                  style: textStyle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Creators, managers, and approvers who need a repeatable process for generating proposals and controlling risk before sending to clients.',
                                  style: textStyle.copyWith(
                                    color: Colors.white.withOpacity(0.86),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.pushNamed(context, '/login');
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.65),
                                    width: 1.1,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                child: const Text('Sign In'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.pushNamed(context, '/register');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD72638),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: const Text('Get Started'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TourStep extends StatelessWidget {
  const _TourStep({
    required this.number,
    required this.title,
    required this.body,
    required this.textStyle,
  });

  final int number;
  final String title;
  final String body;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Text(
            number.toString(),
            style: textStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textStyle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: textStyle.copyWith(
                  color: Colors.white.withOpacity(0.84),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialCircleButton extends StatelessWidget {
  const _SocialCircleButton({
    required this.size,
    required this.iconSize,
    required this.gradient,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final double size;
  final double iconSize;
  final LinearGradient gradient;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: FaIcon(
                  icon,
                  size: iconSize,
                  color: Colors.black,
                ),
              ),
            ),
          ),
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

