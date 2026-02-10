import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'template_builder.dart';
import '../../theme/premium_theme.dart';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';

class TemplateLibraryPage extends StatefulWidget {
  const TemplateLibraryPage({Key? key}) : super(key: key);

  @override
  _TemplateLibraryPageState createState() => _TemplateLibraryPageState();
}

class _TemplateLibraryPageState extends State<TemplateLibraryPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  bool _isLoading = true;
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  String _currentPage = 'Templates';

  List<Template> _templates = [];
  List<Template> _filteredTemplates = [];
  List<Template> _myTemplates = [];
  List<Template> _publicTemplates = [];

  final Map<String, StatusConfig> _statusConfig = {
    'draft': StatusConfig(
      color: Colors.grey.shade100,
      textColor: Colors.grey.shade800,
      icon: Icons.description,
      label: 'Draft',
    ),
    'pending_approval': StatusConfig(
      color: Colors.orange.shade100,
      textColor: Colors.orange.shade800,
      icon: Icons.schedule,
      label: 'Pending',
    ),
    'approved': StatusConfig(
      color: Colors.green.shade100,
      textColor: Colors.green.shade800,
      icon: Icons.check_circle,
      label: 'Approved',
    ),
    'rejected': StatusConfig(
      color: Colors.red.shade100,
      textColor: Colors.red.shade800,
      icon: Icons.close,
      label: 'Rejected',
    ),
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.value = 1.0;
    _loadTemplates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Mock API call - replace with your actual API
      await Future.delayed(const Duration(seconds: 1));

      // Mock data
      final List<Template> mockTemplates = [
        Template(
          id: '1',
          name: 'Consulting & Technology Delivery Proposal Template',
          description:
              'Complete proposal template with all 11 sections - Cover Page, Executive Summary, Problem Statement, Scope of Work, Timeline, Team, Delivery Approach, Pricing, Risks, Governance, and Company Profile',
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
          dynamicFields: [
            DynamicField(fieldKey: 'client_name', fieldName: 'Client Name'),
            DynamicField(
                fieldKey: 'client_stakeholder',
                fieldName: 'Client Stakeholder'),
            DynamicField(fieldKey: 'project_name', fieldName: 'Project Name'),
            DynamicField(fieldKey: 'date', fieldName: 'Date'),
            DynamicField(fieldKey: 'total_cost', fieldName: 'Total Cost'),
            DynamicField(
                fieldKey: 'engagement_lead_name',
                fieldName: 'Engagement Lead Name'),
            DynamicField(
                fieldKey: 'technical_lead_name',
                fieldName: 'Technical Lead Name'),
            DynamicField(
                fieldKey: 'business_analyst_name',
                fieldName: 'Business Analyst Name'),
            DynamicField(
                fieldKey: 'qa_analyst_name', fieldName: 'QA/Test Analyst Name'),
          ],
          usageCount: 0,
          createdBy: 'admin@khonology.com',
          createdDate: DateTime.now(),
          content: jsonEncode({
            "templateType": "proposal",
            "name": "Consulting & Technology Delivery Proposal Template",
            "description": "Complete proposal template with all sections",
            "sections": [
              {
                "title": "Cover Page",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"cover\", \"page\", \"module\"] -->\n<h1>Consulting & Technology Delivery Proposal</h1>\n\n<p><strong>Client:</strong> {{Client Name}}</p>\n<p><strong>Prepared For:</strong> {{Client Stakeholder}}</p>\n<p><strong>Prepared By:</strong> Khonology Team</p>\n<p><strong>Date:</strong> {{Date}}</p>\n\n<h2>Cover Summary</h2>\n<p>Khonology proposes a customised consulting and technology delivery engagement to support {{Client Name}} in achieving operational excellence, digital transformation, and data-driven decision-making.</p>"
              },
              {
                "title": "Executive Summary",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"executive\", \"summary\", \"module\"] -->\n<h1>Executive Summary</h1>\n\n<h2>Purpose of This Proposal</h2>\n<p>This proposal outlines Khonology's recommended approach, delivery methodology, timelines, governance, and expected outcomes for the {{Project Name}} initiative.</p>\n\n<h2>What We Bring</h2>\n<ul>\n<li>Strong expertise in digital transformation and enterprise delivery</li>\n<li>Deep experience in banking, insurance, ESG reporting, and financial services</li>\n<li>Proven capability across data engineering, cloud, automation, and governance</li>\n<li>A people-first consulting culture focused on delivery excellence</li>\n</ul>\n\n<h2>Expected Outcomes</h2>\n<ul>\n<li>Streamlined processes</li>\n<li>Robust governance</li>\n<li>Improved operational visibility</li>\n<li>Higher efficiency and reduced risk</li>\n<li>A scalable delivery architecture to support strategic goals</li>\n</ul>"
              },
              {
                "title": "Problem Statement",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"problem\", \"statement\", \"module\"] -->\n<h1>Problem Statement</h1>\n\n<h2>Current State Challenges</h2>\n<p>{{Client Name}} is experiencing the following challenges:</p>\n<ul>\n<li>Limited visibility into operational performance</li>\n<li>Manual processes creating inefficiencies</li>\n<li>High reporting complexity</li>\n<li>Lack of integrated workflows or automated governance</li>\n<li>Upcoming deadlines causing pressure on compliance and reporting</li>\n</ul>\n\n<h2>Opportunity</h2>\n<p>With a modern delivery framework, workflows, and reporting structures, {{Client Name}} can unlock operational excellence and achieve strategic growth objectives.</p>"
              },
              {
                "title": "Scope of Work",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"scope\", \"work\", \"module\"] -->\n<h1>Scope of Work</h1>\n\n<p>Khonology proposes the following Scope of Work:</p>\n\n<h2>1. Discovery & Assessment</h2>\n<ul>\n<li>Requirements gathering</li>\n<li>Stakeholder workshops</li>\n<li>Current-state assessment</li>\n</ul>\n\n<h2>2. Solution Design</h2>\n<ul>\n<li>Technical architecture</li>\n<li>Workflow design</li>\n<li>Data models and integration approach</li>\n</ul>\n\n<h2>3. Build & Configuration</h2>\n<ul>\n<li>Product configuration</li>\n<li>UI/UX setup</li>\n<li>Data pipeline setup</li>\n<li>Reporting components</li>\n</ul>\n\n<h2>4. Implementation & Testing</h2>\n<ul>\n<li>UAT support</li>\n<li>QA testing</li>\n<li>Release preparation</li>\n</ul>\n\n<h2>5. Training & Knowledge Transfer</h2>\n<ul>\n<li>System training</li>\n<li>Documentation handover</li>\n</ul>"
              },
              {
                "title": "Project Timeline",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"timeline\", \"project\", \"module\"] -->\n<h1>Project Timeline</h1>\n\n<table>\n<thead>\n<tr>\n<th>Phase</th>\n<th>Duration</th>\n<th>Description</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>Discovery</td>\n<td>1–2 Weeks</td>\n<td>Requirements & assessment</td>\n</tr>\n<tr>\n<td>Design</td>\n<td>1 Week</td>\n<td>Architecture & workflow design</td>\n</tr>\n<tr>\n<td>Build</td>\n<td>2–4 Weeks</td>\n<td>Development & configuration</td>\n</tr>\n<tr>\n<td>UAT</td>\n<td>1–2 Weeks</td>\n<td>Testing & validation</td>\n</tr>\n<tr>\n<td>Go-Live</td>\n<td>1 Week</td>\n<td>Deployment & full handover</td>\n</tr>\n</tbody>\n</table>"
              },
              {
                "title": "Team & Bios",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"team\", \"bios\", \"module\"] -->\n<h1>Team & Bios</h1>\n\n<h2>Engagement Lead – {{Name}}</h2>\n<p>Responsible for oversight, governance, and stakeholder engagement.</p>\n\n<h2>Technical Lead – {{Name}}</h2>\n<p>Owns architecture, technical design, integration, and delivery.</p>\n\n<h2>Business Analyst – {{Name}}</h2>\n<p>Facilitates workshops, documents requirements, and translations.</p>\n\n<h2>QA/Test Analyst – {{Name}}</h2>\n<p>Ensures solution quality and manages UAT cycles.</p>"
              },
              {
                "title": "Delivery Approach",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"delivery\", \"approach\", \"module\"] -->\n<h1>Delivery Approach</h1>\n\n<p>Khonology follows a structured delivery methodology combining Agile, Lean, and governance best practices.</p>\n\n<h2>Key Features</h2>\n<ul>\n<li>Iterative sprint cycles</li>\n<li>Frequent stakeholder engagement</li>\n<li>Automated governance checkpoints</li>\n<li>Traceability from requirements → delivery → reporting</li>\n</ul>"
              },
              {
                "title": "Pricing Table",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"pricing\", \"table\", \"module\"] -->\n<h1>Pricing Table</h1>\n\n<table>\n<thead>\n<tr>\n<th>Service Component</th>\n<th>Quantity</th>\n<th>Rate</th>\n<th>Total</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>Assessment & Discovery</td>\n<td>2 Weeks</td>\n<td>R X</td>\n<td>R X</td>\n</tr>\n<tr>\n<td>Build & Configuration</td>\n<td>4 Weeks</td>\n<td>R X</td>\n<td>R X</td>\n</tr>\n<tr>\n<td>UAT & Release</td>\n<td>2 Weeks</td>\n<td>R X</td>\n<td>R X</td>\n</tr>\n<tr>\n<td>Training & Handover</td>\n<td>1 Week</td>\n<td>R X</td>\n<td>R X</td>\n</tr>\n</tbody>\n</table>\n\n<p><strong>Total Estimated Cost:</strong> R {{Total}}</p>\n\n<p>Final costs will be confirmed after detailed scoping.</p>"
              },
              {
                "title": "Risks & Mitigation",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"risks\", \"mitigation\", \"module\"] -->\n<h1>Risks & Mitigation</h1>\n\n<table>\n<thead>\n<tr>\n<th>Risk</th>\n<th>Impact</th>\n<th>Likelihood</th>\n<th>Mitigation</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>Limited stakeholder availability</td>\n<td>High</td>\n<td>Medium</td>\n<td>Align early calendars</td>\n</tr>\n<tr>\n<td>Data quality issues</td>\n<td>High</td>\n<td>High</td>\n<td>Early validation</td>\n</tr>\n<tr>\n<td>Changing scope</td>\n<td>Medium</td>\n<td>Medium</td>\n<td>Governance checkpoints</td>\n</tr>\n<tr>\n<td>Lack of documentation</td>\n<td>Medium</td>\n<td>High</td>\n<td>Early analysis and mapping</td>\n</tr>\n</tbody>\n</table>"
              },
              {
                "title": "Governance Model",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"governance\", \"model\", \"module\"] -->\n<h1>Governance Model</h1>\n\n<h2>Governance Structure</h2>\n<ul>\n<li>Engagement Lead</li>\n<li>Product Owner (Client)</li>\n<li>Delivery Team</li>\n<li>QA & Compliance Group</li>\n</ul>\n\n<h2>Tools</h2>\n<ul>\n<li>Jira</li>\n<li>Teams/Email</li>\n<li>Automated reporting dashboard</li>\n</ul>\n\n<h2>Cadence</h2>\n<ul>\n<li>Daily standups</li>\n<li>Weekly status updates</li>\n<li>Monthly executive review</li>\n</ul>"
              },
              {
                "title": "Appendix – Company Profile",
                "required": true,
                "content":
                    "<!-- tags: [\"template\", \"proposal\", \"company\", \"profile\", \"module\"] -->\n<h1>Appendix – Company Profile</h1>\n\n<h2>About Khonology</h2>\n<p>Khonology is a South African-based digital consulting and technology delivery company specialising in:</p>\n<ul>\n<li>Enterprise automation</li>\n<li>Digital transformation</li>\n<li>ESG reporting</li>\n<li>Data engineering & cloud</li>\n<li>Business analysis and enterprise delivery</li>\n</ul>\n\n<p>We partner with organisations to deliver impactful solutions that transform operations and unlock measurable value.</p>"
              }
            ]
          }),
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
          dynamicFields: [
            DynamicField(fieldKey: 'client_name', fieldName: 'Client Name'),
            DynamicField(fieldKey: 'project_scope', fieldName: 'Project Scope'),
          ],
          usageCount: 15,
          createdBy: 'admin@khonology.com',
          createdDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
        Template(
          id: '3',
          name: 'Statement of Work (SOW) Template',
          description:
              'Complete SOW template with all sections - Project Overview, Scope, Deliverables, Timeline, Resources, and Terms',
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
          usageCount: 8,
          createdBy: 'admin@khonology.com',
          createdDate: DateTime.now().subtract(const Duration(days: 15)),
        ),
        Template(
          id: '4',
          name: 'My Custom Proposal',
          description: 'Custom proposal template for tech clients',
          templateType: 'proposal',
          approvalStatus: 'draft',
          isPublic: false,
          isApproved: false,
          version: 1,
          sections: [
            TemplateSection(title: 'Technical Approach', required: true),
          ],
          usageCount: 0,
          createdBy: 'current_user',
          createdDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

      setState(() {
        _templates = mockTemplates;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load templates: $e');
    }
  }

  void _applyFilters() {
    _filteredTemplates = _templates.where((template) {
      final matchesSearch = template.name
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()) ||
          (template.description
                  ?.toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ??
              false);
      final matchesType =
          _typeFilter == 'all' || template.templateType == _typeFilter;
      final matchesStatus =
          _statusFilter == 'all' || template.approvalStatus == _statusFilter;
      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    // Separate my templates and public templates
    _myTemplates =
        _filteredTemplates.where((t) => t.createdBy == 'current_user').toList();
    _publicTemplates =
        _filteredTemplates.where((t) => t.isPublic && t.isApproved).toList();
  }

  Future<void> _cloneTemplate(Template template) async {
    try {
      // Mock API call - replace with your actual API
      await Future.delayed(const Duration(seconds: 1));

      final clonedTemplate = Template(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${template.name} (Copy)',
        description: template.description,
        templateType: template.templateType,
        approvalStatus: 'draft',
        isPublic: false,
        isApproved: false,
        version: 1,
        sections: template.sections,
        dynamicFields: template.dynamicFields,
        usageCount: 0,
        createdBy: 'current_user',
        createdDate: DateTime.now(),
        basedOnTemplateId: template.id,
      );

      setState(() {
        _templates.insert(0, clonedTemplate);
        _applyFilters();
      });

      _showSuccess('Template cloned successfully!');
    } catch (e) {
      _showError('Failed to clone template: $e');
    }
  }

  Future<void> _deleteTemplate(String templateId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumTheme.darkBg2,
        title: const Text('Delete Template',
            style: TextStyle(color: PremiumTheme.textPrimary)),
        content: const Text(
            'Are you sure you want to delete this template? This action cannot be undone.',
            style: TextStyle(color: PremiumTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: PremiumTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: PremiumTheme.error),
            child: const Text('Delete',
                style: TextStyle(color: PremiumTheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Mock API call - replace with your actual API
        await Future.delayed(const Duration(seconds: 1));

        setState(() {
          _templates.removeWhere((t) => t.id == templateId);
          _applyFilters();
        });

        _showSuccess('Template deleted successfully!');
      } catch (e) {
        _showError('Failed to delete template: $e');
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
      if (_isSidebarCollapsed) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 'My Proposals':
        Navigator.pushReplacementNamed(context, '/proposals');
        break;
      case 'Templates':
        // Already on templates page
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Client Management':
        Navigator.pushReplacementNamed(context, '/client_management');
        break;
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      case 'Logout':
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Perform logout
                final app = context.read<AppState>();
                app.logout();
                AuthService.logout();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSidebarCollapsed ? 90.0 : 250.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.2),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          right: BorderSide(
            color: PremiumTheme.glassWhiteBorder,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: InkWell(
                onTap: _toggleSidebar,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: PremiumTheme.glassWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: PremiumTheme.glassWhiteBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: _isSidebarCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isSidebarCollapsed)
                        Expanded(
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Navigation',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: _isSidebarCollapsed ? 0 : 8),
                        child: Icon(
                          _isSidebarCollapsed
                              ? Icons.keyboard_arrow_right
                              : Icons.keyboard_arrow_left,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildNavItem('Dashboard', 'assets/images/Dahboard.png',
                _currentPage == 'Dashboard', context),
            _buildNavItem('My Proposals', 'assets/images/My_Proposals.png',
                _currentPage == 'My Proposals', context),
            _buildNavItem('Templates', 'assets/images/content_library.png',
                _currentPage == 'Templates', context),
            _buildNavItem(
                'Content Library',
                'assets/images/content_library.png',
                _currentPage == 'Content Library',
                context),
            _buildNavItem(
                'Client Management',
                'assets/images/collaborations.png',
                _currentPage == 'Client Management',
                context),
            _buildNavItem(
                'Approved Proposals',
                'assets/images/Time Allocation_Approval_Blue.png',
                _currentPage == 'Approved Proposals',
                context),
            _buildNavItem(
                'Analytics (My Pipeline)',
                'assets/images/analytics.png',
                _currentPage == 'Analytics (My Pipeline)',
                context),
            const SizedBox(height: 20),
            if (!_isSidebarCollapsed)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 1,
                color: const Color(0xFF2C3E50),
              ),
            const SizedBox(height: 12),
            _buildNavItem(
                'Logout', 'assets/images/Logout_KhonoBuzz.png', false, context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
      String label, String assetPath, bool isActive, BuildContext context) {
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              setState(() => _currentPage = label);
              _navigateToPage(context, label);
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFFCBD5E1),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: AssetService.buildImageWidget(assetPath,
                    fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _currentPage = label);
          _navigateToPage(context, label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: const Color(0xFF2980B9), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFFCBD5E1),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: AssetService.buildImageWidget(assetPath,
                      fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFECF0F1),
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isActive)
                const Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: PremiumTheme.teal))
            : Row(
                children: [
                  // Sidebar
                  _buildSidebar(context),
                  // Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          _buildHeader(),
                          const SizedBox(height: 24),

                          // Filters
                          _buildFilters(),
                          const SizedBox(height: 24),

                          // Public Templates
                          _buildPublicTemplates(),
                          const SizedBox(height: 24),

                          // My Templates
                          _buildMyTemplates(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to TemplateBuilder
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TemplateBuilder()),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: PremiumTheme.teal,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.dashboard, size: 32, color: PremiumTheme.teal),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Template Library',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: PremiumTheme.textPrimary),
            ),
            Text(
              'Create and manage proposal templates with dynamic fields',
              style: const TextStyle(color: PremiumTheme.textSecondary),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      decoration: PremiumTheme.glassCard(borderRadius: 16),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: PremiumTheme.textPrimary),
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.search, color: PremiumTheme.textSecondary),
                hintText: 'Search templates...',
                hintStyle: const TextStyle(color: PremiumTheme.textTertiary),
                filled: true,
                fillColor: PremiumTheme.darkBg2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: PremiumTheme.teal, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 12),

          // Type Filter
          Container(
            width: 150,
            decoration: BoxDecoration(
              color: PremiumTheme.darkBg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _typeFilter,
              dropdownColor: PremiumTheme.darkBg2,
              style: const TextStyle(color: PremiumTheme.textPrimary),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: PremiumTheme.darkBg2,
              ),
              items: const [
                DropdownMenuItem(
                    value: 'all',
                    child: Text('All Types',
                        style: TextStyle(color: PremiumTheme.textPrimary))),
                DropdownMenuItem(
                    value: 'proposal',
                    child: Text('Proposal',
                        style: TextStyle(color: PremiumTheme.textPrimary))),
                DropdownMenuItem(
                    value: 'sow',
                    child: Text('SOW',
                        style: TextStyle(color: PremiumTheme.textPrimary))),
                DropdownMenuItem(
                    value: 'rfi',
                    child: Text('RFI',
                        style: TextStyle(color: PremiumTheme.textPrimary))),
              ],
              onChanged: (value) {
                setState(() {
                  _typeFilter = value!;
                  _applyFilters();
                });
              },
            ),
          ),
          const SizedBox(width: 12),

          // Status Filter
          Container(
            width: 150,
            decoration: BoxDecoration(
              color: PremiumTheme.darkBg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              dropdownColor: PremiumTheme.darkBg2,
              style: const TextStyle(color: PremiumTheme.textPrimary),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: PremiumTheme.darkBg2,
              ),
              items: const [
                DropdownMenuItem(
                    value: 'all',
                    child: Text('All Status',
                        style: TextStyle(color: PremiumTheme.textPrimary))),
                DropdownMenuItem(
                    value: 'draft',
                    child: Text('Draft',
                        style: TextStyle(color: PremiumTheme.textPrimary))),
                DropdownMenuItem(
                    value: 'pending_approval',
                    child: Text('Pending',
                        style: TextStyle(color: PremiumTheme.textPrimary))),
                DropdownMenuItem(
                    value: 'approved',
                    child: Text('Approved',
                        style: TextStyle(color: PremiumTheme.textPrimary))),
              ],
              onChanged: (value) {
                setState(() {
                  _statusFilter = value!;
                  _applyFilters();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicTemplates() {
    return Container(
      decoration: PremiumTheme.glassCard(borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.star, color: PremiumTheme.warning, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Approved Templates',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: PremiumTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PremiumTheme.darkBg3,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _publicTemplates.length.toString(),
                    style: const TextStyle(
                        color: PremiumTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _publicTemplates.isEmpty
                ? _buildEmptyState(
                    icon: Icons.star,
                    message: 'No approved templates yet',
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          MediaQuery.of(context).size.width > 1200 ? 3 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: _publicTemplates.length,
                    itemBuilder: (context, index) =>
                        _buildTemplateCard(_publicTemplates[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTemplates() {
    return Container(
      decoration: PremiumTheme.glassCard(borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.people, color: PremiumTheme.info, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'My Templates',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: PremiumTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PremiumTheme.darkBg3,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _myTemplates.length.toString(),
                    style: const TextStyle(
                        color: PremiumTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _myTemplates.isEmpty
                ? _buildEmptyState(
                    icon: Icons.dashboard,
                    message: 'You haven\'t created any templates yet',
                    showButton: true,
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TemplateBuilder()),
                      );
                    },
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          MediaQuery.of(context).size.width > 1200 ? 3 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: _myTemplates.length,
                    itemBuilder: (context, index) => _buildTemplateCard(
                        _myTemplates[index],
                        isMyTemplate: true),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Template template, {bool isMyTemplate = false}) {
    final statusConfig = _statusConfig[template.approvalStatus]!;
    final isSOW = template.templateType.toLowerCase() == 'sow';
    final isProposal = template.templateType.toLowerCase() == 'proposal';
    final cardColor = isSOW
        ? PremiumTheme.success
        : isProposal
            ? PremiumTheme.info
            : PremiumTheme.purple;

    return Container(
      decoration: PremiumTheme.glassCard(
        borderRadius: 16,
        gradientStart: cardColor.withOpacity(0.1),
        gradientEnd: cardColor.withOpacity(0.05),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: PremiumTheme.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (template.description != null)
                      Text(
                        template.description!,
                        style: const TextStyle(
                            fontSize: 12, color: PremiumTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: PremiumTheme.darkBg3,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Text(
                            template.templateType.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                color: PremiumTheme.textSecondary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusConfig.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: statusConfig.color.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusConfig.icon,
                                  size: 12, color: statusConfig.textColor),
                              const SizedBox(width: 4),
                              Text(statusConfig.label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: statusConfig.textColor)),
                            ],
                          ),
                        ),
                        if (template.isPublic)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: PremiumTheme.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: PremiumTheme.purple.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'Public',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: PremiumTheme.purple,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Stats
          Text(
            '${template.sections.length} sections • ${template.usageCount} uses',
            style:
                const TextStyle(fontSize: 12, color: PremiumTheme.textTertiary),
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPreviewDialog(template),
                  icon: const Icon(Icons.visibility,
                      size: 16, color: PremiumTheme.teal),
                  label: const Text('Preview',
                      style: TextStyle(color: PremiumTheme.teal)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: PremiumTheme.teal),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isMyTemplate) ...[
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TemplateBuilder(templateId: template.id),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    foregroundColor: PremiumTheme.textSecondary,
                  ),
                  child: const Icon(Icons.edit, size: 16),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => _cloneTemplate(template),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    foregroundColor: PremiumTheme.textSecondary,
                  ),
                  child: const Icon(Icons.copy, size: 16),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: () => _deleteTemplate(template.id),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: PremiumTheme.error),
                    foregroundColor: PremiumTheme.error,
                  ),
                  child: const Icon(Icons.delete, size: 16),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cloneTemplate(template),
                    icon: Icon(Icons.copy,
                        size: 16, color: Colors.white.withOpacity(0.7)),
                    label: Text('Clone',
                        style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    bool showButton = false,
    VoidCallback? onButtonPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: PremiumTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: PremiumTheme.textSecondary),
          ),
          if (showButton) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onButtonPressed,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create Your First Template',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPreviewDialog(Template template) {
    final content = template.content ?? '';

    // Check if content is JSON (full template structure)
    Widget contentWidget;
    try {
      if (content.trim().startsWith('{')) {
        final decoded = jsonDecode(content);
        if (decoded is Map && decoded.containsKey('sections')) {
          // Render as structured template
          contentWidget = _buildStructuredTemplatePreview(
              Map<String, dynamic>.from(decoded));
        } else {
          // Render as formatted text
          contentWidget = _buildHtmlPreview(content);
        }
      } else if (content.isNotEmpty) {
        // Render HTML content properly
        contentWidget = _buildHtmlPreview(content);
      } else {
        // Fallback: show sections list if no content
        contentWidget = _buildSectionsList(template);
      }
    } catch (e) {
      // Fallback: show sections list if parsing fails
      contentWidget = _buildSectionsList(template);
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: PremiumTheme.darkBg2,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: PremiumTheme.darkBg2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PremiumTheme.teal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.preview,
                        color: PremiumTheme.teal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      template.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const Divider(height: 32, color: Colors.white24),
              Expanded(
                child: SingleChildScrollView(
                  child: contentWidget,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionsList(Template template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (template.description != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PremiumTheme.darkBg3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              template.description!,
              style: const TextStyle(color: PremiumTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          'Sections (${template.sections.length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: PremiumTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...template.sections.map((section) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: PremiumTheme.darkBg3,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: ListTile(
                title: Text(
                  section.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: PremiumTheme.textPrimary,
                  ),
                ),
                trailing: section.required
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: PremiumTheme.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 12,
                            color: PremiumTheme.success,
                          ),
                        ),
                      )
                    : null,
                subtitle: section.defaultContent != null
                    ? Text(
                        section.defaultContent!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PremiumTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
            )),
      ],
    );
  }

  Widget _buildStructuredTemplatePreview(Map<String, dynamic> decoded) {
    final sections = decoded['sections'] as List?;
    if (sections == null) {
      return const Text("No content available",
          style: TextStyle(color: Colors.white70));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (decoded.containsKey('description'))
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              decoded['description'].toString(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ...sections.map<Widget>((section) {
          if (section is Map) {
            final title = section['title']?.toString() ?? '';
            final content = section['content']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildHtmlPreview(content),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }).toList(),
      ],
    );
  }

  Widget _buildHtmlPreview(String htmlContent) {
    final widgets = <Widget>[];

    // First, extract and render tables
    final tablePattern = RegExp(r'<table>.*?</table>', dotAll: true);
    int lastIndex = 0;
    final matches = tablePattern.allMatches(htmlContent);

    for (final match in matches) {
      // Add content before the table
      if (match.start > lastIndex) {
        final beforeTable = htmlContent.substring(lastIndex, match.start);
        widgets.addAll(_parseNonTableContent(beforeTable));
      }

      // Parse and render the table
      final tableHtml = match.group(0)!;
      widgets.add(_buildHtmlTable(tableHtml));

      lastIndex = match.end;
    }

    // Add remaining content after the last table
    if (lastIndex < htmlContent.length) {
      final remaining = htmlContent.substring(lastIndex);
      widgets.addAll(_parseNonTableContent(remaining));
    }

    // If no tables were found, parse entire content
    if (widgets.isEmpty) {
      widgets.addAll(_parseNonTableContent(htmlContent));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets.isEmpty
          ? [
              const Text(
                "No content available",
                style: TextStyle(color: Colors.white70),
              ),
            ]
          : widgets,
    );
  }

  List<Widget> _parseNonTableContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Skip table-related tags as they're handled separately
      if (line.contains('<table>') ||
          line.contains('</table>') ||
          line.contains('<thead>') ||
          line.contains('</thead>') ||
          line.contains('<tbody>') ||
          line.contains('</tbody>') ||
          line.contains('<tr>') ||
          line.contains('</tr>') ||
          line.contains('<th>') ||
          line.contains('</th>') ||
          line.contains('<td>') ||
          line.contains('</td>')) {
        continue;
      }

      if (line.contains('<h1>')) {
        final text = _extractTextFromTag(line, 'h1');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
      } else if (line.contains('<h2>')) {
        final text = _extractTextFromTag(line, 'h2');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      } else if (line.contains('<h3>')) {
        final text = _extractTextFromTag(line, 'h3');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
      } else if (line.contains('<p>')) {
        final text = _extractTextFromTag(line, 'p');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ));
      } else if (line.contains('<li>')) {
        final text = _extractTextFromTag(line, 'li');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  color: PremiumTheme.teal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (line.trim().startsWith('|') && line.contains('|')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            line,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ));
      } else if (line.trim().startsWith('#')) {
        final level = line.split(' ').first.length;
        final text = line.substring(level).trim();
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 8, top: level > 1 ? 12 : 16),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: level == 1
                  ? 24
                  : level == 2
                      ? 20
                      : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
      } else if (line.trim().startsWith('-') || line.trim().startsWith('*')) {
        final text = line.replaceFirst(RegExp(r'^[\s\-\*]+'), '').trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  color: PremiumTheme.teal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (line.trim().isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _stripHtmlTags(line),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ));
      }
    }

    return widgets;
  }

  Widget _buildHtmlTable(String tableHtml) {
    // Extract header rows
    final theadPattern = RegExp(r'<thead>(.*?)</thead>', dotAll: true);
    final theadMatch = theadPattern.firstMatch(tableHtml);
    List<String> headers = [];

    if (theadMatch != null) {
      final theadContent = theadMatch.group(1)!;
      final thPattern = RegExp(r'<th>(.*?)</th>', dotAll: true);
      headers = thPattern
          .allMatches(theadContent)
          .map((m) => _stripHtmlTags(m.group(1)!))
          .toList();
    }

    // Extract body rows
    final tbodyPattern = RegExp(r'<tbody>(.*?)</tbody>', dotAll: true);
    final tbodyMatch = tbodyPattern.firstMatch(tableHtml);
    List<List<String>> rows = [];

    if (tbodyMatch != null) {
      final tbodyContent = tbodyMatch.group(1)!;
      final trPattern = RegExp(r'<tr>(.*?)</tr>', dotAll: true);
      for (final trMatch in trPattern.allMatches(tbodyContent)) {
        final trContent = trMatch.group(1)!;
        final tdPattern = RegExp(r'<td>(.*?)</td>', dotAll: true);
        final cells = tdPattern
            .allMatches(trContent)
            .map((m) => _stripHtmlTags(m.group(1)!))
            .toList();
        if (cells.isNotEmpty) {
          rows.add(cells);
        }
      }
    }

    // If no thead/tbody, try to find tr tags directly
    if (headers.isEmpty && rows.isEmpty) {
      final trPattern = RegExp(r'<tr>(.*?)</tr>', dotAll: true);
      final allRows = trPattern.allMatches(tableHtml).toList();
      if (allRows.isNotEmpty) {
        // First row is header
        final firstRowContent = allRows[0].group(1)!;
        final thPattern = RegExp(r'<th>(.*?)</th>', dotAll: true);
        headers = thPattern
            .allMatches(firstRowContent)
            .map((m) => _stripHtmlTags(m.group(1)!))
            .toList();

        // Rest are body rows
        for (int i = 1; i < allRows.length; i++) {
          final rowContent = allRows[i].group(1)!;
          final tdPattern = RegExp(r'<td>(.*?)</td>', dotAll: true);
          final cells = tdPattern
              .allMatches(rowContent)
              .map((m) => _stripHtmlTags(m.group(1)!))
              .toList();
          if (cells.isNotEmpty) {
            rows.add(cells);
          }
        }
      }
    }

    if (headers.isEmpty && rows.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine column count
    final columnCount = headers.isNotEmpty
        ? headers.length
        : (rows.isNotEmpty ? rows[0].length : 0);
    if (columnCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: PremiumTheme.darkBg3.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Table(
          columnWidths: Map.fromIterable(
            List.generate(columnCount, (index) => index),
            key: (index) => index,
            value: (index) => const FlexColumnWidth(1),
          ),
          border: TableBorder(
            horizontalInside: BorderSide(color: Colors.white.withOpacity(0.1)),
            verticalInside: BorderSide(color: Colors.white.withOpacity(0.1)),
            bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            top: BorderSide(color: Colors.white.withOpacity(0.1)),
            left: BorderSide(color: Colors.white.withOpacity(0.1)),
            right: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          children: [
            // Header row
            if (headers.isNotEmpty)
              TableRow(
                decoration: BoxDecoration(
                  color: PremiumTheme.teal.withOpacity(0.2),
                ),
                children: headers
                    .map((header) => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            header,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            // Body rows
            ...rows.map((row) => TableRow(
                  children: List.generate(columnCount, (index) {
                    final cell = index < row.length ? row[index] : '';
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        cell,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }),
                )),
          ],
        ),
      ),
    );
  }

  String _extractTextFromTag(String html, String tag) {
    final openTag = '<$tag>';
    final closeTag = '</$tag>';
    final openIndex = html.indexOf(openTag);
    if (openIndex == -1) return html;
    final closeIndex = html.indexOf(closeTag, openIndex);
    if (closeIndex == -1) return html.substring(openIndex + openTag.length);
    return html
        .substring(openIndex + openTag.length, closeIndex)
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('{{', '{{')
        .replaceAll('}}', '}}');
  }

  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}

// Data Models
class Template {
  final String id;
  final String name;
  final String? description;
  final String templateType;
  final String approvalStatus;
  final bool isPublic;
  final bool isApproved;
  final int version;
  final List<TemplateSection> sections;
  final List<DynamicField> dynamicFields;
  final int usageCount;
  final String createdBy;
  final DateTime createdDate;
  final String? basedOnTemplateId;
  final String? content; // Full template content as JSON or HTML

  Template({
    required this.id,
    required this.name,
    this.description,
    required this.templateType,
    required this.approvalStatus,
    required this.isPublic,
    required this.isApproved,
    required this.version,
    required this.sections,
    this.dynamicFields = const [],
    required this.usageCount,
    required this.createdBy,
    required this.createdDate,
    this.basedOnTemplateId,
    this.content,
  });
}

class TemplateSection {
  final String title;
  final bool required;
  final String? defaultContent;

  TemplateSection({
    required this.title,
    this.required = false,
    this.defaultContent,
  });
}

class DynamicField {
  final String fieldKey;
  final String fieldName;

  DynamicField({
    required this.fieldKey,
    required this.fieldName,
  });
}

class StatusConfig {
  final Color color;
  final Color textColor;
  final IconData icon;
  final String label;

  StatusConfig({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.label,
  });
}
