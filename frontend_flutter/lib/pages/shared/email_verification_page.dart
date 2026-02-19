import 'package:flutter/material.dart';
import '../../services/smtp_auth_service.dart';

class EmailVerificationPage extends StatefulWidget {
  final String? token;
  final String? email;

  const EmailVerificationPage({
    super.key,
    this.token,
    this.email,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isLoading = false;
  bool _isVerified = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _verifyEmail();
    }
  }

  Future<void> _verifyEmail() async {
    if (widget.token == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SmtpAuthService.verifyEmail(token: widget.token!);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVerified = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to login page after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushNamed(context, '/login');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (widget.email == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SmtpAuthService.resendVerificationEmail(email: widget.email!);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              _isVerified ? Icons.check_circle : Icons.email_outlined,
              size: 80,
              color: _isVerified ? Colors.green : Colors.blue,
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              _isVerified ? 'Email Verified!' : 'Verify Your Email',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              _isVerified
                  ? 'Your email has been successfully verified. You can now log in to your account.'
                  : 'We\'ve sent a verification link to your email address. Please check your inbox and click the link to verify your account.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Loading indicator
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null) ...[
              // Error message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Resend button
              if (widget.email != null)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _resendVerificationEmail,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Resend Verification Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ] else if (!_isVerified) ...[
              // Resend button
              if (widget.email != null)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _resendVerificationEmail,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Resend Verification Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 24),

            // Back to login button
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ),
    );
  }
}
