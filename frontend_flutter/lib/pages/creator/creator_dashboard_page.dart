import 'package:flutter/material.dart';
import '../../widgets/footer.dart';
import '../../widgets/role_switcher.dart';
import '../../widgets/async_widget.dart';
import '../../services/error_service.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import '../../services/role_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  String _currentPage = 'Dashboard';
  bool _isRefreshing = false;
  String _statusFilter = 'all'; // all, draft, published, pending, approved

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Start collapsed
    _animationController.value = 1.0;

    // Refresh data when dashboard loads (after AppState is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure AppState has the token before refreshing
      final app = context.read<AppState>();
      if (app.authToken == null && AuthService.token != null) {
        print('🔄 Syncing token to AppState...');
        app.authToken = AuthService.token;
        app.currentUser = AuthService.currentUser;
      }
      await _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final app = context.read<AppState>();

      // Double-check auth token is synced
      if (app.authToken == null && AuthService.token != null) {
        app.authToken = AuthService.token;
        app.currentUser = AuthService.currentUser;
        ErrorService.logError(
          'Synced token from AuthService',
          context: 'DashboardPage._refreshData',
          additionalData: {
            'tokenLength': AuthService.token?.length,
          },
        );
      }

      if (app.authToken == null) {
        ErrorService.handleError(
          'Authentication required. Please log in again.',
          context: 'DashboardPage._refreshData',
          severity: ErrorSeverity.high,
        );
        return;
      }

      await Future.wait([
        app.fetchProposals(),
        app.fetchDashboard(),
      ]);
      
      ErrorService.logError(
        'Dashboard data refreshed successfully',
        context: 'DashboardPage._refreshData',
        additionalData: {
          'proposalsCount': app.proposals.length,
        },
      );
    } catch (e) {
      ErrorService.handleError(
        'Failed to refresh dashboard data. Please try again.',
        error: e,
        context: 'DashboardPage._refreshData',
        severity: ErrorSeverity.medium,
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  List<dynamic> _getFilteredProposals(List<dynamic> proposals) {
    if (_statusFilter == 'all') {
      return proposals;
    }
    return proposals.where((proposal) {
      final status = proposal['status']?.toString().toLowerCase() ?? 'draft';
      return status == _statusFilter.toLowerCase();
    }).toList();
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
                      // Role Switcher
                      const CompactRoleSwitcher(),
                      const SizedBox(width: 20),
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
                          // Navigation items
                          _buildNavItem(
                              'Dashboard',
                              'assets/images/Dahboard.png',
                              _currentPage == 'Dashboard',
                              context),
                          _buildNavItem(
                              'My Proposals',
                              'assets/images/My_Proposals.png',
                              _currentPage == 'My Proposals',
                              context),
                          _buildNavItem(
                              'Templates',
                              'assets/images/content_library.png',
                              _currentPage == 'Templates',
                              context),
                          _buildNavItem(
                              'Content Library',
                              'assets/images/content_library.png',
                              _currentPage == 'Content Library',
                              context),
                          _buildNavItem(
                              'Collaboration',
                              'assets/images/collaborations.png',
                              _currentPage == 'Collaboration',
                              context),
                          _buildNavItem(
                              'Approvals Status',
                              'assets/images/Time Allocation_Approval_Blue.png',
                              _currentPage == 'Approvals Status',
                              context),
                          _buildNavItem(
                              'Analytics (My Pipeline)',
                              'assets/images/analytics.png',
                              _currentPage == 'Analytics (My Pipeline)',
                              context),

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
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: RefreshIndicator(
                      onRefresh: _refreshData,
                      color: const Color(0xFF3498DB),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: _buildRoleSpecificContent(userRole, counts, app),
                      ),
                    ),
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
        Navigator.pushNamed(context, '/approvals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushNamed(context, '/analytics');
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
    return InkWell(
      onTap: () {
        // Navigate to proposals page when clicking on stat cards
        Navigator.pushNamed(context, '/proposals');
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
    final filteredProposals = _getFilteredProposals(proposals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterTab('All', 'all', proposals.length),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'Draft',
                  'draft',
                  proposals
                      .where((p) =>
                          (p['status'] ?? 'draft').toString().toLowerCase() ==
                          'draft')
                      .length),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'Sent to Client',
                  'sent to client',
                  proposals
                      .where((p) =>
                          (p['status'] ?? '').toString().toLowerCase() ==
                          'sent to client')
                      .length),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'Pending CEO Approval',
                  'pending ceo approval',
                  proposals
                      .where((p) =>
                          (p['status'] ?? '').toString().toLowerCase() ==
                          'pending ceo approval')
                      .length),
              const SizedBox(width: 8),
              _buildFilterTab(
                  'Signed',
                  'signed',
                  proposals
                      .where((p) =>
                          (p['status'] ?? '').toString().toLowerCase() ==
                          'signed')
                      .length),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filtered Proposals List
        if (filteredProposals.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No proposals found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredProposals.take(5).map((proposal) {
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
      ],
    );
  }

  Widget _buildFilterTab(String label, String value, int count) {
    final isActive = _statusFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF3498DB) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF2980B9) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF2C3E50),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.3)
                      : const Color(0xFF3498DB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF3498DB),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
      case 'Client':
        return _buildClientDashboard(counts, app);
      case 'Financial Manager':
      default:
        return _buildFinancialManagerDashboard(counts, app);
    }
  }

  Widget _buildCEODashboard(Map<String, dynamic> counts, AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👔 CEO Executive Dashboard',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Organization-wide overview and pending approvals',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),

        // CEO Dashboard Grid
        _buildSection(
          '📊 Organization Overview',
          _buildDashboardGrid(counts, context),
        ),
        const SizedBox(height: 20),

        // Pending Approvals Section (CEO-specific)
        _buildSection(
          '⏳ Awaiting Your Approval',
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.pending_actions,
                    size: 48, color: Color(0xFFE67E22)),
                const SizedBox(height: 12),
                Text(
                  '${counts['Pending CEO Approval'] ?? 0} proposals pending your approval',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.approval),
                  label: const Text('Review Pending Approvals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/approvals');
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Recent Proposals
        _buildSection(
          '📝 All Proposals (Organization-wide)',
          _buildRecentProposals(app.proposals),
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
          '💼 Financial Manager Dashboard',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create and manage proposals for client engagement',
          style: TextStyle(color: Colors.grey),
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
          '🤝 Client Portal',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 8),
        const Text(
          'View and manage proposals sent to you',
          style: TextStyle(color: Colors.grey),
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
}
