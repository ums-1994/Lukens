import 'package:flutter/material.dart';
import '../../widgets/footer.dart';
import '../../widgets/role_switcher.dart';
import '../../widgets/custom_scrollbar.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/asset_service.dart';
import '../../services/role_service.dart';
import '../../theme/premium_theme.dart';

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
  final ScrollController _scrollController = ScrollController();

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
        final t = AuthService.token ?? '';
        final preview = t.length > 20 ? t.substring(0, 20) : t;
        print('✅ Synced token from AuthService: $preview...');
      }

      if (app.authToken == null) {
        print('❌ No auth token available - cannot fetch data');
        return;
      }

      await Future.wait([
        app.fetchProposals(),
        app.fetchDashboard(),
      ]);
      print(
          '✅ Dashboard data refreshed - ${app.proposals.length} proposals loaded');
    } catch (e) {
      print('❌ Error refreshing dashboard: $e');
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
    _scrollController.dispose();
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
      body: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            // Header
            Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getHeaderTitle(userRole),
                      style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
                    ),
                    Row(
                      children: [
                        const CompactRoleSwitcher(),
                        const SizedBox(width: 20),
                        ClipOval(
                          child: Image.asset(
                            'assets/images/User_Profile.png',
                            width: 48,
                            height: 48,
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
                          icon:
                              const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'logout') {
                              app.logout();
                              AuthService.logout();
                              Navigator.pushNamed(context, '/login');
                            }
                          },
                          itemBuilder: (BuildContext context) => const [
                            PopupMenuItem<String>(
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
                // Collapsible Sidebar with Glass Effect
                AnimatedContainer(
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
                          // Toggle button
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
                              'Client Management',
                              'assets/images/collaborations.png',
                              _currentPage == 'Client Management',
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

                // Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CustomScrollbar(
                      controller: _scrollController,
                    child: RefreshIndicator(
                      onRefresh: _refreshData,
                      color: const Color(0xFF3498DB),
                      child: SingleChildScrollView(
                          controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(right: 24),
                        child: _buildRoleSpecificContent(userRole, counts, app),
                        ),
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
        Navigator.pushReplacementNamed(context, '/proposals');
        break;
      case 'Templates':
        // Templates functionality - redirect to content library for now
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Client Management':
        Navigator.pushReplacementNamed(context, '/collaboration');
        break;
      case 'Approvals Status':
        Navigator.pushReplacementNamed(context, '/approvals');
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

  Widget _buildSection(String title, Widget content) {
    return GlassContainer(
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PremiumTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildDashboardGrid(
      Map<String, dynamic> counts, BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
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
    // Assign different gradients to different cards
    Gradient gradient;
    switch (title) {
      case 'Draft Proposals':
        gradient = PremiumTheme.orangeGradient;
        break;
      case 'Pending CEO Approval':
        gradient = PremiumTheme.purpleGradient;
        break;
      case 'Sent to Client':
        gradient = PremiumTheme.blueGradient;
        break;
      case 'Signed':
        gradient = PremiumTheme.tealGradient;
        break;
      default:
        gradient = PremiumTheme.blueGradient;
    }

    return PremiumStatCard(
      title: title,
      value: value,
      subtitle: subtitle,
      gradient: gradient,
      onTap: () {
        Navigator.pushNamed(context, '/proposals');
      },
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
    final app = context.watch<AppState>();
    final proposals = app.proposals;
    
    // Find proposals that can be analyzed (draft or sent status)
    final analyzableProposals = proposals.where((p) {
      final status = (p['status'] ?? '').toString().toLowerCase();
      return status == 'draft' || status == 'sent' || status == 'sent to client';
    }).toList();
    
    // Get the most recent one or first one
    final targetProposal = analyzableProposals.isNotEmpty 
        ? analyzableProposals.first 
        : null;
    
    return GlassContainer(
      borderRadius: 24,
      gradientStart: PremiumTheme.orange.withOpacity(0.3),
      gradientEnd: PremiumTheme.error.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PremiumTheme.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  color: PremiumTheme.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Powered Compound Risk Gate',
                      style: PremiumTheme.titleMedium.copyWith(
                        fontSize: 18,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI analyzes multiple small deviations and flags combined risks',
                      style: PremiumTheme.bodyMedium.copyWith(
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (targetProposal != null)
            InkWell(
              onTap: () => _runRiskAnalysisForProposal(targetProposal),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PremiumTheme.glassWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: PremiumTheme.glassWhiteBorder,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            targetProposal['title'] ?? 'Untitled Proposal',
                            style: PremiumTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: PremiumTheme.textPrimary,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: PremiumTheme.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click to run AI risk analysis and detect potential issues',
                      style: PremiumTheme.bodyMedium.copyWith(
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: PremiumTheme.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: PremiumTheme.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_circle_outline,
                            size: 16,
                            color: PremiumTheme.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Run Analysis',
                            style: PremiumTheme.labelMedium.copyWith(
                              color: PremiumTheme.orange,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PremiumTheme.glassWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PremiumTheme.glassWhiteBorder,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No proposals available for risk analysis',
                    style: PremiumTheme.bodyMedium.copyWith(
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/proposals'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Create Proposal',
                      style: TextStyle(decoration: TextDecoration.none),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runRiskAnalysisForProposal(Map<String, dynamic> proposal) async {
    final app = context.read<AppState>();
    final token = AuthService.token ?? app.authToken;
    
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required. Please log in again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final proposalId = proposal['id'];
    if (proposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal ID missing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final intId = proposalId is int
        ? proposalId
        : int.tryParse(proposalId.toString());

    if (intId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid proposal ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final result = await ApiService.analyzeRisks(
        token: token,
        proposalId: intId,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Risk analysis failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show risk analysis results
      _showRiskAnalysisResults(result, proposal);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRiskAnalysisResults(
    Map<String, dynamic> result,
    Map<String, dynamic> proposal,
  ) {
    final riskScore = result['risk_score'] ?? 0;
    final canRelease = result['can_release'] ?? false;
    final issues = result['issues'] as List<dynamic>? ?? [];
    final summary = result['summary'] ?? 'No summary available';

    final riskLevel = riskScore <= 30
        ? 'Ready'
        : riskScore <= 60
            ? 'At Risk'
            : 'Blocked';

    final riskColor = riskScore <= 30
        ? PremiumTheme.success
        : riskScore <= 60
            ? PremiumTheme.orange
            : PremiumTheme.error;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumTheme.darkBg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.security, color: riskColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Risk Analysis Results',
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proposal['title'] ?? 'Untitled Proposal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: riskColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Risk Score',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$riskScore/100',
                          style: TextStyle(
                            color: riskColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        riskLevel,
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                summary,
                style: TextStyle(
                  color: Colors.white70,
                  decoration: TextDecoration.none,
                ),
              ),
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Issues Detected:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                ...issues.take(5).map((issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: PremiumTheme.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue['description'] ?? 'Unknown issue',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!canRelease)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<AppState>().selectProposal(Map<String, dynamic>.from(proposal));
                Navigator.pushNamed(context, '/compose');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Review Proposal'),
            ),
        ],
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? PremiumTheme.blueGradient
              : null,
          color: isActive ? null : PremiumTheme.glassWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive 
                ? Colors.transparent 
                : PremiumTheme.glassWhiteBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : PremiumTheme.textPrimary,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.3)
                      : PremiumTheme.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isActive ? Colors.white : PremiumTheme.teal,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumTheme.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PremiumTheme.glassWhiteBorder,
          width: 1,
        ),
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
                  style: PremiumTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: PremiumTheme.bodyMedium.copyWith(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
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
        return PremiumTheme.orange;
      case 'in review':
      case 'pending ceo approval':
        return PremiumTheme.purple;
      case 'sent to client':
        return PremiumTheme.info;
      case 'signed':
        return PremiumTheme.teal;
      default:
        return PremiumTheme.orange;
    }
  }

  Color _getStatusTextColor(String status) {
    // For the new premium design, we use the same color for text
    // with opacity adjustments in the container
    return _getStatusColor(status);
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
