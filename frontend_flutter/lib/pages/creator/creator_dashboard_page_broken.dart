import 'package:flutter/material.dart';
import '../../widgets/footer.dart';
import '../../widgets/globe_3d_widget.dart';
import '../../widgets/bg_video.dart';
import '../../widgets/liquid_glass_card.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import '../../services/currency_service.dart';
import '../../widgets/currency_picker.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;
  String _currentPage = 'Dashboard';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _widthAnimation = Tween<double>(
      begin: 250.0,
      end: 90.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    // Start collapsed
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final counts = app.dashboardCounts;
    final userRole = app.currentUser?['role'] ?? 'Financial Manager';

    print('Dashboard - Current User: ${app.currentUser}');
    print('Dashboard - User Role: $userRole');
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
                  Text(
                    _getHeaderTitle(userRole),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/User_Profile.png',
                          width: 105,
                          height: 105,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getUserName(app.currentUser),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            userRole,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'logout') {
                            app.logout();
                            AuthService.logout();
                            Navigator.pushNamed(context, '/login');
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

          // Main Content with Sidebar
          Expanded(
            child: Row(
              children: [
                // Collapsible Sidebar
                GestureDetector(
                  onTap: () {
                    if (_isSidebarCollapsed) _toggleSidebar();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isSidebarCollapsed ? 90.0 : 250.0,
                    color: const Color(0xFF34495E),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Toggle button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: InkWell(
                              onTap: _toggleSidebar,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C3E50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: _isSidebarCollapsed
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (!_isSidebarCollapsed)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          'Navigation',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12),
                                        ),
                                      ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal:
                                              _isSidebarCollapsed ? 0 : 8),
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
                          // Role-based Navigation items
                          ..._getRoleBasedNavItems(userRole).map((item) => 
                            _buildNavItem(
                              item['label'],
                              item['asset'],
                              _currentPage == item['label'],
                              context,
                            ),
                          ).toList(),

                          const SizedBox(height: 20),

                          // Divider
                          if (!_isSidebarCollapsed)
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              height: 1,
                              color: const Color(0xFF2C3E50),
                            ),

                          const SizedBox(height: 12),

                          // Logout button
                          _buildNavItem(
                              'Logout',
                              'assets/images/Logout_KhonoBuzz.png',
                              false,
                              context),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildRoleSpecificContent(userRole, counts, app),
                  ),
                ),
              ],
            ),
          ),

          const Footer(),
        ],
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

  List<Map<String, dynamic>> _getRoleBasedNavItems(String userRole) {
    switch (userRole) {
      case 'CEO':
        return [
          {'label': 'Dashboard', 'asset': 'assets/images/Dahboard.png'},
          {'label': 'Analytics', 'asset': 'assets/images/analytics.png'},
          {'label': 'Approvals', 'asset': 'assets/images/Time Allocation_Approval_Blue.png'},
          {'label': 'Admin Panel', 'asset': 'assets/images/Dahboard.png'},
          {'label': 'User Management', 'asset': 'assets/images/Dahboard.png'},
          {'label': 'System Settings', 'asset': 'assets/images/Dahboard.png'},
        ];
      case 'Reviewer':
        return [
          {'label': 'Dashboard', 'asset': 'assets/images/Dahboard.png'},
          {'label': 'Pending Reviews', 'asset': 'assets/images/Time Allocation_Approval_Blue.png'},
          {'label': 'Review Queue', 'asset': 'assets/images/Time Allocation_Approval_Blue.png'},
          {'label': 'Approved Proposals', 'asset': 'assets/images/My_Proposals.png'},
          {'label': 'Collaboration', 'asset': 'assets/images/collaborations.png'},
          {'label': 'Analytics', 'asset': 'assets/images/analytics.png'},
          {'label': 'Quality Metrics', 'asset': 'assets/images/analytics.png'},
        ];
      case 'Client':
        return [
          {'label': 'My Proposals', 'asset': 'assets/images/My_Proposals.png'},
          {'label': 'Signed Documents', 'asset': 'assets/images/My_Proposals.png'},
          {'label': 'Messages', 'asset': 'assets/images/collaborations.png'},
          {'label': 'Support', 'asset': 'assets/images/Dahboard.png'},
          {'label': 'Profile', 'asset': 'assets/images/Dahboard.png'},
          {'label': 'Notifications', 'asset': 'assets/images/Dahboard.png'},
        ];
      default: // Financial Manager
        return [
          {'label': 'Dashboard', 'asset': 'assets/images/Dahboard.png'},
          {'label': 'My Proposals', 'asset': 'assets/images/My_Proposals.png'},
          {'label': 'Templates', 'asset': 'assets/images/content_library.png'},
          {'label': 'Content Library', 'asset': 'assets/images/content_library.png'},
          {'label': 'Collaboration', 'asset': 'assets/images/collaborations.png'},
          {'label': 'Approvals Status', 'asset': 'assets/images/Time Allocation_Approval_Blue.png'},
          {'label': 'Analytics (My Pipeline)', 'asset': 'assets/images/analytics.png'},
        ];
    }
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        // Already on dashboard
        break;
      case 'My Proposals':
        Navigator.pushNamed(context, '/proposals');
        break;
      case 'Templates':
        Navigator.pushNamed(context, '/templates');
        break;
      case 'Content Library':
        Navigator.pushNamed(context, '/content_library');
        break;
      case 'Collaboration':
        Navigator.pushNamed(context, '/collaboration');
        break;
      case 'Approvals Status':
      case 'Approvals':
        Navigator.pushNamed(context, '/approvals');
        break;
      case 'Analytics (My Pipeline)':
      case 'Analytics':
        Navigator.pushNamed(context, '/analytics');
        break;
      // CEO-specific pages
      case 'Admin Panel':
        Navigator.pushNamed(context, '/admin_panel');
        break;
      case 'User Management':
        Navigator.pushNamed(context, '/user_management');
        break;
      case 'System Settings':
        Navigator.pushNamed(context, '/system_settings');
        break;
      // Reviewer-specific pages
      case 'Pending Reviews':
        Navigator.pushNamed(context, '/pending_reviews');
        break;
      case 'Review Queue':
        Navigator.pushNamed(context, '/review_queue');
        break;
      case 'Approved Proposals':
        Navigator.pushNamed(context, '/approved_proposals');
        break;
      case 'Quality Metrics':
        Navigator.pushNamed(context, '/quality_metrics');
        break;
      // Client-specific pages
      case 'Signed Documents':
        Navigator.pushNamed(context, '/signed_documents');
        break;
      case 'Messages':
        Navigator.pushNamed(context, '/messages');
        break;
      case 'Support':
        Navigator.pushNamed(context, '/support');
        break;
      case 'Profile':
        Navigator.pushNamed(context, '/profile');
        break;
      case 'Notifications':
        Navigator.pushNamed(context, '/notifications');
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
        _buildStatCard('Draft Proposals', counts['Draft']?.toString() ?? '0',
            'Active', context),
        _buildStatCard(
            'Pending CEO Approval',
            counts['Pending CEO Approval']?.toString() ?? '0',
            'Awaiting Review',
            context),
        _buildStatCard(
            'Sent to Client',
            counts['Sent to Client']?.toString() ?? '0',
            'With Clients',
            context),
        _buildStatCard('Signed', counts['Signed']?.toString() ?? '0',
            'Completed', context),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, BuildContext context) {
    return LiquidGlassCard(
      onTap: () => Navigator.pushNamed(context, '/proposals'),
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00D4FF),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB0B6BB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
          Navigator.pushNamed(context, '/compose');
          break;
        case 'Govern':
          Navigator.pushNamed(context, '/govern');
          break;
        case 'AI Risk Gate':
          // For now, navigate to approvals as AI risk gate might be part of approval process
          Navigator.pushNamed(context, '/approvals');
          break;
        case 'Internal Sign-off':
          Navigator.pushNamed(context, '/approvals');
          break;
        case 'Client Sign-off':
          Navigator.pushNamed(context, '/approvals');
          break;
        default:
          Navigator.pushNamed(context, '/creator_dashboard');
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
          Navigator.pushNamed(context, '/compose');
          break;
        case 'Content Blocks':
          Navigator.pushNamed(context, '/content_library');
          break;
        case 'Collaboration Tools':
          Navigator.pushNamed(context, '/approvals');
          break;
        case 'E-Signature':
          Navigator.pushNamed(context, '/approvals');
          break;
        case 'Analytics':
          Navigator.pushNamed(context, '/proposals');
          break;
        case 'User Management':
          Navigator.pushNamed(context, '/admin_dashboard');
          break;
        default:
          Navigator.pushNamed(context, '/creator_dashboard');
      }
    });
  }

  Widget _buildAISection() {
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

  Widget _buildRecentProposals(List<dynamic> proposals) {
    return Column(
      children: proposals.take(3).map((proposal) {
        String status = proposal['status'] ?? 'Draft';
        Color statusColor = _getStatusColor(status);
        Color textColor = _getStatusTextColor(status);

        return _buildProposalItem(
          proposal['title'] ?? 'Untitled',
          'Last modified: ${_formatDate(proposal['updated_at'])}',
          status,
          statusColor,
          textColor,
        );
      }).toList(),
    );
  }

  Widget _buildProposalItem(String title, String subtitle, String status,
      Color statusColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
      ),
      child: Row(
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
        return LiquidGlassCard(
          onTap: () => _navigateToSystemComponent(context, component['label']!),
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                component['icon']!,
                style: const TextStyle(fontSize: 24, color: Color(0xFF00D4FF)),
              ),
              const SizedBox(height: 8),
              Text(
                component['label']!,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
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

  String _getHeaderTitle(String role) {
    switch (role) {
      case 'CEO':
        return 'CEO Dashboard - Executive Overview';
      case 'Financial Manager':
        return 'Financial Manager - Proposal Management';
      case 'Client':
        return 'Client Portal - My Proposals';
      default:
        return 'Proposal & SOW Builder';
    }
  }

  Widget _buildRoleSpecificContent(
      String role, Map<String, dynamic> counts, AppState app) {
    switch (role) {
      case 'CEO':
        return _buildCEODashboard(counts, app);
      case 'Reviewer':
        return _buildReviewerDashboard(counts, app);
      case 'Client':
        return _buildClientDashboard(counts, app);
      case 'Financial Manager':
      default:
        return _buildFinancialManagerDashboard(counts, app);
    }
  }

  Widget _buildCEODashboard(Map<String, dynamic> counts, AppState app) {
    return Container(
      color: Colors.transparent,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Ultra Premium Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE9293A), Color(0xFFFFD700), Color(0xFF14B3BB)],
                  ).createShader(bounds),
                  child: const Text(
                    'ULTRA PREMIUM 2025 DASHBOARD',
          style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
        ),
        const SizedBox(height: 8),
        const Text(
                  'Executive Overview • Global Analytics',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFB0B6BB),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),

          // Main Content Grid
          SizedBox(
            height: 500,
            child: Row(
              children: [
                // Left Column - Data Cards
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildPremiumMetricCard(
                        'DRAFT PROPOSALS',
                        counts['Draft']?.toString() ?? '0',
                        '90.0%',
                        const LinearGradient(
                          colors: [Color(0xFFE9293A), Color(0xFFFFD700)],
                        ),
                        Icons.edit_document,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumMetricCard(
                        'PENDING APPROVAL',
                        counts['Pending CEO Approval']?.toString() ?? '0',
                        '15.0%',
                        const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        Icons.pending_actions,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumMetricCard(
                        'SENT TO CLIENT',
                        counts['Sent to Client']?.toString() ?? '0',
                        '7.5%',
                        const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF14B3BB)],
                        ),
                        Icons.send,
                      ),
                    ],
                  ),
                ),

                // Center - Global Analytics
                Expanded(
                  flex: 3,
                  child: _buildGlobalAnalyticsCard(),
                ),

                // Right Column - Data Cards
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildPremiumMetricCard(
                        'SIGNED PROPOSALS',
                        counts['Signed']?.toString() ?? '0',
                        '2.5%',
                        const LinearGradient(
                          colors: [Color(0xFF14B3BB), Color(0xFF00D4FF)],
                        ),
                        Icons.check_circle,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumMetricCard(
                        'TOTAL REVENUE',
                        CurrencyService().formatLargeAmount(2847392),
                        '08.9%',
                        const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        Icons.attach_money,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumMetricCard(
                        'LIQUIDATED',
                        counts['Liquidated']?.toString() ?? '0',
                        '0%',
                        const LinearGradient(
                          colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
                        ),
                        Icons.water_drop,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          const Footer(),
        ],
      ),
    );
  }

  Widget _buildReviewStatCard(String title, String value, Color color, IconData icon) {
    return LiquidGlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewQueueItem(String title, String client, String priority, String time, Color priorityColor) {
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14B3BB).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF14B3BB).withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'LIVE DATA',
                              style: TextStyle(
                                color: Color(0xFF14B3BB),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              '20 ACTIVE NODES',
                              style: TextStyle(
                                color: Color(0xFFFFD700),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Column - Data Cards
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildPremiumMetricCard(
                        'SIGNED PROPOSALS',
                        counts['Signed']?.toString() ?? '0',
                        '2.5%',
                        const LinearGradient(
                          colors: [Color(0xFF14B3BB), Color(0xFF00D4FF)],
                        ),
                        Icons.check_circle,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumMetricCard(
                        'TOTAL REVENUE',
                        CurrencyService().formatLargeAmount(2847392),
                        '08.9%',
                        const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        Icons.attach_money,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumMetricCard(
                        'LIQUIDATED',
                        counts['Liquidated']?.toString() ?? '0',
                        '0%',
                        const LinearGradient(
                          colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
                        ),
                        Icons.water_drop,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

          // Bottom Section - Awaiting Approval
          _buildUltraPremiumApprovalSection(counts),
        ],
      ),
    );
  }

  // Premium glass-morphic stat card used across dashboards
  Widget _buildPremiumStatCard(
    String title,
    String value,
    String delta,
    Color startColor,
    Color endColor,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor.withOpacity(0.85), endColor.withOpacity(0.85)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
        ),
            padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(value,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(delta,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateTotalRevenue(List<dynamic> proposals) {
    // placeholder: sum proposal['amount'] if exists
    double total = 0;
    for (final p in proposals) {
      final amount = p['amount'];
      if (amount is num) total += amount.toDouble();
    }
    if (total == 0) return '0';
    return total.toStringAsFixed(0);
  }

  // Ultra Premium Glassmorphic Card
  Widget _buildUltraPremiumCard(
    String title,
    String value,
    String percentage,
    Color startColor,
    Color endColor,
    IconData icon,
  ) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            startColor.withOpacity(0.8),
            endColor.withOpacity(0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Text(
                    title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          percentage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ultra Premium Approval Section
  Widget _buildUltraPremiumApprovalSection(Map<String, dynamic> counts) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE9293A).withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFE9293A).withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE9293A).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.pending_actions,
                color: Color(0xFFE9293A),
                size: 30,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AWAITING YOUR APPROVAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${counts['Pending CEO Approval'] ?? 0} proposals pending your review',
                    style: const TextStyle(
                      color: Color(0xFFB0B6BB),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/approvals'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE9293A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
                shadowColor: const Color(0xFFE9293A).withOpacity(0.4),
              ),
              child: const Text(
                'REVIEW',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewerDashboard(Map<String, dynamic> counts, AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quality control and review management',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFFB0B6BB),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 32),

        // Review Metrics Row
        Row(
          children: [
            Expanded(
              child: _buildReviewStatCard(
                'Pending Reviews',
                '12',
                const Color(0xFFE9293A),
                Icons.pending_actions,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildReviewStatCard(
                'High Priority',
                '3',
                const Color(0xFFFFD700),
                Icons.priority_high,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildReviewStatCard(
                'Completed Today',
                '5',
                const Color(0xFF14B3BB),
                Icons.check_circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildReviewStatCard(
                'Avg Review Time',
                '2.5h',
                const Color(0xFF00D4FF),
                Icons.access_time,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Review Queue Section
        LiquidGlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Review Queue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/pending_reviews'),
                    icon: const Icon(Icons.visibility, color: Colors.white),
                    label: const Text('View All', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE9293A),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildReviewQueueItem(
                'Q4 Marketing Campaign Proposal',
                'TechCorp Inc.',
                'High',
                '2 hours ago',
                const Color(0xFFE9293A),
              ),
              const SizedBox(height: 12),
              _buildReviewQueueItem(
                'Software Development SOW',
                'StartupXYZ',
                'Medium',
                '1 day ago',
                const Color(0xFFFFD700),
              ),
              const SizedBox(height: 12),
              _buildReviewQueueItem(
                'Consulting Services Agreement',
                'Enterprise Solutions',
                'Low',
                '3 days ago',
                const Color(0xFF14B3BB),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Quality Metrics Section
        LiquidGlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quality Metrics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildQualityMetric(
                      'Approval Rate',
                      '85%',
                      const Color(0xFF14B3BB),
                      Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQualityMetric(
                      'Avg Review Score',
                      '4.2/5',
                      const Color(0xFFFFD700),
                      Icons.star,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQualityMetric(
                      'Revision Rate',
                      '15%',
                      const Color(0xFFE9293A),
                      Icons.edit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Recent Activity
        LiquidGlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Review Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildActivityItem(
                'Approved "Q3 Financial Report"',
                '2 hours ago',
                const Color(0xFF14B3BB),
                Icons.check_circle,
              ),
              const SizedBox(height: 12),
              _buildActivityItem(
                'Requested revision for "Marketing Strategy"',
                '4 hours ago',
                const Color(0xFFFFD700),
                Icons.edit,
              ),
              const SizedBox(height: 12),
              _buildActivityItem(
                'Completed review of "Tech Proposal"',
                '6 hours ago',
                const Color(0xFF00D4FF),
                Icons.visibility,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Footer(),
      ],
    );
  }

  Widget _buildReviewStatCard(String title, String value, Color color, IconData icon) {
    return LiquidGlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewQueueItem(String title, String client, String priority, String time, Color priorityColor) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/review_queue'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    client,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: priorityColor),
              ),
              child: Text(
                priority,
                style: TextStyle(
                  color: priorityColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityMetric(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialManagerDashboard(
      Map<String, dynamic> counts, AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Manager Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create and manage proposals for client engagement',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFFB0B6BB),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 24),

        // Dashboard Grid
        _buildSection(
          '📊 My Proposal Dashboard',
          _buildDashboardGrid(counts, context),
        ),
        const SizedBox(height: 20),

        // End-to-End Proposal Flow
        _buildSection(
          '🔧 Proposal Workflow',
          _buildWorkflow(context),
        ),
        const SizedBox(height: 20),

        // AI-Powered Compound Risk Gate
        _buildAISection(),
        const SizedBox(height: 20),

        // Recent Proposals
        _buildSection(
          '📝 My Recent Proposals',
          _buildRecentProposals(app.proposals),
        ),
        const SizedBox(height: 20),

        // System Components
        _buildSection(
          '🧩 Available Tools',
          _buildSystemComponents(),
        ),
      ],
    );
  }

  Widget _buildClientDashboard(Map<String, dynamic> counts, AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Client Portal',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Access your proposals and communicate with our team',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFFB0B6BB),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 24),

        // Simplified Dashboard for Clients
        _buildSection(
          '📊 My Proposals Status',
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            children: [
              _buildStatCard(
                  'Active Proposals',
                  counts['Sent to Client']?.toString() ?? '0',
                  'For Review',
                  context),
              _buildStatCard('Signed', counts['Signed']?.toString() ?? '0',
                  'Completed', context),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Active Proposals
        _buildSection(
          '📝 Proposals Sent to Me',
          app.proposals.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No proposals yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildRecentProposals(app.proposals),
        ),
        const SizedBox(height: 20),

        // Quick Actions
        _buildSection(
          '⚡ Quick Actions',
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download Signed Documents'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feature coming soon!')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.support_agent),
                label: const Text('Contact Support'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Support: support@example.com')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumMetricCard(String label, String value, String percentage, LinearGradient gradient, IconData icon) {
    return GestureDetector(
      onTap: () {
        // Navigate based on the metric type
        switch (label) {
          case 'DRAFT PROPOSALS':
            Navigator.pushNamed(context, '/proposals');
            break;
          case 'PENDING APPROVAL':
            Navigator.pushNamed(context, '/approvals');
            break;
          case 'SENT TO CLIENT':
            Navigator.pushNamed(context, '/proposals');
            break;
          case 'SIGNED PROPOSALS':
            Navigator.pushNamed(context, '/proposals');
            break;
          case 'TOTAL REVENUE':
            Navigator.pushNamed(context, '/analytics');
            break;
          case 'LIQUIDATED':
            Navigator.pushNamed(context, '/proposals');
            break;
        }
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      percentage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalAnalyticsCard() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/analytics'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9293A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE9293A)),
                    ),
                    child: const Text(
                      'GLOBAL ANALYTICS',
                      style: TextStyle(
                        color: Color(0xFFE9293A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/analytics'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B3BB).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF14B3BB)),
                    ),
                    child: const Text(
                      'LIVE DATA',
                      style: TextStyle(
                        color: Color(0xFF14B3BB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: const BgVideo(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/user_management'),
                  child: _buildAnalyticsMetric('Clients', '156', const Color(0xFF14B3BB)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/analytics'),
                  child: _buildAnalyticsMetric('Countries', '23', const Color(0xFF00D4FF)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/analytics'),
                  child: _buildAnalyticsMetric('Growth', '+23%', const Color(0xFFE9293A)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildClientStatCard(String title, String value, Color color, IconData icon) {
    return LiquidGlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientProposalItem(String title, String status, String time, Color statusColor, IconData icon) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/proposals'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          children: [
            Icon(icon, color: statusColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(String title, String description, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlassCard(
        borderRadius: 12,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientActivityItem(String title, String time, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
