import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import 'governance_panel.dart';

class EnhancedComposePage extends StatefulWidget {
  final String proposalId;
  final String proposalTitle;
  final String templateType;
  final List<String> selectedModules;

  const EnhancedComposePage({
    super.key,
    required this.proposalId,
    required this.proposalTitle,
    required this.templateType,
    required this.selectedModules,
  });

  @override
  State<EnhancedComposePage> createState() => _EnhancedComposePageState();
}

class _EnhancedComposePageState extends State<EnhancedComposePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _proposalData = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeProposal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeProposal() async {
    setState(() => _isLoading = true);

    try {
      // Initialize proposal data based on template type and selected modules
      _proposalData.addAll({
        'id': widget.proposalId,
        'title': widget.proposalTitle,
        'templateType': widget.templateType,
        'status': 'Draft',
        'createdAt': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      });

      // Initialize content for selected modules
      for (final module in widget.selectedModules) {
        _proposalData[module] = _getDefaultContent(module);
        _controllers[module] = TextEditingController(
          text: _getDefaultContent(module),
        );
      }

      // Add common fields
      _proposalData['clientName'] = '';
      _proposalData['clientEmail'] = '';
      _proposalData['projectType'] = '';
      _proposalData['estimatedValue'] = '';
      _proposalData['timeline'] = '';

      _controllers['clientName'] = TextEditingController();
      _controllers['clientEmail'] = TextEditingController();
      _controllers['projectType'] = TextEditingController();
      _controllers['estimatedValue'] = TextEditingController();
      _controllers['timeline'] = TextEditingController();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getDefaultContent(String module) {
    switch (module) {
      case 'executive_summary':
        return 'This proposal outlines our comprehensive solution for your business needs. We are confident that our approach will deliver significant value and help you achieve your objectives.';
      case 'company_profile':
        return 'Khonology is a leading technology consulting firm with over 10 years of experience in digital transformation. We specialize in helping organizations modernize their technology infrastructure and processes.';
      case 'scope_deliverables':
        return 'Our services include:\n\n• Project planning and requirements analysis\n• System design and architecture\n• Implementation and deployment\n• Testing and quality assurance\n• Training and knowledge transfer\n• Ongoing support and maintenance';
      case 'delivery_approach':
        return 'We follow an agile methodology that emphasizes:\n\n• Regular communication and feedback\n• Iterative development and testing\n• Risk mitigation and quality assurance\n• Transparent reporting and documentation';
      case 'case_studies':
        return 'Recent Success Stories:\n\n• Digital transformation for Fortune 500 company\n• Cloud migration reducing costs by 40%\n• Mobile app development with 100k+ downloads\n• Data analytics platform improving decision making';
      case 'team_bios':
        return 'Our team includes:\n\n• Senior Project Manager with 15+ years experience\n• Lead Developer with expertise in modern technologies\n• UX/UI Designer focused on user experience\n• Quality Assurance Specialist ensuring excellence';
      case 'assumptions_risks':
        return 'Project Assumptions:\n\n• Client will provide necessary access and resources\n• Requirements will remain stable during development\n• Key stakeholders will be available for feedback\n\nRisk Mitigation:\n\n• Regular check-ins and status updates\n• Flexible approach to accommodate changes\n• Comprehensive testing and quality assurance';
      case 'terms_conditions':
        return 'Terms and Conditions:\n\n• Payment terms: 50% upfront, 50% on completion\n• Project timeline: 3-6 months from contract signing\n• Warranty: 90 days post-completion support\n• Intellectual property: Client retains ownership of custom work';
      default:
        return '';
    }
  }

  void _onContentChanged(String module, String content) {
    setState(() {
      _proposalData[module] = content;
      _proposalData['lastModified'] = DateTime.now().toIso8601String();
    });
  }

  Future<void> _saveProposal() async {
    setState(() => _isSaving = true);

    try {
      final app = context.read<AppState>();
      // Persist edited sections using existing API
      await app.updateSections(_proposalData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal saved successfully'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving proposal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: Text(widget.proposalTitle),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProposal,
            tooltip: 'Save Proposal',
          ),
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: () {
              // Navigate to preview
            },
            tooltip: 'Preview',
          ),
        ],
      ),
      body: Row(
        children: [
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF2C3E50),
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: const Color(0xFF3498DB),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.edit_outlined),
                        text: 'Compose',
                      ),
                      Tab(
                        icon: Icon(Icons.visibility_outlined),
                        text: 'Preview',
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildComposeView(),
                      _buildPreviewView(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Governance Panel
          GovernancePanel(
            proposalId: widget.proposalId,
            proposalData: _proposalData,
            onStatusChange: () {
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComposeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Information
          _buildSection(
            'Basic Information',
            Icons.info_outline,
            [
              _buildTextField(
                  'Client Name', 'clientName', 'Enter client company name'),
              _buildTextField(
                  'Client Email', 'clientEmail', 'Enter client contact email'),
              _buildTextField(
                  'Project Type', 'projectType', 'Enter project type'),
              _buildTextField(
                  'Estimated Value', 'estimatedValue', 'Enter estimated value'),
              _buildTextField('Timeline', 'timeline', 'Enter project timeline'),
            ],
          ),

          const SizedBox(height: 24),

          // Content Modules
          ...widget.selectedModules
              .map((module) => _buildModuleSection(module)),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
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
                Text(
                  _proposalData['title'] ?? 'Untitled Proposal',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prepared for: ${_proposalData['clientName'] ?? 'Client Name'}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${_formatDate(DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Content Sections
          ...widget.selectedModules
              .map((module) => _buildPreviewSection(module)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Icon(icon, color: const Color(0xFF3498DB), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModuleSection(String module) {
    final title = _getModuleTitle(module);
    final icon = _getModuleIcon(module);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: _buildSection(
        title,
        icon,
        [
          TextFormField(
            controller: _controllers[module],
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Enter $title content...',
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
                borderSide:
                    const BorderSide(color: Color(0xFF3498DB), width: 2),
              ),
            ),
            onChanged: (value) => _onContentChanged(module, value),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String field, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _controllers[field],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
        onChanged: (value) => _onContentChanged(field, value),
      ),
    );
  }

  Widget _buildPreviewSection(String module) {
    final title = _getModuleTitle(module);
    final content = _proposalData[module] ?? '';

    if (content.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
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
  }

  String _getModuleTitle(String module) {
    switch (module) {
      case 'executive_summary':
        return 'Executive Summary';
      case 'company_profile':
        return 'Company Profile';
      case 'scope_deliverables':
        return 'Scope & Deliverables';
      case 'delivery_approach':
        return 'Delivery Approach';
      case 'case_studies':
        return 'Case Studies';
      case 'team_bios':
        return 'Team Bios';
      case 'assumptions_risks':
        return 'Assumptions & Risks';
      case 'terms_conditions':
        return 'Terms & Conditions';
      default:
        return module
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'executive_summary':
        return Icons.summarize_outlined;
      case 'company_profile':
        return Icons.business_outlined;
      case 'scope_deliverables':
        return Icons.assignment_outlined;
      case 'delivery_approach':
        return Icons.delivery_dining_outlined;
      case 'case_studies':
        return Icons.cases_outlined;
      case 'team_bios':
        return Icons.people_outlined;
      case 'assumptions_risks':
        return Icons.warning_outlined;
      case 'terms_conditions':
        return Icons.gavel_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
