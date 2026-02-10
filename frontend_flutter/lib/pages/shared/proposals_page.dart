import 'package:flutter/material.dart';
import 'dart:ui';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../widgets/footer.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../theme/premium_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/fixed_sidebar.dart';

class ProposalsPage extends StatefulWidget {
  const ProposalsPage({super.key});

  @override
  _ProposalsPageState createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<ProposalsPage>
    with TickerProviderStateMixin {
  static const Color _navSurface = Color(0xFF1A1F2B);
  static const Color _navBorder = Color(0xFF1F2A3D);
  String _filterStatus = 'All Statuses';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> proposals = [];
  bool _isLoading = true;
  String? _token;

  // Sidebar state
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  String _currentPage = 'My Proposals';

  // Sidebar methods
  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 'My Proposals':
        // Already on proposals page
        break;
      case 'Templates':
        Navigator.pushReplacementNamed(context, '/templates');
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
                final app = context.read<dynamic>();
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

  final ScrollController _scrollController = ScrollController();
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Start collapsed
    _animationController.value = 1.0;
    _loadProposals();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Refresh proposals when returning to this page
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
      _loadProposals();
    }
  }

  Future<void> _loadProposals() async {
    setState(() => _isLoading = true);
    try {
      // Get token from AuthService (backend JWT) - same as document editor
      final token = AuthService.token;

      // Fallback to AppState if token not in AuthService
      if (token == null || token.isEmpty) {
        if (mounted) {
          final appState = context.read<AppState>();
          _token = appState.authToken;
        }
      } else {
        _token = token;
      }

      if (_token != null && _token!.isNotEmpty) {
        print('Γ£à Loading proposals with token...');
        final data = await ApiService.getProposals(_token!);
        if (mounted) {
          setState(() {
            proposals = List<Map<String, dynamic>>.from(data);
            print('Γ£à Loaded ${proposals.length} proposals');
          });
        }
      } else {
        print('ΓÜá∩╕Å No authentication token found');
        if (mounted) {
          setState(() {
            proposals = [];
          });
        }
      }
    } catch (e) {
      print('Γ¥î Error loading proposals: $e');
      if (mounted) {
        setState(() {
          proposals = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateNewDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF2563EB),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Create New',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2c3e50),
                ),
              ),
              const SizedBox(height: 24),
              // Start from scratch option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    _navigateToBlankProposal();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFe2e8f0)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF3498DB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF3498DB),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Start from scratch',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2c3e50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Create a blank proposal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF718096)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Choose from template gallery option
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/proposal-wizard')
                        .then((_) => _loadProposals());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFe2e8f0)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2ECC71).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.library_books_outlined,
                            color: Color(0xFF2ECC71),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Choose from Template Gallery',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2c3e50),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Select a template to get started',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF718096),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF718096)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToBlankProposal() async {
    try {
      // Navigate directly to blank document editor
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/blank-document',
          arguments: {
            'proposalId': 'temp-${DateTime.now().millisecondsSinceEpoch}',
            'proposalTitle': 'Untitled Document',
          },
        ).then((_) => _loadProposals());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening blank document: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final userRole = app.currentUser?['role'] ?? 'Financial Manager';

    final filtered = proposals.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client_name'] ?? p['client'] ?? '').toString().toLowerCase();
      final matchesSearch =
          title.contains(_searchController.text.toLowerCase()) ||
              client.contains(_searchController.text.toLowerCase());
      final matchesStatus = _filterStatus == 'All Statuses' ||
          (p['status'] ?? '') == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Container(
          color: Colors.transparent,
          child: Row(
            children: [
              // Fixed Sidebar - Full Height
              _buildSidebar(context),

              // Main Content Area
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                      child: _buildHeader(context, app, userRole),
                    ),

                    // Content Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildToolbar(),
                            const SizedBox(height: 24),
                            Expanded(
                              child: CustomScrollbar(
                                controller: _scrollController,
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: _buildFilterPanel(filtered),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildHeader(BuildContext context, AppState app, String userRole) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      gradientStart: const Color(0xFF1D2B64),
      gradientEnd: const Color(0xFF1D4350),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'My Proposals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your business proposals and approvals',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/User_Profile.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getUserName(app.currentUser),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    userRole,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'logout') {
                    _handleLogout(context);
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
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return FixedSidebar(
      currentPage: 'My Proposals',
      isCollapsed: _isSidebarCollapsed,
      onToggle: _toggleSidebar,
      onNavigate: (label) => _navigateToPage(context, label),
      onLogout: () => _handleLogout(context),
    );
  }

  Widget _buildToolbar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Proposals',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              SizedBox(height: 6),
              Text('Manage all your business proposals and SOWs',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search proposals...',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: PremiumTheme.purple.withValues(alpha: 0.8),
                  ),
                ),
                prefixIconColor: Colors.white70,
                hintStyle: const TextStyle(
                  color: Colors.white54,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: _showCreateNewDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Proposal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel(List<Map<String, dynamic>> filtered) {
    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Proposals',
                style: PremiumTheme.titleMedium,
              ),
              Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search proposals...',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                        ),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: PremiumTheme.purple.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        dropdownColor: PremiumTheme.darkBg2,
                        iconEnabledColor: Colors.white70,
                        style: const TextStyle(color: Colors.white),
                        items: [
                          'All Statuses',
                          'Draft',
                          'Sent',
                          'Approved',
                          'Declined'
                        ]
                            .map((String value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (String? newValue) => setState(
                            () => _filterStatus = newValue ?? 'All Statuses'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(PremiumTheme.purple),
                ),
              ),
            )
          else if (proposals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No proposals yet',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Create your first proposal to get started',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showCreateNewDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Your First Proposal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PremiumTheme.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => Divider(
                  height: 1, color: Colors.white.withValues(alpha: 0.08)),
              itemBuilder: (context, index) {
                final proposal = filtered[index];
                return ProposalItem(
                    proposal: proposal, onRefresh: _loadProposals);
              },
            ),
        ],
      ),
    );
  }

  // Helper methods from dashboard
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
                color: isActive
                    ? PremiumTheme.purple.withValues(alpha: 0.3)
                    : _navSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? PremiumTheme.purple
                      : _navBorder.withValues(alpha: 0.6),
                  width: isActive ? 2 : 1,
                ),
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
            color: isActive
                ? PremiumTheme.purple.withValues(alpha: 0.25)
                : _navSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? PremiumTheme.purple
                  : _navBorder.withValues(alpha: 0.7),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive
                      ? PremiumTheme.purple.withValues(alpha: 0.3)
                      : _navSurface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? PremiumTheme.purple
                        : _navBorder.withValues(alpha: 0.6),
                    width: isActive ? 2 : 1,
                  ),
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
                    color: isActive ? Colors.white : Colors.white70,
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

class ProposalItem extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final VoidCallback? onRefresh;

  const ProposalItem({Key? key, required this.proposal, this.onRefresh})
      : super(key: key);

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is String) {
      try {
        final parsed = DateTime.parse(date);
        final now = DateTime.now();
        final difference = now.difference(parsed);

        if (difference.inDays == 0) {
          return 'Today, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        } else if (difference.inDays == 1) {
          return 'Yesterday, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        } else {
          return '${parsed.day}/${parsed.month}/${parsed.year}';
        }
      } catch (e) {
        return date.toString();
      }
    }
    return date.toString();
  }

  @override
  Widget build(BuildContext context) {
    final status = (proposal['status'] ?? '').toString().toLowerCase().trim();
    Color statusColor;
    switch (status) {
      case 'draft':
        statusColor = PremiumTheme.purple;
        break;
      case 'pending':
      case 'pending approval':
      case 'pending ceo approval':
        statusColor = PremiumTheme.orange;
        break;
      case 'sent':
      case 'sent to client':
        statusColor = PremiumTheme.pink;
        break;
      case 'approved':
        statusColor = PremiumTheme.teal;
        break;
      case 'declined':
      case 'rejected':
        statusColor = PremiumTheme.error;
        break;
      default:
        statusColor = Colors.white70;
    }

    final Color statusBgColor = statusColor == Colors.white70
        ? Colors.white.withValues(alpha: 0.08)
        : statusColor.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(proposal['title'] ?? 'Untitled Proposal',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 8),
              Wrap(spacing: 16, children: [
                Text(
                    'Last modified: ${_formatDate(proposal['updated_at'] ?? proposal['updatedAt'])}',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
                if (proposal['client_name'] != null ||
                    proposal['client'] != null)
                  Text(
                      'Client: ${proposal['client_name'] ?? proposal['client']}',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70)),
              ])
            ]),
          ),
          Row(children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(proposal['status'] ?? 'Unknown',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if ((proposal['status'] ?? '').toString().toLowerCase() ==
                    'draft') {
                  Navigator.pushNamed(context, '/compose', arguments: proposal)
                      .then((_) {
                    if (onRefresh != null) onRefresh!();
                  });
                } else {
                  // Ensure preview page knows which proposal to show
                  try {
                    context
                        .read<AppState>()
                        .selectProposal(Map<String, dynamic>.from(proposal));
                  } catch (_) {}
                  Navigator.pushNamed(context, '/preview', arguments: proposal)
                      .then((_) {
                    if (onRefresh != null) onRefresh!();
                  });
                }
              },
              child: Text(
                  (proposal['status'] ?? '').toString().toLowerCase() == 'draft'
                      ? 'Edit'
                      : 'View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.purple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                              title: const Text('Delete proposal?'),
                              content: const Text(
                                  'Are you sure you want to delete this proposal?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete'))
                              ]));
                  if (confirm == true) {
                    // Use AuthService token (same as document editor)
                    final token = AuthService.token;
                    if (token != null && token.isNotEmpty) {
                      final idVal = proposal['id'];
                      final intId = idVal is int
                          ? idVal
                          : int.tryParse(idVal.toString()) ?? 0;
                      if (intId != 0) {
                        final success = await ApiService.deleteProposal(
                            token: token, id: intId);

                        if (success) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Proposal deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          if (onRefresh != null) onRefresh!();
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Failed to delete proposal. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invalid proposal ID'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Authentication required. Please log in.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                })
          ])
        ],
      ),
    );
  }
}
