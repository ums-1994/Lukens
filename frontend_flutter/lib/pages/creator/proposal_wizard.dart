import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/ai_analysis_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import 'content_library_dialog.dart';
import 'template_library_page.dart';
import 'blank_document_editor/services/document_proposal_service.dart';

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

  // Form data
  final Map<String, dynamic> _formData = {
    'templateId': '',
    'templateType': '',
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

  // Scroll controllers
  final ScrollController _composeScrollController = ScrollController();
  final ScrollController _governScrollController = ScrollController();
  final ScrollController _riskScrollController = ScrollController();
  final ScrollController _internalSignoffScrollController = ScrollController();

  // Workflow steps matching the image
  final List<Map<String, String>> _workflowSteps = [
    {'number': '1', 'label': 'Compose'},
    {'number': '2', 'label': 'Govern'},
    {'number': '3', 'label': 'AI Risk Gate'},
    {'number': '4', 'label': 'Preview'},
    {'number': '5', 'label': 'Internal Sign-off'},
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
    final allModuleIds = _contentModules.map((m) => m['id'] as String).toList();
    _formData['selectedModules'] = List<String>.from(allModuleIds);
    // initialize module contents map
    _formData['moduleContents'] = <String, String>{};
    // Load templates from template library
    _loadTemplatesFromLibrary();
  }

  Future<void> _loadTemplatesFromLibrary() async {
    setState(() => _isLoadingTemplates = true);
    try {
      // For now, use mock templates similar to template_library_page
      // In the future, this should fetch from an API
      await Future.delayed(const Duration(milliseconds: 500));

      // Mock templates - in production, fetch from API
      final mockTemplates = [
        Template(
          id: '1',
          name: 'Consulting & Technology Delivery Proposal Template',
          description: 'Complete proposal template with all 11 sections',
          templateType: 'proposal',
          approvalStatus: 'approved',
          isPublic: true,
          isApproved: true,
          version: 1,
          sections: [
            TemplateSection(title: 'Cover Page', required: true),
            TemplateSection(title: 'Executive Summary', required: true),
            TemplateSection(title: 'Problem Statement', required: true),
            TemplateSection(title: 'Scope of Work', required: true),
            TemplateSection(title: 'Project Timeline', required: true),
            TemplateSection(title: 'Team & Bios', required: true),
            TemplateSection(title: 'Delivery Approach', required: true),
            TemplateSection(title: 'Pricing Table', required: true),
            TemplateSection(title: 'Risks & Mitigation', required: true),
            TemplateSection(title: 'Governance Model', required: true),
            TemplateSection(
                title: 'Appendix – Company Profile', required: true),
          ],
          dynamicFields: [],
          usageCount: 0,
          createdBy: 'admin@khonology.com',
          createdDate: DateTime.now(),
        ),
        Template(
          id: '2',
          name: 'Standard Proposal Template',
          description: 'Comprehensive proposal template for enterprise clients',
          templateType: 'proposal',
          approvalStatus: 'approved',
          isPublic: true,
          isApproved: true,
          version: 2,
          sections: [
            TemplateSection(title: 'Executive Summary', required: true),
            TemplateSection(title: 'Company Profile', required: true),
            TemplateSection(title: 'Scope & Deliverables', required: true),
          ],
          dynamicFields: [],
          usageCount: 15,
          createdBy: 'admin@khonology.com',
          createdDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
        Template(
          id: '3',
          name: 'Statement of Work (SOW) Template',
          description: 'Complete SOW template with all sections',
          templateType: 'sow',
          approvalStatus: 'approved',
          isPublic: true,
          isApproved: true,
          version: 1,
          sections: [
            TemplateSection(title: 'Project Overview', required: true),
            TemplateSection(title: 'Scope of Work', required: true),
            TemplateSection(title: 'Deliverables', required: true),
            TemplateSection(title: 'Timeline & Milestones', required: true),
            TemplateSection(title: 'Resources & Team', required: true),
            TemplateSection(title: 'Terms & Conditions', required: true),
          ],
          dynamicFields: [],
          usageCount: 8,
          createdBy: 'admin@khonology.com',
          createdDate: DateTime.now().subtract(const Duration(days: 15)),
        ),
      ];

      setState(() {
        _availableTemplates =
            mockTemplates.where((t) => t.isApproved && t.isPublic).toList();
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
    _composeScrollController.dispose();
    _governScrollController.dispose();
    _riskScrollController.dispose();
    _internalSignoffScrollController.dispose();
    super.dispose();
  }

  void _nextStep() async {
    // Step index 2 is the AI Risk Gate - show strong warning but allow override
    if (_currentStep == 2) {
      final proceed = await _handleRiskGateOverride();
      if (!proceed) {
        return;
      }
    }

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

  Future<bool> _handleRiskGateOverride() async {
    // Require a risk assessment before leaving the AI Risk Gate step
    if (_riskAssessment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Run AI Risk Assessment before proceeding.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    final String aiStatus =
        (_riskAssessment['ai_status'] ?? '').toString().toUpperCase();
    final String riskLevel =
        (_riskAssessment['risk_level'] ?? '').toString().toUpperCase();

    final bool isBlocked = aiStatus == 'BLOCKED' || riskLevel == 'HIGH';

    // For low/medium risk we allow progression without extra confirmation
    if (!isBlocked) {
      return true;
    }

    final riskScore = _riskAssessment['risk_score'] ?? 0;
    final risks = List.from(_riskAssessment['risks'] ?? const []);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('AI Risk Gate Warning'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI has flagged this proposal as HIGH RISK or BLOCKED.',
                  style: PremiumTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Risk Level: ${_riskAssessment['risk_level'] ?? 'High'}',
                  style: PremiumTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Risk Score: ${riskScore.toStringAsFixed(0)}/100',
                  style: PremiumTheme.bodyMedium,
                ),
                if (risks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Key risks identified:',
                    style: PremiumTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...risks.take(3).map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${r.toString()}'),
                      )),
                ],
                const SizedBox(height: 16),
                Text(
                  'Proceeding may violate internal governance or expose the client to unmanaged risk. Only override if you are confident the issues are understood and accepted.',
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: PremiumTheme.error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Override and Proceed'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
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
      // When a template is selected, make all content modules available
      final allModuleIds =
          _contentModules.map((m) => m['id'] as String).toList();
      _formData['selectedModules'] = allModuleIds;
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

  Map<String, dynamic> _calculateComposeReadiness() {
    final missing = <String>[];
    int completed = 0;
    int total = 0;

    void checkField(String key, String label) {
      total++;
      final value = _formData[key]?.toString().trim() ?? '';
      if (value.isEmpty) {
        missing.add(label);
      } else {
        completed++;
      }
    }

    // Template selection
    checkField('templateId', 'Template');

    // Client details
    checkField('clientName', 'Client Name');
    checkField('clientEmail', 'Client Email');
    checkField('clientHolding', 'Client Holding / Group');
    checkField('clientAddress', 'Client Address');
    checkField('clientContactName', 'Client Contact Name');
    checkField('clientContactEmail', 'Client Contact Email');
    checkField('clientContactMobile', 'Client Contact Mobile');

    // Engagement details
    checkField('opportunityName', 'Project / Opportunity Name');
    checkField('projectType', 'Engagement Type');
    checkField('estimatedValue', 'Estimated Value');
    checkField('timeline', 'Timeline');

    // Required content modules must be selected
    final requiredModules =
        _contentModules.where((m) => m['required'] == true).toList();
    final selectedIds =
        List<String>.from(_formData['selectedModules'] ?? const []);
    for (final module in requiredModules) {
      total++;
      final id = module['id'] as String;
      final name = (module['name'] as String?) ?? id;
      if (selectedIds.contains(id)) {
        completed++;
      } else {
        missing.add('Required section: $name');
      }
    }

    final int score = total == 0 ? 0 : ((completed / total) * 100).round();

    return {
      'score': score,
      'missing': missing,
    };
  }

  bool _isComposeStepValid() {
    final readiness = _calculateComposeReadiness();
    final List<String> missing =
        List<String>.from(readiness['missing'] ?? const <String>[]);
    return missing.isEmpty;
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Compose - require core setup before moving on
        return _isComposeStepValid();
      case 1: // Govern - require AI governance results
        return _governanceResults.isNotEmpty;
      case 2: // AI Risk Gate - require risk assessment to have run
        return _riskAssessment.isNotEmpty;
      case 3: // Preview - review step
        return true;
      case 4: // Internal Sign-off - require internal approval flag
        return _isInternalApproved;
      default:
        return false;
    }
  }

  Future<void> _createProposal() async {
    setState(() => _isLoading = true);

    try {
      final app = context.read<AppState>();

      // Create proposal in backend so that downstream flows have a real ID
      final created = await app.createProposal(
        _formData['opportunityName'],
        _formData['clientName'],
        templateKey: _formData['templateId']?.toString().isNotEmpty == true
            ? _formData['templateId'].toString()
            : null,
      );

      final proposalId = (created != null && created['id'] != null)
          ? created['id'].toString()
          : 'draft-${DateTime.now().millisecondsSinceEpoch}';

      _proposalId = proposalId;

      // Build initial proposal data to seed EnhancedCompose
      final Map<String, String> moduleContents =
          Map<String, String>.from(_formData['moduleContents'] ?? {});

      final Map<String, dynamic> initialData = {
        'clientName': _formData['clientName'] ?? '',
        'clientEmail': _formData['clientEmail'] ?? '',
        'projectType': _formData['projectType'] ?? '',
        'estimatedValue': _formData['estimatedValue'] ?? '',
        'timeline': _formData['timeline'] ?? '',
        'opportunityName': _formData['opportunityName'] ?? '',
      };

      moduleContents.forEach((key, value) {
        initialData[key] = value;
      });

      final proposalTitle =
          (_formData['proposalTitle']?.toString().isNotEmpty ?? false)
              ? _formData['proposalTitle'].toString()
              : _formData['opportunityName'];

      // Navigate to enhanced compose page
      Navigator.pushReplacementNamed(
        context,
        '/enhanced-compose',
        arguments: {
          'proposalId': proposalId,
          'proposalTitle': proposalTitle,
          'templateType': _formData['templateType'],
          'selectedModules': _formData['selectedModules'],
          'initialData': initialData,
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
                            child: _buildReviewPage(),
                          ), // Step 4: Preview
                          SizedBox.expand(
                            child: _buildInternalSignoffStep(),
                          ), // Step 5: Internal Sign-off
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

  String? _mapSectionTitleToModuleId(String title) {
    switch (title) {
      case 'Executive Summary':
        return 'executive_summary';
      case 'Scope & Deliverables':
      case 'Scope of Work':
        return 'scope_deliverables';
      case 'Company Profile':
      case 'Appendix – Company Profile':
        return 'company_profile';
      case 'Terms & Conditions':
        return 'terms_conditions';
      case 'Assumptions & Risks':
      case 'No Assumptions Section':
        return 'assumptions_risks';
      case 'Team & Bios':
      case 'Team Bios':
        return 'team_bios';
      case 'Delivery Approach':
        return 'delivery_approach';
      case 'Case Studies':
        return 'case_studies';
      default:
        return null;
    }
  }

  Widget _buildHeader() {
    final templateType = (_formData['templateType'] as String?) ?? '';
    String documentLabel;
    switch (templateType.toLowerCase()) {
      case 'sow':
        documentLabel = 'Statement of Work (SOW)';
        break;
      case 'rfi':
        documentLabel = 'Request for Information (RFI)';
        break;
      default:
        documentLabel = 'Proposal';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New $documentLabel',
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
    final proposalTitle =
        (_formData['proposalTitle']?.toString().isNotEmpty ?? false)
            ? _formData['proposalTitle'].toString()
            : 'Untitled Proposal';
    final clientName = (_formData['clientName']?.toString().isNotEmpty ?? false)
        ? _formData['clientName'].toString()
        : 'Client Name';
    final opportunityName =
        (_formData['opportunityName']?.toString().isNotEmpty ?? false)
            ? _formData['opportunityName'].toString()
            : null;

    final selectedModuleIds =
        List<String>.from(_formData['selectedModules'] ?? const []);
    final moduleContents =
        Map<String, String>.from(_formData['moduleContents'] ?? {});

    final date = DateTime.now();
    final dateLabel = '${date.day}/${date.month}/${date.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document Preview',
          style: PremiumTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Review the proposal as your client will see it',
          style: PremiumTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: CustomScrollbar(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              proposalTitle,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Prepared for: $clientName',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            if (opportunityName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                opportunityName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              'Date: $dateLabel',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Content sections
                      ...selectedModuleIds.map((moduleId) {
                        final module = _contentModules.firstWhere(
                          (m) => m['id'] == moduleId,
                          orElse: () => {
                            'id': moduleId,
                            'name': moduleId.toString().replaceAll('_', ' '),
                          },
                        );

                        final title =
                            module['name']?.toString() ?? moduleId.toString();
                        final content = moduleContents[moduleId] ?? '';

                        if (content.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                content,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2C3E50),
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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

      var raw = (selected['content'] ?? '').toString();
      raw = raw.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
      raw = raw.replaceAll(RegExp(r'<[^>]+>'), '');
      raw = raw.replaceAll(RegExp(r'\s+'), ' ');

      contents[moduleId] = raw.trim();
      setState(() {
        _formData['moduleContents'] = contents;
      });
    }
  }

  Future<void> _showGeneratedContentDialog(
      String moduleId, String content) async {
    final module = _contentModules.firstWhere(
      (m) => m['id'] == moduleId,
      orElse: () => {
        'id': moduleId,
        'name': moduleId.replaceAll('_', ' '),
      },
    );

    final title = module['name']?.toString() ?? moduleId.replaceAll('_', ' ');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController(text: content);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: GlassContainer(
            borderRadius: 24,
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 700,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI content for $title',
                    style: PremiumTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 260,
                    child: CustomScrollbar(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: TextFormField(
                          controller: controller,
                          maxLines: null,
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: PremiumTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                'Review or refine the AI-generated content before saving...',
                            hintStyle: PremiumTheme.bodyMedium.copyWith(
                              color: PremiumTheme.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          final updated = controller.text;
                          setState(() {
                            final Map<String, String> contents =
                                Map<String, String>.from(
                                    _formData['moduleContents'] ?? {});
                            contents[moduleId] = updated;
                            _formData['moduleContents'] = contents;
                          });
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('Save'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          final updated = controller.text;
                          setState(() {
                            final Map<String, String> contents =
                                Map<String, String>.from(
                                    _formData['moduleContents'] ?? {});
                            contents[moduleId] = updated;
                            _formData['moduleContents'] = contents;
                            _currentStep = 0;
                            _pageController.jumpToPage(0);
                          });
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text('Save & Edit in Compose'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _ensureModuleSelected(String moduleId) {
    final modules = List<String>.from(_formData['selectedModules'] ?? []);
    if (!modules.contains(moduleId)) {
      modules.add(moduleId);
      setState(() {
        _formData['selectedModules'] = modules;
      });
    }
  }

  Future<void> _addModuleWithAI(String moduleId) async {
    _ensureModuleSelected(moduleId);

    final app = context.read<AppState>();
    if (app.authToken != null) {
      AIAnalysisService.setAuthToken(app.authToken!);
    }

    final contextData = _buildProposalDataForAI();

    setState(() {
      _isLoading = true;
    });

    try {
      final generated = await AIAnalysisService.generateSection(
        moduleId,
        contextData,
      );

      final Map<String, String> contents =
          Map<String, String>.from(_formData['moduleContents'] ?? {});
      contents[moduleId] = generated;

      setState(() {
        _formData['moduleContents'] = contents;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'AI generated initial content for ${moduleId.replaceAll('_', ' ')}'),
          backgroundColor: PremiumTheme.teal,
        ),
      );

      await _showGeneratedContentDialog(moduleId, generated);

      // If the user is currently on the Govern step, automatically refresh
      // the governance check so "missing section" issues clear once
      // content has been added via AI.
      if (_currentStep == 1) {
        await _runGovernanceCheck();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating AI content: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
    final readiness = _calculateComposeReadiness();
    final int score = (readiness['score'] as int?) ?? 0;
    final List<String> missing =
        List<String>.from(readiness['missing'] ?? const <String>[]);

    Color statusColor;
    String statusLabel;
    if (score >= 90 && missing.isEmpty) {
      statusColor = PremiumTheme.success;
      statusLabel = 'Ready';
    } else if (score >= 60) {
      statusColor = Colors.orange;
      statusLabel = 'Partially ready';
    } else {
      statusColor = PremiumTheme.error;
      statusLabel = 'Not ready';
    }

    return CustomScrollbar(
      controller: _composeScrollController,
      child: SingleChildScrollView(
        controller: _composeScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Readiness summary for the Compose step
            GlassContainer(
              borderRadius: 16,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Compose Readiness',
                        style: PremiumTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$score% • $statusLabel',
                        style: PremiumTheme.bodyMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (score.clamp(0, 100)) / 100.0,
                      backgroundColor: PremiumTheme.glassWhite,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 6,
                    ),
                  ),
                  if (missing.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Missing before you can proceed:',
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: PremiumTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: missing.take(6).map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: PremiumTheme.error.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item,
                            style: PremiumTheme.labelMedium.copyWith(
                              color: PremiumTheme.error,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Sub-tabs for Template, Client, Engagement, and Content
            DefaultTabController(
              length: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: PremiumTheme.textSecondary,
                    indicator: BoxDecoration(
                      color: PremiumTheme.teal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(text: 'Template'),
                      Tab(text: 'Client Info'),
                      Tab(text: 'Engagement'),
                      Tab(text: 'Content'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 500,
                    child: TabBarView(
                      children: [
                        _buildTemplateSelection(),
                        _buildClientDetails(),
                        _buildProjectDetails(),
                        _buildComposeContentStep(),
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
            controller: _governScrollController,
            child: SingleChildScrollView(
              controller: _governScrollController,
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
            controller: _riskScrollController,
            child: SingleChildScrollView(
              controller: _riskScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: _buildRiskAssessment(),
            ),
          ),
        ),
      ],
    );
  }

  // Step 5: Internal Sign-off
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
            controller: _internalSignoffScrollController,
            child: SingleChildScrollView(
              controller: _internalSignoffScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: _buildInternalApproval(),
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
          'Select Template from Library (Wizard v2)',
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
    final clientHoldingController = TextEditingController(
        text: _formData['clientHolding']?.toString() ?? '');
    final clientAddressController = TextEditingController(
        text: _formData['clientAddress']?.toString() ?? '');
    final clientContactNameController = TextEditingController(
        text: _formData['clientContactName']?.toString() ?? '');
    final clientContactEmailController = TextEditingController(
        text: _formData['clientContactEmail']?.toString() ?? '');
    final clientContactMobileController = TextEditingController(
        text: _formData['clientContactMobile']?.toString() ?? '');
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
                        'Client Holding / Group',
                        'Parent company or group',
                        (value) =>
                            setState(() => _formData['clientHolding'] = value),
                        Icons.account_tree_outlined,
                        controller: clientHoldingController,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        'Client Address',
                        'Physical or postal address',
                        (value) =>
                            setState(() => _formData['clientAddress'] = value),
                        Icons.location_on_outlined,
                        controller: clientAddressController,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'Client Contact Name',
                              'Primary contact person',
                              (value) => setState(
                                  () => _formData['clientContactName'] = value),
                              Icons.person_outline,
                              controller: clientContactNameController,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'Client Contact Email',
                              'contact@client.com',
                              (value) => setState(() =>
                                  _formData['clientContactEmail'] = value),
                              Icons.alternate_email,
                              keyboardType: TextInputType.emailAddress,
                              controller: clientContactEmailController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        'Client Contact Mobile',
                        'Mobile number',
                        (value) => setState(
                            () => _formData['clientContactMobile'] = value),
                        Icons.phone_iphone,
                        keyboardType: TextInputType.phone,
                        controller: clientContactMobileController,
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
                      'Select project timeline',
                      (value) => setState(() => _formData['timeline'] = value),
                      Icons.schedule,
                      controller: timelineController,
                      readOnly: true,
                      onTap: () async {
                        final now = DateTime.now();
                        DateTime initialDate = now;
                        final text = timelineController.text.trim();
                        if (text.isNotEmpty) {
                          try {
                            final parts = text.split('/');
                            if (parts.length == 3) {
                              final year = int.parse(parts[0]);
                              final month = int.parse(parts[1]);
                              final day = int.parse(parts[2]);
                              initialDate = DateTime(year, month, day);
                            }
                          } catch (_) {}
                        }

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 10),
                        );

                        if (picked != null) {
                          final y = picked.year.toString().padLeft(4, '0');
                          final m = picked.month.toString().padLeft(2, '0');
                          final d = picked.day.toString().padLeft(2, '0');
                          final formatted = '$y/$m/$d';

                          setState(() {
                            timelineController.text = formatted;
                            _formData['timeline'] = formatted;
                          });
                        }
                      },
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

  Widget _buildComposeContentStep() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildContentSelection(),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _buildContentEditor(),
        ),
      ],
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
    VoidCallback? onTap,
    bool readOnly = false,
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
        onTap: onTap,
        readOnly: readOnly,
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
    final score = _governanceResults['score'] ?? 0;
    final checks = _governanceResults['checks'] ?? [];
    final issues = List.from(_governanceResults['issues'] ?? const []);
    final passed = status == 'Ready';

    Color statusColor = PremiumTheme.success;
    if (status == 'Blocked') statusColor = PremiumTheme.error;
    if (status == 'At Risk' || status == 'PENDING') statusColor = Colors.orange;

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
                      'Score: ${score.toStringAsFixed(0)}%',
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
        // Checklist Results in Compact Grid
        if (checks.isNotEmpty) ...[
          Text(
            'Checklist Results',
            style: PremiumTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              // Use 2 columns for better space utilization
              final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: crossAxisCount == 2 ? 4 : 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: checks.length,
                itemBuilder: (context, index) {
                  final check = checks[index];
                  final checkLabel = check['label'] as String? ?? '';
                  final checkPassed = (check['passed'] as bool?) ?? false;
                  final checkRequired = (check['required'] as bool?) ?? false;

                  return GlassContainer(
                    borderRadius: 12,
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          checkPassed ? Icons.check_circle : Icons.cancel,
                          color: checkPassed
                              ? PremiumTheme.success
                              : PremiumTheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                checkLabel,
                                style: PremiumTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                  decoration: checkPassed
                                      ? null
                                      : TextDecoration.lineThrough,
                                  color: checkPassed
                                      ? PremiumTheme.textPrimary
                                      : PremiumTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (checkRequired && !checkPassed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Required',
                                    style: PremiumTheme.labelMedium.copyWith(
                                      color: PremiumTheme.error,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
        // Issues/Recommendations (Compact)
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Issues & AI Recommendations',
            style: PremiumTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...issues.map<Widget>((raw) {
            // Support both plain-string issues and structured AI issues
            if (raw is! Map<String, dynamic>) {
              return Padding(
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
                          raw.toString(),
                          style: PremiumTheme.bodyMedium.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final issue = raw as Map<String, dynamic>;
            final title = issue['title']?.toString() ?? 'Issue';
            final description = issue['description']?.toString() ?? '';
            final action = issue['action']?.toString();
            final type = issue['type']?.toString();
            final sectionId = _mapSectionTitleToModuleId(title);

            final bool canAutoAddModule =
                type == 'missing_section' && sectionId != null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GlassContainer(
                borderRadius: 12,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: PremiumTheme.info,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: PremiumTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              if (description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    description,
                                    style: PremiumTheme.bodyMedium.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (action != null && action.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    action,
                                    style: PremiumTheme.bodyMedium.copyWith(
                                      fontSize: 11,
                                      color: PremiumTheme.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (canAutoAddModule)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                if (sectionId != null) {
                                  _ensureModuleSelected(sectionId);
                                  await _openContentLibraryAndInsert(sectionId);
                                }
                              },
                              child: const Text('Add module'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PremiumTheme.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () {
                                if (sectionId != null) {
                                  _addModuleWithAI(sectionId);
                                }
                              },
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Add with AI'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // Risk Assessment Builder
  Widget _buildRiskAssessment() {
    final hasRiskData = _riskAssessment.isNotEmpty;

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

    final riskLevel = _riskAssessment['risk_level'] ?? 'Low';
    final riskScore = _riskAssessment['risk_score'] ?? 0;
    final risks = _riskAssessment['risks'] ?? [];
    final recommendations = _riskAssessment['recommendations'] ?? [];

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
        if (risks.isNotEmpty) ...[
          Text(
            'Identified Risks',
            style: PremiumTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...risks.map<Widget>((risk) => Padding(
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
    setState(() => _isLoading = true);

    try {
      final app = context.read<AppState>();
      if (app.authToken != null) {
        AIAnalysisService.setAuthToken(app.authToken!);
      }

      final proposalData = _buildProposalDataForAI();

      final analysis =
          await AIAnalysisService.analyzeProposalContent(proposalData);

      final int rawRiskScore = (analysis['riskScore'] ?? 0) as int;
      String riskLevel;
      if (rawRiskScore <= 10) {
        riskLevel = 'Low';
      } else if (rawRiskScore <= 20) {
        riskLevel = 'Medium';
      } else {
        riskLevel = 'High';
      }

      final issues = List<Map<String, dynamic>>.from(
        analysis['issues'] ?? const [],
      );

      final risks = issues.map((issue) {
        return issue['title']?.toString() ?? 'Issue';
      }).toList();

      final recommendations = issues
          .map((issue) {
            return issue['action']?.toString() ??
                issue['description']?.toString() ??
                '';
          })
          .where((r) => r.isNotEmpty)
          .toList();

      // Convert raw risk points into a 0-100"score" where higher is better
      final double displayScore = (100 - rawRiskScore).clamp(0, 100).toDouble();

      setState(() {
        _riskAssessment = {
          'risk_level': riskLevel,
          'risk_score': displayScore,
          'risks': risks,
          'recommendations': recommendations,
          'ai_status': analysis['status'] ?? 'Ready',
          'ai_riskScore': rawRiskScore,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error running risk assessment: $e')),
      );
    }
  }

  Map<String, dynamic> _buildProposalDataForAI() {
    final selectedModules =
        List<String>.from(_formData['selectedModules'] ?? const []);
    final moduleContents =
        Map<String, String>.from(_formData['moduleContents'] ?? {});

    final data = <String, dynamic>{
      'id': _proposalId ?? 'draft',
      'title': _formData['proposalTitle']?.toString().isNotEmpty == true
          ? _formData['proposalTitle'].toString()
          : _formData['opportunityName']?.toString() ?? '',
      'clientName': _formData['clientName'] ?? '',
      'clientEmail': _formData['clientEmail'] ?? '',
      'projectType': _formData['projectType'] ?? '',
      'estimatedValue': _formData['estimatedValue'] ?? '',
      'timeline': _formData['timeline'] ?? '',
    };

    for (final moduleId in selectedModules) {
      data[moduleId] = moduleContents[moduleId] ?? '';
    }

    return data;
  }

  // Run AI Governance Check
  Future<void> _runGovernanceCheck() async {
    setState(() => _isRunningGovernance = true);

    try {
      final app = context.read<AppState>();
      if (app.authToken != null) {
        AIAnalysisService.setAuthToken(app.authToken!);
      }

      final proposalData = _buildProposalDataForAI();

      final analysis =
          await AIAnalysisService.analyzeProposalContent(proposalData);

      final int rawRiskScore = (analysis['riskScore'] ?? 0) as int;
      // Convert raw risk points into a readiness percentage (higher is better)
      final int readinessScore = (100 - rawRiskScore).clamp(0, 100).toInt();

      final issues = List<Map<String, dynamic>>.from(
        analysis['issues'] ?? const [],
      );

      // Derive simple checklist from AI issues
      final checks = issues.map((issue) {
        final priority = issue['priority']?.toString() ?? 'info';
        final isRequired = priority == 'critical' ||
            priority == 'high' ||
            priority == 'warning';
        final hasPassed =
            (issue['type']?.toString() ?? '') != 'missing_section' &&
                (issue['type']?.toString() ?? '') != 'incomplete_content';

        return {
          'id': issue['type']?.toString() ?? 'ai_issue',
          'label': issue['title']?.toString() ?? 'Issue',
          'required': isRequired,
          'passed': hasPassed,
        };
      }).toList();

      setState(() {
        _governanceResults = {
          'status': analysis['status'] ?? 'PENDING',
          'score': readinessScore,
          'checks': checks,
          'issues': issues,
        };
        _isRunningGovernance = false;
      });
    } catch (e) {
      setState(() => _isRunningGovernance = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error running governance check: $e')),
      );
    }
  }

  Future<void> _submitForInternalApproval() async {
    setState(() => _isLoading = true);

    try {
      // Check if governance passed (AI Ready status)
      final governanceStatus =
          (_governanceResults['status'] as String?) ?? 'PENDING';

      if (governanceStatus != 'Ready') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Governance check must be Ready before submitting for approval'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final app = context.read<AppState>();
      final token = app.authToken;

      if (token == null || token.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to submit for approval'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int? proposalId;
      if (_proposalId != null) {
        proposalId = int.tryParse(_proposalId!);
      }

      if (proposalId == null && app.currentProposal != null) {
        final dynamic rawId = app.currentProposal!['id'];
        if (rawId is int) {
          proposalId = rawId;
        } else if (rawId is String) {
          proposalId = int.tryParse(rawId);
        }
      }

      if (proposalId == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No saved proposal found. Please create and save the proposal before submitting for approval.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final response = await DocumentProposalService.sendForApproval(
        proposalId,
        token,
      );

      setState(() {
        _isInternalApproved = true;
        _isLoading = false;
      });

      final status = response?['status']?.toString() ?? 'Pending CEO Approval';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proposal submitted for internal approval ($status)'),
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
      final app = context.read<AppState>();

      int? proposalId;
      if (_proposalId != null) {
        proposalId = int.tryParse(_proposalId!);
      }

      if (proposalId == null && app.currentProposal != null) {
        final dynamic rawId = app.currentProposal!['id'];
        if (rawId is int) {
          proposalId = rawId;
        } else if (rawId is String) {
          proposalId = int.tryParse(rawId);
        }
      }

      if (proposalId == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No saved proposal found. Please create and save the proposal before sending to the client.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final clientName =
          (_formData['clientName']?.toString().isNotEmpty ?? false)
              ? _formData['clientName'].toString()
              : 'Client';
      final clientEmail =
          (_formData['clientEmail']?.toString().isNotEmpty ?? false)
              ? _formData['clientEmail'].toString()
              : '';

      if (clientEmail.isEmpty || !clientEmail.contains('@')) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a valid client email before sending'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final result = await app.sendProposalForSignature(
        proposalId: proposalId,
        signerName: clientName,
        signerEmail: clientEmail,
      );

      if (result == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send proposal to client'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
}
