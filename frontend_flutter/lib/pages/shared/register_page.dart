// ignore_for_file: deprecated_member_use, unused_field
import 'package:flutter/material.dart';
import '../../services/smtp_auth_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'Financial Manager';
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

  final List<String> _roles = ['CEO', 'Financial Manager', 'Client'];

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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await SmtpAuthService.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        role: _selectedRole,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result != null) {
          // Skip email verification - go directly to login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please login.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        fit: StackFit.expand,
        children: [
          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),

          // Floating registration card
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 40 : 100, // Increased padding
                vertical: 40,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: isMobile
                          ? double.infinity
                          : 550), // Adjusted max width
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo with subtle breathing fade animation
                      Center(
                        child: Image.asset(
                          'assets/images/2026.png',
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text(
                              '✕ Khonology',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

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
                            _passwordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _passwordVisible = !_passwordVisible),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Password required';
                          if (v.length < 8) return 'Min 8 characters';
                          if (!RegExp(r'[A-Z]').hasMatch(v))
                            return 'Need uppercase';
                          if (!RegExp(r'[0-9]').hasMatch(v))
                            return 'Need number';
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
                          onPressed: () => setState(() =>
                              _confirmPasswordVisible =
                                  !_confirmPasswordVisible),
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
                      SizedBox(
                        width: double.infinity,
                        height: 56, // Set height to 56
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                                0xFFC10D00), // Set background color to #C10D00
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  50), // Set border radius to 50
                            ),
                            elevation: 0, // Remove glowing effect
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
                                  'REGISTER', // All caps text
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
                            onPressed: () =>
                                Navigator.pushNamed(context, '/login'),
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
                              // Forgot password feature coming soon
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
                ),
              ),
            ),
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
          // Social login coming soon
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
