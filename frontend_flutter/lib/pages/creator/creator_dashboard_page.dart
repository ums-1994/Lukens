import 'package:flutter/material.dart';
import '../../widgets/footer.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/auth_service.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final counts = app.dashboardCounts;

    // Debug: Print current state
    print('Dashboard - Current User: ${app.currentUser}');
    print('Dashboard - Counts: $counts');
    print('Dashboard - Proposals: ${app.proposals}');

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                        child: Center(
                          child: Text(
                            _getUserInitials(app.currentUser),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getUserName(app.currentUser),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'logout') {
                            app.logout();
                            AuthService.logout();
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
                // Sidebar
                Container(
                  width: 250,
                  color: const Color(0xFF34495E),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Title with better styling
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3E50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF34495E), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                color: Color(0xFF3498DB),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
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
                        _buildNavItem('📊', 'Dashboard', true, context),
                        _buildNavItem('📝', 'My Proposals', false, context),
                        _buildNavItem('📂', 'Templates', false, context),
                        _buildNavItem('🧩', 'Content Library', false, context),
                        _buildNavItem('👥', 'Collaboration', false, context),
                        _buildNavItem('📋', 'Approvals Status', false, context),
                        _buildNavItem(
                            '🔍', 'Analytics (My Pipeline)', false, context),

                        // Divider
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          height: 1,
                          color: const Color(0xFF2C3E50),
                        ),

                        // Quick Actions Section
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Quick Actions',
                            style: TextStyle(
                              color: Color(0xFF95A5A6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        _buildNavItem('➕', 'New Proposal', false, context),
                        _buildNavItem('⚙️', 'Settings', false, context),

                        // Debug section
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ElevatedButton(
                            onPressed: () {
                              print(
                                  'Debug button clicked - navigating to templates');
                              Navigator.pushReplacementNamed(
                                  context, '/templates');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE74C3C),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('DEBUG: Go to Templates'),
                          ),
                        ),

                        const SizedBox(height: 20), // Add bottom padding
                      ],
                    ),
                  ),
                ),

                // Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Proposal Dashboard Section
                          _buildSection(
                            '📊 Proposal Dashboard',
                            _buildDashboardGrid(counts, context),
                          ),
                          const SizedBox(height: 20),

                          // End-to-End Proposal Flow
                          _buildSection(
                            '🔧 End-to-End Proposal Flow',
                            _buildWorkflow(context),
                          ),
                          const SizedBox(height: 20),

                          // AI-Powered Compound Risk Gate
                          _buildAISection(context),
                          const SizedBox(height: 20),

                          // Recent Proposals
                          _buildSection(
                            '📝 Recent Proposals',
                            _buildRecentProposals(context, app.proposals),
                          ),
                          const SizedBox(height: 20),

                          // System Components
                          _buildSection(
                            '🧩 System Components',
                            _buildSystemComponents(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Footer(),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      String icon, String label, bool isActive, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(color: const Color(0xFF2980B9), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            print('Tapped on: $label'); // Debug print
            _navigateToPage(context, label);
          },
          onHover: (hovering) {
            // This will provide visual feedback on hover
          },
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(icon,
                    style: TextStyle(
                      fontSize: 18,
                      color: isActive ? Colors.white : const Color(0xFFBDC3C7),
                    )),
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
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.white,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, String label) {
    print('Navigating to: $label'); // Debug print

    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/creator_dashboard');
        break;
      case 'My Proposals':
        Navigator.pushReplacementNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushReplacementNamed(context, '/templates');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
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
      case 'New Proposal':
        Navigator.pushReplacementNamed(context, '/compose');
        break;
      case 'Settings':
        // For now, show a message as settings page might not exist
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings page coming soon!'),
            backgroundColor: Color(0xFFE67E22),
          ),
        );
        break;
      default:
        // Default to dashboard
        Navigator.pushReplacementNamed(context, '/creator_dashboard');
    }
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: const Color(0xFFCCC), style: BorderStyle.solid),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 15),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(
      Map<String, dynamic> counts, BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      children: [
        _buildStatCard('Draft Proposals', counts['Draft']?.toString() ?? '4',
            'Active', context),
        _buildStatCard('In Review', counts['In Review']?.toString() ?? '2',
            'Pending', context),
        _buildStatCard('Awaiting Sign-off',
            counts['Released']?.toString() ?? '3', 'With Clients', context),
        _buildStatCard('Signed', counts['Signed']?.toString() ?? '12',
            'This Quarter', context),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, BuildContext context) {
    return InkWell(
      onTap: () {
        // Navigate to proposals page when clicking on stat cards
        Navigator.pushReplacementNamed(context, '/proposals');
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3498DB),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7F8C8D),
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
    );
  }

  Widget _buildWorkflow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildWorkflowStep('1', 'Compose', context),
        _buildWorkflowStep('2', 'Govern', context),
        _buildWorkflowStep('3', 'AI Risk Gate', context),
        _buildWorkflowStep('4', 'Internal Sign-off', context),
        _buildWorkflowStep('5', 'Client Sign-off', context),
      ],
    );
  }

  Widget _buildWorkflowStep(String number, String label, BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          _navigateToWorkflowStep(context, label);
        },
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2F8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3498DB), width: 2),
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Color(0xFF3498DB),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7F8C8D),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToWorkflowStep(BuildContext context, String step) {
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $step...'),
        duration: const Duration(milliseconds: 500),
        backgroundColor: const Color(0xFF3498DB),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      switch (step) {
        case 'Compose':
          Navigator.pushReplacementNamed(context, '/compose');
          break;
        case 'Govern':
          Navigator.pushReplacementNamed(context, '/govern');
          break;
        case 'AI Risk Gate':
          // For now, navigate to approvals as AI risk gate might be part of approval process
          Navigator.pushReplacementNamed(context, '/approvals');
          break;
        case 'Internal Sign-off':
          Navigator.pushReplacementNamed(context, '/approvals');
          break;
        case 'Client Sign-off':
          Navigator.pushReplacementNamed(context, '/approvals');
          break;
        default:
          Navigator.pushReplacementNamed(context, '/creator_dashboard');
      }
    });
  }

  void _navigateToSystemComponent(BuildContext context, String component) {
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $component...'),
        duration: const Duration(milliseconds: 500),
        backgroundColor: const Color(0xFF3498DB),
      ),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      switch (component) {
        case 'Template Library':
          Navigator.pushReplacementNamed(context, '/compose');
          break;
        case 'Content Blocks':
          Navigator.pushReplacementNamed(context, '/content_library');
          break;
        case 'Collaboration Tools':
          Navigator.pushReplacementNamed(context, '/approvals');
          break;
        case 'E-Signature':
          Navigator.pushReplacementNamed(context, '/approvals');
          break;
        case 'Analytics':
          Navigator.pushReplacementNamed(context, '/proposals');
          break;
        case 'User Management':
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
          break;
        default:
          Navigator.pushReplacementNamed(context, '/creator_dashboard');
      }
    });
  }

  Widget _buildAISection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFFFFA94D), style: BorderStyle.solid),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🤖 AI-Powered Compound Risk Gate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE67E22),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'AI analyzes multiple small deviations and flags combined risks before release',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: const Color(0xFFEEE),
            ),
            const SizedBox(height: 10),
            _buildProposalItem(
              context,
              'GlobalTech Cloud Migration',
              '3 risks detected: Missing assumptions, Incomplete bios, Altered clauses',
              'Review Needed',
              const Color(0xFFB8DAFF),
              const Color(0xFF004085),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProposals(BuildContext context, List<dynamic> proposals) {
    return Column(
      children: proposals.take(3).map((proposal) {
        String status = proposal['status'] ?? 'Draft';
        Color statusColor = _getStatusColor(status);
        Color textColor = _getStatusTextColor(status);

        return _buildProposalItem(
          context,
          proposal['title'] ?? 'Untitled',
          'Last modified: ${_formatDate(proposal['updated_at'])}',
          status,
          statusColor,
          textColor,
          proposalId: proposal['id'],
        );
      }).toList(),
    );
  }

  Widget _buildProposalItem(BuildContext context, String title, String subtitle, String status,
      Color statusColor, Color textColor, {String? proposalId}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (status == 'Draft' && proposalId != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _submitForApproval(context, proposalId, title),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Submit for Approval'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _submitForApproval(BuildContext context, String proposalId, String proposalTitle) {
    Navigator.pushNamed(
      context,
      '/submit_for_approval',
      arguments: {
        'proposalId': proposalId,
        'proposalTitle': proposalTitle,
      },
    );
  }

  Widget _buildSystemComponents() {
    final components = [
      {'icon': '📋', 'label': 'Template Library'},
      {'icon': '📁', 'label': 'Content Blocks'},
      {'icon': '💬', 'label': 'Collaboration Tools'},
      {'icon': '🖊️', 'label': 'E-Signature'},
      {'icon': '📈', 'label': 'Analytics'},
      {'icon': '👥', 'label': 'User Management'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: components.length,
      itemBuilder: (context, index) {
        final component = components[index];
        return InkWell(
          onTap: () {
            _navigateToSystemComponent(context, component['label']!);
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: const Color(0xFFDDD), style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  component['icon']!,
                  style:
                      const TextStyle(fontSize: 24, color: Color(0xFF3498DB)),
                ),
                const SizedBox(height: 8),
                Text(
                  component['label']!,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0xFFFFEEBA);
      case 'in review':
        return const Color(0xFFB8DAFF);
      case 'signed':
        return const Color(0xFFC3E6CB);
      default:
        return const Color(0xFFFFEEBA);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0xFF856404);
      case 'in review':
        return const Color(0xFF004085);
      case 'signed':
        return const Color(0xFF155724);
      default:
        return const Color(0xFF856404);
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    // Simple date formatting - you might want to use intl package for better formatting
    return date.toString();
  }

  String _getUserInitials(Map<String, dynamic>? user) {
    if (user == null) return 'U';

    // Try different possible field names for the user's name
    String? name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email']?.split('@')[0];

    if (name == null || name.isEmpty) return 'U';

    // Extract initials from the name
    List<String> nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else {
      return name.substring(0, 2).toUpperCase();
    }
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'User';

    // Try different possible field names for the user's name
    String? name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email']?.split('@')[0];

    return name ?? 'User';
  }
}
