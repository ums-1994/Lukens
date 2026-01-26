import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../theme/premium_theme.dart';

class FinanceOnboardingPage extends StatefulWidget {
  const FinanceOnboardingPage({super.key});

  @override
  State<FinanceOnboardingPage> createState() => _FinanceOnboardingPageState();
}

class _FinanceOnboardingPageState extends State<FinanceOnboardingPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _holdingInfoController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  final TextEditingController _contactMobileController =
      TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _clientEmailController.dispose();
    _holdingInfoController.dispose();
    _addressController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactMobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              decoration: PremiumTheme.glassCard(borderRadius: 20),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finance Onboarding',
                            style: PremiumTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Capture new client information for finance.',
                            style: PremiumTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              _formKey.currentState?.reset();
                              _nameController.clear();
                              _clientEmailController.clear();
                              _holdingInfoController.clear();
                              _addressController.clear();
                              _contactNameController.clear();
                              _contactEmailController.clear();
                              _contactMobileController.clear();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Clear Form'),
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
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildField(
                          label: 'Client Name',
                          controller: _nameController,
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: 'Client Email',
                          controller: _clientEmailController,
                          isRequired: true,
                          keyboardType: TextInputType.emailAddress,
                          isEmail: true,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: 'Client Holding',
                          controller: _holdingInfoController,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: 'Client Address',
                          controller: _addressController,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: 'Client Contact Name',
                          controller: _contactNameController,
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: 'Client Contact Email',
                          controller: _contactEmailController,
                          isRequired: true,
                          keyboardType: TextInputType.emailAddress,
                          isEmail: true,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          label: 'Client Contact Mobile',
                          controller: _contactMobileController,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                _formKey.currentState?.reset();
                                _nameController.clear();
                                _clientEmailController.clear();
                                _holdingInfoController.clear();
                                _addressController.clear();
                                _contactNameController.clear();
                                _contactEmailController.clear();
                                _contactMobileController.clear();
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveClient,
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
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isEmail = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    if (isEmail && !value.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _saveClient() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final token = AuthService.token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to save a client'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final body = {
        'company_name': _nameController.text.trim(),
        'email': _clientEmailController.text.trim(),
        'contact_person': _contactNameController.text.trim(),
        'phone': _contactMobileController.text.trim(),
        'holding': _holdingInfoController.text.trim(),
        'address': _addressController.text.trim(),
        'contact_email': _contactEmailController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/clients/manual'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Return to previous page (e.g. ClientManagementPage) and signal success
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        String message = 'Failed to save client';
        try {
          final decoded = json.decode(response.body) as Map<String, dynamic>;
          if (decoded['error'] != null) {
            message = decoded['error'].toString();
          } else if (decoded['detail'] != null) {
            message = decoded['detail'].toString();
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving client: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
