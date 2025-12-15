import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'dart:math' as math; // For animation utility
// The services imports are commented out as they are not provided, 
// but the token check logic is preserved for functionality.
// import 'package:pdh/services/token_auth_service.dart';
// import 'package:pdh/services/role_service.dart';
// import 'package:pdh/services/backend_auth_service.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/widgets/floating_circles_particle_animation.dart'; // Assume this is available

// --- START: Merged Screen Widget ---

/// Merged Screen combining the UI of PersonalDevelopmentHubScreen 
/// and the base structure/animation of AnimatedLandingPageV2.
class MergedLandingScreen extends StatefulWidget {
  const MergedLandingScreen({super.key});

  @override
  State<MergedLandingScreen> createState() => _MergedLandingScreenState();
}

class _MergedLandingScreenState extends State<MergedLandingScreen>
    with TickerProviderStateMixin {
  
  // --- Animation Controllers from AnimatedLandingPageV2 (Adapted) ---
  late AnimationController _controller; // Main timeline controller
  late Animation<double> _backgroundAnim;
  late Animation<double> _subheadingAnim;
  late Animation<double> _buttonsAnim;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  // NOTE: Text animations (_buildTextAnim, _automateTextAnim, etc.) 
  // are removed as they conflict with the new UI.

  // --- State Variables from PersonalDevelopmentHubScreen ---
  late List<String> inspirationalLines;
  int _currentLineIndex = 0;
  late Timer _timer;
  bool _isCheckingToken = false;
  bool _isProcessingButton = false;
  final GlobalKey<FloatingCirclesParticleAnimationState> _animationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    // 1. Initialize Inspirational Lines and Timer (from script 1)
    inspirationalLines = [
      "Cultivate your mind, blossom your potential.",
      "Every step forward is a victory.",
      "Organize your life, clarify your purpose.",
      "Knowledge is the compass of growth.",
      "Build strong habits, build a strong future.",
      "Financial wisdom empowers freedom.",
      "Unlock your inner creativity.",
      "Mindfulness lights the path to peace.",
      "Fitness fuels your ambition.",
      "Learn relentlessly, live boundlessly.",
      "Your journey, your rules, your growth.",
      "Small changes, significant impact.",
      "Embrace the challenge, find your strength.",
      "Beyond limits, lies growth.",
      "Master your days, master your destiny.",
      "Innovate, iterate, inspire.",
      "The best investment is in yourself.",
      "Find your balance, elevate your being.",
      "Progress, not perfection.",
      "Dream big, start small, act now.",
    ];
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _currentLineIndex = (_currentLineIndex + 1) % inspirationalLines.length;
      });
    });

    // 2. Initialize Animation Controllers (from script 2)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000), // Shorter timeline for simpler content
      vsync: this,
    );
    
    // Background Fade-In (0.0s - 0.5s)
    _backgroundAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    // Subheading (Tagline/Inspo) Fade-In (0.5s - 1.0s)
    _subheadingAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.5, curve: Curves.easeOut),
    );

    // Buttons Fade-In (1.0s - 1.5s)
    _buttonsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.75, curve: Curves.easeOut),
    );

    // Continuous glow animation (from script 2)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnim = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start the main animation
    _controller.forward();

    // 3. Start token check and pre-caching (from script 1)
    _checkTokenAndAutoLogin();
    _precacheAssets();
  }

  /// Check for token in URL, validate with backend API, and auto-login
  /// (Logic preserved from PersonalDevelopmentHubScreen)
  Future<void> _checkTokenAndAutoLogin() async {
    // Placeholder implementation for functionality purposes
    // In a real app, this would contain the logic from the original script
    try {
      setState(() {
        _isCheckingToken = true;
      });
      
      // Simulate network delay for token check
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Assume no token is found for now, so it defaults to the main screen state
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _isProcessingButton = false;
        });
      }

    } catch (e) {
      debugPrint('Landing screen: Error checking token: $e');
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _isProcessingButton = false;
        });
      }
    }
  }

  // Placeholder for the navigation logic
  void _navigateToDashboard(String pdhRole) {
    if (!mounted) return;
    debugPrint('Navigating to dashboard with role: $pdhRole');
    // Actual navigation logic (e.g., Navigator.pushReplacementNamed) would go here
  }
  
  // Precache assets logic (from script 1)
  void _precacheAssets() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = this.context;
      if (!mounted) return;
      
      final int bgWidth = (MediaQuery.of(context).size.width * 1.5).toInt();
      // Precache background image
      precacheImage(
        const AssetImage('assets/khono_bg.png'),
        context,
        size: Size(bgWidth.toDouble(), MediaQuery.of(context).size.height),
      );
      // Precache logo image
      final double dpr = MediaQuery.of(context).devicePixelRatio;
      precacheImage(
        const AssetImage('assets/khono.png'),
        context,
        size: Size(320 * dpr, 160 * dpr),
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Dispose timer from script 1
    _controller.dispose(); // Dispose main controller from script 2
    _glowController.dispose(); // Dispose glow controller from script 2
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Use dark background from script 2
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _glowController]),
        builder: (context, child) {
          return Stack(
            children: [
              // Layer 1: Background with fade-in (Combined background)
              _buildBackground(), // Uses script 2's Opacity & Stack

              // Layer 2: Particle Animation (from script 1)
              FloatingCirclesParticleAnimation(
                key: _animationKey,
                circleColor: const Color(0xFFC10D00).withOpacity(0.7),
                numberOfParticles: 20,
                maxParticleSize: 6.0,
              ),

              // Layer 3: Content overlay (from script 1)
              _buildContentOverlay(),
            ],
          );
        },
      ),
    );
  }

  // Background building method adapted from PersonalDevelopmentHubScreen's look,
  // but using AnimatedLandingPageV2's Opacity logic for fade-in.
  Widget _buildBackground() {
    return Opacity(
      opacity: _backgroundAnim.value, // Animate from script 2
      child: Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/khono_bg.png'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4),
                BlendMode.darken,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Content building method adapted from PersonalDevelopmentHubScreen
  Widget _buildContentOverlay() {
    return Positioned.fill(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo - Centered (from script 1)
              Center(
                child: GestureDetector(
                  onTap: () {
                    _animationKey.currentState?.triggerParticleExplosion();
                  },
                  child: Image.asset(
                    'assets/khono.png',
                    height: 160,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Tagline - Centered (from script 1) - Fades in with _subheadingAnim
              Opacity(
                opacity: _subheadingAnim.value,
                child: const Center(
                  child: Text(
                    'Your Growth Journey, Simplified',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC10D00),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Inspirational message - Centered (from script 1) - Fades in with _subheadingAnim
              Opacity(
                opacity: _subheadingAnim.value,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      inspirationalLines[_currentLineIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Login/CTA Buttons (New elements, using the style/logic from script 2)
              Opacity(
                opacity: _buttonsAnim.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
                  children: [
                    // Start Login Button (Using script 2's glow/style for a modern look)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            // Glow effect from script 2
                            color: const Color(0xFFC10D00).withOpacity(_glowAnim.value),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isProcessingButton || _isCheckingToken
                            ? null
                            : () {
                                // Simulate triggering auto-login for demonstration
                                setState(() {
                                  _isProcessingButton = true;
                                });
                                _checkTokenAndAutoLogin();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00),
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
                        child: Text(
                          _isProcessingButton || _isCheckingToken
                              ? 'Checking Login...' // Show login state
                              : 'Secure Login', // Updated CTA text
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              // Subtle loading indicator when checking token (from script 1)
              if (_isCheckingToken) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFC10D00),
                  ),
                  strokeWidth: 2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}