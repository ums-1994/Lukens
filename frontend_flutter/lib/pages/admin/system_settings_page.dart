import 'package:flutter/material.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';
import '../../widgets/currency_picker.dart';
import '../../services/currency_service.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  bool _emailNotifications = true;
  bool _autoSave = true;
  bool _darkMode = true;
  String _defaultLanguage = 'English';
  String _timezone = 'UTC';
  double _sessionTimeout = 30.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'System Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure system parameters and preferences',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFB0B6BB),
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 32),

            // Settings Sections
            _buildSettingsSection(
              'General Settings',
              Icons.settings,
              [
                _buildSwitchSetting(
                  'Email Notifications',
                  'Receive email notifications for important events',
                  _emailNotifications,
                  (value) => setState(() => _emailNotifications = value),
                ),
                _buildSwitchSetting(
                  'Auto Save',
                  'Automatically save changes while editing',
                  _autoSave,
                  (value) => setState(() => _autoSave = value),
                ),
                _buildSwitchSetting(
                  'Dark Mode',
                  'Use dark theme interface',
                  _darkMode,
                  (value) => setState(() => _darkMode = value),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSettingsSection(
              'Localization',
              Icons.language,
              [
                _buildDropdownSetting(
                  'Default Language',
                  'Select the default language for the interface',
                  _defaultLanguage,
                  ['English', 'Spanish', 'French', 'German', 'Chinese'],
                  (value) => setState(() => _defaultLanguage = value!),
                ),
                _buildDropdownSetting(
                  'Timezone',
                  'Select your timezone for accurate timestamps',
                  _timezone,
                  ['UTC', 'EST', 'PST', 'GMT', 'CET'],
                  (value) => setState(() => _timezone = value!),
                ),
                _buildCurrencySetting(),
              ],
            ),
            const SizedBox(height: 24),

            _buildSettingsSection(
              'Security',
              Icons.security,
              [
                _buildSliderSetting(
                  'Session Timeout (minutes)',
                  'Automatically log out after inactivity',
                  _sessionTimeout,
                  5,
                  120,
                  (value) => setState(() => _sessionTimeout = value),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            Center(
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE9293A),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, IconData icon, List<Widget> children) {
    return LiquidGlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE9293A), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(String title, String description, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFE9293A),
            activeTrackColor: const Color(0xFFE9293A).withOpacity(0.3),
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white30,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting(String title, String description, String value, List<String> options, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            dropdownColor: const Color(0xFF1A1A1B),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white30),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white30),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE9293A)),
              ),
            ),
            items: options.map((option) => DropdownMenuItem(
              value: option,
              child: Text(option),
            )).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting(String title, String description, double value, double min, double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: (max - min).round(),
                  activeColor: const Color(0xFFE9293A),
                  inactiveColor: Colors.white30,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${value.round()} min',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Color(0xFF14B3BB),
      ),
    );
  }

  Widget _buildCurrencySetting() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Default Currency',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select the default currency for all financial displays',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          CurrencySelector(
            initialCurrency: CurrencyService().selectedCurrency,
            onChanged: (currency) {
              CurrencyService().setCurrency(currency);
            },
            showLabel: false,
          ),
        ],
      ),
    );
  }
}
