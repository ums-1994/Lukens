import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../api.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
 

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'Manager';
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  double _passwordStrength = 0.0;
  Map<String, bool> _criteria = {
    'minLength': false,
    'uppercase': false,
    'number': false,
    'special': false,
  };

  final List<String> _roles = ['Manager', 'Admin'];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _evaluatePassword(String value) {
    final hasMinLength = value.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
    final hasNumber = RegExp(r'[0-9]').hasMatch(value);
    final hasSpecial =
        RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/`~+=;]').hasMatch(value);

    final passed = [hasMinLength, hasUppercase, hasNumber, hasSpecial]
        .where((e) => e)
        .length;
    setState(() {
      _criteria = {
        'minLength': hasMinLength,
        'uppercase': hasUppercase,
        'number': hasNumber,
        'special': hasSpecial,
      };
      _passwordStrength = passed / 4.0;
    });
  }

  Color _getPasswordStrengthBarColor() {
    if (_passwordStrength >= 0.75)
      return const Color(0xFF16A34A); // Green - Strong
    if (_passwordStrength >= 0.5)
      return const Color(0xFFF59E0B); // Orange - Medium
    if (_passwordStrength > 0) return const Color(0xFFD72638); // Red - Weak
    return const Color(0xFF1A1A1A); // Dark - No password
  }

  bool _validateInputs() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    String? error;
    if (firstName.isEmpty) error = 'First name required';
    else if (lastName.isEmpty) error = 'Last name required';
    else if (email.isEmpty) error = 'Email required';
    else if (!email.contains('@')) error = 'Invalid email';
    else if (password.isEmpty) error = 'Password required';
    else if (password.length < 8) error = 'Min 8 characters';
    else if (!RegExp(r'[A-Z]').hasMatch(password)) error = 'Need uppercase';
    else if (!RegExp(r'[0-9]').hasMatch(password)) error = 'Need number';
    else if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/`~+=;]')
        .hasMatch(password)) error = 'Need special char';
    else if (confirm.isEmpty) error = 'Confirm password';
    else if (confirm != password) error = "Passwords don't match";

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return false;
    }
    return true;
  }

  Future<void> _register() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final role =
          _selectedRole.toLowerCase(); // Convert to lowercase for backend

      // Step 1: Create user in Firebase
      print('🔥 Creating user in Firebase...');
      UserCredential? firebaseCredential;
      String? firebaseError;

      try {
        firebaseCredential = await FirebaseService.signUpWithEmailAndPassword(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          role: role,
        );
      } catch (e) {
        print('❌ Firebase registration error: $e');
        firebaseError = e.toString();
      }

      if (firebaseCredential == null || firebaseCredential.user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          String errorMessage =
              'Firebase registration failed. Please try again.';

          // Provide more specific error messages
          if (firebaseError != null) {
            if (firebaseError.contains('email-already-in-use')) {
              errorMessage =
                  'An account with this email already exists. Please login instead.';
            } else if (firebaseError.contains('weak-password')) {
              errorMessage =
                  'Password is too weak. Please choose a stronger password.';
            } else if (firebaseError.contains('invalid-email')) {
              errorMessage = 'Invalid email address. Please check your email.';
            } else if (firebaseError.contains('network')) {
              errorMessage =
                  'Network error. Please check your internet connection.';
            } else {
              errorMessage =
                  'Registration failed: ${firebaseError.length > 100 ? firebaseError.substring(0, 100) + "..." : firebaseError}';
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
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

      print('📡 Syncing user to backend database...');
      Map<String, dynamic>? userProfile;
      String authToken = firebaseIdToken;

      try {
        final response = await http.post(
          Uri.parse('${AuthService.baseUrl}/firebase'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'id_token': firebaseIdToken,
            'role': role,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final result = json.decode(response.body);
          userProfile = result['user'] as Map<String, dynamic>?;
          authToken = (result['token'] as String?) ?? firebaseIdToken;
        } else {
          print(
              '⚠️ Backend registration failed with status ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        print('⚠️ Backend sync failed, continuing with Firebase only: $e');
      }

      if (mounted) {
        setState(() => _isLoading = false);

        Map<String, dynamic> effectiveProfile;
        if (userProfile != null) {
          effectiveProfile = userProfile;
        } else {
          effectiveProfile = {
            'email': email,
            'full_name': '$firstName $lastName'.trim(),
            'role': role == 'admin' ? 'admin' : 'manager',
          };
        }

        final appState = context.read<AppState>();
        appState.authToken = authToken;
        appState.currentUser = effectiveProfile;

        AuthService.setUserData(effectiveProfile, authToken);

        final roleService = context.read<RoleService>();
        await roleService.initializeRoleFromUser(effectiveProfile);

        await appState.init();

        final userRole =
            (effectiveProfile['role']?.toString() ?? '').toLowerCase().trim();
        String dashboardRoute;

        print('🔍 User role from backend: "$userRole"');
        print('🔍 Requested role: "$role"');

        if (userRole == 'admin' || userRole == 'ceo' || role == 'admin') {
          dashboardRoute = '/approver_dashboard';
          print('✅ Routing to Approval Dashboard');
        } else {
          dashboardRoute = '/creator_dashboard';
          print('✅ Routing to Creator Dashboard');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          dashboardRoute,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('❌ Registration error: $e');
        String errorMessage = 'Registration failed. Please try again.';

        // Parse Firebase errors
        if (e.toString().contains('email-already-in-use')) {
          errorMessage =
              'An account with this email already exists. Please login instead.';
        } else if (e.toString().contains('weak-password')) {
          errorMessage =
              'Password is too weak. Please choose a stronger password.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Invalid email address.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/khono_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: Colors.black);
            },
          ),

          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),

          // No floating shapes

          // Floating registration card
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 40,
                vertical: 40,
              ),
              child: _buildRegistrationCard(isMobile),
            ),
          ),
        ],
      ),
    );
  }

  

  Widget _buildRegistrationCard(bool isMobile) {
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
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Removed top animated asset
            const SizedBox(height: 0),

            // First & Last Name Row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Email
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Role Dropdown
            _buildRoleDropdown(),
            const SizedBox(height: 12),

            // Password
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: !_passwordVisible,
              onChanged: _evaluatePassword,
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
                if (v.length < 8) return 'Min 8 characters';
                if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Need uppercase';
                if (!RegExp(r'[0-9]').hasMatch(v)) return 'Need number';
                if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/`~+=;]')
                    .hasMatch(v)) {
                  return 'Need special char';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Confirm Password
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              obscureText: !_confirmPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _confirmPasswordVisible = !_confirmPasswordVisible),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirm password';
                if (v != _passwordController.text)
                  return 'Passwords don\'t match';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Password Strength Loader
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Password Strength',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _passwordStrength,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF1A1A1A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getPasswordStrengthBarColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Register Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
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
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
                        'Register',
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
                _buildSocialButton(Icons.g_mobiledata),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.window),
                const SizedBox(width: 16),
                _buildSocialButton(Icons.business),
              ],
            ),
            const SizedBox(height: 24),

            // Login / Forgot Password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text(
                    'Login',
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
                  },
                  child: const Text(
                    'Forgot Password',
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
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
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE9293A), width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedRole,
        dropdownColor: const Color(0xFF2A2A2A),
        style: const TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          labelText: 'Role',
          labelStyle: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        icon: const Icon(Icons.keyboard_arrow_down,
            color: Colors.white70, size: 20),
        items: _roles.map((role) {
          return DropdownMenuItem(
            value: role,
            child: Text(role),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedRole = value);
          }
        },
      ),
    );
  }

  Widget _buildSocialButton(IconData icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: IconButton(
        icon: Icon(icon, size: 28, color: Colors.black87),
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
