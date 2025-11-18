import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/client_service.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/role_switcher.dart';
import '../../widgets/footer.dart';
import '../../theme/premium_theme.dart';
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
                        child: const Icon(Icons.mail_outline, color: Colors.white, size: 24),
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
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.send, size: 18),
                            SizedBox(width: 8),
                            Text('Send Invitation', style: TextStyle(fontWeight: FontWeight.w600)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendInvitation(String email, String company, int expiryDays) async {
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
                          icon: const Icon(Icons.more_vert, color: Colors.white),
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
                  // Collapsible Sidebar
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
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'Navigation',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
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
                          // Navigation items
                          _buildNavItem('Dashboard', 'assets/images/Dahboard.png', _currentPage == 'Dashboard', context),
                          if (!_isAdminUser()) // Only show for non-admin users
                            _buildNavItem('My Proposals', 'assets/images/My_Proposals.png', _currentPage == 'My Proposals', context),
                          _buildNavItem('Templates', 'assets/images/content_library.png', _currentPage == 'Templates', context),
                          _buildNavItem('Content Library', 'assets/images/content_library.png', _currentPage == 'Content Library', context),
                          _buildNavItem('Client Management', 'assets/images/collaborations.png', _currentPage == 'Client Management', context),
                          _buildNavItem('Approved Proposals', 'assets/images/Time Allocation_Approval_Blue.png', _currentPage == 'Approved Proposals', context),
                          if (!_isAdminUser()) // Only show for non-admin users
                            _buildNavItem('Analytics (My Pipeline)', 'assets/images/analytics.png', _currentPage == 'Analytics (My Pipeline)', context),

                          const SizedBox(height: 20),

                          // Divider
                          if (!_isSidebarCollapsed)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              height: 1,
                              color: const Color(0xFF2C3E50),
                            ),

                          const SizedBox(height: 12),

                          // Logout button
                          _buildNavItem('Logout', 'assets/images/Logout_KhonoBuzz.png', false, context),
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
                                const Center(child: CircularProgressIndicator(color: PremiumTheme.teal))
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
                ],
              ),
            ),

            const Footer(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(String label, String assetPath, bool isActive, BuildContext context) {
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
                  color: isActive ? const Color(0xFFE74C3C) : const Color(0xFFCBD5E1),
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
                child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
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
            border: isActive ? Border.all(color: const Color(0xFF2980B9), width: 1) : null,
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
                    color: isActive ? const Color(0xFFE74C3C) : const Color(0xFFCBD5E1),
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
                  child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
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
        Navigator.pushReplacementNamed(context, '/content_library');
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

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                label: const Text('Invite Client', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: PremiumTheme.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search clients...',
                      hintStyle: TextStyle(color: Color(0xFF78909C)),
                      prefixIcon: Icon(Icons.search, color: PremiumTheme.teal),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _inviteFilter,
                      dropdownColor: const Color(0xFF0E1726),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'verified', child: Text('Verified', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'unverified', child: Text('Unverified', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (val) => setState(() => _inviteFilter = val ?? 'all'),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final pendingInvites = _invitations.where((i) => i['status'] == 'pending').length;
    final completedInvites = _invitations.where((i) => i['status'] == 'completed').length;

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
                        Text('Total Clients', style: TextStyle(color: Colors.white, fontSize: 14)),
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
                        Text('Pending Invites', style: TextStyle(color: Colors.white, fontSize: 14)),
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
                        Text('This Month', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_clients.where((c) {
                        if (c['created_at'] == null) return false;
                        try {
                          final createdAt = DateTime.parse(c['created_at'].toString());
                          final now = DateTime.now();
                          return createdAt.month == now.month && createdAt.year == now.year;
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
                          color: _selectedTab == 'clients' ? PremiumTheme.teal : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Clients (${_clients.length})',
                          style: TextStyle(
                            color: _selectedTab == 'clients' ? PremiumTheme.teal : Colors.white,
                            fontWeight: _selectedTab == 'clients' ? FontWeight.w600 : FontWeight.w400,
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
                          color: _selectedTab == 'invitations' ? PremiumTheme.teal : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Invitations (${_invitations.length})',
                          style: TextStyle(
                            color: _selectedTab == 'invitations' ? PremiumTheme.teal : Colors.white,
                            fontWeight: _selectedTab == 'invitations' ? FontWeight.w600 : FontWeight.w400,
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
                  Icon(Icons.people_outline, size: 64, color: Color(0xFF78909C)),
                  SizedBox(height: 16),
                  Text(
                    'No clients yet',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
                    Expanded(flex: 3, child: Text('Company', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Industry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    SizedBox(width: 80, child: Text('Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
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
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(company, style: const TextStyle(color: Colors.white))),
          Expanded(flex: 2, child: Text(contact, style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(flex: 2, child: Text(email, style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(flex: 2, child: Text(industry, style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'active' ? PremiumTheme.success.withValues(alpha: 0.2) : PremiumTheme.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'active' ? PremiumTheme.success : PremiumTheme.warning,
                  width: 1,
                ),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: status == 'active' ? PremiumTheme.success : PremiumTheme.warning,
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
    var filteredInvitations = _invitations;
    // Apply verified/unverified filter
    if (_inviteFilter != 'all') {
      final wantVerified = _inviteFilter == 'verified';
      filteredInvitations = filteredInvitations.where((inv) {
        final emailVerified = (inv['email_verified'] == true) ||
            (inv['email_verified_at'] != null && inv['email_verified_at'].toString().isNotEmpty);
        return wantVerified ? emailVerified : !emailVerified;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filteredInvitations = _invitations.where((invite) {
        final email = invite['invited_email']?.toString().toLowerCase() ?? '';
        final company = invite['expected_company']?.toString().toLowerCase() ?? '';
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
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
                    Expanded(flex: 3, child: Text('Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Company', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Sent Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Expires', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                    SizedBox(width: 80, child: Text('Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              // Table Rows
              ...filteredInvitations.map((invite) => _buildInvitationRow(invite)),
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
    final emailVerified = (invite['email_verified'] == true) ||
        (invite['email_verified_at'] != null && invite['email_verified_at'].toString().isNotEmpty);
    
    final sentDate = invite['invited_at'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(invite['invited_at'].toString()))
        : 'N/A';
    
    final expiresDate = invite['expires_at'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(invite['expires_at'].toString()))
        : 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(email, style: const TextStyle(color: Colors.white))),
          Expanded(flex: 2, child: Text(company, style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(flex: 2, child: Text(sentDate, style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(flex: 2, child: Text(expiresDate, style: const TextStyle(color: Color(0xFFB0BEC5)))),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor(status), width: 1),
              ),
              child: Text(
                emailVerified ? 'VERIFIED' : status.toUpperCase(),
                style: TextStyle(
                  color: emailVerified ? PremiumTheme.success : _getStatusColor(status),
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
                if (!emailVerified) const PopupMenuItem(value: 'send_code', child: Text('Send Verification Code')),
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

  void _handleInvitationAction(String action, Map<String, dynamic> invite) async {
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
        final success = await ClientService.sendVerificationCode(token, inviteId);
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
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

