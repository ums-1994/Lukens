// ignore_for_file: unused_field, unused_element, unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/footer.dart';
import '../../theme/premium_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_side_nav.dart';
import '../../api.dart';
import 'dart:ui';

class ClientManagementPage extends StatefulWidget {
  const ClientManagementPage({super.key});

  @override
  State<ClientManagementPage> createState() => _ClientManagementPageState();
}

class _ClientManagementPageState extends State<ClientManagementPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _invitations = [];
  String _selectedTab = 'clients'; // clients, invitations
  String _inviteFilter = 'all'; // all, verified, unverified
  String _searchQuery = '';
  String _currentPage = 'Client Management';
  bool _isSidebarCollapsed = false;
  final ScrollController _scrollController = ScrollController();
  bool _routeSynced = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRoute());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _syncRoute() {
    if (_routeSynced || !mounted) return;
    final routeName = ModalRoute.of(context)?.settings.name;
    if (routeName != '/client_management') {
      _routeSynced = true;
      Navigator.of(context).pushReplacementNamed('/client_management');
    } else {
      _routeSynced = true;
    }
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'User';
    return user['full_name'] ?? user['email'] ?? 'User';
  }

  /// Helper function to check if an invitation email is verified
  /// Handles different data types (boolean, string, int) and checks email_verified_at
  bool _isEmailVerified(Map<String, dynamic> invite) {
    final emailVerifiedValue = invite['email_verified'];
    final emailVerifiedAt = invite['email_verified_at'];
    return emailVerifiedValue == true ||
        emailVerifiedValue == 'true' ||
        emailVerifiedValue == 1 ||
        (emailVerifiedAt != null &&
            emailVerifiedAt.toString().isNotEmpty &&
            emailVerifiedAt.toString() != 'null');
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final token = AuthService.token;
      if (token != null) {
        final results = await Future.wait([
          ClientService.getClients(token),
          ClientService.getInvitations(token),
        ]);

        if (mounted) {
          setState(() {
            _clients = List<Map<String, dynamic>>.from(results[0]);
            _invitations = List<Map<String, dynamic>>.from(results[1]);
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    final companyController = TextEditingController();
    final expiryController = TextEditingController(text: '7');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(32),
              decoration: PremiumTheme.glassCard(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: PremiumTheme.tealGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mail_outline,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Invite Client',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Send a secure onboarding link to your client',
                    style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: emailController,
                    label: 'Client Email',
                    icon: Icons.email,
                    hint: 'client@company.com',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: companyController,
                    label: 'Company Name (Optional)',
                    icon: Icons.business,
                    hint: 'Acme Inc.',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: expiryController,
                    label: 'Link Expires in (Days)',
                    icon: Icons.timer,
                    hint: '7',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFFB0BEC5)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (emailController.text.trim().isEmpty) {
                            _showSnackBar('Please enter a client email');
                            return;
                          }

                          Navigator.pop(ctx);
                          await _sendInvitation(
                            emailController.text.trim(),
                            companyController.text.trim(),
                            int.tryParse(expiryController.text.trim()) ?? 7,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumTheme.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.send, size: 18),
                            SizedBox(width: 8),
                            Text('Send Invitation',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF78909C)),
              prefixIcon: Icon(icon, color: PremiumTheme.teal, size: 20),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendInvitation(
      String email, String company, int expiryDays) async {
    setState(() => _loading = true);
    try {
      final token = AuthService.token;
      print('[DEBUG] Sending invitation to: $email');
      print('[DEBUG] Company: $company');
      print('[DEBUG] Expiry days: $expiryDays');
      print('[DEBUG] Token available: ${token != null}');

      if (token == null) {
        print('[ERROR] No authentication token available');
        _showSnackBar('Authentication error: Please log in again');
        return;
      }

      final result = await ClientService.sendInvitation(
        token: token,
        email: email,
        companyName: company.isNotEmpty ? company : null,
        expiryDays: expiryDays,
      );

      print('[DEBUG] Invitation result: $result');

      if (result != null) {
        _showSnackBar('Invitation sent successfully!', isSuccess: true);
        _loadData();
      } else {
        _showSnackBar('Failed to send invitation - check console for details');
      }
    } catch (e) {
      print('[ERROR] Exception sending invitation: $e');
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? PremiumTheme.success : PremiumTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppState>(context);
    final user = app.currentUser;
    final userRole = user?['role'] ?? 'Financial Manager';

    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            // Consistent Sidebar using AppSideNav
            Consumer<AppState>(
              builder: (context, app, child) {
                final role = (app.currentUser?['role'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                final isAdmin = role == 'admin' || role == 'ceo';
                return AppSideNav(
                  isCollapsed: app.isSidebarCollapsed,
                  currentLabel: app.currentNavLabel,
                  isAdmin: isAdmin,
                  onToggle: app.toggleSidebar,
                  onSelect: (label) {
                    app.setCurrentNavLabel(label);
                    _navigateToPage(context, label);
                  },
                );
              },
            ),

            // Main Content Area
            Expanded(
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
                            'Client Management',
                            style:
                                PremiumTheme.titleLarge.copyWith(fontSize: 22),
                          ),
                          Row(
                            children: [
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
                                    _getUserName(user),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    userRole.toString(),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white),
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

                  // Content Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CustomScrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(right: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 24),
                              _buildSearchAndFilter(),
                              const SizedBox(height: 24),
                              _buildStats(),
                              const SizedBox(height: 24),
                              _buildTabs(),
                              const SizedBox(height: 20),
                              if (_loading)
                                const Center(
                                    child: CircularProgressIndicator(
                                        color: PremiumTheme.teal))
                              else if (_selectedTab == 'clients')
                                _buildClientsTable()
                              else
                                _buildInvitationsTable(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Footer(),
                ],
              ),
            ),
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
            ],
          ),
        ),
      ),
    );
  }

  bool _isAdminUser() {
    try {
      final user = AuthService.currentUser;
      if (user == null) return false;
      final role = (user['role']?.toString() ?? '').toLowerCase().trim();
      return role == 'admin' || role == 'ceo';
    } catch (e) {
      return false;
    }
  }

  void _navigateToPage(BuildContext context, String label) {
    final isAdmin = _isAdminUser();

    switch (label) {
      case 'Dashboard':
        if (isAdmin) {
          Navigator.pushReplacementNamed(context, '/approver_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/creator_dashboard');
        }
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
      case 'Client Management':
        // Already on client management page
        break;
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Analytics (My Pipeline)':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      case 'Logout':
        final app = Provider.of<AppState>(context, listen: false);
        app.logout();
        AuthService.logout();
        Navigator.pushNamed(context, '/login');
        break;
      default:
        if (isAdmin) {
          Navigator.pushReplacementNamed(context, '/approver_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/creator_dashboard');
        }
    }
  }

  // Exact Dashboard Sidebar Implementation
  Widget _buildFixedSidebar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 768;
    final effectiveCollapsed = isSmall ? true : _isSidebarCollapsed;

    return AnimatedContainer(
      duration: AppColors.animationDuration,
      width: effectiveCollapsed
          ? AppColors.collapsedWidth
          : AppColors.expandedWidth,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundColor
                .withValues(alpha: AppColors.backgroundOpacity),
            border: Border(
              right: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Header Section
              SizedBox(
                height: AppColors.headerHeight,
                child: Padding(
                  padding: AppSpacing.sidebarHeaderPadding,
                  child: InkWell(
                    onTap: () {
                      if (!isSmall) {
                        setState(
                            () => _isSidebarCollapsed = !_isSidebarCollapsed);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: AppColors.itemHeight,
                      decoration: BoxDecoration(
                        color: AppColors.hoverColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: effectiveCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.spaceBetween,
                        children: [
                          if (!effectiveCollapsed)
                            Expanded(
                              child: Text(
                                'Navigation',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: effectiveCollapsed ? 0 : 8),
                            child: Icon(
                              effectiveCollapsed
                                  ? Icons.keyboard_arrow_right
                                  : Icons.keyboard_arrow_left,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Navigation Items
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildSidebarNavItem(
                        label: 'Dashboard',
                        assetPath: 'assets/images/Dahboard.png',
                        isSelected: _currentPage == 'Dashboard',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => _navigateToPage(context, 'Dashboard'),
                      ),
                      _buildSidebarNavItem(
                        label: 'My Proposals',
                        assetPath: 'assets/images/My_Proposals.png',
                        isSelected: _currentPage == 'My Proposals',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => _navigateToPage(context, 'My Proposals'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Templates',
                        assetPath: 'assets/images/content_library.png',
                        isSelected: _currentPage == 'Templates',
                        isCollapsed: effectiveCollapsed,
                        onTap: () => _navigateToPage(context, 'Templates'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Content Library',
                        assetPath: 'assets/images/content_library.png',
                        isSelected: _currentPage == 'Content Library',
                        isCollapsed: effectiveCollapsed,
                        onTap: () =>
                            _navigateToPage(context, 'Content Library'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Client Management',
                        assetPath: 'assets/images/collaborations.png',
                        isSelected: _currentPage == 'Client Management',
                        isCollapsed: effectiveCollapsed,
                        onTap: () =>
                            _navigateToPage(context, 'Client Management'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Approved Proposals',
                        assetPath:
                            'assets/images/Time Allocation_Approval_Blue.png',
                        isSelected: _currentPage == 'Approved Proposals',
                        isCollapsed: effectiveCollapsed,
                        onTap: () =>
                            _navigateToPage(context, 'Approved Proposals'),
                      ),
                      _buildSidebarNavItem(
                        label: 'Analytics (My Pipeline)',
                        assetPath: 'assets/images/analytics.png',
                        isSelected: _currentPage == 'Analytics (My Pipeline)',
                        isCollapsed: effectiveCollapsed,
                        onTap: () =>
                            _navigateToPage(context, 'Analytics (My Pipeline)'),
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      if (!effectiveCollapsed)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      const SizedBox(height: 12),

                      // Logout
                      _buildSidebarNavItem(
                        label: 'Logout',
                        assetPath: 'assets/images/Logout_KhonoBuzz.png',
                        isSelected: false,
                        isCollapsed: effectiveCollapsed,
                        onTap: () => _handleLogout(context),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required String label,
    required String assetPath,
    required bool isSelected,
    required bool isCollapsed,
    required VoidCallback onTap,
    bool showProfileIndicator = false,
  }) {
    bool hovering = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: MouseRegion(
            onEnter: (_) => setState(() => hovering = true),
            onExit: (_) => setState(() => hovering = false),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: AppColors.animationDuration,
                height: AppColors.itemHeight,
                decoration: BoxDecoration(
                  color: _getItemColor(isSelected, hovering, isCollapsed),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _getItemShadow(isSelected, hovering, isCollapsed),
                ),
                child: isCollapsed
                    ? _buildCollapsedItem(
                        assetPath, isSelected, showProfileIndicator)
                    : _buildExpandedItem(label, assetPath, isSelected),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedItem(
      String assetPath, bool isSelected, bool showProfileIndicator) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: AssetService.buildImageWidget(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
          if (showProfileIndicator)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.activeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedItem(String label, String assetPath, bool isSelected) {
    return Padding(
      padding: AppSpacing.sidebarItemPadding,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: AssetService.buildImageWidget(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppColors.textPrimary,
            ),
        ],
      ),
    );
  }

  Color _getItemColor(bool isSelected, bool hovering, bool isCollapsed) {
    if (isCollapsed) {
      return Colors.transparent; // All items transparent when collapsed
    }

    if (isSelected) {
      return AppColors.activeColor;
    }

    if (hovering) {
      return AppColors.hoverColor;
    }

    return Colors.transparent;
  }

  List<BoxShadow> _getItemShadow(
      bool isSelected, bool hovering, bool isCollapsed) {
    if (isCollapsed) {
      return []; // No shadow when collapsed
    }

    if (isSelected) {
      return [
        BoxShadow(
          color: AppColors.activeColor.withValues(alpha: 0x35),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
    }

    if (hovering) {
      return [
        BoxShadow(
          color: AppColors.hoverColor.withValues(alpha: 0x35),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
    }

    return [];
  }

  void _handleLogout(BuildContext context) {
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
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final app = Provider.of<AppState>(context, listen: false);
                app.logout();
                AuthService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: PremiumTheme.glassCard(
          gradientStart: PremiumTheme.cyan,
          gradientEnd: PremiumTheme.teal,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.people, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Manage your clients and track onboarding progress',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFE0F7FA),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text('Invite Client',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: PremiumTheme.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: PremiumTheme.glassCard(),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search clients...',
                      hintStyle: TextStyle(color: Color(0xFF78909C)),
                      prefixIcon: Icon(Icons.search, color: PremiumTheme.teal),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
              if (_selectedTab == 'invitations') ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _inviteFilter,
                      dropdownColor: const Color(0xFF0E1726),
                      items: const [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text('All',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: 'verified',
                            child: Text('Verified',
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: 'unverified',
                            child: Text('Unverified',
                                style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) =>
                          setState(() => _inviteFilter = val ?? 'all'),
                      icon: const Icon(Icons.filter_alt, color: Colors.white),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final activeClients = _clients.where((c) => c['status'] == 'active').length;
    // Count only active invitations (exclude completed ones - they're now clients)
    final activeInvitations = _invitations.where((i) {
      final status = i['status']?.toString().toLowerCase() ?? '';
      final clientId = i['client_id'];
      return status != 'completed' &&
          (clientId == null || clientId.toString().isEmpty);
    }).toList();

    // Count pending invites - those that are not verified yet (from active invitations only)
    final pendingInvites = activeInvitations.where((i) {
      return !_isEmailVerified(i) &&
          (i['status'] == 'pending' || i['status'] == null);
    }).length;
    // Count completed invites - those that are verified (from active invitations only)
    final completedInvites = activeInvitations.where((i) {
      return _isEmailVerified(i);
    }).length;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: PremiumTheme.statCard(PremiumTheme.tealGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Total Clients',
                            style:
                                TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_clients.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$activeClients active',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: PremiumTheme.statCard(PremiumTheme.blueGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mail, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Pending Invites',
                            style:
                                TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$pendingInvites',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$completedInvites completed',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: PremiumTheme.statCard(PremiumTheme.purpleGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.rate_review, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('This Month',
                            style:
                                TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_clients.where((c) {
                        if (c['created_at'] == null) return false;
                        try {
                          final createdAt =
                              DateTime.parse(c['created_at'].toString());
                          final now = DateTime.now();
                          return createdAt.month == now.month &&
                              createdAt.year == now.year;
                        } catch (_) {
                          return false;
                        }
                      }).length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'new clients',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: PremiumTheme.glassCard(),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = 'clients'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedTab == 'clients'
                          ? PremiumTheme.teal.withValues(alpha: 0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: _selectedTab == 'clients'
                          ? Border.all(color: PremiumTheme.teal, width: 2)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          color: _selectedTab == 'clients'
                              ? PremiumTheme.teal
                              : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Clients (${_clients.length})',
                          style: TextStyle(
                            color: _selectedTab == 'clients'
                                ? PremiumTheme.teal
                                : Colors.white,
                            fontWeight: _selectedTab == 'clients'
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedTab = 'invitations'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedTab == 'invitations'
                          ? PremiumTheme.teal.withValues(alpha: 0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: _selectedTab == 'invitations'
                          ? Border.all(color: PremiumTheme.teal, width: 2)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail,
                          color: _selectedTab == 'invitations'
                              ? PremiumTheme.teal
                              : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Invitations (${_invitations.where((i) {
                            final status =
                                i['status']?.toString().toLowerCase() ?? '';
                            final clientId = i['client_id'];
                            return status != 'completed' &&
                                (clientId == null ||
                                    clientId.toString().isEmpty);
                          }).length})',
                          style: TextStyle(
                            color: _selectedTab == 'invitations'
                                ? PremiumTheme.teal
                                : Colors.white,
                            fontWeight: _selectedTab == 'invitations'
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientsTable() {
    var filteredClients = _clients;
    if (_searchQuery.isNotEmpty) {
      filteredClients = _clients.where((client) {
        final name = client['company_name']?.toString().toLowerCase() ?? '';
        final email = client['email']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    if (filteredClients.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(48),
            decoration: PremiumTheme.glassCard(),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: Color(0xFF78909C)),
                  SizedBox(height: 16),
                  Text(
                    'No clients yet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start by inviting your first client',
                    style: TextStyle(color: Color(0xFF78909C)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: PremiumTheme.glassCard(),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text('Company',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 2,
                        child: Text('Contact',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 2,
                        child: Text('Email',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 2,
                        child: Text('Industry',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 1,
                        child: Text('Status',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    SizedBox(
                        width: 80,
                        child: Text('Actions',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              // Table Rows
              ...filteredClients.map((client) => _buildClientRow(client)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientRow(Map<String, dynamic> client) {
    final company = client['company_name'] ?? 'N/A';
    final contact = client['contact_person'] ?? 'N/A';
    final email = client['email'] ?? 'N/A';
    final industry = client['industry'] ?? 'N/A';
    final status = client['status'] ?? 'active';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child:
                  Text(company, style: const TextStyle(color: Colors.white))),
          Expanded(
              flex: 2,
              child: Text(contact,
                  style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(
              flex: 2,
              child: Text(email,
                  style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(
              flex: 2,
              child: Text(industry,
                  style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'active'
                    ? PremiumTheme.success.withValues(alpha: 0.2)
                    : PremiumTheme.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'active'
                      ? PremiumTheme.success
                      : PremiumTheme.warning,
                  width: 1,
                ),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: status == 'active'
                      ? PremiumTheme.success
                      : PremiumTheme.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  color: PremiumTheme.cyan,
                  onPressed: () => _showClientDetails(client),
                  tooltip: 'View Details',
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  color: Colors.white,
                  onPressed: () => _showClientMenu(client),
                  tooltip: 'More Options',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationsTable() {
    // Filter out completed invitations - they should appear in clients list instead
    var filteredInvitations = _invitations.where((inv) {
      final status = inv['status']?.toString().toLowerCase() ?? '';
      final clientId = inv['client_id'];
      // Exclude invitations that are completed or have a client_id (they're now clients)
      return status != 'completed' &&
          (clientId == null || clientId.toString().isEmpty);
    }).toList();

    // Apply verified/unverified filter
    if (_inviteFilter != 'all') {
      final wantVerified = _inviteFilter == 'verified';
      filteredInvitations = filteredInvitations.where((inv) {
        return wantVerified ? _isEmailVerified(inv) : !_isEmailVerified(inv);
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filteredInvitations = filteredInvitations.where((invite) {
        final email = invite['invited_email']?.toString().toLowerCase() ?? '';
        final company =
            invite['expected_company']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return email.contains(query) || company.contains(query);
      }).toList();
    }

    if (filteredInvitations.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(48),
            decoration: PremiumTheme.glassCard(),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Color(0xFF78909C)),
                  SizedBox(height: 16),
                  Text(
                    'No invitations yet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Send your first client invitation',
                    style: TextStyle(color: Color(0xFF78909C)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: PremiumTheme.glassCard(),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text('Email',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 2,
                        child: Text('Company',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 2,
                        child: Text('Sent Date',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 2,
                        child: Text('Expires',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 1,
                        child: Text('Status',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                    SizedBox(
                        width: 80,
                        child: Text('Actions',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              // Table Rows
              ...filteredInvitations
                  .map((invite) => _buildInvitationRow(invite)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationRow(Map<String, dynamic> invite) {
    final email = invite['invited_email'] ?? 'N/A';
    final company = invite['expected_company'] ?? 'Not specified';
    final status = invite['status'] ?? 'pending';
    final emailVerified = _isEmailVerified(invite);

    final sentDate = invite['invited_at'] != null
        ? DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(invite['invited_at'].toString()))
        : 'N/A';

    final expiresDate = invite['expires_at'] != null
        ? DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(invite['expires_at'].toString()))
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(email, style: const TextStyle(color: Colors.white))),
          Expanded(
              flex: 2,
              child: Text(company,
                  style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(
              flex: 2,
              child: Text(sentDate,
                  style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(
              flex: 2,
              child: Text(expiresDate,
                  style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: emailVerified
                    ? PremiumTheme.success.withValues(alpha: 0.2)
                    : _getStatusColor(status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: emailVerified
                        ? PremiumTheme.success
                        : _getStatusColor(status),
                    width: 1),
              ),
              child: Text(
                emailVerified ? 'VERIFIED' : status.toUpperCase(),
                style: TextStyle(
                  color: emailVerified
                      ? PremiumTheme.success
                      : _getStatusColor(status),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
              onSelected: (value) => _handleInvitationAction(value, invite),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'resend', child: Text('Resend')),
                if (!_isEmailVerified(invite))
                  const PopupMenuItem(
                      value: 'send_code',
                      child: Text('Send Verification Code')),
                const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return PremiumTheme.success;
      case 'pending':
        return PremiumTheme.warning;
      case 'expired':
        return PremiumTheme.error;
      default:
        return PremiumTheme.info;
    }
  }

  void _handleInvitationAction(
      String action, Map<String, dynamic> invite) async {
    final token = AuthService.token;
    if (token == null) return;

    final inviteId = invite['id'];
    if (inviteId == null) return;

    switch (action) {
      case 'resend':
        final success = await ClientService.resendInvitation(token, inviteId);
        _showSnackBar(
          success ? 'Invitation resent!' : 'Failed to resend invitation',
          isSuccess: success,
        );
        if (success) _loadData();
        break;
      case 'send_code':
        final success =
            await ClientService.sendVerificationCode(token, inviteId);
        _showSnackBar(
          success ? 'Verification code sent!' : 'Failed to send code',
          isSuccess: success,
        );
        if (success) _loadData();
        break;
      case 'cancel':
        final success = await ClientService.cancelInvitation(token, inviteId);
        _showSnackBar(
          success ? 'Invitation canceled' : 'Failed to cancel invitation',
          isSuccess: success,
        );
        if (success) _loadData();
        break;
      case 'delete':
        final confirmed = await _confirmAction(
          title: 'Delete Invitation',
          message:
              'This will permanently remove the invitation for ${invite['invited_email'] ?? 'this email'}. Continue?',
          confirmLabel: 'Delete',
        );
        if (!confirmed) return;
        final success = await ClientService.deleteInvitation(token, inviteId);
        _showSnackBar(
          success ? 'Invitation deleted' : 'Failed to delete invitation',
          isSuccess: success,
        );
        if (success) _loadData();
        break;
    }
  }

  void _showClientDetails(Map<String, dynamic> client) {
    // TODO: Show client details dialog with notes and proposals
    _showSnackBar('Client details view coming soon!');
  }

  void _showClientMenu(Map<String, dynamic> client) {
    // TODO: Show menu with options (edit, view notes, link proposal, etc.)
    _showSnackBar('Client menu coming soon!');
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1726),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PremiumTheme.error.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PremiumTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
