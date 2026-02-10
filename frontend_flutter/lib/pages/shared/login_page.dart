import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/role_service.dart';
import '../../api.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;

  late final AnimationController _frameController;
  late final AnimationController _parallaxController;
  late final AnimationController _fadeInController;

  final List<String> _backgroundImages = [
    'assets/images/Khonology Landing Page Animation Frame 1.jpg',
  ];

  int _currentFrameIndex = 0;

  @override
  void initState() {
    super.initState();

    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _parallaxController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _precacheFrames();
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _frameController.dispose();
    _parallaxController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Step 1: Sign in with Firebase
      print('🔥 Signing in with Firebase...');
      final firebaseCredential =
          await FirebaseService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (firebaseCredential == null || firebaseCredential.user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Firebase authentication failed. Please check your credentials.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Step 2: Get Firebase ID token
      print('🔥 Getting Firebase ID token...');
      final firebaseIdToken = await firebaseCredential.user!.getIdToken();

      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get Firebase ID token.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print(
          '✅ Firebase ID token obtained: ${firebaseIdToken.substring(0, 20)}...');

      // Step 3: Send Firebase ID token to backend to create/update user in database
      print('📡 Sending Firebase token to backend...');
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/api/firebase'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_token': firebaseIdToken}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = json.decode(response.body);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error['detail'] ?? 'Backend authentication failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final result = json.decode(response.body);
      final userProfile = result['user'] as Map<String, dynamic>?;
      final String authToken = firebaseIdToken;

      if (mounted) {
        setState(() => _isLoading = false);

        if (userProfile != null) {
          final appState = context.read<AppState>();

          // Use Firebase ID token (not legacy token)
          appState.authToken = authToken;
          appState.currentUser = userProfile;

          // IMPORTANT: Store Firebase ID token in AuthService
          AuthService.setUserData(userProfile, authToken);

          // Initialize role service with user's role
          final roleService = context.read<RoleService>();
          await roleService.initializeRoleFromUser(userProfile);

          await appState.init();

          // Redirect based on user role
          // Only two roles: admin and manager
          final rawRole = userProfile['role']?.toString() ?? '';
          final userRole = rawRole.toLowerCase().trim();

          // Use RoleService mapping as one view of the role
          final currentRole = roleService.currentRole;

          print('🔍 Login: Raw role from backend: "$rawRole"');
          print('🔍 Login: Normalized role: "$userRole"');
          print('🔍 Login: Frontend mapped role: $currentRole');
          print('🔍 Login: Full userProfile: $userProfile');

          String dashboardRoute;

          final isAdmin = userRole == 'admin' || userRole == 'ceo';
          final isFinance = userRole == 'finance' ||
              userRole == 'finance manager' ||
              userRole == 'financial manager' ||
              userRole == 'finance_manager' ||
              userRole == 'financial_manager';
          final isManager = userRole == 'manager' ||
              userRole == 'creator' ||
              userRole == 'user';

          if (isAdmin) {
            dashboardRoute = '/approver_dashboard';
            print(
                '✅ Routing to Admin/Approver Dashboard (from normalized role)');
          } else if (isFinance) {
            dashboardRoute = '/finance_dashboard';
            print('✅ Routing to Finance Dashboard (from normalized role)');
          } else if (isManager) {
            dashboardRoute = '/creator_dashboard';
            print('✅ Routing to Creator Dashboard (Manager normalized role)');
          } else {
            // Fallback: treat unknown roles as manager
            dashboardRoute = '/creator_dashboard';
            print(
                '⚠️ Unknown normalized role "$userRole", defaulting to Creator Dashboard');
          }

          print(
              '🔀 Redirecting user with normalized role "$userRole" to $dashboardRoute');

          Navigator.pushNamedAndRemoveUntil(
            context,
            dashboardRoute,
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get user profile from backend.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('❌ Login error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background image with dark overlay
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.4),
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
                        // Login form content that scrolls
                        _buildLoginCard(isMobile),
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
        // Base background image (same as landing page)
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
              color: Colors.black.withValues(alpha: darkness.clamp(0.0, 1.0)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isMobile) {
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 500),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE9293A).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE9293A).withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome message
            Center(
              child: const Text(
                'WELCOME BACK',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Catchy quote
            Center(
              child: const Text(
                'Sign in to manage your proposals and collaborate with your team',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Email
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
              onSubmitted: () {
                // Focus on password field when email is submitted
                FocusScope.of(context).nextFocus();
              },
            ),
            const SizedBox(height: 12),

            // Password
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: !_passwordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password required';
                return null;
              },
              onSubmitted: () {
                // Trigger login when Enter is pressed in password field
                if (!_isLoading) {
                  _login();
                }
              },
            ),
            const SizedBox(height: 24),

            // Login Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
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
                    color: const Color(0xFFE9293A).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'LOGIN',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Social Login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton('assets/images/Google_Icon.png'),
                const SizedBox(width: 16),
                _buildSocialButton('assets/images/mslogo.png'),
                const SizedBox(width: 16),
                _buildSocialButton('assets/images/github_icon_2.png'),
              ],
            ),
            const SizedBox(height: 24),

            // Back button navigation
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/BackButton-Red.png',
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.arrow_back,
                        color: Color(0xFFE9293A),
                        size: 24,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Register / Forgot Password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text(
                    'REGISTER',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Forgot password
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Forgot password feature coming soon'),
                      ),
                    );
                  },
                  child: const Text(
                    'FORGOT PASSWORD',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFFE9293A),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    VoidCallback? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white70,
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Color(0xFFE9293A), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildSocialButton(String imagePath) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: IconButton(
        icon: Image.asset(
          imagePath,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.error,
              color: Colors.black54,
              size: 24,
            );
          },
        ),
        onPressed: () {
          // TODO: Social login
        },
      ),
    );
  }
}

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
