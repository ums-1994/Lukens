import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/premium_theme.dart';
import 'dart:ui';
import '../../api.dart';

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
    super.dispose();
  }

  Future<void> _validateToken() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/onboard/${widget.token}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _invitedEmail = data['invited_email'];
          _expectedCompany = data['expected_company'];
          _expiresAt = data['expires_at'];
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/onboard/${widget.token}'),
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
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/khono_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.35),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _loading
                    ? _buildLoading()
                    : _errorMessage != null
                        ? _buildError()
                        : _submitted
                            ? _buildSuccess()
                            : _buildForm(),
              ),
            ),
          ),
        ],
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
                  color: PremiumTheme.error.withOpacity(0.2),
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
                  color: PremiumTheme.success.withOpacity(0.2),
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
                  color: PremiumTheme.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PremiumTheme.teal.withOpacity(0.3)),
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
            color: Colors.white.withOpacity(0.1),
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
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
