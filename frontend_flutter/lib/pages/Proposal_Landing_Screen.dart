import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../app_state.dart';
// import '../../api.dart'; // Commented out to avoid AppState conflict

// The main entry point for the Flutter application.
// void main() {
//   runApp(const MyApp());
// }

// A StatelessWidget that sets up the MaterialApp.
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Personal Development Hub',
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         primarySwatch: Colors.blue,
//         fontFamily: 'Inter',
//       ),
//       home: const PersonalDevelopmentHubScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// The main screen widget for the Personal Development Hub.
class PersonalDevelopmentHubScreen extends StatefulWidget {
  const PersonalDevelopmentHubScreen({super.key});

  @override
  State<PersonalDevelopmentHubScreen> createState() =>
      _PersonalDevelopmentHubScreenState();
}

class _PersonalDevelopmentHubScreenState
    extends State<PersonalDevelopmentHubScreen> {
  late List<String> inspirationalLines;
  int _currentLineIndex = 0;
  late Timer _timer;
  bool _isProcessingToken = false;

  @override
  void initState() {
    super.initState();

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

    // Check for JWT token in URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleJwtTokenFromUrl();
    });
  }

  Future<void> _handleJwtTokenFromUrl() async {
    if (!mounted) return;

    final currentUrl = web.window.location.href;
    final uri = Uri.parse(currentUrl);

    // Accept multiple common keys from query
    String? externalToken =
        uri.queryParameters['token'] ??
        uri.queryParameters['jwt'] ??
        uri.queryParameters['access_token'] ??
        uri.queryParameters['id_token'];

    // If not in query, check hash fragment for common keys
    if (externalToken == null || externalToken.isEmpty) {
      final hashMatch = RegExp(r'(?:token|jwt|access_token|id_token)=([^&#]+)')
          .firstMatch(currentUrl);
      if (hashMatch != null) {
        externalToken = Uri.decodeComponent(hashMatch.group(1)!);
      }
    }

    if (externalToken == null || externalToken.isEmpty) {
      return;
    }

    // Remove token from the address bar before proceeding
    try {
      final sanitized = '${uri.scheme}://${uri.host}'
          '${uri.hasPort ? ':${uri.port}' : ''}'
          '${uri.path}';
      web.window.history.replaceState(null, '', sanitized);
    } catch (_) {}

    setState(() {
      _isProcessingToken = true;
    });

    try {
      final loginResult = await AuthService.loginWithJwt(externalToken);
      final userProfile = loginResult?['user'] as Map<String, dynamic>?;
      final token = loginResult?['token'] as String?;

      if (!mounted) return;

      if (userProfile == null || token == null) {
        // Wait minimum 5 seconds before hiding spinner
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        setState(() {
          _isProcessingToken = false;
        });
        return;
      }

      final appState = context.read<AppState>();
      appState.authToken = token;
      appState.currentUser = userProfile;

      final roleService = context.read<RoleService>();
      await roleService.initializeRoleFromUser(userProfile);

      await appState.init();

      final rawRole = userProfile['role']?.toString() ?? '';
      final userRole = rawRole.toLowerCase().trim();
      String dashboardRoute;

      final isAdmin = userRole == 'admin' || userRole == 'ceo';
      final isFinance = userRole == 'proposal & sow builder - finance' ||
          userRole == 'finance' ||
          userRole == 'financial manager';
      final isManager = userRole == 'manager' ||
          userRole == 'creator' ||
          userRole == 'user';

      if (isAdmin) {
        dashboardRoute = '/approver_dashboard';
      } else if (isFinance) {
        dashboardRoute = '/finance_dashboard';
      } else if (isManager) {
        dashboardRoute = '/creator_dashboard';
      } else {
        dashboardRoute = '/creator_dashboard';
      }

      if (!mounted) return;

      // Wait minimum 5 seconds before navigating
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        dashboardRoute,
        (route) => false,
      );
    } catch (e) {
      print('❌ JWT login from landing page failed: $e');
      // Wait minimum 5 seconds before hiding spinner on error
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _isProcessingToken = false;
        });
      }
    }
  }


  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/khono_bg.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.4),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),
          
          // Content overlay
          Positioned.fill(
            child: Stack(
              children: [
                // Center content (tagline and inspirational message)
                Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo - Centered (using khono_backup.png)
                        Center(
                          child: Image.asset(
                            'assets/images/khono_backup.png',
                            height: 160,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Tagline - Centered
                        const Center(
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
                        const SizedBox(height: 12),
                        // Inspirational message - Centered
                        Center(
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
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
                // Logo - Bottom centered
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      'assets/images/f65f74_85875a9997aa4107b0ce9b656b80d19b~mv2 1.png',
                      height: 120,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Red spinning loader overlay when processing JWT token
          if (_isProcessingToken)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE9293A)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Please wait we\'re signing you in...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
