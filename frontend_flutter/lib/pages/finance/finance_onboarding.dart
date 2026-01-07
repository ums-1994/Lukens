import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/client_service.dart';
import '../../theme/premium_theme.dart';

class FinanceOnboardingPage extends StatefulWidget {
  const FinanceOnboardingPage({super.key});

  @override
  State<FinanceOnboardingPage> createState() => _FinanceOnboardingPageState();
}

class _FinanceOnboardingPageState extends State<FinanceOnboardingPage> {
  // Manual onboarding form
  final _manualFormKey = GlobalKey<FormState>();
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

  bool _submittingManual = false;

  // Invitation form
  final _inviteEmailController = TextEditingController();
  final _inviteCompanyController = TextEditingController();
  final _inviteExpiryController = TextEditingController(text: '7');
  bool _sendingInvite = false;

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
    _inviteEmailController.dispose();
    _inviteCompanyController.dispose();
    _inviteExpiryController.dispose();
    super.dispose();
  }

  Future<void> _submitManualOnboarding() async {
    if (!_manualFormKey.currentState!.validate()) return;

    final token = AuthService.token;
    if (token == null) {
      _showSnackBar('Authentication error: Please log in again');
      return;
    }

    setState(() => _submittingManual = true);

    try {
      final client = await ClientService.createClient(
        token: token,
        companyName: _companyNameController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        industry: _industryController.text.trim(),
        companySize: _companySizeController.text.trim(),
        location: _locationController.text.trim(),
        businessType: _businessTypeController.text.trim(),
        projectNeeds: _projectNeedsController.text.trim(),
        budgetRange: _budgetRangeController.text.trim(),
        timeline: _timelineController.text.trim(),
        additionalInfo: _additionalInfoController.text.trim(),
      );

      if (client != null) {
        _showSnackBar('Client onboarded successfully', isSuccess: true);
      } else {
        _showSnackBar('Failed to onboard client. Please check details.');
      }
    } catch (e) {
      _showSnackBar('Error onboarding client: $e');
    } finally {
      if (mounted) {
        setState(() => _submittingManual = false);
      }
    }
  }

  Future<void> _sendOnboardingInvite() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid client email');
      return;
    }

    final token = AuthService.token;
    if (token == null) {
      _showSnackBar('Authentication error: Please log in again');
      return;
    }

    final expiryDays = int.tryParse(_inviteExpiryController.text.trim()) ?? 7;

    setState(() => _sendingInvite = true);

    try {
      final result = await ClientService.sendInvitation(
        token: token,
        email: email,
        companyName: _inviteCompanyController.text.trim().isEmpty
            ? null
            : _inviteCompanyController.text.trim(),
        expiryDays: expiryDays,
      );

      if (result != null) {
        _showSnackBar('Onboarding invitation sent', isSuccess: true);
      } else {
        _showSnackBar('Failed to send invitation. See console for details.');
      }
    } catch (e) {
      _showSnackBar('Error sending invitation: $e');
    } finally {
      if (mounted) {
        setState(() => _sendingInvite = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? PremiumTheme.success : PremiumTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final userName = user != null
        ? (user['full_name'] ?? user['email'] ?? 'Finance User')
        : 'Finance User';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Global BG.jpg',
              fit: BoxFit.cover,
            ),
          ),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(userName),
                  const SizedBox(height: 24),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 1100;
                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(child: _buildManualCard()),
                              const SizedBox(width: 24),
                              Expanded(child: _buildInviteCard()),
                            ],
                          );
                        }
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildManualCard(),
                              const SizedBox(height: 24),
                              _buildInviteCard(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: PremiumTheme.glassCard(
            gradientStart: PremiumTheme.cyan,
            gradientEnd: PremiumTheme.teal,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finance Onboarding',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Manually onboard clients or send them a self-service onboarding link',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFE0F7FA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Financial Manager',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: PremiumTheme.glassCard(),
          child: Form(
            key: _manualFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: PremiumTheme.tealGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Client Onboarding',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Capture client details directly into the system',
                            style: TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('Company Information'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Company Name',
                        controller: _companyNameController,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        label: 'Industry',
                        controller: _industryController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Company Size',
                        controller: _companySizeController,
                        hint: 'e.g., 1-10, 11-50',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        label: 'Business Type',
                        controller: _businessTypeController,
                        hint: 'e.g., B2B, B2C',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Location',
                  controller: _locationController,
                  hint: 'City, Country',
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('Contact Information'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Contact Person',
                        controller: _contactPersonController,
                        required: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        label: 'Email',
                        controller: _emailController,
                        required: true,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Phone',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                _buildSectionHeader('Engagement Details'),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Project Needs',
                  controller: _projectNeedsController,
                  maxLines: 3,
                  hint: 'What are we helping the client with?',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Budget Range',
                        controller: _budgetRangeController,
                        hint: 'e.g., R50k - R250k',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        label: 'Timeline',
                        controller: _timelineController,
                        hint: 'e.g., 3-6 months',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Additional Information',
                  controller: _additionalInfoController,
                  maxLines: 3,
                  hint:
                      'Any risk notes, internal comments, or special terms...',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _submittingManual ? null : _submitManualOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submittingManual
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Client',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: PremiumTheme.glassCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: PremiumTheme.tealGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Onboarding Form',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Email a secure link so the client can onboard themselves',
                          style: TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Client Email',
                controller: _inviteEmailController,
                required: true,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Company Name (Optional)',
                controller: _inviteCompanyController,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Link Expires In (Days)',
                controller: _inviteExpiryController,
                keyboardType: TextInputType.number,
                hint: '7',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: PremiumTheme.teal,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The client will receive a secure link and email verification step before they can submit their onboarding form.',
                        style: TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendingInvite ? null : _sendOnboardingInvite,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: PremiumTheme.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _sendingInvite
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PremiumTheme.teal,
                          ),
                        )
                      : const Text(
                          'Send Onboarding Link',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        const Icon(
          Icons.circle,
          size: 8,
          color: PremiumTheme.teal,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(
                  color: PremiumTheme.error,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF78909C),
                fontSize: 12,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    if ((label == 'Email' || label == 'Client Email') &&
                        !value.contains('@')) {
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
