import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/client_service.dart';
import '../../theme/premium_theme.dart';

class FinanceAddClientPage extends StatefulWidget {
  const FinanceAddClientPage({super.key});

  @override
  State<FinanceAddClientPage> createState() => _FinanceAddClientPageState();
}

class _FinanceAddClientPageState extends State<FinanceAddClientPage> {
  bool _saving = false;

  final _nameController = TextEditingController();
  final _holdingController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactMobileController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _holdingController.dispose();
    _addressController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactMobileController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    final holding = _holdingController.text.trim();
    final address = _addressController.text.trim();
    final contactName = _contactNameController.text.trim();
    final contactEmail = _contactEmailController.text.trim();
    final contactMobile = _contactMobileController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Please enter client name');
      return;
    }

    if (contactEmail.isEmpty) {
      _showSnackBar('Please enter client contact email address');
      return;
    }

    setState(() => _saving = true);
    try {
      final token = AuthService.token;
      if (token == null) {
        _showSnackBar('Authentication error: Please log in again');
        return;
      }

      final result = await ClientService.createClient(
        token: token,
        companyName: name,
        email: contactEmail,
        contactPerson: contactName.isNotEmpty ? contactName : null,
        phone: contactMobile.isNotEmpty ? contactMobile : null,
        holdingInformation: holding.isNotEmpty ? holding : null,
        address: address.isNotEmpty ? address : null,
        clientContactEmail: contactEmail,
        clientContactMobile: contactMobile.isNotEmpty ? contactMobile : null,
      );

      final ok = result != null && result['success'] == true;
      if (!ok) {
        _showSnackBar('Failed to add client');
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: PremiumTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Client'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: PremiumTheme.darkBg2.withOpacity(0.9),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField(
                    label: 'Enter Client Information Name',
                    controller: _nameController,
                    icon: Icons.business,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Enter Client Information Holding Information',
                    controller: _holdingController,
                    icon: Icons.apartment,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Enter Client Information Address',
                    controller: _addressController,
                    icon: Icons.location_on,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Enter Client Information Client Contact Name',
                    controller: _contactNameController,
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label:
                        'Enter Client Information Client Contact Email Address',
                    controller: _contactEmailController,
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label:
                        'Enter Client Information Client Contact Mobile Number',
                    controller: _contactMobileController,
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save Client'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumTheme.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: PremiumTheme.teal),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: PremiumTheme.teal, width: 2),
        ),
      ),
    );
  }
}
