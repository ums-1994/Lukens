import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import '../shared/document_settings_page.dart';
import '../../services/khonology_templates_service.dart';
import '../../services/template_service.dart';

// ... existing code until line 838 ...

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  String _selectedCategory = 'All Templates';
  final TextEditingController _searchController = TextEditingController();
  bool _isEditingMode = false;
  String _selectedTemplate = '';
  String _selectedBlock = '';

  // Text properties
  String _selectedFontFamily = 'Arial';
  double _selectedFontSize = 16.0;
  FontWeight _selectedFontWeight = FontWeight.normal;
  Color _selectedTextColor = const Color(0xFF2C3E50);
  TextAlign _selectedTextAlign = TextAlign.left;
  String _selectedTextId = '';
  Map<String, String> _textContents = {};
  Map<String, String> _textFontFamilies = {};
  Map<String, double> _textFontSizes = {};
  Map<String, FontWeight> _textFontWeights = {};
  Map<String, Color> _textColors = {};
  Map<String, TextAlign> _textAlignments = {};

  // Header properties
  String _selectedHeaderBackground =
      'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80';
  bool _headerHasBackgroundImage = true;
  Color _headerBackgroundColor = const Color(0xFF2C3E50);
  double _headerHeight = 300.0;

  // Image properties
  String _selectedImageUrl = '';
  double _selectedImageWidth = 200.0;
  double _selectedImageHeight = 150.0;
  BoxFit _selectedImageFit = BoxFit.cover;
  String _selectedImageId = '';
  Map<String, String> _imageUrls = {};
  Map<String, double> _imageWidths = {};
  Map<String, double> _imageHeights = {};
  Map<String, BoxFit> _imageFits = {};

  // Signature properties
  final SignatureController _companySignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final SignatureController _clientSignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  Uint8List? _companySignatureData;
  Uint8List? _clientSignatureData;

  // Available templates
  final List<Map<String, dynamic>> _templates = [
    {
      'id': 'khonology_digital_transformation',
      'name': 'Digital Transformation Strategy',
      'description':
          'Comprehensive digital transformation proposal following Khonology standards',
      'category': 'Khonology Standards',
      'industry': 'Technology',
      'complexity': 'High',
      'estimatedDuration': '6-12 months',
      'thumbnail': 'assets/images/business-presentation-template.png',
    },
    {
      'id': 'khonology_ai_ml_implementation',
      'name': 'AI/ML Implementation Strategy',
      'description':
          'End-to-end AI and machine learning solution implementation',
      'category': 'Khonology Standards',
      'industry': 'Technology',
      'complexity': 'High',
      'estimatedDuration': '4-8 months',
      'thumbnail': 'assets/images/software-development-proposal-template.jpg',
    },
    {
      'id': 'khonology_data_engineering',
      'name': 'Data Engineering Platform',
      'description': 'Comprehensive data engineering and analytics platform',
      'category': 'Khonology Standards',
      'industry': 'Technology',
      'complexity': 'Medium',
      'estimatedDuration': '3-6 months',
      'thumbnail': 'assets/images/web-development-scope-document.jpg',
    },
    {
      'id': 'khonology_custom_development',
      'name': 'Custom Application Development',
      'description':
          'Bespoke application development following Khonology standards',
      'category': 'Khonology Standards',
      'industry': 'Technology',
      'complexity': 'High',
      'estimatedDuration': '6-12 months',
      'thumbnail': 'assets/images/software-development-proposal-template.jpg',
    },
    {
      'id': 'khonology_cloud_migration',
      'name': 'Cloud Migration Strategy',
      'description': 'Comprehensive cloud migration and optimization strategy',
      'category': 'Khonology Standards',
      'industry': 'Technology',
      'complexity': 'Medium',
      'estimatedDuration': '4-8 months',
      'thumbnail': 'assets/images/consulting-contract-template.jpg',
    },
  ];

  // Template content
  Map<String, dynamic> _proposalData = {
    'title': 'Business Proposal Template',
    'proposalNumber': 'ACME-2023-089',
    'date': 'October 25, 2023',
    'companyName': 'Acme Inc.',
    'companyAddress': '123 Business Ave, Suite 100\nNew York, NY 10001',
    'companyEmail': 'contact@acmeinc.com',
    'companyPhone': '(555) 123-4567',
    'clientName': 'Global Enterprises',
    'clientContact': 'John Smith, Procurement Manager',
    'clientAddress': '456 Corporate Blvd\nChicago, IL 60601',
    'clientEmail': 'john.smith@globalent.com',
    'executiveSummary':
        'Thank you for the opportunity to submit this proposal. We have carefully reviewed your requirements and are confident that our solution will meet your needs effectively and efficiently.',
    'proposedSolution':
        'Based on our analysis, we recommend the following approach:\n• Implementation of our premium software platform\n• Customization to integrate with your existing systems\n• Comprehensive training for your team members\n• Ongoing support and maintenance',
    'investment': [
      {
        'item': 'Software License',
        'description': 'Enterprise Plan (Annual)',
        'quantity': 1,
        'unitPrice': 9999.00,
        'total': 9999.00
      },
      {
        'item': 'Implementation',
        'description': 'System Setup & Integration',
        'quantity': 1,
        'unitPrice': 4500.00,
        'total': 4500.00
      },
      {
        'item': 'Training',
        'description': 'On-site Training Sessions',
        'quantity': 3,
        'unitPrice': 1200.00,
        'total': 3600.00
      },
      {
        'item': 'Support',
        'description': 'Premium Support (Annual)',
        'quantity': 1,
        'unitPrice': 2000.00,
        'total': 2000.00
      },
    ],
    'subtotal': 20099.00,
    'tax': 1607.92,
    'total': 21706.92,
    'terms':
        'This proposal is valid for 30 days from the date of issue. Payment terms are 50% upon signing and 50% upon completion. The project timeline is 8-10 weeks from project kickoff.',
  };

  @override
  void initState() {
    super.initState();
    _loadCustomTemplates();
    _loadKhonologyTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTemplateDialog,
        backgroundColor: const Color(0xFF2C3E50),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create New Template',
      ),
      body: Column(
        children: [
          // Header
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Proposal & SOW Builder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3498DB),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('User', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'logout') {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: Row(
                              children: [
                                Icon(Icons.logout),
                                SizedBox(width: 8),
                                Text('Logout'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Main Content
          Expanded(
            child: Row(
              children: [
                // Left Sidebar (Navigation)
                Container(
                  width: 250,
                  color: const Color(0xFF34495E),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Title
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3E50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF34495E),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: Color(0xFF3498DB),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Business Developer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildNavItem('📊', 'Dashboard', false, context),
                        _buildNavItem('📝', 'My Proposals', false, context),
                        _buildNavItem('📂', 'Templates', true, context),
                        _buildNavItem('🧩', 'Content Library', false, context),
                        _buildNavItem('👥', 'Collaboration', false, context),
                        _buildNavItem('📋', 'Approvals Status', false, context),
                        _buildNavItem(
                          '🔍',
                          'Analytics (My Pipeline)',
                          false,
                          context,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                // Main Content Area
                Expanded(
                  child: _isEditingMode
                      ? _buildTemplateEditor()
                      : _buildTemplateLibrary(),
                ),
                // Right Sidebar (Properties Panel) - Only shown in editing mode
                if (_isEditingMode)
                  Container(
                    width: 300,
                    color: Colors.white,
                    child: _buildPropertiesPanel(),
                  ),
              ],
            ),
          ),
          // Footer
          Container(
            height: 50,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFDDD),
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: const Center(
              child: Text(
                'Khonology Proposal & SOW Builder | End-to-End Proposal Generation and Sign-Off',
                style: TextStyle(
                  color: Color(0xFF7F8C8D),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateLibrary() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Browse and manage proposal templates',
                      style: TextStyle(
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Filter and Search Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All Templates',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 200,
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search templates...',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(6)),
                                    borderSide:
                                        BorderSide(color: Color(0xFFe2e8f0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(6)),
                                    borderSide:
                                        BorderSide(color: Color(0xFFe2e8f0)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFe2e8f0)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCategory,
                                    items: [
                                      'All Templates',
                                      'Proposals',
                                      'SOWs',
                                      'Contracts',
                                      'Presentations'
                                    ].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedCategory = newValue!;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Templates Grid
                    _buildTemplatesGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesGrid() {
    // Use the loaded templates from _templates list, with fallback defaults
    final templates =
        _templates.isNotEmpty ? _templates : _getDefaultTemplates();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 0.85,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isEditingMode = true;
            _selectedTemplate = (template['name'] ??
                template['title'] ??
                'Unknown Template') as String;
            _loadKhonologyTemplate((template['id'] ?? '') as String);
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  color: const Color(0xFFF8F9FA),
                ),
                child: Stack(
                  children: [
                    // Template image
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Image.asset(
                        (template['thumbnail'] ??
                            'assets/images/placeholder.jpg') as String,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to gradient if image fails to load
                          return Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF3498DB)
                                      .withValues(alpha: 0.1),
                                  const Color(0xFF2ECC71)
                                      .withValues(alpha: 0.1),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                (template['icon'] ?? Icons.description)
                                    as IconData,
                                size: 48,
                                color: const Color(0xFF3498DB),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Category badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          (template['category'] ?? 'Unknown') as String,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        (template['name'] ??
                            template['title'] ??
                            'Unknown Template') as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Description
                      Text(
                        (template['description'] ?? 'No description available')
                            as String,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Category and Complexity
                      if (template['category'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: template['category'] ==
                                        'Khonology Standards'
                                    ? const Color(0xFF2C3E50)
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (template['category'] ?? 'Unknown') as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: (template['category'] ?? '') ==
                                          'Khonology Standards'
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            if (template['complexity'] != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: template['complexity'] == 'High'
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : template['complexity'] == 'Medium'
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timeline,
                                      size: 12,
                                      color: template['complexity'] == 'High'
                                          ? Colors.red
                                          : template['complexity'] == 'Medium'
                                              ? Colors.orange
                                              : Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (template['complexity'] ?? 'Low')
                                          as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            (template['complexity'] ?? 'Low') ==
                                                    'High'
                                                ? Colors.red
                                                : (template['complexity'] ??
                                                            'Low') ==
                                                        'Medium'
                                                    ? Colors.orange
                                                    : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      // Duration
                      if (template['estimatedDuration'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule,
                                size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(
                              (template['estimatedDuration'] ?? 'Not specified')
                                  as String,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Author and date
                      Row(
                        children: [
                          Text(
                            'By ${template['author'] ?? 'Unknown'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            (template['date'] ?? 'Unknown date') as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditingMode = true;
                                  _selectedTemplate = (template['name'] ??
                                      template['title'] ??
                                      'Unknown Template') as String;
                                  _loadKhonologyTemplate(
                                      (template['id'] ?? '') as String);
                                });
                              },
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              // Copy functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Template copied!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF64748B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {
                              // Delete functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Template deleted!'),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete_outline, size: 16),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              foregroundColor: const Color(0xFF64748B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildTemplateEditor() {
    return Column(
      children: [
        // Top Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isEditingMode = false;
                        _selectedTemplate = '';
                        _selectedBlock = '';
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedTemplate,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Template saved!'),
                              backgroundColor: Color(0xFF2ECC71),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DocumentSettingsPage(
                                selectedTemplate: _selectedTemplate.isNotEmpty
                                    ? _selectedTemplate
                                    : 'Starter Template',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.rocket_launch, size: 16),
                        label: const Text('Generate Proposal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE74C3C),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preview opened!'),
                              backgroundColor: Color(0xFF3498DB),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('Preview'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Main Canvas
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/khonology_bg.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Container(
                  width: 800,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  child: _buildBlockBasedTemplate(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockBasedTemplate() {
    final blocks = [
      {
        'id': 'header',
        'type': 'header',
        'title': 'Professional Business Proposal',
        'content': 'Professional Business Proposal',
        'subtitle': 'Date: October 25, 2023 | Proposal #: ACME-2023-089',
      },
      {
        'id': 'executive-summary',
        'type': 'section',
        'title': 'Executive Summary',
        'content':
            'Thank you for the opportunity to submit this proposal. We have carefully reviewed your requirements and are confident that our solution will meet your needs effectively and efficiently.',
      },
      {
        'id': 'proposed-solution',
        'type': 'section',
        'title': 'Proposed Solution',
        'content':
            'Based on our analysis, we recommend the following approach:\n• Implementation of our premium software platform\n• Customization to integrate with your existing systems\n• Comprehensive training for your team members\n• Ongoing support and maintenance',
      },
      {
        'id': 'pricing-table',
        'type': 'table',
        'title': 'Investment Summary',
        'content': 'Pricing details and investment breakdown',
      },
      {
        'id': 'terms-conditions',
        'type': 'section',
        'title': 'Terms & Conditions',
        'content':
            'This proposal is valid for 30 days from the date of issue. Payment terms are 50% upon signing and 50% upon completion.',
      },
      {
        'id': 'signature-section',
        'type': 'signature',
        'title': 'Signatures',
        'content': 'Digital signature section for both parties',
      },
    ];

    return Column(
      children: [
        // Template blocks
        ...blocks.map((block) => _buildTemplateBlock(block)).toList(),
      ],
    );
  }

  Widget _buildTemplateBlock(Map<String, dynamic> block) {
    final isSelected = _selectedBlock == block['id'];

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedBlock = block['id'] as String;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: _buildBlockContent(block),
      ),
    );
  }

  Widget _buildBlockContent(Map<String, dynamic> block) {
    switch (block['type']) {
      case 'header':
        return _buildHeaderBlock(block);
      case 'section':
        return _buildSectionBlock(block);
      case 'table':
        return _buildTableBlock(block);
      case 'signature':
        return _buildSignatureBlock(block);
      default:
        return _buildTextBlock(block);
    }
  }

  Widget _buildHeaderBlock(Map<String, dynamic> block) {
    final isSelected = _selectedBlock == block['id'];

    return InkWell(
      onTap: () {
        setState(() {
          _selectedBlock = block['id'] as String;
        });
      },
      child: Container(
        height: _headerHeight,
        decoration: BoxDecoration(
          gradient: _headerHasBackgroundImage
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _headerBackgroundColor,
                    _headerBackgroundColor.withValues(alpha: 0.8)
                  ],
                ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            // Background Image Overlay
            if (_headerHasBackgroundImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(_selectedHeaderBackground),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        // Fallback to gradient if image fails
                      },
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            // Content
            Container(
              padding: const EdgeInsets.all(35),
              child: Column(
                children: [
                  // Logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.rocket_launch,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'PROPOSIFY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  // Title
                  _buildEditableText(
                    (block['title'] as String?) ??
                        'Professional Business Proposal',
                    'header_title',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  // Subtitle
                  _buildEditableText(
                    (block['subtitle'] as String?) ??
                        'Professional Business Proposal',
                    'header_subtitle',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  // Company and Client Info
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompanyInfo(),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: _buildClientInfo(),
                      ),
                    ],
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'SELECTED - CLICK TO EDIT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildSectionBlock(Map<String, dynamic> block) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSectionIcon((block['title'] as String?) ?? 'Section'),
                color: const Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                (block['title'] as String?) ?? 'Section',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (_selectedBlock == block['id'])
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditableText(
            (block['content'] as String?) ?? '',
            '${block['id']}_content',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          // Add image gallery for specific sections
          if (block['title'] == 'Executive Summary' ||
              block['title'] == 'Proposed Solution' ||
              block['title'] == 'Terms & Conditions')
            _buildImageGallery((block['title'] as String?) ?? 'Section'),
        ],
      ),
    );
  }

  Widget _buildImageGallery(String sectionTitle) {
    List<Map<String, String>> images = [];

    if (sectionTitle == 'Executive Summary') {
      images = [
        {
          'url':
              'https://images.unsplash.com/photo-1497215728101-856f4ea42174?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
          'caption': 'Our team in action'
        },
        {
          'url':
              'https://images.unsplash.com/photo-1552664730-d307ca884978?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
          'caption': 'Proven results'
        },
      ];
    } else if (sectionTitle == 'Proposed Solution') {
      images = [
        {
          'url':
              'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
          'caption': 'Our software interface'
        },
        {
          'url':
              'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
          'caption': 'Team training session'
        },
        {
          'url':
              'https://images.unsplash.com/photo-1568992687947-868a62a9f521?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
          'caption': '24/7 support team'
        },
      ];
    } else if (sectionTitle == 'Terms & Conditions') {
      images = [
        {
          'url':
              'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
          'caption': 'Secure agreement process'
        },
      ];
    }

    if (images.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 25),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: images.map((image) => _buildImageItem(image)).toList(),
      ),
    );
  }

  Widget _buildImageItem(Map<String, String> image) {
    final imageId = '${image['url']}_${image['caption']}';
    final isSelected = _selectedImageId == imageId;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedImageId = imageId;
            _selectedBlock = 'image_$imageId';
            _selectedImageUrl = image['url']!;
            _selectedImageWidth = _imageWidths[imageId] ?? 250.0;
            _selectedImageHeight = _imageHeights[imageId] ?? 200.0;
            _selectedImageFit = _imageFits[imageId] ?? BoxFit.cover;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: Image.network(
                    image['url']!,
                    width: 250,
                    height: 200,
                    fit: _imageFits[imageId] ?? BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 250,
                        height: 200,
                        color: const Color(0xFFF8F9FA),
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Edit overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                // Selection indicator
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            Container(
              width: 250,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF0F9FF)
                    : const Color(0xFFF9F9F9),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                image['caption']!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF64748B),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.business, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'From:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEditableText(
            'Acme Inc.',
            'company_name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildEditableInfoRow(Icons.location_on,
              '123 Business Ave, Suite 100', 'company_address1'),
          _buildEditableInfoRow(
              Icons.location_on, 'New York, NY 10001', 'company_address2'),
          _buildEditableInfoRow(
              Icons.email, 'contact@acmeinc.com', 'company_email'),
          _buildEditableInfoRow(Icons.phone, '(555) 123-4567', 'company_phone'),
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'To:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildEditableText(
            'Global Enterprises',
            'client_name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildEditableText(
            'Attn: John Smith, Procurement Manager',
            'client_contact',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildEditableInfoRow(
              Icons.location_on, '456 Corporate Blvd', 'client_address1'),
          _buildEditableInfoRow(
              Icons.location_on, 'Chicago, IL 60601', 'client_address2'),
          _buildEditableInfoRow(
              Icons.email, 'john.smith@globalent.com', 'client_email'),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(IconData icon, String text, String textId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: _buildEditableText(
              text,
              textId,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableBlock(Map<String, dynamic> block) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                (block['title'] as String?) ?? 'Section',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (_selectedBlock == block['id'])
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPricingTable(),
        ],
      ),
    );
  }

  Widget _buildTextBlock(Map<String, dynamic> block) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Text Block',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const Spacer(),
              if (_selectedBlock == block['id'])
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (block['content'] as String?) ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF1E293B),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBlock(Map<String, dynamic> block) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                (block['title'] as String?) ?? 'Section',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (_selectedBlock == block['id'])
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SELECTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSignatureBox('For Acme Inc.'),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSignatureBox('For Global Enterprises'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Proposal accepted!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Accept Proposal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSectionIcon(String title) {
    switch (title.toLowerCase()) {
      case 'executive summary':
        return Icons.description;
      case 'proposed solution':
        return Icons.lightbulb;
      case 'terms & conditions':
        return Icons.assignment;
      default:
        return Icons.text_fields;
    }
  }

  Widget _buildPricingTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFDDD)),
        children: [
          // Header
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFF2C3E50)),
            children: [
              _buildTableCell('Item', isHeader: true),
              _buildTableCell('Description', isHeader: true),
              _buildTableCell('Quantity', isHeader: true),
              _buildTableCell('Unit Price', isHeader: true),
              _buildTableCell('Total', isHeader: true),
            ],
          ),
          // Data rows
          ...((_proposalData['investment'] as List<Map<String, dynamic>?>?) ??
                  [])
              .where((item) => item != null)
              .map((item) {
            final safeItem = item!;
            return TableRow(
              decoration: BoxDecoration(
                color: ((_proposalData['investment'] as List?) ?? [])
                                .indexOf(item) %
                            2 ==
                        0
                    ? Colors.white
                    : const Color(0xFFF9F9F9),
              ),
              children: [
                _buildTableCell(safeItem['item']?.toString() ?? ''),
                _buildTableCell(safeItem['description']?.toString() ?? ''),
                _buildTableCell(safeItem['quantity']?.toString() ?? '0'),
                _buildTableCell(
                    '\$${_safeFormatCurrency(safeItem['unitPrice'])}'),
                _buildTableCell('\$${_safeFormatCurrency(safeItem['total'])}'),
              ],
            );
          }).toList(),
          // Subtotal
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFE8F4FC)),
            children: [
              _buildTableCell('Subtotal'),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell(
                  '\$${_safeFormatCurrency(_proposalData['subtotal'])}',
                  isBold: true),
            ],
          ),
          // Tax
          TableRow(
            children: [
              _buildTableCell('Tax'),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell('\$${_safeFormatCurrency(_proposalData['tax'])}'),
            ],
          ),
          // Total
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFE8F4FC)),
            children: [
              _buildTableCell('Total'),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell(''),
              _buildTableCell(
                  '\$${_safeFormatCurrency(_proposalData['total'])}',
                  isBold: true),
            ],
          ),
        ],
      ),
    );
  }

  String _safeFormatCurrency(dynamic value) {
    if (value == null) return '0.00';
    if (value is num) return value.toStringAsFixed(2);
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.toStringAsFixed(2) ?? '0.00';
    }
    return '0.00';
  }

  Widget _buildTableCell(String text,
      {bool isHeader = false, bool isBold = false}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          style: TextStyle(
            color: isHeader ? Colors.white : const Color(0xFF2C3E50),
            fontWeight:
                isHeader || isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isHeader ? 16 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureBox(String title) {
    final isCompany = title.contains('Acme');
    final signatureData =
        isCompany ? _companySignatureData : _clientSignatureData;
    final controller =
        isCompany ? _companySignatureController : _clientSignatureController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCCC), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: signatureData != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(signatureData, fit: BoxFit.contain),
                )
              : Signature(
                  controller: controller,
                  backgroundColor: Colors.white,
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showSignatureDialog(controller, isCompany),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Sign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            if (signatureData != null)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    if (isCompany) {
                      _companySignatureData = null;
                      _companySignatureController.clear();
                    } else {
                      _clientSignatureData = null;
                      _clientSignatureController.clear();
                    }
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 15),
        const Text('Name: _________________________'),
        const Text('Title: _________________________'),
        const Text('Date: _________________________'),
      ],
    );
  }

  Widget _buildPropertiesPanel() {
    if (_selectedBlock.isEmpty) {
      return const Center(
        child: Text(
          'Select an element to edit its properties',
          style: TextStyle(color: Color(0xFF718096)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Properties',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Selected: $_selectedBlock',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 20),

          // Determine element type and show appropriate properties
          _buildElementTypeProperties(),
        ],
      ),
    );
  }

  Widget _buildElementTypeProperties() {
    // Determine element type based on selected block
    String elementType = _getElementType(_selectedBlock);

    switch (elementType) {
      case 'image':
        return _buildImageProperties();
      case 'text':
        return _buildTextProperties();
      case 'video':
        return _buildVideoProperties();
      case 'signature':
        return _buildSignatureProperties();
      case 'table':
        return _buildTableProperties();
      case 'header':
        return _buildHeaderProperties();
      default:
        return _buildTextProperties(); // Default to text properties
    }
  }

  String _getElementType(String blockId) {
    if (blockId.contains('image') || blockId.contains('gallery')) {
      return 'image';
    } else if (blockId.contains('video')) {
      return 'video';
    } else if (blockId.contains('signature')) {
      return 'signature';
    } else if (blockId.contains('table') || blockId.contains('pricing')) {
      return 'table';
    } else if (blockId.contains('header')) {
      return 'header';
    } else {
      return 'text';
    }
  }

  String _getFontWeightString(FontWeight weight) {
    if (weight == FontWeight.normal) {
      return 'FontWeight.normal';
    } else if (weight == FontWeight.bold) {
      return 'FontWeight.bold';
    } else if (weight == FontWeight.w300) {
      return 'FontWeight.w300';
    } else if (weight == FontWeight.w500) {
      return 'FontWeight.w500';
    } else if (weight == FontWeight.w700) {
      return 'FontWeight.w700';
    } else {
      return 'FontWeight.normal'; // Default fallback
    }
  }

  Widget _buildEditableText(String text, String textId,
      {TextStyle? style, TextAlign? textAlign}) {
    final isSelected = _selectedTextId == textId;
    final displayText = _textContents[textId] ?? text;
    final displayStyle =
        style ?? const TextStyle(fontSize: 16, color: Color(0xFF2C3E50));
    final displayAlign = _textAlignments[textId] ?? textAlign ?? TextAlign.left;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTextId = textId;
          _selectedBlock = 'text_$textId';
          _selectedFontFamily = _textFontFamilies[textId] ?? 'Arial';
          _selectedFontSize = _textFontSizes[textId] ?? 16.0;
          _selectedFontWeight = _textFontWeights[textId] ?? FontWeight.normal;
          _selectedTextColor = _textColors[textId] ?? const Color(0xFF2C3E50);
          _selectedTextAlign = _textAlignments[textId] ?? TextAlign.left;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
          color: isSelected ? const Color(0xFFF0F9FF) : Colors.transparent,
        ),
        child: Text(
          displayText,
          style: displayStyle.copyWith(
            fontFamily: _textFontFamilies[textId] ?? displayStyle.fontFamily,
            fontSize: _textFontSizes[textId] ?? displayStyle.fontSize,
            fontWeight: _textFontWeights[textId] ?? displayStyle.fontWeight,
            color: _textColors[textId] ?? displayStyle.color,
          ),
          textAlign: displayAlign,
        ),
      ),
    );
  }

  Widget _buildTextProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Text Properties',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),

        // Selected text info
        if (_selectedTextId.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B82F6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.text_fields,
                    color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editing: ${_selectedTextId.replaceAll('_', ' ').toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Text content editor
        if (_selectedTextId.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Text Content',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) {
                  setState(() {
                    _textContents[_selectedTextId] = value;
                  });
                },
                controller: TextEditingController(
                    text: _textContents[_selectedTextId] ?? ''),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter text content...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),

        // Font Family
        _buildPropertyDropdown(
          'Font Family',
          _selectedFontFamily,
          [
            'Arial',
            'Times New Roman',
            'Helvetica',
            'Georgia',
            'Verdana',
            'Courier New',
            'Calibri'
          ],
          (value) {
            setState(() {
              _selectedFontFamily = value!;
              if (_selectedTextId.isNotEmpty) {
                _textFontFamilies[_selectedTextId] = value;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Font Size
        _buildPropertySlider(
          'Font Size',
          _selectedFontSize,
          8.0,
          72.0,
          (value) {
            setState(() {
              _selectedFontSize = value;
              if (_selectedTextId.isNotEmpty) {
                _textFontSizes[_selectedTextId] = value;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Font Weight
        _buildPropertyDropdown(
          'Font Weight',
          _getFontWeightString(_selectedFontWeight),
          [
            'FontWeight.normal',
            'FontWeight.bold',
            'FontWeight.w300',
            'FontWeight.w500',
            'FontWeight.w700'
          ],
          (value) {
            setState(() {
              switch (value) {
                case 'FontWeight.normal':
                  _selectedFontWeight = FontWeight.normal;
                  break;
                case 'FontWeight.bold':
                  _selectedFontWeight = FontWeight.bold;
                  break;
                case 'FontWeight.w300':
                  _selectedFontWeight = FontWeight.w300;
                  break;
                case 'FontWeight.w500':
                  _selectedFontWeight = FontWeight.w500;
                  break;
                case 'FontWeight.w700':
                  _selectedFontWeight = FontWeight.w700;
                  break;
              }
              if (_selectedTextId.isNotEmpty) {
                _textFontWeights[_selectedTextId] = _selectedFontWeight;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Text Color
        _buildPropertyColorPicker(
          'Text Color',
          _selectedTextColor,
          (color) {
            setState(() {
              _selectedTextColor = color;
              if (_selectedTextId.isNotEmpty) {
                _textColors[_selectedTextId] = color;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Text Alignment
        _buildPropertyDropdown(
          'Text Alignment',
          _selectedTextAlign.toString(),
          [
            'TextAlign.left',
            'TextAlign.center',
            'TextAlign.right',
            'TextAlign.justify'
          ],
          (value) {
            setState(() {
              switch (value) {
                case 'TextAlign.left':
                  _selectedTextAlign = TextAlign.left;
                  break;
                case 'TextAlign.center':
                  _selectedTextAlign = TextAlign.center;
                  break;
                case 'TextAlign.right':
                  _selectedTextAlign = TextAlign.right;
                  break;
                case 'TextAlign.justify':
                  _selectedTextAlign = TextAlign.justify;
                  break;
              }
              if (_selectedTextId.isNotEmpty) {
                _textAlignments[_selectedTextId] = _selectedTextAlign;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Bold/Italic toggles
        Row(
          children: [
            Expanded(
              child: _buildPropertySwitch(
                'Bold',
                _selectedFontWeight == FontWeight.bold ||
                    _selectedFontWeight == FontWeight.w700,
                (value) {
                  setState(() {
                    _selectedFontWeight =
                        value ? FontWeight.bold : FontWeight.normal;
                    if (_selectedTextId.isNotEmpty) {
                      _textFontWeights[_selectedTextId] = _selectedFontWeight;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPropertySwitch(
                'Italic',
                false, // You can add _selectedFontStyle state variable if needed
                (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Italic ${value ? 'enabled' : 'disabled'}'),
                      backgroundColor: const Color(0xFF3498DB),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image Properties',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),

        // Selected image info
        if (_selectedImageId.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B82F6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.image, color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editing: ${_selectedImageId.split('_').last}',
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Upload/Replace buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showImageUploadDialog(),
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showImageUploadDialog(),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Replace'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Image URL
        _buildPropertyTextField(
          'Image URL',
          _selectedImageUrl,
          (value) {
            setState(() {
              _selectedImageUrl = value;
              if (_selectedImageId.isNotEmpty) {
                _imageUrls[_selectedImageId] = value;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Image Width
        _buildPropertySlider(
          'Width',
          _selectedImageWidth,
          50.0,
          500.0,
          (value) {
            setState(() {
              _selectedImageWidth = value;
              if (_selectedImageId.isNotEmpty) {
                _imageWidths[_selectedImageId] = value;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Image Height
        _buildPropertySlider(
          'Height',
          _selectedImageHeight,
          50.0,
          500.0,
          (value) {
            setState(() {
              _selectedImageHeight = value;
              if (_selectedImageId.isNotEmpty) {
                _imageHeights[_selectedImageId] = value;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Image Fit
        _buildPropertyDropdown(
          'Image Fit',
          _selectedImageFit.toString(),
          [
            'BoxFit.cover',
            'BoxFit.contain',
            'BoxFit.fill',
            'BoxFit.fitWidth',
            'BoxFit.fitHeight'
          ],
          (value) {
            setState(() {
              switch (value) {
                case 'BoxFit.cover':
                  _selectedImageFit = BoxFit.cover;
                  break;
                case 'BoxFit.contain':
                  _selectedImageFit = BoxFit.contain;
                  break;
                case 'BoxFit.fill':
                  _selectedImageFit = BoxFit.fill;
                  break;
                case 'BoxFit.fitWidth':
                  _selectedImageFit = BoxFit.fitWidth;
                  break;
                case 'BoxFit.fitHeight':
                  _selectedImageFit = BoxFit.fitHeight;
                  break;
              }
              if (_selectedImageId.isNotEmpty) {
                _imageFits[_selectedImageId] = _selectedImageFit;
              }
            });
          },
        ),
        const SizedBox(height: 15),

        // Crop button
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Crop image functionality'),
                backgroundColor: Color(0xFF9B59B6),
              ),
            );
          },
          icon: const Icon(Icons.crop, size: 16),
          label: const Text('Crop Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9B59B6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 15),

        // Border toggle
        _buildPropertySwitch(
          'Show Border',
          true,
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Border ${value ? 'enabled' : 'disabled'}'),
                backgroundColor: const Color(0xFFE67E22),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPropertyDropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(item),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertySlider(String label, double value, double min,
      double max, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(1)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / 0.5).round(),
          onChanged: onChanged,
          activeColor: const Color(0xFF3498DB),
        ),
      ],
    );
  }

  Widget _buildPropertyColorPicker(
      String label, Color value, Function(Color) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                children: [
                  _buildColorOption(const Color(0xFF2C3E50), onChanged),
                  _buildColorOption(const Color(0xFF3498DB), onChanged),
                  _buildColorOption(const Color(0xFFE74C3C), onChanged),
                  _buildColorOption(const Color(0xFF2ECC71), onChanged),
                  _buildColorOption(const Color(0xFFF39C12), onChanged),
                  _buildColorOption(const Color(0xFF9B59B6), onChanged),
                  _buildColorOption(Colors.black, onChanged),
                  _buildColorOption(Colors.white, onChanged),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorOption(Color color, Function(Color) onChanged) {
    return InkWell(
      onTap: () => onChanged(color),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildPropertyTextField(
      String label, String value, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Video Properties',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),

        // Embed URL
        _buildPropertyTextField(
          'Embed URL',
          '',
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Video URL updated: $value'),
                backgroundColor: const Color(0xFF3498DB),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Thumbnail upload
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Upload video thumbnail'),
                backgroundColor: Color(0xFF2ECC71),
              ),
            );
          },
          icon: const Icon(Icons.image, size: 16),
          label: const Text('Upload Thumbnail'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 15),

        // Video dimensions
        Row(
          children: [
            Expanded(
              child: _buildPropertySlider(
                'Width',
                400.0,
                200.0,
                800.0,
                (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Video width: ${value.toStringAsFixed(0)}px'),
                      backgroundColor: const Color(0xFF9B59B6),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPropertySlider(
                'Height',
                300.0,
                150.0,
                600.0,
                (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Video height: ${value.toStringAsFixed(0)}px'),
                      backgroundColor: const Color(0xFF9B59B6),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // Autoplay toggle
        _buildPropertySwitch(
          'Autoplay',
          false,
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Autoplay ${value ? 'enabled' : 'disabled'}'),
                backgroundColor: const Color(0xFFE67E22),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Loop toggle
        _buildPropertySwitch(
          'Loop',
          false,
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loop ${value ? 'enabled' : 'disabled'}'),
                backgroundColor: const Color(0xFFE67E22),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSignatureProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Signature Properties',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),

        // Signature type selection
        _buildPropertyDropdown(
          'Signature Type',
          'draw',
          ['draw', 'type', 'upload'],
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Signature type: $value'),
                backgroundColor: const Color(0xFF3498DB),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Draw signature button
        ElevatedButton.icon(
          onPressed: () {
            _showSignatureDialog(
              _selectedBlock.contains('company')
                  ? _companySignatureController
                  : _clientSignatureController,
              _selectedBlock.contains('company'),
            );
          },
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Draw Signature'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3498DB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 8),

        // Type signature button
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Type signature functionality'),
                backgroundColor: Color(0xFF2ECC71),
              ),
            );
          },
          icon: const Icon(Icons.text_fields, size: 16),
          label: const Text('Type Signature'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 8),

        // Upload signature button
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Upload signature functionality'),
                backgroundColor: Color(0xFF9B59B6),
              ),
            );
          },
          icon: const Icon(Icons.upload, size: 16),
          label: const Text('Upload Signature'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9B59B6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 15),

        // Signature size
        _buildPropertySlider(
          'Signature Size',
          100.0,
          50.0,
          200.0,
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Signature size: ${value.toStringAsFixed(0)}%'),
                backgroundColor: const Color(0xFFE67E22),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Clear signature button
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              if (_selectedBlock.contains('company')) {
                _companySignatureData = null;
                _companySignatureController.clear();
              } else {
                _clientSignatureData = null;
                _clientSignatureController.clear();
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Signature cleared'),
                backgroundColor: Color(0xFFE74C3C),
              ),
            );
          },
          icon: const Icon(Icons.clear, size: 16),
          label: const Text('Clear Signature'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE74C3C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildTableProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Table Properties',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),

        // Table style
        _buildPropertyDropdown(
          'Table Style',
          'default',
          ['default', 'striped', 'bordered', 'hover'],
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Table style: $value'),
                backgroundColor: const Color(0xFF3498DB),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Header color
        _buildPropertyColorPicker(
          'Header Color',
          const Color(0xFF2C3E50),
          (color) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Header color updated'),
                backgroundColor: const Color(0xFF2ECC71),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Row color
        _buildPropertyColorPicker(
          'Row Color',
          const Color(0xFFF9F9F9),
          (color) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Row color updated'),
                backgroundColor: const Color(0xFF2ECC71),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Border toggle
        _buildPropertySwitch(
          'Show Borders',
          true,
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Borders ${value ? 'enabled' : 'disabled'}'),
                backgroundColor: const Color(0xFFE67E22),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Add row button
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Add row functionality'),
                backgroundColor: Color(0xFF2ECC71),
              ),
            );
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Row'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 8),

        // Add column button
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Add column functionality'),
                backgroundColor: Color(0xFF3498DB),
              ),
            );
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Column'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3498DB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderProperties() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Header Properties',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 15),

        // Background type toggle
        _buildPropertySwitch(
          'Background Image',
          _headerHasBackgroundImage,
          (value) {
            setState(() {
              _headerHasBackgroundImage = value;
            });
          },
        ),
        const SizedBox(height: 15),

        // Background image URL (only show if background image is enabled)
        if (_headerHasBackgroundImage) ...[
          _buildPropertyTextField(
            'Background Image URL',
            _selectedHeaderBackground,
            (value) {
              setState(() {
                _selectedHeaderBackground = value;
              });
            },
          ),
          const SizedBox(height: 15),

          // Background image upload button
          ElevatedButton.icon(
            onPressed: () => _showHeaderBackgroundDialog(),
            icon: const Icon(Icons.image, size: 16),
            label: const Text('Choose Background'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 15),
        ],

        // Background color (only show if no background image)
        if (!_headerHasBackgroundImage) ...[
          _buildPropertyColorPicker(
            'Background Color',
            _headerBackgroundColor,
            (color) {
              setState(() {
                _headerBackgroundColor = color;
              });
            },
          ),
          const SizedBox(height: 15),
        ],
        const SizedBox(height: 15),

        // Header height
        _buildPropertySlider(
          'Header Height',
          _headerHeight,
          100.0,
          500.0,
          (value) {
            setState(() {
              _headerHeight = value;
            });
          },
        ),
        const SizedBox(height: 15),

        // Logo upload
        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Upload logo functionality'),
                backgroundColor: Color(0xFF2ECC71),
              ),
            );
          },
          icon: const Icon(Icons.image, size: 16),
          label: const Text('Upload Logo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
        const SizedBox(height: 15),

        // Text color
        _buildPropertyColorPicker(
          'Text Color',
          Colors.white,
          (color) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Text color updated'),
                backgroundColor: const Color(0xFF2ECC71),
              ),
            );
          },
        ),
        const SizedBox(height: 15),

        // Background image toggle
        _buildPropertySwitch(
          'Background Image',
          true,
          (value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Background image ${value ? 'enabled' : 'disabled'}'),
                backgroundColor: const Color(0xFFE67E22),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPropertySwitch(
      String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF3498DB),
        ),
      ],
    );
  }

  Widget _buildNavItem(
      String icon, String label, bool isActive, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          // Navigation logic based on label
          switch (label) {
            case 'Dashboard':
              Navigator.pushReplacementNamed(context, '/dashboard');
              break;
            case 'My Proposals':
              Navigator.pushReplacementNamed(context, '/proposals');
              break;
            case 'Templates':
              // Already on templates page, do nothing
              break;
            case 'Content Library':
              Navigator.pushReplacementNamed(context, '/content');
              break;
            case 'Collaboration':
              Navigator.pushReplacementNamed(context, '/collaboration');
              break;
            case 'Approvals Status':
              Navigator.pushReplacementNamed(context, '/approvals');
              break;
            case 'Analytics (My Pipeline)':
              Navigator.pushReplacementNamed(context, '/analytics');
              break;
            default:
              // Show a snackbar for unimplemented features
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label feature coming soon!'),
                  backgroundColor: const Color(0xFF3498DB),
                ),
              );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFFBDC3C7),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDefaultTemplates() {
    return [
      {
        'id': '1',
        'name': 'Professional Business Proposal',
        'title': 'Professional Business Proposal',
        'category': 'Proposals',
        'description':
            'Comprehensive professional proposal with branding, pricing tables, and signature blocks',
        'author': 'System',
        'date': 'Today',
        'thumbnail': 'assets/images/software-development-proposal-template.jpg',
        'icon': Icons.description,
        'complexity': 'Medium',
        'estimatedDuration': '2-4 weeks',
      },
      {
        'id': '2',
        'name': 'Marketing Campaign SOW',
        'title': 'Marketing Campaign SOW',
        'category': 'SOWs',
        'description':
            'Statement of work for marketing campaigns and strategies',
        'author': 'Jane Smith',
        'date': '1 week ago',
        'thumbnail': 'assets/images/marketing-campaign-document-template.jpg',
        'icon': Icons.campaign,
        'complexity': 'Low',
        'estimatedDuration': '1-2 weeks',
      },
      {
        'id': '3',
        'name': 'Consulting Services Contract',
        'title': 'Consulting Services Contract',
        'category': 'Contracts',
        'description': 'Professional services contract template',
        'author': 'Mike Johnson',
        'date': '3 days ago',
        'thumbnail': 'assets/images/consulting-contract-template.jpg',
        'icon': Icons.handshake,
        'complexity': 'Medium',
        'estimatedDuration': '1-3 weeks',
      },
      {
        'id': '4',
        'name': 'Web Development Scope',
        'title': 'Web Development Scope Document',
        'category': 'SOWs',
        'description': 'Detailed scope of work for web development projects',
        'author': 'Sarah Wilson',
        'date': '2 days ago',
        'thumbnail': 'assets/images/web-development-scope-document.jpg',
        'icon': Icons.web,
        'complexity': 'Medium',
        'estimatedDuration': '2-3 weeks',
      },
      {
        'id': '5',
        'name': 'Service Agreement Contract',
        'title': 'Service Agreement Contract',
        'category': 'Contracts',
        'description': 'Comprehensive service agreement template',
        'author': 'David Brown',
        'date': '5 days ago',
        'thumbnail': 'assets/images/service-agreement-contract-template.jpg',
        'icon': Icons.assignment,
        'complexity': 'High',
        'estimatedDuration': '3-4 weeks',
      },
      {
        'id': '6',
        'name': 'Business Presentation',
        'title': 'Business Presentation Template',
        'category': 'Presentations',
        'description': 'Professional business presentation template',
        'author': 'Lisa Garcia',
        'date': '1 week ago',
        'thumbnail': 'assets/images/business-presentation-template.png',
        'icon': Icons.slideshow,
        'complexity': 'Low',
        'estimatedDuration': '1 week',
      },
    ];
  }

  void _loadCustomTemplates() async {
    // Load custom templates from local storage
    final customTemplates = await TemplateService.getCustomTemplates();
    setState(() {
      for (var template in customTemplates) {
        if (!_templates.any((t) => t['id'] == template['id'])) {
          _templates.add(template);
        }
      }
    });
  }

  void _loadKhonologyTemplates() {
    // Load Khonology-standard templates
    final khonologyTemplates = KhonologyTemplatesService.getAllTemplates();
    setState(() {
      // Add Khonology templates to the existing list
      for (var template in khonologyTemplates) {
        if (!_templates.any((t) => t['id'] == template['id'])) {
          // Normalize the template data to ensure all required fields are present
          final normalizedTemplate = {
            'id': template['id'] ?? 'unknown',
            'name': template['name'] ?? 'Unknown Template',
            'title': template['name'] ?? 'Unknown Template',
            'category': template['category'] ?? 'Unknown',
            'description':
                template['description'] ?? 'No description available',
            'author': 'Khonology',
            'date': 'Recently',
            'thumbnail':
                template['thumbnail'] ?? 'assets/images/placeholder.jpg',
            'icon': template['icon'] ?? Icons.description,
            'complexity': template['complexity'] ?? 'Medium',
            'estimatedDuration': template['estimatedDuration'] ?? '3-6 months',
            'industry': template['industry'] ?? 'Technology',
            'template': template['template'] ?? {},
          };
          _templates.add(normalizedTemplate);
        }
      }
    });
  }

  void _loadKhonologyTemplate(String templateId) {
    final template = KhonologyTemplatesService.getTemplateById(templateId);
    if (template != null && template['template'] != null) {
      final templateData = template['template'] as Map<String, dynamic>;
      setState(() {
        // Ensure all required fields have default values
        _proposalData = {
          'title': templateData['title'] ?? 'Business Proposal Template',
          'proposalNumber': templateData['proposalNumber'] ?? 'TEMPLATE-001',
          'date': templateData['date'] ?? 'Today',
          'companyName': templateData['companyName'] ?? 'Company Name',
          'companyAddress': templateData['companyAddress'] ?? 'Company Address',
          'companyEmail': templateData['companyEmail'] ?? 'contact@company.com',
          'companyPhone': templateData['companyPhone'] ?? '(555) 000-0000',
          'clientName': templateData['clientName'] ?? 'Client Name',
          'clientContact': templateData['clientContact'] ?? 'Client Contact',
          'clientAddress': templateData['clientAddress'] ?? 'Client Address',
          'clientEmail': templateData['clientEmail'] ?? 'client@company.com',
          'executiveSummary': templateData['executiveSummary'] ??
              'Executive summary not available.',
          'proposedSolution': templateData['proposedSolution'] ??
              'Proposed solution not available.',
          'investment': templateData['investment'] ?? [],
          'subtotal': templateData['subtotal'] ?? 0.0,
          'tax': templateData['tax'] ?? 0.0,
          'total': templateData['total'] ?? 0.0,
          'terms':
              templateData['terms'] ?? 'Terms and conditions not available.',
          'timeline': templateData['timeline'] ?? [],
          'deliverables': templateData['deliverables'] ?? [],
          'successMetrics': templateData['successMetrics'] ?? [],
        };
      });
    }
  }

  void _showSignatureDialog(SignatureController controller, bool isCompany) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${isCompany ? 'Company' : 'Client'} Signature'),
          content: SizedBox(
            width: 400,
            height: 200,
            child: Signature(
              controller: controller,
              backgroundColor: Colors.white,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.clear();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.isNotEmpty) {
                  final signatureData = await controller.toPngBytes();
                  setState(() {
                    if (isCompany) {
                      _companySignatureData = signatureData;
                    } else {
                      _clientSignatureData = signatureData;
                    }
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showImageUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upload Image'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose how you want to add an image:'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showImageUrlDialog();
                        },
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('From URL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showImageGalleryDialog();
                        },
                        icon: const Icon(Icons.photo_library, size: 16),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Camera functionality would be implemented here'),
                          backgroundColor: Color(0xFF9B59B6),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B59B6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showImageUrlDialog() {
    final TextEditingController urlController =
        TextEditingController(text: _selectedImageUrl);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Image from URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://example.com/image.jpg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedImageUrl.isNotEmpty)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _selectedImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image,
                              size: 48, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedImageUrl = urlController.text;
                  if (_selectedImageId.isNotEmpty) {
                    _imageUrls[_selectedImageId] = urlController.text;
                  }
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image URL updated!'),
                    backgroundColor: Color(0xFF2ECC71),
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showImageGalleryDialog() {
    final List<Map<String, String>> galleryImages = [
      {
        'url':
            'https://images.unsplash.com/photo-1497215728101-856f4ea42174?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        'caption': 'Business Meeting'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1552664730-d307ca884978?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        'caption': 'Team Collaboration'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        'caption': 'Technology'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1573164713714-d95e436ab8d6?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        'caption': 'Training Session'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1568992687947-868a62a9f521?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        'caption': 'Support Team'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80',
        'caption': 'Security'
      },
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose from Gallery'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: galleryImages.length,
              itemBuilder: (context, index) {
                final image = galleryImages[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedImageUrl = image['url']!;
                      if (_selectedImageId.isNotEmpty) {
                        _imageUrls[_selectedImageId] = image['url']!;
                      }
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Selected: ${image['caption']}'),
                        backgroundColor: const Color(0xFF2ECC71),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            child: Image.network(
                              image['url']!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 32, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            image['caption']!,
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showHeaderBackgroundDialog() {
    final List<Map<String, String>> headerBackgrounds = [
      {
        'url':
            'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
        'caption': 'Business Office'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1497366216548-37526070297c?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
        'caption': 'Modern Workspace'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1497366754035-f200968a6e72?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
        'caption': 'Corporate Building'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
        'caption': 'Abstract Business'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1551434678-e076c223a692?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
        'caption': 'Team Meeting'
      },
      {
        'url':
            'https://images.unsplash.com/photo-1559136555-9303baea8ebd?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
        'caption': 'Technology Focus'
      },
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Header Background'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: headerBackgrounds.length,
              itemBuilder: (context, index) {
                final background = headerBackgrounds[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedHeaderBackground = background['url']!;
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Background changed: ${background['caption']}'),
                        backgroundColor: const Color(0xFF2ECC71),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            child: Image.network(
                              background['url']!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 32, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            background['caption']!,
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateTemplateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => const CreateTemplateDialog(),
    );
  }

  @override
  void dispose() {
    _companySignatureController.dispose();
    _clientSignatureController.dispose();
    super.dispose();
  }
}

class CreateTemplateDialog extends StatefulWidget {
  const CreateTemplateDialog({super.key});

  @override
  State<CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<CreateTemplateDialog> {
  int _currentStep = 1;
  final PageController _pageController = PageController();

  // Form data
  final Map<String, dynamic> _formData = {
    'title': '',
    'category': '',
    'description': '',
    'clientName': '',
    'clientEmail': '',
    'clientCompany': '',
    'projectDescription': '',
    'estimatedValue': '',
    'dueDate': '',
  };

  final List<String> _selectedContentBlocks = [];

  // Available content blocks (mock data - in real app, fetch from API)
  final List<Map<String, dynamic>> _contentBlocks = [
    {
      'id': 1,
      'title': 'Khonology Company Profile',
      'category': 'Company Profile',
      'selected': true
    },
    {
      'id': 2,
      'title': 'Vision & Mission Statement',
      'category': 'Company Profile',
      'selected': true
    },
    {
      'id': 3,
      'title': 'Leadership Team Bio: Dapo Adeyemo',
      'category': 'Team Bio',
      'selected': false
    },
    {
      'id': 4,
      'title': 'Leadership Team Bio: Africa Nkosi',
      'category': 'Team Bio',
      'selected': false
    },
    {
      'id': 5,
      'title': 'Delivery Framework',
      'category': 'Proposal Module',
      'selected': true
    },
    {
      'id': 6,
      'title': 'Services Offering',
      'category': 'Services',
      'selected': true
    },
    {
      'id': 7,
      'title': 'Standard Terms & Conditions',
      'category': 'Legal / Terms',
      'selected': true
    },
  ];

  final List<Map<String, dynamic>> _steps = [
    {'id': 1, 'name': 'Basic Info', 'icon': Icons.description_outlined},
    {'id': 2, 'name': 'Client Details', 'icon': Icons.person_outline},
    {'id': 3, 'name': 'Content Selection', 'icon': Icons.settings_outlined},
    {'id': 4, 'name': 'Review', 'icon': Icons.visibility_outlined},
  ];

  void _nextStep() {
    if (_currentStep < _steps.length) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _createTemplate() {
    // Validate required fields
    if (_formData['title']?.toString().trim().isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a template title'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
      return;
    }

    if (_formData['category']?.toString().trim().isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a template category'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
      return;
    }

    if (_formData['clientName']?.toString().trim().isEmpty ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter client name'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
      return;
    }

    // Create template data
    final templateData = _createTemplateData();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );

    // Simulate API call with delay
    Future.delayed(const Duration(seconds: 2), () async {
      Navigator.of(context).pop(); // Close loading dialog

      // Create the template
      final success = await _saveTemplate(templateData);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Template "${_formData['title']}" created successfully!'),
            backgroundColor: const Color(0xFF2ECC71),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(); // Close create template dialog
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create template. Please try again.'),
            backgroundColor: Color(0xFFE74C3C),
          ),
        );
      }
    });
  }

  Map<String, dynamic> _createTemplateData() {
    final now = DateTime.now();
    final templateId = 'custom_${now.millisecondsSinceEpoch}';

    // Calculate totals from investment items
    final investmentItems = _createInvestmentItems();
    final subtotal = investmentItems.fold<double>(
        0.0, (sum, item) => sum + (item['total'] as double));
    final tax = subtotal * 0.08; // 8% tax
    final total = subtotal + tax;

    return {
      'id': templateId,
      'name': _formData['title'],
      'category': _formData['category'],
      'description': 'Custom template created by user',
      'industry': 'Custom',
      'complexity': _determineComplexity(),
      'estimatedDuration': _formData['dueDate']?.isNotEmpty == true
          ? _formData['dueDate']
          : '3-6 months',
      'createdAt': now.toIso8601String(),
      'createdBy': 'Current User', // In real app, get from auth service
      'template': {
        'title': _formData['title'],
        'proposalNumber':
            'CUSTOM-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'date': '${now.day}/${now.month}/${now.year}',
        'companyName': 'Khonology Solutions',
        'companyAddress': '123 Innovation Drive\nTech City, TC 12345',
        'companyEmail': 'proposals@khonology.com',
        'companyPhone': '+1 (555) 123-4567',
        'clientName': _formData['clientName'] ?? 'Client Name',
        'clientContact': _formData['clientEmail']?.isNotEmpty == true
            ? 'Contact Person'
            : 'Client Contact',
        'clientAddress': 'Client Address\nCity, State ZIP',
        'clientEmail': _formData['clientEmail'] ?? 'client@company.com',
        'executiveSummary': _createExecutiveSummary(),
        'proposedSolution': _createProposedSolution(),
        'investment': investmentItems,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'terms': _createTermsAndConditions(),
        'timeline': _createTimeline(),
        'deliverables': _createDeliverables(),
        'successMetrics': _createSuccessMetrics(),
        'selectedContentBlocks': _selectedContentBlocks,
        'projectDescription': _formData['projectDescription'] ?? '',
        'estimatedValue': _formData['estimatedValue'] ?? '',
      }
    };
  }

  List<Map<String, dynamic>> _createInvestmentItems() {
    final baseItems = [
      {
        'item': 'Project Planning',
        'description': 'Initial planning and requirements analysis',
        'quantity': 1,
        'unitPrice': 5000.00,
        'total': 5000.00
      },
      {
        'item': 'Development',
        'description': 'Core development and implementation',
        'quantity': 1,
        'unitPrice': 15000.00,
        'total': 15000.00
      },
      {
        'item': 'Testing & QA',
        'description': 'Quality assurance and testing',
        'quantity': 1,
        'unitPrice': 3000.00,
        'total': 3000.00
      },
      {
        'item': 'Deployment',
        'description': 'Deployment and configuration',
        'quantity': 1,
        'unitPrice': 2000.00,
        'total': 2000.00
      }
    ];

    // Add custom items based on selected content blocks
    if (_selectedContentBlocks.contains('Khonology Company Profile')) {
      baseItems.add({
        'item': 'Company Profile Integration',
        'description': 'Custom company profile setup',
        'quantity': 1,
        'unitPrice': 1000.00,
        'total': 1000.00
      });
    }

    if (_selectedContentBlocks.contains('Delivery Framework')) {
      baseItems.add({
        'item': 'Delivery Framework Setup',
        'description': 'Khonology delivery framework implementation',
        'quantity': 1,
        'unitPrice': 2000.00,
        'total': 2000.00
      });
    }

    if (_selectedContentBlocks.contains('Services Offering')) {
      baseItems.add({
        'item': 'Services Configuration',
        'description': 'Services offering configuration',
        'quantity': 1,
        'unitPrice': 1500.00,
        'total': 1500.00
      });
    }

    return baseItems;
  }

  String _determineComplexity() {
    final contentBlockCount = _selectedContentBlocks.length;
    if (contentBlockCount >= 5) return 'High';
    if (contentBlockCount >= 3) return 'Medium';
    return 'Low';
  }

  String _createExecutiveSummary() {
    return '''
We are pleased to present this comprehensive proposal for ${_formData['title']}. Our approach combines industry best practices with proven methodologies to deliver measurable business outcomes.

${_formData['projectDescription']?.isNotEmpty == true ? _formData['projectDescription'] : 'This project will help your organization achieve its strategic objectives through innovative solutions and expert implementation.'}

Our solution includes:
• Strategic alignment with your business objectives
• Proven methodologies and best practices
• Comprehensive project management
• Quality assurance and testing
• Ongoing support and maintenance

This proposal outlines our recommended approach, timeline, and investment required to successfully deliver your project.
    ''';
  }

  String _createProposedSolution() {
    return '''
## Project Implementation Framework

### Phase 1: Planning & Setup (Weeks 1-2)
- Requirements finalization and documentation
- Project team assembly and role definition
- Development environment setup
- Initial stakeholder meetings and alignment

### Phase 2: Development & Implementation (Weeks 3-8)
- Core development and feature implementation
- Integration with existing systems
- Regular progress reviews and feedback sessions
- Quality assurance and testing

### Phase 3: Testing & Refinement (Weeks 9-10)
- Comprehensive testing and bug fixes
- User acceptance testing
- Performance optimization
- Documentation and training materials

### Phase 4: Deployment & Launch (Weeks 11-12)
- Production deployment
- User training and onboarding
- Go-live support and monitoring
- Post-launch optimization
    ''';
  }

  String _createTermsAndConditions() {
    return '''
This proposal is valid for 30 days from the date of issue. Payment terms are 50% upon project initiation and 50% upon completion. 

The project timeline is estimated at ${_formData['dueDate']?.isNotEmpty == true ? _formData['dueDate'] : '3-6 months'} from project kickoff.

All work will be performed according to industry best practices and will include comprehensive testing and quality assurance.

Intellectual property rights will be transferred to the client upon final payment, with Khonology retaining rights to methodologies and frameworks used.
    ''';
  }

  List<Map<String, dynamic>> _createTimeline() {
    return [
      {'phase': 'Planning & Setup', 'duration': '2 weeks', 'start': 'Week 1'},
      {
        'phase': 'Development & Implementation',
        'duration': '6 weeks',
        'start': 'Week 3'
      },
      {
        'phase': 'Testing & Refinement',
        'duration': '2 weeks',
        'start': 'Week 9'
      },
      {
        'phase': 'Deployment & Launch',
        'duration': '2 weeks',
        'start': 'Week 11'
      }
    ];
  }

  List<String> _createDeliverables() {
    final deliverables = [
      'Project requirements and specifications document',
      'Fully functional solution as specified',
      'User documentation and training materials',
      'Technical documentation and source code',
      'Deployment and maintenance guides',
      'Post-implementation support plan'
    ];

    // Add specific deliverables based on content blocks
    if (_selectedContentBlocks.contains('Khonology Company Profile')) {
      deliverables.add('Custom company profile integration');
    }
    if (_selectedContentBlocks.contains('Delivery Framework')) {
      deliverables.add('Khonology delivery framework implementation');
    }
    if (_selectedContentBlocks.contains('Services Offering')) {
      deliverables.add('Services offering configuration');
    }

    return deliverables;
  }

  List<String> _createSuccessMetrics() {
    return [
      '100% feature completion per requirements',
      '99.9% system uptime and reliability',
      'Sub-3 second response times for key operations',
      '95% user satisfaction rating',
      'Zero critical security vulnerabilities',
      'On-time delivery within agreed timeline'
    ];
  }

  Future<bool> _saveTemplate(Map<String, dynamic> templateData) async {
    try {
      // Save template using the TemplateService
      final success = await TemplateService.saveTemplate(templateData);

      if (success) {
        // Optionally refresh the templates list
        // You could call a method to reload templates here
        print('Template saved successfully: ${templateData['name']}');
      }

      return success;
    } catch (e) {
      print('Error saving template: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF27272A))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Template',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Step 1 of 4',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress Steps
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: _steps.map((step) {
                  final isActive = _currentStep == step['id'];
                  final isCompleted = _currentStep > step['id'];
                  final index = _steps.indexOf(step);

                  return Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.white
                                : isActive
                                    ? Colors.transparent
                                    : Colors.transparent,
                            border: Border.all(
                              color: isCompleted || isActive
                                  ? Colors.white
                                  : const Color(0xFF3F3F46),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check,
                                    color: Colors.black, size: 20)
                                : Icon(
                                    step['icon'] as IconData,
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF71717A),
                                    size: 20,
                                  ),
                          ),
                        ),
                        if (index < _steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: isCompleted
                                  ? Colors.white
                                  : const Color(0xFF3F3F46),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Step Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInfoStep(),
                  _buildClientDetailsStep(),
                  _buildContentSelectionStep(),
                  _buildReviewStep(),
                ],
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF27272A))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _currentStep == 1 ? null : _previousStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, size: 16),
                        SizedBox(width: 8),
                        Text('Previous'),
                      ],
                    ),
                  ),
                  if (_currentStep == _steps.length)
                    ElevatedButton(
                      onPressed: _createTemplate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Create Template'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Next'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
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

  Widget _buildBasicInfoStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Template Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Template Title
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Template Title',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => _formData['title'] = value,
          ),
          const SizedBox(height: 16),

          // Template Selection
          const Text(
            'Select Template Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: KhonologyTemplatesService.getAllTemplates().length,
              itemBuilder: (context, index) {
                final template =
                    KhonologyTemplatesService.getAllTemplates()[index];
                final isSelected = _formData['category'] == template['name'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _formData['category'] = template['name'];
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isSelected ? Colors.white : const Color(0xFF18181B),
                      border: Border.all(
                        color:
                            isSelected ? Colors.white : const Color(0xFF3F3F46),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            template['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.grey[600]
                                  : Colors.grey[400],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientDetailsStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Client Name
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Client Name',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => _formData['clientName'] = value,
          ),
          const SizedBox(height: 12),

          // Client Email
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Client Email',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => _formData['clientEmail'] = value,
          ),
          const SizedBox(height: 12),

          // Company Name
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Company Name',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => _formData['clientCompany'] = value,
          ),
          const SizedBox(height: 12),

          // Project Description
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Project Description',
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3F3F46)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            onChanged: (value) => _formData['projectDescription'] = value,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Estimated Value',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => _formData['estimatedValue'] = value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Due Date',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF3F3F46)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => _formData['dueDate'] = value,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Content Blocks',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose which content blocks to include in your template',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _contentBlocks.length,
              itemBuilder: (context, index) {
                final block = _contentBlocks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      block['title'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      block['category'],
                      style: const TextStyle(color: Colors.grey),
                    ),
                    value: block['selected'],
                    onChanged: (value) {
                      setState(() {
                        block['selected'] = value ?? false;
                        if (value == true) {
                          _selectedContentBlocks.add(block['title']);
                        } else {
                          _selectedContentBlocks.remove(block['title']);
                        }
                      });
                    },
                    activeColor: Colors.white,
                    checkColor: Colors.black,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Your Template',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please review all details before creating your template',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Template Details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Template Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildReviewItem('Title', _formData['title']),
                        _buildReviewItem('Category', _formData['category']),
                        _buildReviewItem(
                            'Estimated Value', _formData['estimatedValue']),
                        _buildReviewItem('Due Date', _formData['dueDate']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Client Information
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Client Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildReviewItem('Name', _formData['clientName']),
                        _buildReviewItem('Email', _formData['clientEmail']),
                        _buildReviewItem('Company', _formData['clientCompany']),
                        _buildReviewItem(
                            'Description', _formData['projectDescription']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Content Blocks
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Content Blocks',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedContentBlocks.isEmpty)
                          const Text(
                            'No content blocks selected',
                            style: TextStyle(color: Colors.grey),
                          )
                        else
                          ..._selectedContentBlocks.map(
                            (block) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $block',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
