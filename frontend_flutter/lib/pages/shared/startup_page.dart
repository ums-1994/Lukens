import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'animated_landing_page.dart';

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the cinematic sequence with all 9 frames
    // return const CinematicSequencePage();

    // Alternative: Use V1 (previous version)
    return const AnimatedLandingPage();

    // Old simple startup page (commented out, can be restored if needed)
    /*
    final theme = Theme.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final content = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'ProposeIt',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Create and manage proposals effortlessly.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 360,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 360,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Sign In'),
                ),
              ),
            ],
          );

          final hero = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/Image (2).png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(Icons.image_outlined, size: 80),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );

          final partnerLogo = const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: GlowingLogo(
                assetPath:
                    'assets/images/f65f74_85875a9997aa4107b0ce9b656b80d19b~mv2 1.png',
                height: 214,
              ),
            ),
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: hero),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        content,
                        const SizedBox(height: 72),
                        partnerLogo,
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                hero,
                const SizedBox(height: 48),
                content,
                const SizedBox(height: 72),
                partnerLogo,
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const Footer(),
    );
    */
  }
}

class GlowingLogo extends StatefulWidget {
  final String assetPath;
  final double height;
  const GlowingLogo({super.key, required this.assetPath, required this.height});

  @override
  State<GlowingLogo> createState() => _GlowingLogoState();
}

class _GlowingLogoState extends State<GlowingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 0.9)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);
    _scale = Tween<double>(begin: 0.98, end: 1.02)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Soft inner glow layer (subtle)
            Opacity(
              opacity: _pulse.value,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFE9293A),
                    BlendMode.srcATop,
                  ),
                  child: Image.asset(
                    widget.assetPath,
                    height: widget.height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Ambient outer glow (very subtle)
            Opacity(
              opacity: (_pulse.value * 0.6).clamp(0.0, 1.0),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF780A01),
                    BlendMode.srcATop,
                  ),
                  child: Image.asset(
                    widget.assetPath,
                    height: widget.height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: _scale.value,
              child: Image.asset(
                widget.assetPath,
                height: widget.height,
                fit: BoxFit.contain,
              ),
            ),
          ],
        );
      },
    );
  }
}
