import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';

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
  bool _isLoading = false;

  // Form data
  final Map<String, dynamic> _formData = {
    'templateType': '',
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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
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
        return _formData['clientName'].isNotEmpty &&
            _formData['opportunityName'].isNotEmpty;
      case 2:
        return _formData['projectType'].isNotEmpty;
      case 3:
        return _formData['selectedModules'].isNotEmpty;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('New Proposal'),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 4,
                    backgroundColor: Colors.grey[300],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Step ${_currentStep + 1} of 4',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),

          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Template'),
                _buildStepConnector(),
                _buildStepIndicator(1, 'Client'),
                _buildStepConnector(),
                _buildStepIndicator(2, 'Project'),
                _buildStepConnector(),
                _buildStepIndicator(3, 'Content'),
              ],
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
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
            ),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF3498DB)),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed()
                        ? (_currentStep == 3 ? _createProposal : _nextStep)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : Text(_currentStep == 3 ? 'Create Proposal' : 'Next'),
                  ),
                ),
              ],
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
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF2ECC71)
                : isActive
                    ? const Color(0xFF3498DB)
                    : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? const Color(0xFF2C3E50) : Colors.grey[600],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: Colors.grey[300],
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
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 2.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _templateTypes.length,
              itemBuilder: (context, index) {
                final template = _templateTypes[index];
                final isSelected = _formData['templateType'] == template['id'];

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
                              const SizedBox(height: 4),
                              Text(
                                template['description'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Includes: ${template['sections'].join(', ')}',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientDetails() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client & Opportunity Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter client information and opportunity details',
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
                  _buildTextField(
                    'Client Name',
                    'Enter client company name',
                    (value) => _formData['clientName'] = value,
                    Icons.business_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    'Client Email',
                    'Enter client contact email',
                    (value) => _formData['clientEmail'] = value,
                    Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    'Opportunity Name',
                    'Enter project or opportunity name',
                    (value) => _formData['opportunityName'] = value,
                    Icons.lightbulb_outline,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDetails() {
    return Padding(
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
                    (value) => _formData['projectType'] = value,
                    Icons.work_outline,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    'Estimated Value',
                    'Enter estimated project value (e.g., \$50,000)',
                    (value) => _formData['estimatedValue'] = value,
                    Icons.attach_money,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    'Timeline',
                    'Enter project timeline (e.g., 3 months)',
                    (value) => _formData['timeline'] = value,
                    Icons.schedule,
                  ),
                ],
              ),
            ),
          ),
        ],
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
  }) {
    return TextFormField(
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
      keyboardType: keyboardType,
      onChanged: onChanged,
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
      value: value?.isEmpty == true ? null : value,
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option),
        );
      }).toList(),
      onChanged: (value) => onChanged(value ?? ''),
    );
  }
}
