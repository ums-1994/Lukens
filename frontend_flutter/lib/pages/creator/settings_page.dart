import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedSettings = 'general';
  String _selectedWorkflowTab = 'standard';
  final TextEditingController _searchController = TextEditingController();

  // Form controllers for general settings
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _openaiApiKeyController = TextEditingController();

  // Settings state
  Map<String, dynamic> _generalSettings = {};
  Map<String, dynamic> _templateSettings = {};
  Map<String, dynamic> _userSettings = {};
  Map<String, dynamic> _workflowSettings = {};
  Map<String, dynamic> _integrationSettings = {};
  Map<String, dynamic> _securitySettings = {};
  Map<String, dynamic> _aiSettings = {};
  Map<String, dynamic> _notificationSettings = {};

  bool _isLoading = false;
  String? _companyLogoPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _companyNameController.dispose();
    _openaiApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/settings'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _generalSettings = Map<String, dynamic>.from(data['system'] ?? {});
        _templateSettings = Map<String, dynamic>.from(data['templates'] ?? {});
        _userSettings =
            Map<String, dynamic>.from(data['user_preferences'] ?? {});
        _workflowSettings = Map<String, dynamic>.from(data['workflows'] ?? {});
        _integrationSettings =
            Map<String, dynamic>.from(data['integrations'] ?? {});
        _securitySettings = Map<String, dynamic>.from(data['security'] ?? {});
        _aiSettings = Map<String, dynamic>.from(data['ai'] ?? {});
        _notificationSettings =
            Map<String, dynamic>.from(data['notifications'] ?? {});

        // Update form controllers
        _companyNameController.text =
            _generalSettings['company_name'] ?? 'Khonology';
        _openaiApiKeyController.text = _aiSettings['openai_api_key'] ?? '';
        _companyLogoPath = _generalSettings['logo_url'] ?? '';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading settings: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error loading settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      bool success = false;

      switch (_selectedSettings) {
        case 'general':
          success = await _updateGeneralSettings({
            'company_name': _companyNameController.text,
            'logo_url': _companyLogoPath,
            'default_currency': _generalSettings['default_currency'] ?? 'USD',
            'default_timezone': _generalSettings['default_timezone'] ?? 'est',
          });
          break;
        case 'ai':
          success = await _updateAISettings({
            'openai_api_key': _openaiApiKeyController.text,
            'ai_enabled': _aiSettings['ai_enabled'] ?? true,
            'ai_model': _aiSettings['ai_model'] ?? 'gpt-3.5-turbo',
          });
          break;
        // Add other cases as needed
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings')),
        );
      }
    } catch (e) {
      print('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _updateGeneralSettings(Map<String, dynamic> settings) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:8000/api/settings/system'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(settings),
      );

      if (response.statusCode == 200) {
        setState(() {
          _generalSettings = settings;
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating general settings: $e');
      return false;
    }
  }

  Future<bool> _updateAISettings(Map<String, dynamic> settings) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:8000/api/settings/ai'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(settings),
      );

      if (response.statusCode == 200) {
        setState(() {
          _aiSettings = settings;
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating AI settings: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header with search and user actions
          _buildHeader(),

          // Main content
          Expanded(
            child: Row(
              children: [
                // Settings Sidebar
                _buildSettingsSidebar(),

                // Settings Content
                Expanded(child: _buildSettingsContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search Bar
          Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search settings...',
                hintStyle: TextStyle(color: Color(0xFF64748B)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),

          const Spacer(),

          // User Actions
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'JD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSidebar() {
    return Container(
      width: 250,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),

          // Settings Navigation
          Expanded(
            child: ListView(
              children: [
                _buildSettingsNavItem(
                  'General Settings',
                  Icons.settings,
                  'general',
                ),
                _buildSettingsNavItem(
                  'Template Management',
                  Icons.description,
                  'templates',
                ),
                _buildSettingsNavItem(
                  'User & Permissions',
                  Icons.people,
                  'users',
                ),
                _buildSettingsNavItem(
                  'Approval Workflows',
                  Icons.account_tree,
                  'workflows',
                ),
                _buildSettingsNavItem(
                  'Integrations',
                  Icons.integration_instructions,
                  'integrations',
                ),
                _buildSettingsNavItem('Security', Icons.security, 'security'),
                _buildSettingsNavItem(
                  'AI Configuration',
                  Icons.psychology,
                  'ai',
                ),
                _buildSettingsNavItem(
                  'Notifications',
                  Icons.notifications,
                  'notifications',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsNavItem(String title, IconData icon, String key) {
    final isSelected = _selectedSettings == key;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedSettings = key),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0F7FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Container(
      margin: const EdgeInsets.only(right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Page Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Text(
                  _getSettingsTitle(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveSettings,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Settings Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildSettingsSection(),
                  ),
          ),
        ],
      ),
    );
  }

  String _getSettingsTitle() {
    switch (_selectedSettings) {
      case 'general':
        return 'General Settings';
      case 'templates':
        return 'Template Management';
      case 'users':
        return 'User & Permissions';
      case 'workflows':
        return 'Approval Workflows';
      case 'integrations':
        return 'Integrations';
      case 'security':
        return 'Security';
      case 'ai':
        return 'AI Configuration';
      case 'notifications':
        return 'Notifications';
      default:
        return 'Settings';
    }
  }

  Widget _buildSettingsSection() {
    switch (_selectedSettings) {
      case 'general':
        return _buildGeneralSettings();
      case 'templates':
        return _buildTemplateManagement();
      case 'users':
        return _buildUserPermissions();
      case 'workflows':
        return _buildApprovalWorkflows();
      case 'integrations':
        return _buildIntegrations();
      case 'security':
        return _buildSecurity();
      case 'ai':
        return _buildAIConfiguration();
      case 'notifications':
        return _buildNotifications();
      default:
        return _buildGeneralSettings();
    }
  }

  Widget _buildGeneralSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormGroup(
          'Company Name',
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              hintText: 'Khonology',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        _buildFormGroup(
          'Company Logo',
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _companyLogoPath != null && _companyLogoPath!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _companyLogoPath!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.business,
                            size: 32,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.business,
                        size: 32,
                        color: Color(0xFF2563EB),
                      ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Placeholder for logo upload
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Logo upload feature coming soon!')),
                  );
                },
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Upload New Logo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ],
          ),
        ),
        _buildFormGroup(
          'Default Currency',
          DropdownButtonFormField<String>(
            value: _generalSettings['default_currency'] ?? 'USD',
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: ['USD', 'EUR', 'GBP', 'CAD']
                .map(
                  (currency) => DropdownMenuItem<String>(
                    value: currency,
                    child: Text(currency),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _generalSettings['default_currency'] = value;
                });
              }
            },
          ),
        ),
        _buildFormGroup(
          'Default Timezone',
          DropdownButtonFormField<String>(
            value: _generalSettings['default_timezone'] ?? 'est',
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'est', child: Text('Eastern Time (ET)')),
              DropdownMenuItem(value: 'cst', child: Text('Central Time (CT)')),
              DropdownMenuItem(value: 'pst', child: Text('Pacific Time (PT)')),
              DropdownMenuItem(
                  value: 'gmt', child: Text('Greenwich Mean Time (GMT)')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _generalSettings['default_timezone'] = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateManagement() {
    return const Center(
      child: Text('Template Management - Coming Soon!'),
    );
  }

  Widget _buildUserPermissions() {
    return const Center(
      child: Text('User & Permissions - Coming Soon!'),
    );
  }

  Widget _buildApprovalWorkflows() {
    return const Center(
      child: Text('Approval Workflows - Coming Soon!'),
    );
  }

  Widget _buildIntegrations() {
    return const Center(
      child: Text('Integrations - Coming Soon!'),
    );
  }

  Widget _buildSecurity() {
    return const Center(
      child: Text('Security Settings - Coming Soon!'),
    );
  }

  Widget _buildAIConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormGroup(
          'OpenAI API Key',
          TextField(
            controller: _openaiApiKeyController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'sk-proj-...',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.visibility),
            ),
          ),
        ),
        _buildCheckboxGroup(
          'Enable AI Analysis',
          _aiSettings['ai_enabled'] ?? true,
          (value) {
            setState(() {
              _aiSettings['ai_enabled'] = value ?? false;
            });
          },
        ),
        _buildFormGroup(
          'AI Model',
          DropdownButtonFormField<String>(
            value: _aiSettings['ai_model'] ?? 'gpt-3.5-turbo',
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                value: 'gpt-3.5-turbo',
                child: Text('GPT-3.5 Turbo'),
              ),
              DropdownMenuItem(value: 'gpt-4', child: Text('GPT-4')),
              DropdownMenuItem(
                value: 'gpt-4-turbo',
                child: Text('GPT-4 Turbo'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _aiSettings['ai_model'] = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotifications() {
    return const Center(
      child: Text('Notification Settings - Coming Soon!'),
    );
  }

  Widget _buildFormGroup(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildCheckboxGroup(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}
