import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/asset_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ApproverDashboardPage extends StatefulWidget {
  const ApproverDashboardPage({super.key});

  @override
  State<ApproverDashboardPage> createState() => _ApproverDashboardPageState();
}

class _ApproverDashboardPageState extends State<ApproverDashboardPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: 'R', decimalDigits: 0);
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  String _currentPage = 'Proposals for Review';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.value = 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceAccessAndLoad();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _enforceAccessAndLoad() async {
    final userRole =
        AuthService.currentUser?['role']?.toString().toLowerCase() ?? 'manager';

    // Only allow admin/CEO users to access this dashboard
    if (userRole != 'admin' && userRole != 'ceo') {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/creator_dashboard');
      return;
    }

    await _loadData();
  }

  Future<void> _loadData() async {
    print('🔄 Approver Dashboard: Loading data...');
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      print('🔄 Restoring session from storage...');
      AuthService.restoreSessionFromStorage();

      var token = AuthService.token;
      print('🔑 After restore - Token available: ${token != null}');
      print('🔑 After restore - User: ${AuthService.currentUser?['email']}');
      print('🔑 After restore - isLoggedIn: ${AuthService.isLoggedIn}');

      if (token == null) {
        print(
            '⚠️ Token still null after restore, checking localStorage directly...');
        try {
          final data = html.window.localStorage['lukens_auth_session'];
          print('📦 localStorage data exists: ${data != null}');
          if (data != null) {
            print('📦 localStorage content: ${data.substring(0, 50)}...');
          }
        } catch (e) {
          print('❌ Error accessing localStorage: $e');
        }

        await Future.delayed(const Duration(milliseconds: 500));
        token = AuthService.token;
      }

      if (token == null) {
        print('❌ No token available after restoration attempts');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  '⚠️ Session expired. Please switch back to Creator mode.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _loadData(),
              ),
            ),
          );
        }
        return;
      }

      print('📡 Fetching proposals from API...');

      // Fetch pending approvals
      print(
          '🌐 Fetching pending approvals from: ${ApiService.baseUrl}/api/proposals/pending_approval');
      final pendingResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/proposals/pending_approval'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ Timeout! Pending approvals API call took too long');
          throw Exception('Request timed out');
        },
      );

      List<Map<String, dynamic>> pending = [];
      if (pendingResponse.statusCode == 200) {
        final pendingData = json.decode(pendingResponse.body);
        pending = (pendingData['proposals'] as List? ?? [])
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
        print('✅ Pending approvals received: ${pending.length}');
      } else {
        print(
            '⚠️ Failed to fetch pending approvals: ${pendingResponse.statusCode}');
      }

      if (mounted) {
        setState(() {
          _pendingApprovals = pending;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading approver data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Global BG.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.65),
                  Colors.black.withOpacity(0.35),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(app),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      children: [
                        _buildSidebar(context),
                        const SizedBox(width: 24),
                        Expanded(
                          child: GlassContainer(
                            borderRadius: 32,
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeroSection(),
                                const SizedBox(height: 16),
                                _buildStatusOverviewRow(),
                                const SizedBox(height: 24),
                                Expanded(
                                  child: CustomScrollbar(
                                    controller: _scrollController,
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSection(
                                            '⏳ Proposals for Review',
                                            _isLoading
                                                ? const Center(
                                                    child:
                                                        CircularProgressIndicator())
                                                : _buildPendingApprovalsList(),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppState app) {
    final user = AuthService.currentUser ?? app.currentUser ?? {};
    final email = user['email']?.toString() ?? 'admin@khonology.com';
    final backendRole = user['role']?.toString().toLowerCase() ?? 'admin';
    final displayRole =
        backendRole == 'admin' || backendRole == 'ceo' ? 'Admin' : 'Admin';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: PremiumTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Review proposals, manage governance, and oversee system operations',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  displayRole,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      gradientStart: PremiumTheme.teal,
      gradientEnd: PremiumTheme.tealGradient.colors.last,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.pending_actions,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Approvals Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _pendingApprovals.isEmpty
                      ? 'No proposals currently in your review pipeline.'
                      : '${_pendingApprovals.length} proposal${_pendingApprovals.length == 1 ? '' : 's'} across all review stages.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
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
            _buildNavItem('Dashboard', 'assets/images/Dahboard.png',
                _currentPage == 'Dashboard', context),
            _buildNavItem(
                'Proposals for Review',
                'assets/images/Time Allocation_Approval_Blue.png',
                _currentPage == 'Proposals for Review',
                context),
            _buildNavItem(
                'Governance & Risk',
                'assets/images/Time Allocation_Approval_Blue.png',
                _currentPage == 'Governance & Risk',
                context),
            _buildNavItem(
                'Template Management',
                'assets/images/content_library.png',
                _currentPage == 'Template Management',
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
            _buildNavItem('User Management', 'assets/images/collaborations.png',
                _currentPage == 'User Management', context),
            _buildNavItem(
                'Approved Proposals',
                'assets/images/Time Allocation_Approval_Blue.png',
                _currentPage == 'Approved Proposals',
                context),
            _buildNavItem('Audit Logs', 'assets/images/analytics.png',
                _currentPage == 'Audit Logs', context),
            _buildNavItem('Settings', 'assets/images/analytics.png',
                _currentPage == 'Settings', context),
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
              width: 50,
              height: 50,
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
                    color: Colors.black.withOpacity(0.08),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _currentPage = label);
          _navigateToPage(context, label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border:
                isActive ? Border.all(color: const Color(0xFF2980B9)) : null,
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

  Map<String, int> _getStageCounts() {
    final stages = <String, int>{
      'Pending Review': 0,
      'Sent to Client': 0,
      'Client Approved': 0,
      'Archived': 0,
    };

    for (final proposal in _pendingApprovals) {
      final stage = _mapStatusToStage(proposal['status']?.toString());
      stages[stage] = (stages[stage] ?? 0) + 1;
    }

    return stages;
  }

  Map<String, List<Map<String, dynamic>>> _groupProposalsByStage() {
    final groups = <String, List<Map<String, dynamic>>>{
      'Pending Review': [],
      'Sent to Client': [],
      'Client Approved': [],
      'Archived': [],
    };

    for (final proposal in _pendingApprovals) {
      final stage = _mapStatusToStage(proposal['status']?.toString());
      groups[stage]!.add(proposal);
    }

    return groups;
  }

  String _mapStatusToStage(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) {
      return 'Pending Review';
    }

    final lower = rawStatus.toLowerCase();

    // Closed/terminal statuses
    if (lower.contains('archived') || lower.contains('declined')) {
      return 'Archived';
    }

    if (lower.contains('client approved') ||
        lower.contains('client signed') ||
        lower == 'signed') {
      return 'Client Approved';
    }

    // Sent out to client
    if (lower.contains('sent to client') || lower.contains('released')) {
      return 'Sent to Client';
    }

    // Internal pending review (creator/finance/admin)
    if (lower.contains('pending ceo') ||
        lower.contains('pending approval') ||
        lower.contains('submitted') ||
        lower.contains('review') ||
        lower == 'draft' ||
        lower.contains('approved')) {
      return 'Pending Review';
    }

    return 'Pending Review';
  }

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'Pending Review':
        return PremiumTheme.orange;
      case 'Sent to Client':
        return const Color(0xFF3498DB);
      case 'Client Approved':
        return const Color(0xFF1ABC9C);
      case 'Archived':
        return Colors.grey;
      default:
        return PremiumTheme.orange;
    }
  }

  IconData _getStageIcon(String stage) {
    switch (stage) {
      case 'Pending Review':
        return Icons.pending_actions;
      case 'Sent to Client':
        return Icons.send;
      case 'Client Approved':
        return Icons.thumb_up_alt;
      case 'Archived':
        return Icons.archive;
      default:
        return Icons.pending_actions;
    }
  }

  Widget _buildStatusOverviewRow() {
    final counts = _getStageCounts();
    final stages = [
      'Pending Review',
      'Sent to Client',
      'Client Approved',
      'Archived',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final cards = stages.map((stage) {
          final count = counts[stage] ?? 0;
          final color = _getStageColor(stage);
          final icon = _getStageIcon(stage);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: GlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stage,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList();

        if (isNarrow) {
          return Column(
            children: [
              Row(children: cards.sublist(0, 3)),
              Row(children: cards.sublist(3)),
            ],
          );
        }

        return Row(children: cards);
      },
    );
  }

  Widget _buildPendingApprovalsList() {
    if (_pendingApprovals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.pending_actions, size: 54, color: PremiumTheme.orange),
            SizedBox(height: 12),
            Text(
              'No proposals in your review pipeline',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupProposalsByStage();
    final stagesInOrder = [
      'Pending Review',
      'Sent to Client',
      'Client Approved',
      'Archived',
    ];

    final List<Widget> children = [];

    for (final stage in stagesInOrder) {
      final proposalsForStage = grouped[stage] ?? [];
      if (proposalsForStage.isEmpty) continue;

      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 16));
      }

      children.add(
        Row(
          children: [
            Icon(
              _getStageIcon(stage),
              size: 18,
              color: _getStageColor(stage),
            ),
            const SizedBox(width: 8),
            Text(
              stage,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

      children.add(const SizedBox(height: 8));
      children.addAll(proposalsForStage.map(_buildPendingApprovalCard));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildPendingApprovalCard(Map<String, dynamic> proposal) {
    final submittedDate = proposal['updated_at'] != null
        ? DateTime.tryParse(proposal['updated_at'].toString())
        : null;
    final value = proposal['budget'];
    final client = proposal['client_name'] ?? proposal['client'] ?? 'Unknown';
    final stage = _mapStatusToStage(proposal['status']?.toString());
    final badgeColor = _getStageColor(stage);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    proposal['title'] ?? 'Untitled Proposal',
                    style: PremiumTheme.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: badgeColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    stage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.business, client),
                const SizedBox(width: 12),
                _buildInfoChip(
                    Icons.calendar_today,
                    submittedDate != null
                        ? DateFormat('dd MMM yyyy').format(submittedDate)
                        : 'Unknown'),
                if (value != null && value != 0) ...[
                  const SizedBox(width: 12),
                  _buildInfoChip(
                      Icons.attach_money, _formatCurrency(_parseBudget(value))),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openProposal(proposal),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Review'),
                  style: TextButton.styleFrom(
                    foregroundColor: PremiumTheme.orange,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approveProposal(proposal),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _rejectProposal(proposal),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _openProposal(Map<String, dynamic> proposal) {
    final id = proposal['id']?.toString();
    if (id == null) return;
    Navigator.pushNamed(
      context,
      '/proposal_review',
      arguments: {
        'id': id,
        'title': proposal['title'],
      },
    );
  }

  Future<void> _approveProposal(Map<String, dynamic> proposal) async {
    final id = proposal['id']?.toString();
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Proposal'),
        content: Text(
          'Are you sure you want to approve "${proposal['title'] ?? 'this proposal'}"? '
          'This will send it to the client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PremiumTheme.teal,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      String? clientEmail;
      final rawEmail = proposal['client_email'] ?? proposal['clientEmail'];
      if (rawEmail is String && rawEmail.trim().isNotEmpty) {
        clientEmail = rawEmail.trim();
      }

      Future<http.Response> sendApproval({String? overrideEmail}) {
        final body = <String, dynamic>{};
        final emailToUse = overrideEmail ?? clientEmail;
        if (emailToUse != null && emailToUse.isNotEmpty) {
          body['client_email'] = emailToUse;
        }
        return http.post(
          Uri.parse('${ApiService.baseUrl}/api/proposals/$id/approve'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode(body),
        );
      }

      http.Response response = await sendApproval();

      if (response.statusCode == 400) {
        try {
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.contains('application/json')) {
            final error = json.decode(response.body);
            if (error is Map &&
                error['error'] == 'missing_client_email' &&
                error['has_override_option'] == true) {
              final controller = TextEditingController(text: clientEmail ?? '');
              final override = await showDialog<String>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Client Email Required'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Client Email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumTheme.teal,
                        ),
                        child: const Text('Continue'),
                      ),
                    ],
                  );
                },
              );

              if (override != null && override.isNotEmpty) {
                clientEmail = override;
                response = await sendApproval(overrideEmail: override);
              }
            }
          }
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal approved and sent to client!'),
              backgroundColor: Color(0xFF2ECC71),
            ),
          );
          _loadData();
        }
      } else {
        String errorMessage = 'Failed to approve proposal';
        try {
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.contains('application/json')) {
            final error = json.decode(response.body);
            errorMessage = error['detail'] ?? errorMessage;
          } else {
            if (response.statusCode == 404) {
              errorMessage =
                  'Proposal approval endpoint not found (404). Please check server configuration.';
            } else {
              errorMessage =
                  'Server error (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}';
            }
          }
        } catch (_) {
          if (response.statusCode == 404) {
            errorMessage =
                'Endpoint not found (404). The approval route may not be registered correctly.';
          } else {
            errorMessage = 'Server returned error ${response.statusCode}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error approving proposal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectProposal(Map<String, dynamic> proposal) async {
    final id = proposal['id']?.toString();
    if (id == null) return;

    final commentsController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Proposal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to reject "${proposal['title'] ?? 'this proposal'}"? '
              'This will return it to draft status.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Rejection Comments (optional)',
                hintText: 'Explain why this proposal is being rejected...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/proposals/$id/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'comments': commentsController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal rejected and returned to draft'),
              backgroundColor: Colors.orange,
            ),
          );
          // Reload data
          _loadData();
        }
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Failed to reject proposal');
      }
    } catch (e) {
      print('❌ Error rejecting proposal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _parseBudget(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  String _formatCurrency(double value) {
    if (value == 0) return 'R0';
    return _currencyFormatter.format(value);
  }

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/approver_dashboard');
        break;
      case 'Proposals for Review':
        // Already on approval dashboard - this is the main page
        Navigator.pushReplacementNamed(context, '/approver_dashboard');
        break;
      case 'Governance & Risk':
        // TODO: Navigate to governance panel
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Governance & Risk Panel - Coming soon'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case 'Template Management':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Client Management':
        Navigator.pushReplacementNamed(context, '/client_management');
        break;
      case 'User Management':
        // TODO: Navigate to user management
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User Management - Coming soon'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Audit Logs':
        // TODO: Navigate to audit logs
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audit Logs - Coming soon'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case 'Settings':
        // TODO: Navigate to admin settings
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin Settings - Coming soon'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case 'Approval Dashboard':
        // Already here
        break;
      case 'Logout':
        AuthService.logout();
        Navigator.pushNamedAndRemoveUntil(
            context, '/login', (Route<dynamic> route) => false);
        break;
    }
  }
}
