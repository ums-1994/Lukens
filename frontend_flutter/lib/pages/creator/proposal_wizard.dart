import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import 'content_library_dialog.dart';

// Custom formatter to force LTR text input and fix reversed text
class LTRTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    
    // If a single character was added
    if (newText.length == oldText.length + 1) {
      // Check if character was prepended (RTL) instead of appended (LTR)
      // If old text appears at the end of new text, the char was prepended
      if (newText.endsWith(oldText)) {
        // Character was prepended - fix by appending it instead
        final addedChar = newText[0];
        final correctedText = oldText + addedChar;
        return TextEditingValue(
          text: correctedText,
          selection: TextSelection.collapsed(offset: correctedText.length),
        );
      }
      // If old text appears at the start, character was appended correctly (LTR) - allow it
      if (newText.startsWith(oldText)) {
        // This is correct LTR behavior
        return newValue;
      }
    }
    
    // Remove any RTL/LTR marks
    final cleanedText = newText.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'), '');
    if (cleanedText != newText) {
      return TextEditingValue(
        text: cleanedText,
        selection: newValue.selection,
      );
    }
    
    return newValue;
  }
}

class ProposalWizard extends StatefulWidget {
  const ProposalWizard({super.key});

  @override
  State<ProposalWizard> createState() => _ProposalWizardState();
}

class _ProposalWizardState extends State<ProposalWizard>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late TabController _tabController;
  int _currentStep = 0;
  static const int _totalSteps = 5;
  bool _isLoading = false;

  // Form data
  final Map<String, dynamic> _formData = {
    'templateType': '',
    'proposalTitle': '',
    'clientName': '',
    'clientEmail': '',
    'opportunityName': '',
    'projectType': '',
    'estimatedValue': '',
    'timeline': '',
    'selectedModules': <String>[],
  };

  // Template types
  final List<Map<String, dynamic>> _templateTypes = [
    {
      'id': 'proposal',
      'name': 'Proposal',
      'description':
          'Standard business proposal with executive summary, scope, and pricing',
      'icon': Icons.description_outlined,
      'color': const Color(0xFF3498DB),
      'sections': [
        'Executive Summary',
        'Company Profile',
        'Scope & Deliverables',
        'Timeline',
        'Investment',
        'Terms & Conditions'
      ],
    },
    {
      'id': 'sow',
      'name': 'Statement of Work (SOW)',
      'description':
          'Detailed work statement with deliverables, timeline, and responsibilities',
      'icon': Icons.work_outline,
      'color': const Color(0xFF2ECC71),
      'sections': [
        'Project Overview',
        'Scope of Work',
        'Deliverables',
        'Timeline',
        'Resources',
        'Terms'
      ],
    },
    {
      'id': 'rfi',
      'name': 'RFI Response',
      'description':
          'Response to Request for Information with technical details and capabilities',
      'icon': Icons.quiz_outlined,
      'color': const Color(0xFFE74C3C),
      'sections': [
        'Company Overview',
        'Technical Capabilities',
        'Past Experience',
        'Team Qualifications',
        'References'
      ],
    },
  ];

  // Content modules
  final List<Map<String, dynamic>> _contentModules = [
    {
      'id': 'company_profile',
      'name': 'Company Profile',
      'category': 'Company',
      'description': 'Standard company information and capabilities',
      'required': true,
    },
    {
      'id': 'executive_summary',
      'name': 'Executive Summary',
      'category': 'Content',
      'description': 'High-level project overview and value proposition',
      'required': true,
    },
    {
      'id': 'scope_deliverables',
      'name': 'Scope & Deliverables',
      'category': 'Project',
      'description': 'Detailed project scope and deliverable specifications',
      'required': true,
    },
    {
      'id': 'delivery_approach',
      'name': 'Delivery Approach',
      'category': 'Methodology',
      'description': 'Project methodology and implementation approach',
      'required': false,
    },
    {
      'id': 'case_studies',
      'name': 'Case Studies',
      'category': 'Portfolio',
      'description': 'Relevant past project examples and success stories',
      'required': false,
    },
    {
      'id': 'team_bios',
      'name': 'Team Bios',
      'category': 'Team',
      'description': 'Key team member profiles and qualifications',
      'required': false,
    },
    {
      'id': 'assumptions_risks',
      'name': 'Assumptions & Risks',
      'category': 'Legal',
      'description': 'Project assumptions and risk mitigation strategies',
      'required': false,
    },
    {
      'id': 'terms_conditions',
      'name': 'Terms & Conditions',
      'category': 'Legal',
      'description': 'Standard legal terms and contract conditions',
      'required': true,
    },
  ];

  // Project types
  final List<String> _projectTypes = [
    'Software Development',
    'Digital Transformation',
    'Cloud Migration',
    'Data Analytics',
    'Cybersecurity',
    'Mobile App Development',
    'Web Development',
    'Consulting',
    'Training',
    'Support & Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tabController = TabController(length: _totalSteps, vsync: this);
    // Pre-select required modules so they are checked by default
    final required = _contentModules
        .where((m) => m['required'] == true)
        .map((m) => m['id'] as String)
        .toList();
    _formData['selectedModules'] = List<String>.from(required);
    // initialize module contents map
    _formData['moduleContents'] = <String, String>{};
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Template Selection';
      case 1:
        return 'Client Details';
      case 2:
        return 'Project Details';
      case 3:
        return 'Content Selection';
      case 4:
        return 'Review';
      default:
        return '';
    }
  }

  void _selectTemplate(String templateId) {
    setState(() {
      _formData['templateType'] = templateId;
    });
  }

  void _toggleModule(String moduleId) {
    setState(() {
      final modules = List<String>.from(_formData['selectedModules']);
      if (modules.contains(moduleId)) {
        modules.remove(moduleId);
      } else {
        modules.add(moduleId);
      }
      _formData['selectedModules'] = modules;
    });
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _formData['templateType'].isNotEmpty;
      case 1:
        // Require proposal title, client name and project/opportunity name
        return (_formData['proposalTitle'] ?? '').toString().isNotEmpty &&
            (_formData['clientName'] ?? '').toString().isNotEmpty &&
            (_formData['opportunityName'] ?? '').toString().isNotEmpty;
      case 2:
        // Require project type to be selected and not empty
        return (_formData['projectType'] ?? '').toString().isNotEmpty;
      case 3:
        return _formData['selectedModules'].isNotEmpty;
      case 4:
        return true; // review/confirm step
      default:
        return false;
    }
  }

  Future<void> _createProposal() async {
    setState(() => _isLoading = true);

    try {
      final app = context.read<AppState>();

      // Create proposal in backend
      await app.createProposal(
        _formData['opportunityName'],
        _formData['clientName'],
      );

      // Generate a temporary proposal ID for the compose page
      final proposalId = 'temp-${DateTime.now().millisecondsSinceEpoch}';

      // Navigate to enhanced compose page
      Navigator.pushReplacementNamed(
        context,
        '/enhanced-compose',
        arguments: {
          'proposalId': proposalId,
          'proposalTitle': _formData['opportunityName'],
          'templateType': _formData['templateType'],
          'selectedModules': _formData['selectedModules'],
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating proposal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Localizations.override(
        context: context,
        locale: const Locale('en', 'US'),
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'New Proposal',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Top navigation bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                InkWell(
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed('/home'),
                  child: Row(
                    children: const [
                      Icon(Icons.arrow_back,
                          size: 20, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text(
                        'Back to Dashboard',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          'Step ${_currentStep + 1} of $_totalSteps: ${_getStepTitle(_currentStep)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${((_currentStep + 1) / _totalSteps * 100).round()}% Complete',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Step indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalSteps * 2 - 1, (i) {
                if (i.isEven) {
                  final step = i ~/ 2;
                  final label = step == 0
                      ? 'Template'
                      : step == 1
                          ? 'Client'
                          : step == 2
                              ? 'Project'
                              : step == 3
                                  ? 'Content'
                                  : 'Review';
                  return _buildStepIndicator(step, label);
                } else {
                  return _buildStepConnector();
                }
              }),
            ),
          ),

          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTemplateSelection(),
                _buildClientDetails(),
                _buildProjectDetails(),
                _buildContentSelection(),
                _buildContentEditor(),
                _buildReviewPage(),
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _previousStep,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Previous',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _canProceed()
                      ? (_currentStep == _totalSteps - 1
                          ? _createProposal
                          : _nextStep)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _currentStep == _totalSteps - 1
                              ? 'Create Proposal'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
    );
  }

  Widget _buildReviewPage() {
    // Get template details
    final template = _templateTypes.firstWhere(
      (t) => t['id'] == _formData['templateType'],
      orElse: () => {'name': 'Unknown Template'},
    );

    // Get selected modules with names instead of IDs
    final selectedModuleIds =
        List<String>.from(_formData['selectedModules'] ?? []);
    final selectedModules = _contentModules
        .where((m) => selectedModuleIds.contains(m['id']))
        .map((m) => m['name'] as String)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review & Create',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50))),
          const SizedBox(height: 8),
          const Text('Review your proposal details and create',
              style: TextStyle(fontSize: 16, color: Color(0xFF718096))),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Proposal Summary',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50))),
                const SizedBox(height: 24),
                _buildReviewRow('Template:',
                    template['name'] ?? 'Standard Business Proposal'),
                _buildReviewRow('Client:', _formData['clientName'] ?? ''),
                _buildReviewRow('Project:', _formData['opportunityName'] ?? ''),
                _buildReviewRow(
                    'Modules:', '${selectedModules.length} selected'),
                const SizedBox(height: 24),
                const Text('Next Steps',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50))),
                const SizedBox(height: 16),
                _buildNextStepItem(
                    '• Your proposal will be created in draft status',
                    Color(0xFF3498DB)),
                _buildNextStepItem(
                    '• You can continue editing and adding content',
                    Color(0xFF3498DB)),
                _buildNextStepItem(
                    '• Submit for approval when ready', Color(0xFF3498DB)),
                _buildNextStepItem(
                    '• Track progress through the approval workflow',
                    Color(0xFF3498DB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C3E50),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child:
          Text(text, style: TextStyle(fontSize: 14, color: color, height: 1.5)),
    );
  }

  Future<void> _openContentLibraryAndInsert(String moduleId) async {
    // Open content library page as a dialog and return selected content
    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 900,
          height: 600,
          child: ContentLibrarySelectionDialog(),
        ),
      ),
    );

    if (selected != null) {
      final Map<String, String> contents =
          Map<String, String>.from(_formData['moduleContents'] ?? {});
      contents[moduleId] = selected['content'] ?? '';
      setState(() {
        _formData['moduleContents'] = contents;
      });
    }
  }

  Widget _buildContentEditor() {
    final selectedIds = List<String>.from(_formData['selectedModules'] ?? []);
    final contents =
        Map<String, String>.from(_formData['moduleContents'] ?? {});

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Content',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50))),
          const SizedBox(height: 8),
          const Text(
              'Fill in the selected sections (you can complete this later)',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: selectedIds.map((moduleId) {
                  final module = _contentModules.firstWhere(
                      (m) => m['id'] == moduleId,
                      orElse: () => {'name': moduleId, 'description': ''});
                  final controller =
                      TextEditingController(text: contents[moduleId] ?? '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(module['name'] ?? '',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50))),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: controller,
                                onChanged: (v) {
                                  final Map<String, String> c =
                                      Map<String, String>.from(
                                          _formData['moduleContents'] ?? {});
                                  c[moduleId] = v;
                                  _formData['moduleContents'] = c;
                                },
                                maxLines: 6,
                                decoration: InputDecoration(
                                    hintText:
                                        'Provide a high-level overview of the project...',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openContentLibraryAndInsert(moduleId),
                                    icon: const Icon(
                                        Icons.library_books_outlined),
                                    label: const Text('Insert from Library'),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = step <= _currentStep;
    final isCompleted = step < _currentStep;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF10B981)
                : isActive
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF10B981)
                  : isActive
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFE2E8F0),
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildTemplateSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Template Type',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the type of document you want to create',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              // responsive columns: 3 on wide, 2 on medium, 1 on small
              int crossAxisCount = 1;
              if (constraints.maxWidth > 1200) {
                crossAxisCount = 3;
              } else if (constraints.maxWidth > 800) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 1;
              }

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: crossAxisCount == 1 ? 3 : 1.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _templateTypes.length,
                itemBuilder: (context, index) {
                  final template = _templateTypes[index];
                  final isSelected =
                      _formData['templateType'] == template['id'];

                  return GestureDetector(
                    onTap: () => _selectTemplate(template['id']),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? template['color']
                              : const Color(0xFFE5E5E5),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: template['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              template['icon'],
                              color: template['color'],
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  template['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  template['description'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  template['sections'].take(3).join(' • '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7F8C8D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2ECC71),
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildClientDetails() {
    // Initialize controllers with current values
    final proposalTitleController = TextEditingController(
        text: _formData['proposalTitle']?.toString() ?? '');
    final clientNameController =
        TextEditingController(text: _formData['clientName']?.toString() ?? '');
    final clientEmailController =
        TextEditingController(text: _formData['clientEmail']?.toString() ?? '');
    final opportunityNameController = TextEditingController(
        text: _formData['opportunityName']?.toString() ?? '');
    final estimatedValueController = TextEditingController(
        text: _formData['estimatedValue']?.toString() ?? '');

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client & Opportunity Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter client information and opportunity details',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTextField(
                      'Proposal Title',
                      'Enter proposal title',
                      (value) =>
                          setState(() => _formData['proposalTitle'] = value),
                      Icons.description_outlined,
                      controller: proposalTitleController,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            'Client Name',
                            'Company or contact name',
                            (value) =>
                                setState(() => _formData['clientName'] = value),
                            Icons.business_outlined,
                            controller: clientNameController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            'Client Email',
                            'client@company.com',
                            (value) => setState(
                                () => _formData['clientEmail'] = value),
                            Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            controller: clientEmailController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Project/Opportunity Name',
                      'Brief project description',
                      (value) =>
                          setState(() => _formData['opportunityName'] = value),
                      Icons.lightbulb_outline,
                      controller: opportunityNameController,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Estimated Value (Optional)',
                      '0',
                      (value) =>
                          setState(() => _formData['estimatedValue'] = value),
                      Icons.attach_money,
                      keyboardType: TextInputType.number,
                      controller: estimatedValueController,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDetails() {
    // Initialize controllers with current values
    final estimatedValueController = TextEditingController(
        text: _formData['estimatedValue']?.toString() ?? '');
    final timelineController =
        TextEditingController(text: _formData['timeline']?.toString() ?? '');

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Specify project type, value, and timeline',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildDropdownField(
                      'Project Type',
                      'Select project type',
                      _formData['projectType'],
                      _projectTypes,
                      (value) => setState(() {
                        _formData['projectType'] = value;
                      }),
                      Icons.work_outline,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Estimated Value',
                      'Enter estimated project value',
                      (value) =>
                          setState(() => _formData['estimatedValue'] = value),
                      Icons.attach_money,
                      controller: estimatedValueController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Timeline',
                      'Enter project timeline',
                      (value) => setState(() => _formData['timeline'] = value),
                      Icons.schedule,
                      controller: timelineController,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSelection() {
    final requiredModules =
        _contentModules.where((m) => m['required']).toList();
    final optionalModules =
        _contentModules.where((m) => !m['required']).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Content Modules',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select content modules to include in your proposal',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Required modules
                  const Text(
                    'Required Modules',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...requiredModules
                      .map((module) => _buildModuleCard(module, true)),
                  const SizedBox(height: 24),

                  // Optional modules
                  const Text(
                    'Optional Modules',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...optionalModules
                      .map((module) => _buildModuleCard(module, false)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module, bool isRequired) {
    final isSelected = _formData['selectedModules'].contains(module['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF3498DB) : const Color(0xFFE5E5E5),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: CheckboxListTile(
        title: Text(
          module['name'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        subtitle: Text(
          module['description'],
          style: const TextStyle(color: Colors.grey),
        ),
        value: isRequired || isSelected,
        onChanged: isRequired ? null : (value) => _toggleModule(module['id']),
        activeColor: const Color(0xFF3498DB),
        controlAffinity: ListTileControlAffinity.leading,
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: module['category'] == 'Company'
                ? const Color(0xFF3498DB).withOpacity(0.1)
                : module['category'] == 'Project'
                    ? const Color(0xFF2ECC71).withOpacity(0.1)
                    : module['category'] == 'Legal'
                        ? const Color(0xFFE74C3C).withOpacity(0.1)
                        : const Color(0xFF9B59B6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            module['category'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: module['category'] == 'Company'
                  ? const Color(0xFF3498DB)
                  : module['category'] == 'Project'
                      ? const Color(0xFF2ECC71)
                      : module['category'] == 'Legal'
                          ? const Color(0xFFE74C3C)
                          : const Color(0xFF9B59B6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    Function(String) onChanged,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    TextEditingController? controller,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) {
          return Localizations.override(
            context: context,
            locale: const Locale('en', 'US'),
      child: TextFormField(
        controller: controller,
        textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              inputFormatters: [
                LTRTextInputFormatter(), // Custom formatter to fix reversed text
                FilteringTextInputFormatter.deny(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]')), // Remove RTL/LTR marks
              ],
        decoration: InputDecoration(
          labelText: label,
                labelStyle: const TextStyle(color: Colors.white70),
          hintText: hint,
                hintStyle: const TextStyle(color: Colors.white60),
          prefixIcon: Icon(icon, color: const Color(0xFF3498DB)),
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
            borderSide: const BorderSide(color: Color(0xFF3498DB), width: 2),
          ),
        ),
        keyboardType: keyboardType,
              onChanged: (value) {
                // Aggressive fix: if text appears reversed, correct it immediately
                if (controller != null && value.length >= 2) {
                  // Check if text is stored in reverse by comparing with what we expect
                  final currentText = controller!.text;
                  if (currentText != value) {
                    // Text might be reversed - check if reversing it makes sense
                    final reversed = value.split('').reversed.join('');
                    // If the reversed version matches a common pattern, fix it
                    if (value.length == 2) {
                      // For 2 characters, if they're in reverse alphabetical order for ASCII, likely reversed
                      final code1 = value.codeUnitAt(0);
                      final code2 = value.codeUnitAt(1);
                      if (code1 > code2 && code1 < 128 && code2 < 128 && 
                          value[0].toLowerCase() != value[1].toLowerCase()) {
                        // Likely reversed, fix it
                        final fixed = reversed;
                        controller!.text = fixed;
                        controller!.selection = TextSelection.collapsed(offset: fixed.length);
                        onChanged(fixed);
                        return;
                      }
                    }
                  }
                }
                onChanged(value);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String hint,
    String? value,
    List<String> options,
    Function(String) onChanged,
    IconData icon,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF3498DB)),
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
          borderSide: const BorderSide(color: Color(0xFF3498DB), width: 2),
        ),
      ),
      initialValue: value?.isEmpty == true ? null : value,
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(option),
          ),
        );
      }).toList(),
      onChanged: (value) => onChanged(value ?? ''),
    );
  }
}
