import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../../api.dart';
import '../../services/client_service.dart';
import '../../shared/widgets/toast.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/animated_button.dart';
import '../../shared/widgets/success_checkmark.dart';
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

  // Form validation errors
  final Map<String, String?> _fieldErrors = {};

  // Form data
  final Map<String, dynamic> _formData = {
    'templateType': '',
    'proposalTitle': '',
    'clientName': '',
    'clientEmail': '',
    'clientId': null,
    'opportunityName': '',
    'projectType': '',
    'estimatedValue': '',
    'timeline': '',
    'selectedModules': <String>[],
  };
  
  // Client selection
  List<dynamic> _clients = [];
  bool _loadingClients = false;
  bool _showClientDropdown = false;
  final TextEditingController _clientSearchController = TextEditingController();

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
    // Load clients when client details step is reached
    _clientSearchController.addListener(_onClientSearchChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients({String? search}) async {
    setState(() => _loadingClients = true);
    try {
      final app = context.read<AppState>();
      final token = app.authToken ?? '';
      if (token.isEmpty) return;
      
      final clients = await ClientService.getClientsForSelection(token, search: search);
      setState(() {
        _clients = clients;
        _loadingClients = false;
      });
    } catch (e) {
      print('Error loading clients: $e');
      setState(() => _loadingClients = false);
    }
  }

  void _onClientSearchChanged() {
    final search = _clientSearchController.text.trim();
    if (search.length >= 2 || search.isEmpty) {
      _loadClients(search: search.isEmpty ? null : search);
    }
  }

  void _selectClient(Map<String, dynamic> client) {
    setState(() {
      _formData['clientId'] = client['id'];
      _formData['clientName'] = client['company_name'] ?? client['label'] ?? '';
      _formData['clientEmail'] = client['email'] ?? '';
      _showClientDropdown = false;
      _clientSearchController.clear();
    });
  }

  void _clearClientSelection() {
    setState(() {
      _formData['clientId'] = null;
      _formData['clientName'] = '';
      _formData['clientEmail'] = '';
      _showClientDropdown = false;
      _clientSearchController.clear();
    });
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
    _fieldErrors.clear();
    bool isValid = true;

    switch (_currentStep) {
      case 0:
        if (_formData['templateType'].isEmpty) {
          _fieldErrors['templateType'] = 'Please select a template type';
          isValid = false;
        }
        break;
      case 1:
        if ((_formData['proposalTitle'] ?? '').toString().isEmpty) {
          _fieldErrors['proposalTitle'] = 'Proposal title is required';
          isValid = false;
        }
        if ((_formData['clientName'] ?? '').toString().isEmpty) {
          _fieldErrors['clientName'] = 'Client name is required';
          isValid = false;
        }
        if ((_formData['opportunityName'] ?? '').toString().isEmpty) {
          _fieldErrors['opportunityName'] = 'Opportunity name is required';
          isValid = false;
        }
        break;
      case 2:
        if ((_formData['projectType'] ?? '').toString().isEmpty) {
          _fieldErrors['projectType'] = 'Please select a project type';
          isValid = false;
        }
        break;
      case 3:
        if (_formData['selectedModules'].isEmpty) {
          _fieldErrors['selectedModules'] = 'Please select at least one content module';
          isValid = false;
        }
        break;
      case 4:
        return true; // review/confirm step
      default:
        return false;
    }

    if (!isValid) {
      setState(() {});
      Toast.showWarning(context, 'Please complete all required fields');
    }

    return isValid;
  }

  Future<void> _createProposal() async {
    setState(() => _isLoading = true);

    try {
      final app = context.read<AppState>();

      // Create proposal in backend
      await app.createProposal(
        _formData['opportunityName'],
        _formData['clientName'],
        clientId: _formData['clientId'],
      );

      // Generate a temporary proposal ID for the compose page
      final proposalId = 'temp-${DateTime.now().millisecondsSinceEpoch}';

      // Show success message with checkmark
      Toast.showSuccess(context, 'Proposal created successfully!');
      
      // Show success checkmark overlay briefly
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SuccessCheckmark(size: 64),
                SizedBox(height: 16),
                Text(
                  'Proposal Created!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      // Close checkmark after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (context.mounted) {
          Navigator.of(context).pop(); // Close checkmark
        }
      });
      
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
      Toast.showError(context, 'Failed to create proposal. Please try again.');
      print('Error creating proposal: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Close dropdown when tapping outside
        if (_showClientDropdown) {
          setState(() => _showClientDropdown = false);
        }
        FocusScope.of(context).unfocus();
      },
      child: Directionality(
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
                _isLoading
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : AnimatedButton(
                        onPressed: _canProceed()
                            ? (_currentStep == _totalSteps - 1
                                ? _createProposal
                                : _nextStep)
                            : null,
                        backgroundColor: _canProceed()
                            ? const Color(0xFF3B82F6)
                            : Colors.grey,
                        child: Text(
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
                      (value) {
                        setState(() {
                          _formData['proposalTitle'] = value;
                          _fieldErrors.remove('proposalTitle');
                        });
                      },
                      Icons.description_outlined,
                      controller: proposalTitleController,
                      errorText: _fieldErrors['proposalTitle'],
                    ),
                    const SizedBox(height: 20),
                    // Client Selection with Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                'Client Name',
                                'Select from Client Management or type manually',
                                (value) => setState(() {
                                  _formData['clientName'] = value;
                                  _fieldErrors.remove('clientName');
                                  // Clear client_id if manually typed
                                  if (value != (_formData['clientName'] ?? '')) {
                                    _formData['clientId'] = null;
                                  }
                                }),
                                Icons.business_outlined,
                                controller: clientNameController,
                                readOnly: _formData['clientId'] != null,
                                errorText: _fieldErrors['clientName'],
                                onTap: _formData['clientId'] == null ? () {
                                  setState(() {
                                    _showClientDropdown = !_showClientDropdown;
                                    if (_showClientDropdown) {
                                      _loadClients();
                                    }
                                  });
                                } : null,
                                suffixIcon: _formData['clientId'] != null
                                    ? IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: _clearClientSelection,
                                        tooltip: 'Clear selection',
                                      )
                                    : const Icon(Icons.arrow_drop_down),
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
                                readOnly: _formData['clientId'] != null,
                              ),
                            ),
                          ],
                        ),
                        // Client Search and Dropdown
                        if (_showClientDropdown)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Search field
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextField(
                                    controller: _clientSearchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search clients...',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: _clientSearchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _clientSearchController.clear();
                                                _loadClients();
                                              },
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                // Client list
                                Flexible(
                                  child: _loadingClients
                                      ? const Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Center(child: CircularProgressIndicator()),
                                        )
                                      : _clients.isEmpty
                                          ? Padding(
                                              padding: const EdgeInsets.all(20.0),
                                              child: Text(
                                                _clientSearchController.text.isNotEmpty
                                                    ? 'No clients found'
                                                    : 'No clients available',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            )
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: _clients.length,
                                              itemBuilder: (context, index) {
                                                final client = _clients[index];
                                                return ListTile(
                                                  leading: const Icon(Icons.business),
                                                  title: Text(
                                                    client['company_name'] ?? client['label'] ?? 'Unknown',
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  subtitle: Text(
                                                    client['contact_person'] ?? '',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                  ),
                                                  trailing: client['email'] != null
                                                      ? Text(
                                                          client['email'],
                                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                        )
                                                      : null,
                                                  onTap: () => _selectClient(client),
                                                );
                                              },
                                            ),
                                ),
                                // Option to create new client
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.add_circle_outline, color: Color(0xFF3498DB)),
                                  title: const Text(
                                    'Create New Client',
                                    style: TextStyle(color: Color(0xFF3498DB)),
                                  ),
                                  onTap: () {
                                    setState(() => _showClientDropdown = false);
                                    // Navigate to client management
                                    Navigator.pushNamed(context, '/collaboration');
                                  },
                                ),
                              ],
                            ),
                          ),
                        if (_formData['clientId'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Linked to client from Client Management',
                                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Project/Opportunity Name',
                      'Brief project description',
                      (value) {
                        setState(() {
                          _formData['opportunityName'] = value;
                          _fieldErrors.remove('opportunityName');
                        });
                      },
                      Icons.lightbulb_outline,
                      controller: opportunityNameController,
                      errorText: _fieldErrors['opportunityName'],
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
    
    // Parse and format timeline date if it exists
    String timelineDisplay = '';
    if (_formData['timeline'] != null && _formData['timeline'].toString().isNotEmpty) {
      try {
        final timelineStr = _formData['timeline'].toString();
        DateTime? date;
        // Try parsing as ISO string first
        if (timelineStr.contains('T')) {
          date = DateTime.parse(timelineStr);
        } else {
          // Try parsing as formatted date
          date = _parseDate(timelineStr);
        }
        if (date != null) {
          timelineDisplay = _formatDate(date);
        }
      } catch (e) {
        // If parsing fails, leave empty
        timelineDisplay = '';
      }
    }
    final timelineController = TextEditingController(text: timelineDisplay);

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
                        _fieldErrors.remove('projectType');
                      }),
                      Icons.work_outline,
                      errorText: _fieldErrors['projectType'],
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
                    _buildDatePickerField(
                      'Timeline',
                      'Select project timeline',
                      timelineController,
                      (DateTime? date) {
                        if (date != null) {
                          setState(() {
                            _formData['timeline'] = date.toIso8601String();
                            timelineController.text = _formatDate(date);
                          });
                        }
                      },
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
          if (_fieldErrors['selectedModules'] != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _fieldErrors['selectedModules']!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
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
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? errorText,
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
              readOnly: readOnly,
              onTap: onTap,
              inputFormatters: [
                LTRTextInputFormatter(), // Custom formatter to fix reversed text
                FilteringTextInputFormatter.deny(RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]')), // Remove RTL/LTR marks
              ],
        decoration: InputDecoration(
          labelText: label,
                labelStyle: const TextStyle(color: Colors.white70),
          hintText: hint,
                hintStyle: const TextStyle(color: Colors.white60),
          prefixIcon: Icon(icon, color: errorText != null ? Colors.red : const Color(0xFF3498DB)),
          suffixIcon: suffixIcon,
          errorText: errorText,
          errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: errorText != null ? Colors.red : const Color(0xFFE5E5E5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: errorText != null ? Colors.red : const Color(0xFFE5E5E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: errorText != null ? Colors.red : const Color(0xFF3498DB), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red, width: 2),
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
    IconData icon, {
    String? errorText,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: errorText != null ? Colors.red : const Color(0xFF3498DB)),
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorText != null ? Colors.red : const Color(0xFFE5E5E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorText != null ? Colors.red : const Color(0xFFE5E5E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: errorText != null ? Colors.red : const Color(0xFF3498DB), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      value: (value != null && value.isNotEmpty) ? value : null,
      items: options.map((option) {
        return DropdownMenuItem<String>(
          value: option,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(option),
          ),
        );
      }).toList(),
      onChanged: (value) {
        onChanged(value ?? '');
        // Clear error when user selects a value
        if (value != null && value.isNotEmpty) {
          setState(() {
            _fieldErrors.remove('projectType');
          });
        }
      },
    );
  }

  Widget _buildDatePickerField(
    String label,
    String hint,
    TextEditingController controller,
    Function(DateTime?) onDateSelected,
  ) {
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
              readOnly: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF3498DB)),
                suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
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
              onTap: () async {
                // Parse initial date from controller or form data
                DateTime initialDate = DateTime.now();
                if (controller.text.isNotEmpty) {
                  final parsed = _parseDate(controller.text);
                  if (parsed != null) {
                    initialDate = parsed;
                  }
                } else if (_formData['timeline'] != null && _formData['timeline'].toString().isNotEmpty) {
                  try {
                    final timelineStr = _formData['timeline'].toString();
                    if (timelineStr.contains('T')) {
                      initialDate = DateTime.parse(timelineStr);
                    } else {
                      final parsed = _parseDate(timelineStr);
                      if (parsed != null) initialDate = parsed;
                    }
                  } catch (e) {
                    // Keep default DateTime.now()
                  }
                }
                
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF3498DB),
                          onPrimary: Colors.white,
                          onSurface: Colors.black87,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  onDateSelected(picked);
                }
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return intl.DateFormat('MMM dd, yyyy').format(date);
  }

  DateTime? _parseDate(String dateString) {
    try {
      return intl.DateFormat('MMM dd, yyyy').parse(dateString);
    } catch (e) {
      try {
        return DateTime.parse(dateString);
      } catch (e2) {
        return null;
      }
    }
  }
}
