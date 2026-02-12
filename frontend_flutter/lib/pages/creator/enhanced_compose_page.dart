import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/api_service.dart';
import 'governance_panel.dart';

class EnhancedComposePage extends StatefulWidget {
  final String proposalId;
  final String proposalTitle;
  final String templateType;
  final List<String> selectedModules;
  final Map<String, dynamic>? initialData;

  const EnhancedComposePage({
    super.key,
    required this.proposalId,
    required this.proposalTitle,
    required this.templateType,
    required this.selectedModules,
    this.initialData,
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

  Future<void> _loadLatestVersionMetadata() async {
    final app = context.read<AppState>();
    final String? token = app.authToken;

    if (token == null || token.isEmpty) {
      return;
    }

    final int? proposalIdInt = int.tryParse(widget.proposalId);
    if (proposalIdInt == null) {
      return;
    }

    try {
      final versions = await ApiService.getVersions(
        token: token,
        proposalId: proposalIdInt,
      );

      if (versions.isEmpty) {
        return;
      }

      final dynamic latest = versions.first;
      if (latest is Map) {
        final dynamic latestVersionRaw = latest['version_number'];
        final dynamic latestCreatedAt = latest['created_at'];

        int? latestVersion;
        if (latestVersionRaw is int) {
          latestVersion = latestVersionRaw;
        } else {
          latestVersion = int.tryParse(latestVersionRaw?.toString() ?? '');
        }

        setState(() {
          if (latestVersion != null) {
            _proposalData['versionNumber'] = latestVersion;
          }
          if (latestCreatedAt != null) {
            _proposalData['createdAt'] = latestCreatedAt.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading latest version metadata: $e');
    }
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
      final Map<String, dynamic> initial =
          Map<String, dynamic>.from(widget.initialData ?? const {});

      final String initialCreatedAt =
          (initial['createdAt']?.toString().isNotEmpty ?? false)
              ? initial['createdAt'].toString()
              : DateTime.now().toIso8601String();

      final dynamic versionRaw = initial['versionNumber'];
      final int initialVersionNumber = versionRaw is int
          ? versionRaw
          : int.tryParse(versionRaw?.toString() ?? '') ?? 1;

      // Initialize proposal data based on template type and selected modules
      _proposalData.addAll({
        'id': widget.proposalId,
        'title': widget.proposalTitle,
        'templateType': widget.templateType,
        'status': 'Draft',
        'createdAt': initialCreatedAt,
        'lastModified': DateTime.now().toIso8601String(),
        'versionNumber': initialVersionNumber,
      });

      // Initialize content for selected modules
      for (final module in widget.selectedModules) {
        final String initialContent =
            (initial[module]?.toString().isNotEmpty ?? false)
                ? initial[module].toString()
                : _getDefaultContent(module);
        _proposalData[module] = initialContent;
        _controllers[module] = TextEditingController(
          text: initialContent,
        );
      }

      // Add common fields
      _proposalData['clientName'] = initial['clientName']?.toString() ?? '';
      _proposalData['clientEmail'] = initial['clientEmail']?.toString() ?? '';
      _proposalData['projectType'] = initial['projectType']?.toString() ?? '';
      _proposalData['estimatedValue'] =
          initial['estimatedValue']?.toString() ?? '';
      _proposalData['timeline'] = initial['timeline']?.toString() ?? '';

      _proposalData['opportunityId'] =
          initial['opportunityId']?.toString() ?? '';
      _proposalData['engagementStage'] =
          initial['engagementStage']?.toString() ?? 'Proposal Drafted';
      _proposalData['engagementOpenedAt'] =
          initial['engagementOpenedAt']?.toString() ?? '';
      _proposalData['ownerName'] = initial['ownerName']?.toString() ?? '';

      _controllers['clientName'] =
          TextEditingController(text: _proposalData['clientName']);
      _controllers['clientEmail'] =
          TextEditingController(text: _proposalData['clientEmail']);
      _controllers['projectType'] =
          TextEditingController(text: _proposalData['projectType']);
      _controllers['estimatedValue'] =
          TextEditingController(text: _proposalData['estimatedValue']);
      _controllers['timeline'] =
          TextEditingController(text: _proposalData['timeline']);

      await _loadLatestVersionMetadata();
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
        return 'Our services include:\n\nâ€¢ Project planning and requirements analysis\nâ€¢ System design and architecture\nâ€¢ Implementation and deployment\nâ€¢ Testing and quality assurance\nâ€¢ Training and knowledge transfer\nâ€¢ Ongoing support and maintenance';
      case 'delivery_approach':
        return 'We follow an agile methodology that emphasizes:\n\nâ€¢ Regular communication and feedback\nâ€¢ Iterative development and testing\nâ€¢ Risk mitigation and quality assurance\nâ€¢ Transparent reporting and documentation';
      case 'case_studies':
        return 'Recent Success Stories:\n\nâ€¢ Digital transformation for Fortune 500 company\nâ€¢ Cloud migration reducing costs by 40%\nâ€¢ Mobile app development with 100k+ downloads\nâ€¢ Data analytics platform improving decision making';
      case 'team_bios':
        return 'Our team includes:\n\nâ€¢ Senior Project Manager with 15+ years experience\nâ€¢ Lead Developer with expertise in modern technologies\nâ€¢ UX/UI Designer focused on user experience\nâ€¢ Quality Assurance Specialist ensuring excellence';
      case 'assumptions_risks':
        return 'Project Assumptions:\n\nâ€¢ Client will provide necessary access and resources\nâ€¢ Requirements will remain stable during development\nâ€¢ Key stakeholders will be available for feedback\n\nRisk Mitigation:\n\nâ€¢ Regular check-ins and status updates\nâ€¢ Flexible approach to accommodate changes\nâ€¢ Comprehensive testing and quality assurance';
      case 'terms_conditions':
        return 'Terms and Conditions:\n\nâ€¢ Payment terms: 50% upfront, 50% on completion\nâ€¢ Project timeline: 3-6 months from contract signing\nâ€¢ Warranty: 90 days post-completion support\nâ€¢ Intellectual property: Client retains ownership of custom work';
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
      await app.updateProposal(widget.proposalId, _proposalData);

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
    final dynamic versionRaw = _proposalData['versionNumber'];
    final int versionNumber = versionRaw is int
        ? versionRaw
        : int.tryParse(versionRaw?.toString() ?? '') ?? 1;

    DateTime createdDate;
    final String? createdAtStr = _proposalData['createdAt']?.toString();
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      try {
        createdDate = DateTime.parse(createdAtStr);
      } catch (_) {
        createdDate = DateTime.now();
      }
    } else {
      createdDate = DateTime.now();
    }

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
                  color: Colors.black.withValues(alpha: 0.05),
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
                  'Opp ${_proposalData['opportunityId'] ?? ''} â€¢ Stage: ${_proposalData['engagementStage'] ?? 'Proposal Drafted'} â€¢ Owner: ${_proposalData['ownerName'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Draft v$versionNumber â€¢ ${_formatDate(createdDate)}',
                  style: const TextStyle(
                    fontSize: 12,
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
            color: Colors.black.withValues(alpha: 0.05),
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
            color: Colors.black.withValues(alpha: 0.05),
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
