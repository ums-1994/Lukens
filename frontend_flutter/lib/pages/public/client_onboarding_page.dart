import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/premium_theme.dart';
import 'dart:ui';

class ClientOnboardingPage extends StatefulWidget {
  final String token;

  const ClientOnboardingPage({super.key, required this.token});

  @override
  State<ClientOnboardingPage> createState() => _ClientOnboardingPageState();
}

class _ClientOnboardingPageState extends State<ClientOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _errorMessage;
  
  // Form fields
  final _companyNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _industryController = TextEditingController();
  final _companySizeController = TextEditingController();
  final _locationController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _projectNeedsController = TextEditingController();
  final _budgetRangeController = TextEditingController();
  final _timelineController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  String? _invitedEmail;
  String? _expectedCompany;
  String? _expiresAt;
  bool _emailVerified = false;
  bool _codeSent = false;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  final _verificationCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _validateToken();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _industryController.dispose();
    _companySizeController.dispose();
    _locationController.dispose();
    _businessTypeController.dispose();
    _projectNeedsController.dispose();
    _budgetRangeController.dispose();
    _timelineController.dispose();
    _additionalInfoController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _validateToken() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/onboard/${widget.token}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _invitedEmail = data['invited_email'];
          _expectedCompany = data['expected_company'];
          _expiresAt = data['expires_at'];
          _emailVerified = data['email_verified'] ?? false;
          _emailController.text = _invitedEmail ?? '';
          _companyNameController.text = _expectedCompany ?? '';
          _loading = false;
        });
      } else {
        final error = json.decode(response.body);
        setState(() {
          _errorMessage = error['error'] ?? 'Invalid invitation link';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to validate invitation. Please check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _sendVerificationCode() async {
    if (_invitedEmail == null) return;
    
    setState(() => _sendingCode = true);
    
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/onboard/${widget.token}/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _invitedEmail}),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _codeSent = true;
          _sendingCode = false;
        });
      } else {
        final error = json.decode(response.body);
        setState(() {
          _errorMessage = error['error'] ?? 'Failed to send verification code';
          _sendingCode = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send verification code. Please try again.';
        _sendingCode = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationCodeController.text.trim().length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit code';
      });
      return;
    }
    
    if (_invitedEmail == null) return;
    
    setState(() {
      _verifyingCode = true;
      _errorMessage = null;
    });
    
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/onboard/${widget.token}/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': _verificationCodeController.text.trim(),
          'email': _invitedEmail,
        }),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _emailVerified = true;
          _verifyingCode = false;
          _errorMessage = null;
        });
      } else {
        final error = json.decode(response.body);
        setState(() {
          _errorMessage = error['error'] ?? 'Invalid verification code';
          _verifyingCode = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to verify code. Please try again.';
        _verifyingCode = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/onboard/${widget.token}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'company_name': _companyNameController.text.trim(),
          'contact_person': _contactPersonController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'industry': _industryController.text.trim(),
          'company_size': _companySizeController.text.trim(),
          'location': _locationController.text.trim(),
          'business_type': _businessTypeController.text.trim(),
          'project_needs': _projectNeedsController.text.trim(),
          'budget_range': _budgetRangeController.text.trim(),
          'timeline': _timelineController.text.trim(),
          'additional_info': _additionalInfoController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        setState(() {
          _submitted = true;
          _submitting = false;
        });
      } else {
        final error = json.decode(response.body);
        setState(() {
          _errorMessage = error['error'] ?? 'Failed to submit form';
          _submitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit form. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumTheme.darkBg1,
              PremiumTheme.darkBg2,
              PremiumTheme.darkBg3,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? _buildLoading()
                  : _errorMessage != null && !_codeSent && !_emailVerified
                      ? _buildError()
                      : _submitted
                          ? _buildSuccess()
                          : !_emailVerified
                              ? _buildVerification()
                              : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: PremiumTheme.glassCard(),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: PremiumTheme.teal),
              SizedBox(height: 24),
              Text(
                'Validating invitation...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(48),
          decoration: PremiumTheme.glassCard(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumTheme.error.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, size: 64, color: PremiumTheme.error),
              ),
              const SizedBox(height: 24),
              const Text(
                'Invalid Invitation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'This invitation link is invalid or has expired.',
                style: const TextStyle(color: PremiumTheme.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerification() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(48),
          decoration: PremiumTheme.glassCard(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumTheme.teal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.email_outlined, size: 64, color: PremiumTheme.teal),
              ),
              const SizedBox(height: 24),
              const Text(
                'Email Verification Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'For your security, please verify your email address before continuing.',
                style: const TextStyle(color: PremiumTheme.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (!_codeSent) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.email, color: PremiumTheme.teal, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _invitedEmail ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sendingCode ? null : _sendVerificationCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _sendingCode
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Send Verification Code',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ] else ...[
                const Text(
                  'We\'ve sent a 6-digit verification code to your email.',
                  style: TextStyle(color: PremiumTheme.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _verificationCodeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: PremiumTheme.textTertiary,
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PremiumTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PremiumTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: PremiumTheme.error, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: PremiumTheme.error, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _verifyingCode ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _verifyingCode
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Verify Code',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _sendingCode ? null : _sendVerificationCode,
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(color: PremiumTheme.teal, fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(48),
          decoration: PremiumTheme.glassCard(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumTheme.success.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, size: 64, color: PremiumTheme.success),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome Aboard!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thank you for completing your onboarding. Our team will be in touch with you shortly.',
                style: TextStyle(color: PremiumTheme.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PremiumTheme.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PremiumTheme.teal.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: PremiumTheme.teal, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will receive a confirmation email shortly.',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(48),
          decoration: PremiumTheme.glassCard(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: PremiumTheme.tealGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.business, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Client Onboarding',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please complete the form below to get started',
                            style: TextStyle(
                              color: PremiumTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Company Information Section
                _buildSectionHeader('Company Information', Icons.business_center),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Company Name', _companyNameController, required: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Industry', _industryController)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Company Size', _companySizeController, hint: 'e.g., 1-10, 11-50')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Business Type', _businessTypeController, hint: 'e.g., B2B, B2C')),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Location', _locationController, hint: 'City, Country'),

                const SizedBox(height: 40),

                // Contact Information Section
                _buildSectionHeader('Contact Information', Icons.person),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Contact Person', _contactPersonController, required: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Email', _emailController, required: true, keyboardType: TextInputType.emailAddress)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Phone', _phoneController, required: true, keyboardType: TextInputType.phone),

                const SizedBox(height: 40),

                // Project Details Section
                _buildSectionHeader('Project Details', Icons.work_outline),
                const SizedBox(height: 20),
                _buildTextField('Project Needs', _projectNeedsController, maxLines: 3, hint: 'What are you looking for?'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Budget Range', _budgetRangeController, hint: 'e.g., \$10k-\$50k')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Timeline', _timelineController, hint: 'e.g., 3-6 months')),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Additional Information', _additionalInfoController, maxLines: 4, hint: 'Any other details you\'d like to share...'),

                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Complete Onboarding',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Footer
                const Center(
                  child: Text(
                    '© 2024 Khonology. All rights reserved.',
                    style: TextStyle(color: PremiumTheme.textTertiary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: PremiumTheme.teal, size: 20),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool required = false,
    int maxLines = 1,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: PremiumTheme.error, fontSize: 14),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: PremiumTheme.textTertiary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    if (label == 'Email' && !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  }
                : null,
          ),
        ),
      ],
    );
  }
}






