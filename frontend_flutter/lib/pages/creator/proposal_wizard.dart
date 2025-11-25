import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import 'content_library_dialog.dart';
import 'template_library_page.dart';

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
  bool _isLoadingTemplates = true;
  List<Template> _availableTemplates = [];
  Template? _selectedTemplate;

  // Form data
  final Map<String, dynamic> _formData = {
    'templateId': '',
    'templateType': '',
    'templateKey': '',
    'proposalTitle': '',
    'clientName': '',
    'clientEmail': '',
    'opportunityName': '',
    'projectType': '',
    'estimatedValue': '',
    'timeline': '',
    'selectedModules': <String>[],
    'moduleContents': <String, String>{},
  };

  // Workflow state
  Map<String, dynamic> _governanceResults =
      {}; // AI-run governance check results
  Map<String, dynamic> _riskAssessment = {};
  bool _isInternalApproved = false;
  bool _isClientSigned = false;
  String? _proposalId; // Store created proposal ID
  bool _isRunningGovernance = false;
  bool _isAnalyzingRisk = false;

  // Workflow steps matching the image
  final List<Map<String, String>> _workflowSteps = [
    {'number': '1', 'label': 'Compose'},
    {'number': '2', 'label': 'Govern'},
    {'number': '3', 'label': 'AI Risk Gate'},
    {'number': '4', 'label': 'Internal Sign-off'},
    {'number': '5', 'label': 'Client Sign-off'},
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
    // Load templates from template library
    _loadTemplatesFromLibrary();
  }

  Future<void> _loadTemplatesFromLibrary() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final app = context.read<AppState>();
      await app.fetchTemplates();
      final fetched = app.templates
          .map((raw) => Template.fromJson(
              Map<String, dynamic>.from(raw as Map<String, dynamic>)))
          .where((template) => template.isApproved && template.isPublic)
          .toList();

      setState(() {
        _availableTemplates = fetched;
        _isLoadingTemplates = false;
      });
    } catch (e) {
      setState(() => _isLoadingTemplates = false);
      print('Error loading templates: $e');
    }
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
    return _workflowSteps[step]['label'] ?? '';
  }

  void _selectTemplate(String templateId) {
    setState(() {
      _formData['templateId'] = templateId;
      final template = _availableTemplates.firstWhere(
        (t) => t.id == templateId,
        orElse: () => _availableTemplates.isNotEmpty
            ? _availableTemplates[0]
            : Template(
                id: '',
                name: '',
                templateType: '',
                templateKey: '',
                approvalStatus: '',
                isPublic: false,
                isApproved: false,
                version: 1,
                sections: [],
                dynamicFields: [],
                usageCount: 0,
                createdBy: '',
                createdDate: DateTime.now(),
              ),
      );
      _formData['templateType'] = template.templateType;
      _formData['templateKey'] = template.templateKey ?? template.id;
      _selectedTemplate = template;

      final List<String> requiredModules = template.sections
          .where((section) => section.required)
          .map((section) => section.key ?? _slugify(section.title))
          .whereType<String>()
          .where((key) => key.isNotEmpty)
          .toList();
      if (requiredModules.isNotEmpty) {
        _formData['selectedModules'] = requiredModules;
      }

      final contents =
          Map<String, String>.from(_formData['moduleContents'] ?? {});
      for (final section in template.sections) {
        final key = section.key ?? _slugify(section.title);
        final defaultContent = section.defaultContent ?? '';
        if (key.isNotEmpty && defaultContent.isNotEmpty) {
          contents[key] = defaultContent;
        }
      }
      _formData['moduleContents'] = contents;
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
      case 0: // Compose - Template Selection
        return _formData['templateId'].toString().isNotEmpty;
      case 1: // Govern - Client Details
        return (_formData['proposalTitle'] ?? '').toString().isNotEmpty &&
            (_formData['clientName'] ?? '').toString().isNotEmpty &&
            (_formData['opportunityName'] ?? '').toString().isNotEmpty;
      case 2: // AI Risk Gate - Project Details
        return (_formData['projectType'] ?? '').toString().isNotEmpty;
      case 3: // Internal Sign-off - Content Selection
        return _formData['selectedModules'].isNotEmpty;
      case 4: // Client Sign-off - Review
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
      final extraData = {
        'client_name': _formData['clientName'],
        'client_email': _formData['clientEmail'],
        'template_id': _formData['templateId'],
        'template_key': _formData['templateKey'],
        'selected_modules': _formData['selectedModules'],
        'module_contents': _formData['moduleContents'],
        'project_type': _formData['projectType'],
        'estimated_value': _formData['estimatedValue'],
        'timeline': _formData['timeline'],
        'opportunity_name': _formData['opportunityName'],
      };

      final created = await app.createProposal(
        _formData['opportunityName'],
        _formData['clientName'],
        templateKey: _selectedTemplate?.templateType,
        extraData: extraData,
      );

      if (created == null) {
        throw Exception('Unable to create proposal');
      }

      _proposalId = created['id']?.toString();

      // Navigate to enhanced compose page
      Navigator.pushReplacementNamed(
        context,
        '/enhanced-compose',
        arguments: {
          'proposalId': _proposalId ?? '',
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
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/Global BG.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.35),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 24),
                  // Proposal Workflow
                  GlassContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proposal Workflow',
                          style: PremiumTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: _workflowSteps.map((step) {
                            final stepIndex = _workflowSteps.indexOf(step);
                            return _buildWorkflowStep(
                              step['number']!,
                              step['label']!,
                              stepIndex,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Content area
                  Expanded(
                    child: GlassContainer(
                      borderRadius: 32,
                      padding: const EdgeInsets.all(24),
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          SizedBox.expand(
                            child: _buildComposeStep(),
                          ), // Step 1: Compose (combines template, client, project, content)
                          SizedBox.expand(
                            child: _buildGovernStep(),
                          ), // Step 2: Govern
                          SizedBox.expand(
                            child: _buildRiskGateStep(),
                          ), // Step 3: AI Risk Gate
                          SizedBox.expand(
                            child: _buildInternalSignoffStep(),
                          ), // Step 4: Internal Sign-off
                          SizedBox.expand(
                            child: _buildClientSignoffStep(),
                          ), // Step 5: Client Sign-off
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Navigation buttons
                  GlassContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(20),
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Previous',
                              style: PremiumTheme.bodyMedium.copyWith(
                                color: PremiumTheme.textSecondary,
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
                            backgroundColor: PremiumTheme.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  _currentStep == _totalSteps - 1
                                      ? 'Create Proposal'
                                      : 'Next',
                                  style: PremiumTheme.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Proposal',
              style: PremiumTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Step ${_currentStep + 1} of $_totalSteps: ${_getStepTitle(_currentStep)} • ${((_currentStep + 1) / _totalSteps * 100).round()}% Complete',
              style: PremiumTheme.bodyMedium,
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed('/dashboard'),
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          label: Text(
            'Back to Dashboard',
            style: PremiumTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewPage() {
    // Get template details from library
    final templateId = _formData['templateId']?.toString() ?? '';
    final template = _availableTemplates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => Template(
        id: '',
        name: 'Unknown Template',
        templateType: '',
        templateKey: '',
        approvalStatus: '',
        isPublic: false,
        isApproved: false,
        version: 1,
        sections: [],
        dynamicFields: [],
        usageCount: 0,
        createdBy: '',
        createdDate: DateTime.now(),
      ),
    );

    // Get selected modules with names instead of IDs
    final selectedModuleIds =
        List<String>.from(_formData['selectedModules'] ?? []);
    final selectedModules = _contentModules
        .where((m) => selectedModuleIds.contains(m['id']))
        .map((m) => m['name'] as String)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & Create',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Review your proposal details and create',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CustomScrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proposal Summary',
                      style: PremiumTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildReviewRow('Template:', template.name),
                    _buildReviewRow('Client:', _formData['clientName'] ?? ''),
                    _buildReviewRow(
                        'Project:', _formData['opportunityName'] ?? ''),
                    _buildReviewRow(
                        'Modules:', '${selectedModules.length} selected'),
                    const SizedBox(height: 24),
                    Text(
                      'Next Steps',
                      style: PremiumTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildNextStepItem(
                        '• Your proposal will be created in draft status',
                        PremiumTheme.info),
                    _buildNextStepItem(
                        '• You can continue editing and adding content',
                        PremiumTheme.info),
                    _buildNextStepItem(
                        '• Submit for approval when ready', PremiumTheme.info),
                    _buildNextStepItem(
                        '• Track progress through the approval workflow',
                        PremiumTheme.info),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: PremiumTheme.bodyMedium.copyWith(
                color: PremiumTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: PremiumTheme.bodyMedium.copyWith(
                color: PremiumTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextStepItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: PremiumTheme.bodyMedium.copyWith(
          color: color,
          height: 1.5,
        ),
      ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Content',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Fill in the selected sections (you can complete this later)',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CustomScrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                        Text(
                          module['name'] ?? '',
                          style: PremiumTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlassContainer(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: controller,
                                style: PremiumTheme.bodyMedium.copyWith(
                                  color: PremiumTheme.textPrimary,
                                ),
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
                                  hintStyle: PremiumTheme.bodyMedium.copyWith(
                                    color: PremiumTheme.textTertiary,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () =>
                                        _openContentLibraryAndInsert(moduleId),
                                    icon: Icon(
                                      Icons.library_books_outlined,
                                      color: PremiumTheme.teal,
                                    ),
                                    label: Text(
                                      'Insert from Library',
                                      style: PremiumTheme.bodyMedium.copyWith(
                                        color: PremiumTheme.teal,
                                      ),
                                    ),
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
        ),
      ],
    );
  }

  Widget _buildWorkflowStep(String number, String label, int stepIndex) {
    final isActive = stepIndex <= _currentStep;
    final isCompleted = stepIndex < _currentStep;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (stepIndex <= _currentStep || isCompleted) {
            setState(() => _currentStep = stepIndex);
            _pageController.jumpToPage(stepIndex);
          }
        },
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted
                    ? PremiumTheme.success
                    : isActive
                        ? const Color(0xFFEAF2F8) // Light blue background
                        : const Color(0xFFEAF2F8).withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted
                      ? PremiumTheme.success
                      : PremiumTheme.info, // Blue border
                  width: 1.5,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        number,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? PremiumTheme.info // Blue text
                              : PremiumTheme.info.withOpacity(0.6),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: PremiumTheme.bodyMedium.copyWith(
                color: isActive
                    ? PremiumTheme.textPrimary
                    : PremiumTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Compose - Combines template selection, client details, project details, content selection, and content editor
  Widget _buildComposeStep() {
    return _buildTemplateSelection(); // For now, start with template selection - we'll make this a multi-tab step
  }

  // Step 2: Govern - Governance checklist (AI-run)
  Widget _buildGovernStep() {
    // Auto-run governance check when step is reached
    if (_governanceResults.isEmpty &&
        !_isRunningGovernance &&
        _currentStep == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runGovernanceCheck();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Governance Check',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'AI-powered compliance and governance analysis',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CustomScrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: _buildGovernanceResults(),
            ),
          ),
        ),
      ],
    );
  }

  // Step 3: AI Risk Gate
  Widget _buildRiskGateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Risk Assessment',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Automated risk analysis and recommendations',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CustomScrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: _buildRiskAssessment(),
            ),
          ),
        ),
      ],
    );
  }

  // Step 4: Internal Sign-off
  Widget _buildInternalSignoffStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Internal Sign-off',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Submit for internal review and approval',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CustomScrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: _buildInternalApproval(),
            ),
          ),
        ),
      ],
    );
  }

  // Step 5: Client Sign-off
  Widget _buildClientSignoffStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client Sign-off',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Send proposal to client for review and signature',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CustomScrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: _buildClientSignature(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateSelection() {
    if (_isLoadingTemplates) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.teal),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Template from Library',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a template from the template library to start your proposal',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _availableTemplates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.library_books_outlined,
                        size: 64,
                        color: PremiumTheme.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No templates available',
                        style: PremiumTheme.titleMedium.copyWith(
                          color: PremiumTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/template_library');
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Go to Template Library'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumTheme.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : CustomScrollbar(
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: crossAxisCount == 1 ? 3 : 1.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _availableTemplates.length,
                      itemBuilder: (context, index) {
                        final template = _availableTemplates[index];
                        final isSelected =
                            _formData['templateId'] == template.id;
                        final color = template.templateType == 'sow'
                            ? const Color(0xFF2ECC71)
                            : template.templateType == 'rfi'
                                ? const Color(0xFFE74C3C)
                                : const Color(0xFF3498DB);

                        return GestureDetector(
                          onTap: () => _selectTemplate(template.id),
                          child: GlassContainer(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(20),
                            gradientStart: isSelected ? color : null,
                            gradientEnd: isSelected ? color : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    template.templateType == 'sow'
                                        ? Icons.work_outline
                                        : template.templateType == 'rfi'
                                            ? Icons.quiz_outlined
                                            : Icons.description_outlined,
                                    color: color,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        template.name,
                                        style: PremiumTheme.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: PremiumTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        template.description ?? '',
                                        style: PremiumTheme.bodyMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${template.sections.length} sections',
                                        style: PremiumTheme.labelMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: PremiumTheme.success,
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
        ),
      ],
    );
  }

  Widget _buildClientDetails() {
    // Initialize controllers with current values and explicit LTR direction
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
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client & Opportunity Details',
              style: PremiumTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter client information and opportunity details',
              style: PremiumTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: CustomScrollbar(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                              (value) => setState(
                                  () => _formData['clientName'] = value),
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
                        (value) => setState(
                            () => _formData['opportunityName'] = value),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Details',
            style: PremiumTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Specify project type, value, and timeline',
            style: PremiumTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: CustomScrollbar(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content Modules',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Select content modules to include in your proposal',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CustomScrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Required modules
                  Text(
                    'Required Modules',
                    style: PremiumTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...requiredModules
                      .map((module) => _buildModuleCard(module, true)),
                  const SizedBox(height: 24),

                  // Optional modules
                  Text(
                    'Optional Modules',
                    style: PremiumTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...optionalModules
                      .map((module) => _buildModuleCard(module, false)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module, bool isRequired) {
    final isSelected = _formData['selectedModules'].contains(module['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        gradientStart: isSelected ? PremiumTheme.teal : null,
        gradientEnd: isSelected ? PremiumTheme.teal : null,
        child: CheckboxListTile(
          title: Text(
            module['name'],
            style: PremiumTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: PremiumTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            module['description'],
            style: PremiumTheme.bodyMedium,
          ),
          value: isRequired || isSelected,
          onChanged: isRequired ? null : (value) => _toggleModule(module['id']),
          activeColor: PremiumTheme.teal,
          checkColor: Colors.white,
          controlAffinity: ListTileControlAffinity.leading,
          secondary: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: module['category'] == 'Company'
                  ? PremiumTheme.info.withOpacity(0.2)
                  : module['category'] == 'Project'
                      ? PremiumTheme.success.withOpacity(0.2)
                      : module['category'] == 'Legal'
                          ? PremiumTheme.error.withOpacity(0.2)
                          : PremiumTheme.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              module['category'],
              style: PremiumTheme.labelMedium.copyWith(
                color: module['category'] == 'Company'
                    ? PremiumTheme.info
                    : module['category'] == 'Project'
                        ? PremiumTheme.success
                        : module['category'] == 'Legal'
                            ? PremiumTheme.error
                            : PremiumTheme.purple,
              ),
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
    // Ensure controller text direction is LTR
    if (controller != null && controller.text.isNotEmpty) {
      // Force LTR by updating the selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.text.isNotEmpty) {
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
      });
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextFormField(
        controller: controller,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
        style: PremiumTheme.bodyMedium.copyWith(
          color: PremiumTheme.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: PremiumTheme.bodyMedium.copyWith(
            color: PremiumTheme.textSecondary,
          ),
          hintStyle: PremiumTheme.bodyMedium.copyWith(
            color: PremiumTheme.textTertiary,
          ),
          prefixIcon: Icon(icon, color: PremiumTheme.teal),
          filled: true,
          fillColor: PremiumTheme.glassWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PremiumTheme.glassWhiteBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PremiumTheme.glassWhiteBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PremiumTheme.teal, width: 2),
          ),
        ),
        keyboardType: keyboardType,
        onChanged: onChanged,
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DropdownButtonFormField<String>(
        initialValue: value?.isEmpty == true ? null : value,
        style: PremiumTheme.bodyMedium.copyWith(
          color: PremiumTheme.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: PremiumTheme.bodyMedium.copyWith(
            color: PremiumTheme.textSecondary,
          ),
          hintStyle: PremiumTheme.bodyMedium.copyWith(
            color: PremiumTheme.textTertiary,
          ),
          prefixIcon: Icon(icon, color: PremiumTheme.teal),
          filled: true,
          fillColor: PremiumTheme.glassWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PremiumTheme.glassWhiteBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PremiumTheme.glassWhiteBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: PremiumTheme.teal, width: 2),
          ),
        ),
        dropdownColor: PremiumTheme.darkBg2,
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                option,
                style: PremiumTheme.bodyMedium,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) => onChanged(value ?? ''),
      ),
    );
  }

  // Governance Results Builder (AI-run)
  Widget _buildGovernanceResults() {
    if (_isRunningGovernance) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.teal),
          ),
          const SizedBox(height: 24),
          Text(
            'Running AI Governance Check...',
            style: PremiumTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing proposal compliance and requirements',
            style: PremiumTheme.bodyMedium.copyWith(
              color: PremiumTheme.textSecondary,
            ),
          ),
        ],
      );
    }

    if (_governanceResults.isEmpty) {
      return Column(
        children: [
          GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 64,
                  color: PremiumTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Run Governance Check',
                  style: PremiumTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Click the button below to analyze your proposal for governance compliance',
                  style: PremiumTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _runGovernanceCheck,
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Run Governance Check'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final status = _governanceResults['status'] ?? 'PENDING';
    final num scoreValue = _governanceResults['score'] is num
        ? _governanceResults['score']
        : 0;
    final scoreText = scoreValue.toStringAsFixed(0);
    final issuesRaw = (_governanceResults['issues'] as List?) ?? [];
    final actions =
        List<String>.from(_governanceResults['required_actions'] ?? []);
    final issues = issuesRaw
        .map((issue) => issue is Map<String, dynamic>
            ? (issue['description'] ??
                issue['section'] ??
                issue.toString())
            : issue.toString())
        .toList();
    final passed = status == 'PASSED';

    Color statusColor = PremiumTheme.success;
    if (status == 'FAILED') statusColor = PremiumTheme.error;
    if (status == 'PENDING') statusColor = Colors.orange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact Status Summary
        GlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                passed ? Icons.check_circle : Icons.warning_amber_rounded,
                color: statusColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $status',
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Score: $scoreText%',
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: PremiumTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _runGovernanceCheck,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Re-run'),
                style: TextButton.styleFrom(
                  foregroundColor: PremiumTheme.teal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Issues/Recommendations (Compact)
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Issues',
            style: PremiumTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...issues.map<Widget>((issue) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GlassContainer(
                  borderRadius: 12,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: PremiumTheme.info,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          issue.toString(),
                          style: PremiumTheme.bodyMedium.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Required Actions',
            style: PremiumTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GlassContainer(
                borderRadius: 12,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.checklist_rtl,
                      color: PremiumTheme.info,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action,
                        style: PremiumTheme.bodyMedium.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Risk Assessment Builder
  Widget _buildRiskAssessment() {
    final hasRiskData = _riskAssessment.isNotEmpty;

    if (_isAnalyzingRisk) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(PremiumTheme.teal),
          ),
          const SizedBox(height: 16),
          Text(
            'Running AI Risk Assessment...',
            style: PremiumTheme.bodyMedium,
          ),
        ],
      );
    }

    if (!hasRiskData) {
      return Column(
        children: [
          GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.assessment_outlined,
                  size: 64,
                  color: PremiumTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Run Risk Assessment',
                  style: PremiumTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Click the button below to analyze your proposal for risks',
                  style: PremiumTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _runRiskAssessment,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Run Risk Assessment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final riskLevel =
        _riskAssessment['risk_level'] ?? _riskAssessment['riskLevel'] ?? 'Low';
    final num riskScore = _riskAssessment['risk_score'] is num
        ? _riskAssessment['risk_score']
        : 0;
    final issuesRaw = (_riskAssessment['issues'] as List?) ??
        (_riskAssessment['risks'] as List?) ??
        [];
    final recommendations =
        (_riskAssessment['recommendations'] as List?) ??
            (_riskAssessment['required_actions'] as List?) ??
            [];
    final issues = issuesRaw
        .map((issue) => issue is Map<String, dynamic>
            ? (issue['description'] ??
                issue['section'] ??
                issue.toString())
            : issue.toString())
        .toList();

    Color riskColor = PremiumTheme.success;
    if (riskLevel == 'Medium') riskColor = Colors.orange;
    if (riskLevel == 'High') riskColor = PremiumTheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Risk Summary Card
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: riskColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Risk Level: $riskLevel',
                          style: PremiumTheme.titleMedium.copyWith(
                            color: riskColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Risk Score: ${riskScore.toStringAsFixed(0)}/100',
                          style: PremiumTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Identified Risks
        if (issues.isNotEmpty) ...[
          Text(
            'Identified Risks',
            style: PremiumTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...issues.map<Widget>((risk) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        color: PremiumTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          risk.toString(),
                          style: PremiumTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ],
        // Recommendations
        if (recommendations.isNotEmpty) ...[
          Text(
            'Recommendations',
            style: PremiumTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...recommendations.map<Widget>((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: PremiumTheme.info,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          rec.toString(),
                          style: PremiumTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ],
    );
  }

  // Internal Approval Builder
  Widget _buildInternalApproval() {
    return Column(
      children: [
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submit for Internal Approval',
                style: PremiumTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Before submitting, ensure:',
                style: PremiumTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildApprovalChecklistItem('✓ Governance checks passed'),
              _buildApprovalChecklistItem('✓ Risk assessment completed'),
              _buildApprovalChecklistItem('✓ All required sections complete'),
              _buildApprovalChecklistItem('✓ Content reviewed for accuracy'),
              const SizedBox(height: 24),
              if (_isInternalApproved)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PremiumTheme.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PremiumTheme.success),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: PremiumTheme.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Approved internally',
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: PremiumTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _submitForInternalApproval,
                  icon: const Icon(Icons.send),
                  label: const Text('Submit for Approval'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              color: PremiumTheme.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: PremiumTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // Client Signature Builder
  Widget _buildClientSignature() {
    return Column(
      children: [
        GlassContainer(
          borderRadius: 24,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send to Client',
                style: PremiumTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Client Information:',
                style: PremiumTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                  'Name:', _formData['clientName'] ?? 'Not specified'),
              _buildInfoRow(
                  'Email:', _formData['clientEmail'] ?? 'Not specified'),
              const SizedBox(height: 24),
              if (_isClientSigned)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PremiumTheme.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PremiumTheme.success),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: PremiumTheme.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Proposal signed by client',
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: PremiumTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _sendToClient,
                  icon: const Icon(Icons.send),
                  label: const Text('Send to Client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: PremiumTheme.bodyMedium.copyWith(
                color: PremiumTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: PremiumTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Action Methods
  Future<void> _runRiskAssessment() async {
    await _runAnalysis(governance: false);
  }

  Future<void> _runGovernanceCheck() async {
    await _runAnalysis(governance: true);
  }

  Future<void> _runAnalysis({required bool governance}) async {
    if (governance) {
      setState(() => _isRunningGovernance = true);
    } else {
      setState(() => _isAnalyzingRisk = true);
    }

    try {
      final app = context.read<AppState>();
      final payload = _buildAnalysisPayload();
      final result = await app.analyzeProposalAI(payload);
      if (result != null) {
        setState(() {
          _governanceResults =
              Map<String, dynamic>.from(result['governance'] ?? {});
          _riskAssessment =
              Map<String, dynamic>.from(result['analysis'] ?? {});
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    } finally {
      if (governance) {
        setState(() => _isRunningGovernance = false);
      } else {
        setState(() => _isAnalyzingRisk = false);
      }
    }
  }

  Map<String, dynamic> _buildAnalysisPayload() {
    final modules = List<String>.from(_formData['selectedModules'] ?? []);
    final moduleContents =
        Map<String, String>.from(_formData['moduleContents'] ?? {});
    final sections = modules
        .map((moduleId) => {
              'key': moduleId,
              'title': _moduleLabel(moduleId),
              'content': moduleContents[moduleId] ?? ''
            })
        .toList();
    return {
      'proposal_id': _proposalId,
      'title': _formData['opportunityName'],
      'client_name': _formData['clientName'],
      'client_email': _formData['clientEmail'],
      'project_type': _formData['projectType'],
      'estimated_value': _formData['estimatedValue'],
      'timeline': _formData['timeline'],
      'selected_modules': modules,
      'module_contents': moduleContents,
      'sections': sections,
    };
  }

  Future<void> _submitForInternalApproval() async {
    setState(() => _isLoading = true);

    try {
      // Check if governance passed
      final governanceStatus = _governanceResults['status'] as String?;

      if (governanceStatus != 'PASSED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Governance check must pass before submitting for approval'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Simulate API call - replace with actual
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isInternalApproved = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal submitted for internal approval'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting for approval: $e')),
      );
    }
  }

  Future<void> _sendToClient() async {
    if (!_isInternalApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete internal approval first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate API call - replace with actual
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isClientSigned = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal sent to client successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending to client: $e')),
      );
    }
  }

  String _moduleLabel(String moduleId) {
    final match = _contentModules.firstWhere(
      (module) => module['id'] == moduleId,
      orElse: () => {'name': moduleId},
    );
    return (match['name'] ?? moduleId).toString();
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+'), '')
        .replaceAll(RegExp(r'_+$'), '');
  }
}
