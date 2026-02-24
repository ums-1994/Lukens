import 'package:flutter/material.dart';

import '../../theme/premium_theme.dart';

class FinanceOnboardingPage extends StatefulWidget {
  const FinanceOnboardingPage({super.key});

  @override
  State<FinanceOnboardingPage> createState() => _FinanceOnboardingPageState();
}

class _FinanceOnboardingPageState extends State<FinanceOnboardingPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _showForm = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _holdingInfoController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  final TextEditingController _contactMobileController =
      TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
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
                  Text(
                    'Finance Onboarding',
                    style: PremiumTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture new client information for finance.',
                    style: PremiumTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showForm = true;
                        });
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('New Client'),
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
                  ),
                  if (_showForm) ...[
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildField(
                            label: 'Client Information Name',
                            controller: _nameController,
                            isRequired: true,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'Client Information Holding Information',
                            controller: _holdingInfoController,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'Client Information Address',
                            controller: _addressController,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label: 'Client Information Client Contact Name',
                            controller: _contactNameController,
                            isRequired: true,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label:
                                'Client Information Client Contact Email Address',
                            controller: _contactEmailController,
                            isRequired: true,
                            keyboardType: TextInputType.emailAddress,
                            isEmail: true,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            label:
                                'Client Information Client Contact Mobile Number',
                            controller: _contactMobileController,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showForm = false;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  final form = _formKey.currentState;
                                  if (form == null) {
                                    return;
                                  }
                                  if (!form.validate()) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Client information captured successfully.',
                                      ),
                                    ),
                                  );
                                },
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
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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
}
