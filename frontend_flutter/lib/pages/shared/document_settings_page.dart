import 'package:flutter/material.dart';
import '../creator/snapshots_page.dart';

class DocumentSettingsPage extends StatefulWidget {
  final String selectedTemplate;

  const DocumentSettingsPage({
    super.key,
    required this.selectedTemplate,
  });

  @override
  State<DocumentSettingsPage> createState() => _DocumentSettingsPageState();
}

class _DocumentSettingsPageState extends State<DocumentSettingsPage> {
  final TextEditingController _documentNameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  String? _selectedClient;
  bool _showClientDropdown = false;

  final List<String> _clients = [
    'Example Company',
    'Tech Solutions Inc.',
    'Global Enterprises',
    'Startup Ventures',
    'Corporate Partners LLC',
  ];

  @override
  void initState() {
    super.initState();
    _documentNameController.text = widget.selectedTemplate;
  }

  @override
  void dispose() {
    _documentNameController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header with back button and progress indicator
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Document Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3498DB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Step 1 of 3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                LinearProgressIndicator(
                  value: 0.33,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Name Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Document Name',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _documentNameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter document name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Company Information Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Company Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _companyController,
                          decoration: const InputDecoration(
                            hintText: 'Enter company name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Client Selection Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Client',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showClientDropdown = !_showClientDropdown;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedClient ?? 'Select a client',
                                    style: TextStyle(
                                      color: _selectedClient != null
                                          ? const Color(0xFF2C3E50)
                                          : const Color(0xFF718096),
                                    ),
                                  ),
                                ),
                                Icon(
                                  _showClientDropdown
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: const Color(0xFF718096),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showClientDropdown)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: _clients.map((client) {
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedClient = client;
                                      _showClientDropdown = false;
                                    });
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      client,
                                      style: const TextStyle(
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF718096),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Navigate to Snapshots page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SnapshotsPage(
                                  documentName:
                                      _documentNameController.text.isNotEmpty
                                          ? _documentNameController.text
                                          : widget.selectedTemplate,
                                  companyName:
                                      _companyController.text.isNotEmpty
                                          ? _companyController.text
                                          : 'Your Company',
                                  selectedClient:
                                      _selectedClient ?? 'No client selected',
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498DB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
