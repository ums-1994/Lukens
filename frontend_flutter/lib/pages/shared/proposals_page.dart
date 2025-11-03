// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/asset_service.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../widgets/footer.dart';

class ProposalsPage extends StatefulWidget {
  const ProposalsPage({super.key});

  @override
  _ProposalsPageState createState() => _ProposalsPageState();
}

class _ProposalsPageState extends State<ProposalsPage>
    with TickerProviderStateMixin {
  String _filterStatus = 'All Statuses';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> proposals = [];
  bool _isLoading = true;
  String? _token;

  // Sidebar state
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  String _currentPage = 'My Proposals';

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
    // Reload proposals whenever we come back to this page
    _loadProposals();
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
        print('✅ Loading proposals with token...');
        final data = await ApiService.getProposals(_token!);
        if (mounted) {
          setState(() {
            proposals = List<Map<String, dynamic>>.from(data);
            print('✅ Loaded ${proposals.length} proposals');
          });
        }
      } else {
        print('⚠️ No authentication token found');
        if (mounted) {
          setState(() {
            proposals = [];
          });
        }
      }
    } catch (e) {
      print('❌ Error loading proposals: $e');
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
                  color: const Color(0xFF2563EB).withOpacity(0.1),
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
                  color: Colors.white,
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
                      border: Border.all(
                          color: const Color(0xFFC10D00).withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withOpacity(0.12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC10D00).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFFC10D00),
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
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Create a blank proposal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
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
                    Navigator.pushNamed(context, '/proposal-wizard');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFC10D00).withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withOpacity(0.12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.library_books_outlined,
                            color: Color(0xFFC10D00),
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
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Select a template to get started',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
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
        );
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
      body: Column(
        children: [
          // Header (same as dashboard)
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFC10D00),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Proposals',
                    style: TextStyle(
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
                            _handleLogout(context, app);
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
                // Collapsible Sidebar (same as dashboard)
                GestureDetector(
                  onTap: () {
                    if (_isSidebarCollapsed) _toggleSidebar();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: ClipRRect(
                    // Re-added ClipRRect
                    borderRadius: BorderRadius.circular(
                        0), // No rounded corners for sidebar
                    child: BackdropFilter(
                      // Re-added BackdropFilter
                      filter: ImageFilter.blur(
                          sigmaX: 2.0, sigmaY: 2.0), // 2% blur effect
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _isSidebarCollapsed ? 90.0 : 250.0,
                        color: Colors.black
                            .withOpacity(0.32), // Adjusted opacity to 0.32
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              // Toggle button
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: InkWell(
                                  onTap: _toggleSidebar,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(
                                          0.12), // Adjusted opacity to 0.12
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
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  height: 1,
                                  color: Colors.black.withOpacity(
                                      0.35), // Adjusted divider color to be blackish
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
                          // Header Row: title, search, actions
                          Row(
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
                                    Text(
                                        'Manage all your business proposals and SOWs',
                                        style:
                                            TextStyle(color: Colors.white70)),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: _showCreateNewDialog,
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('New Proposal'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFC10D00),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Filter card
                          Card(
                            color: Colors
                                .transparent, // Set card color to transparent
                            elevation: 0, // Remove elevation
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFC10D00)
                                            .withOpacity(0.5),
                                        width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('All Proposals',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors
                                                        .white)), // Changed to Colors.white
                                            Row(
                                              children: [
                                                Expanded(
                                                  // Wrap TextField in Expanded
                                                  child: TextField(
                                                    controller:
                                                        _searchController,
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Search proposals...',
                                                      hintStyle: TextStyle(
                                                          color: Colors
                                                              .white70), // Hint text color
                                                      contentPadding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 12,
                                                              vertical: 8),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        borderSide: BorderSide(
                                                            color: const Color(
                                                                    0xFFC10D00)
                                                                .withOpacity(
                                                                    0.5)), // Red border
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        borderSide: BorderSide(
                                                            color: const Color(
                                                                    0xFFC10D00)
                                                                .withOpacity(
                                                                    0.5)), // Red border
                                                      ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        borderSide: BorderSide(
                                                            color: const Color(
                                                                0xFFC10D00)), // Red border on focus
                                                      ),
                                                    ),
                                                    style: TextStyle(
                                                        color: Colors
                                                            .white), // Input text color
                                                    onChanged: (_) =>
                                                        setState(() {}),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  // Wrap in Expanded
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                        border: Border.all(
                                                            color: const Color(
                                                                    0xFFC10D00)
                                                                .withOpacity(
                                                                    0.5)), // Red border
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6)),
                                                    child:
                                                        DropdownButtonHideUnderline(
                                                      child: DropdownButton<
                                                          String>(
                                                        value: _filterStatus,
                                                        dropdownColor: Colors
                                                            .black
                                                            .withOpacity(
                                                                0.8), // Dropdown background color
                                                        style: TextStyle(
                                                            color: Colors
                                                                .white), // Dropdown item text color
                                                        items: [
                                                          'All Statuses',
                                                          'Draft',
                                                          'Sent',
                                                          'Approved',
                                                          'Declined'
                                                        ]
                                                            .map((String
                                                                    value) =>
                                                                DropdownMenuItem<
                                                                        String>(
                                                                    value:
                                                                        value,
                                                                    child: Text(
                                                                        value)))
                                                            .toList(),
                                                        onChanged: (String?
                                                                newValue) =>
                                                            setState(() =>
                                                                _filterStatus =
                                                                    newValue ??
                                                                        'All Statuses'),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        // Proposals list / empty state
                                        if (_isLoading)
                                          const Center(
                                              child: Padding(
                                                  padding: EdgeInsets.all(32.0),
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Color(0xFFC10D00),
                                                  ))) // Red progress indicator
                                        else if (proposals.isEmpty)
                                          Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 48.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .description_outlined,
                                                      size: 64,
                                                      color: Colors.white70),
                                                  const SizedBox(height: 16),
                                                  Text('No proposals yet',
                                                      style: TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white)),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                      'Create your first proposal to get started',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.white70)),
                                                  const SizedBox(height: 20),
                                                  ElevatedButton.icon(
                                                    onPressed:
                                                        _showCreateNewDialog,
                                                    icon: const Icon(Icons.add),
                                                    label: const Text(
                                                        'Create Your First Proposal'),
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                                0xFFC10D00),
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 18,
                                                                vertical: 12),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8))),
                                                  )
                                                ],
                                              ),
                                            ),
                                          )
                                        else
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: filtered.length,
                                            separatorBuilder:
                                                (context, index) =>
                                                    const Divider(
                                              height: 1,
                                              color: Colors.white12,
                                            ), // White divider
                                            itemBuilder: (context, index) {
                                              final proposal = filtered[index];
                                              return ProposalItem(
                                                  proposal: proposal,
                                                  onRefresh: _loadProposals);
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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

          const Footer(),
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
            child: ClipRRect(
              // Re-added ClipRRect
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                // Re-added BackdropFilter
                filter: ImageFilter.blur(
                    sigmaX: 2.0, sigmaY: 2.0), // 2% blur effect
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black
                        .withOpacity(0.12), // Adjusted opacity to 0.12
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFE9293A).withOpacity(
                              0.7) // Active red border, adjusted opacity
                          : const Color(0xFFE9293A).withOpacity(
                              0.3), // Inactive translucent red border, adjusted opacity
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(0.1), // Adjusted shadow opacity
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
        child: ClipRRect(
          // Re-added ClipRRect
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            // Re-added BackdropFilter
            filter:
                ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0), // 2% blur effect
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFE9293A).withOpacity(
                        0.32) // Active translucent red, adjusted opacity
                    : Colors.transparent, // Inactive transparent
                borderRadius: BorderRadius.circular(8),
                border: isActive
                    ? Border.all(
                        color: const Color(0xFFE9293A).withOpacity(0.7),
                        width: 1)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black
                          .withOpacity(0.12), // Adjusted opacity to 0.12
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFE9293A).withOpacity(
                                0.7) // Active red border, adjusted opacity
                            : const Color(0xFFE9293A).withOpacity(
                                0.3), // Inactive translucent red border, adjusted opacity
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(0.1), // Adjusted shadow opacity
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
                        color: isActive
                            ? Colors.white
                            : Colors.white70, // Adjusted text color
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
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
        ),
      ),
    );
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushNamed(context, '/creator_dashboard');
        break;
      case 'My Proposals':
        // Already on proposals page
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
        _handleLogout(context, context.read<AppState>());
        break;
    }
  }

  void _handleLogout(BuildContext context, AppState app) {
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
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
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
    Color statusColor;
    switch ((proposal['status'] ?? '').toString().toLowerCase()) {
      case 'draft':
        statusColor = const Color(0xFFC10D00);
        break;
      case 'sent':
        statusColor = const Color(0xFFC10D00);
        break;
      case 'approved':
        statusColor = const Color(0xFFC10D00);
        break;
      default:
        statusColor = Colors.white70;
    }

    Color statusBgColor;
    switch ((proposal['status'] ?? '').toString().toLowerCase()) {
      case 'draft':
        statusBgColor = const Color(0xFFC10D00).withOpacity(0.32);
        break;
      case 'sent':
        statusBgColor = const Color(0xFFC10D00).withOpacity(0.32);
        break;
      case 'approved':
        statusBgColor = const Color(0xFFC10D00).withOpacity(0.32);
        break;
      default:
        statusBgColor = Colors.black.withOpacity(0.12);
    }

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
                  Navigator.pushNamed(context, '/compose', arguments: proposal);
                } else {
                  Navigator.pushNamed(context, '/preview', arguments: proposal);
                }
              },
              child: Text(
                  (proposal['status'] ?? '').toString().toLowerCase() == 'draft'
                      ? 'Edit'
                      : 'View'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            IconButton(
                icon: const Icon(Icons.delete_outline),
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
                        await ApiService.deleteProposal(
                            token: token, id: intId);
                        if (onRefresh != null) onRefresh!();
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
