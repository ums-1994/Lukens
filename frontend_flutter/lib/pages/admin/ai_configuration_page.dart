import 'package:flutter/material.dart';
import '../../services/ai_analysis_service.dart';

class AIConfigurationPage extends StatefulWidget {
  const AIConfigurationPage({super.key});

  @override
  State<AIConfigurationPage> createState() => _AIConfigurationPageState();
}

class _AIConfigurationPageState extends State<AIConfigurationPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isTesting = false;
  String _testResult = '';
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    final configured = await AIAnalysisService.isConfigured;
    setState(() {
      _isConfigured = configured;
      if (_isConfigured) {
        _apiKeyController.text = 'Backend AI is configured'; // Masked key
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _testAI() async {
    setState(() {
      _isTesting = true;
      _testResult = '';
    });

    try {
      // Test with sample proposal data
      final testData = {
        'title': 'Test Proposal',
        'clientName': 'Test Client',
        'projectType': 'Software Development',
        'timeline': '3 months',
        'executive_summary': 'This is a test proposal for AI analysis.',
        'scope_deliverables':
            'We will deliver a complete software solution including development, testing, and deployment.',
      };

      final result = await AIAnalysisService.analyzeProposalContent(testData);

      setState(() {
        _testResult = 'âœ… AI Analysis Successful!\n\n'
            'Risk Score: ${result['riskScore']}\n'
            'Status: ${result['status']}\n'
            'Issues Found: ${result['issues']?.length ?? 0}';
      });
    } catch (e) {
      setState(() {
        _testResult = 'âŒ AI Analysis Failed: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('AI Configuration'),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isConfigured ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isConfigured ? Colors.green : Colors.orange,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConfigured ? Icons.check_circle : Icons.warning,
                        color: _isConfigured ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConfigured
                            ? 'AI Analysis Enabled'
                            : 'AI Analysis Disabled',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isConfigured
                              ? Colors.green[800]
                              : Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isConfigured
                        ? 'OpenAI API is configured and ready for real-time proposal analysis.'
                        : 'Configure your OpenAI API key to enable AI-powered proposal analysis.',
                    style: TextStyle(
                      color: _isConfigured
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Configuration Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AI features are configured on the backend server. Check the status below.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'Backend AI Status',
                      hintText: 'Checking...',
                      prefixIcon:
                          const Icon(Icons.cloud, color: Color(0xFF3498DB)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: Color(0xFF3498DB), width: 2),
                      ),
                    ),
                    readOnly: true,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  if (!_isConfigured) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _checkConfiguration();
                          if (_isConfigured) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('AI Service is now configured!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'AI Service not available. Check backend configuration.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Check Backend Status',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Test Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test AI Analysis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Test the AI analysis with sample proposal data to verify it\'s working correctly.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isConfigured && !_isTesting ? _testAI : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isTesting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Testing AI...'),
                              ],
                            )
                          : const Text(
                              'Test AI Analysis',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                  if (_testResult.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _testResult.contains('âœ…')
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _testResult.contains('âœ…')
                              ? Colors.green
                              : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _testResult,
                        style: TextStyle(
                          color: _testResult.contains('âœ…')
                              ? Colors.green[800]
                              : Colors.red[800],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Information Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'How AI Analysis Works',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'â€¢ Analyzes proposal content for potential risks and issues\n'
                    'â€¢ Detects unrealistic timelines and vague scope\n'
                    'â€¢ Identifies missing critical information\n'
                    'â€¢ Provides actionable recommendations\n'
                    'â€¢ Updates in real-time as you edit your proposal',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

