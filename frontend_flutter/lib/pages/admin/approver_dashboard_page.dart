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
  String _currentPage = 'Dashboard';
  int _highRiskCount = 0;
  int _approvedThisMonthCount = 0;
  int _sentToClientCount = 0;
  int _clientApprovedCount = 0;
  List<Map<String, dynamic>> _recentApprovals = [];

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

      int highRiskCount = 0;
      int approvedThisMonthCount = 0;
      int sentToClientCount = 0;
      int clientApprovedCount = 0;
      List<Map<String, dynamic>> recentApprovals = [];

      try {
        final allProposals = await ApiService.getProposals(token);
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final startOfNextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);

        for (final raw in allProposals) {
          if (raw is! Map) continue;
          final proposal = Map<String, dynamic>.from(raw);

          final riskScore = _parseDouble(proposal['risk_score']);
          final riskLevel =
              (proposal['risk_level'] ?? '').toString().toLowerCase();
          if ((riskScore != null && riskScore >= 70) ||
              riskLevel == 'high' ||
              riskLevel == 'critical') {
            highRiskCount++;
          }

          final status = (proposal['status'] ?? '').toString().toLowerCase();

          if (status == 'released') {
            sentToClientCount++;
          }
          if (status == 'signed') {
            clientApprovedCount++;
          }

          final isApproved = status == 'signed' ||
              status == 'client signed' ||
              status == 'approved' ||
              status == 'completed';
          if (isApproved) {
            final updatedRaw = proposal['updated_at'] ?? proposal['updatedAt'];
            final updatedAt = _parseDate(updatedRaw);
            if (updatedAt != null &&
                !updatedAt.isBefore(startOfMonth) &&
                updatedAt.isBefore(startOfNextMonth)) {
              approvedThisMonthCount++;
            }
          }
        }

        recentApprovals = List<Map<String, dynamic>>.from(pending);
        recentApprovals.sort((a, b) {
          final aDate = _parseDate(a['updated_at'] ?? a['updatedAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = _parseDate(b['updated_at'] ?? b['updatedAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        if (recentApprovals.length > 5) {
          recentApprovals = recentApprovals.sublist(0, 5);
        }
      } catch (e) {
        print('⚠️ Error computing approver metrics: $e');
      }

      if (mounted) {
        setState(() {
          _pendingApprovals = pending;
          _highRiskCount = highRiskCount;
          _approvedThisMonthCount = approvedThisMonthCount;
          _sentToClientCount = sentToClientCount;
          _clientApprovedCount = clientApprovedCount;
          _recentApprovals = recentApprovals;
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
                                _buildDashboardWelcome(),
                                const SizedBox(height: 24),
                                _buildSummaryCardsRow(),
                                const SizedBox(height: 16),
                                _buildSecondaryCardsRow(),
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
                                            'Recent Proposals',
                                            _buildRecentProposalsTable(),
                                          ),
                                          const SizedBox(height: 24),
                                          _buildSection(
                                            '⏳ Pending CEO Approval',
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

  Widget _buildRecentProposalsTable() {
    if (_recentApprovals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'No recent proposals requiring your review.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildRecentTableHeader(),
        const SizedBox(height: 12),
        ..._recentApprovals.map(_buildRecentProposalRow).toList(),
      ],
    );
  }

  Widget _buildRecentTableHeader() {
    final headerStyle = PremiumTheme.labelMedium.copyWith(
      color: Colors.white70,
      letterSpacing: 1.0,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('PROPOSAL', style: headerStyle)),
          Expanded(flex: 3, child: Text('CLIENT', style: headerStyle)),
          Expanded(flex: 2, child: Text('DATE', style: headerStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildRecentProposalRow(Map<String, dynamic> proposal) {
    final submittedDate = proposal['updated_at'] != null
        ? DateTime.tryParse(proposal['updated_at'].toString())
        : null;
    final client = proposal['client_name'] ?? proposal['client'] ?? 'Unknown';
    final status = proposal['status']?.toString() ?? 'Pending';
    final dateLabel = submittedDate != null
        ? DateFormat('dd MMM yyyy').format(submittedDate)
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              proposal['title'] ?? 'Untitled Proposal',
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              client,
              style: PremiumTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dateLabel,
              style: PremiumTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildStatusPill(status),
          ),
          SizedBox(
            width: 80,
            child: TextButton(
              onPressed: () => _openProposal(proposal),
              child: const Text('Review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;

    if (lower.contains('pending')) {
      bg = PremiumTheme.orange.withOpacity(0.15);
      fg = PremiumTheme.orange;
    } else if (lower.contains('approved') || lower.contains('signed')) {
      bg = PremiumTheme.success.withOpacity(0.15);
      fg = PremiumTheme.success;
    } else if (lower.contains('rejected') ||
        lower.contains('declined') ||
        lower.contains('lost')) {
      bg = PremiumTheme.error.withOpacity(0.15);
      fg = PremiumTheme.error;
    } else {
      bg = Colors.white.withOpacity(0.08);
      fg = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
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

  Widget _buildDashboardWelcome() {
    final user = AuthService.currentUser ?? {};
    final rawName = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email'] ??
        'Approver';
    final firstName = rawName.toString().split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $firstName',
          style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        const Text(
          'Here is what needs your attention today.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSummaryCardsRow() {
    return Row(
      children: [
        Expanded(
          child: PremiumStatCard(
            title: 'Pending Approvals',
            value: _pendingApprovals.length.toString(),
            subtitle: 'Awaiting review',
            icon: Icons.pending_actions,
            gradient: PremiumTheme.blueGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PremiumStatCard(
            title: 'High Risk Items',
            value: _highRiskCount.toString(),
            subtitle: 'Flagged by risk analysis',
            icon: Icons.warning_amber_rounded,
            gradient: PremiumTheme.redGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PremiumStatCard(
            title: 'Approved This Month',
            value: _approvedThisMonthCount.toString(),
            subtitle: 'Client-approved',
            icon: Icons.check_circle_outline,
            gradient: PremiumTheme.tealGradient,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryCardsRow() {
    return Row(
      children: [
        Expanded(
          child: PremiumStatCard(
            title: 'Sent to Client',
            value: _sentToClientCount.toString(),
            subtitle: 'Released to client',
            icon: Icons.send,
            gradient: PremiumTheme.blueGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: PremiumStatCard(
            title: 'Client Approved',
            value: _clientApprovedCount.toString(),
            subtitle: 'Client signed',
            icon: Icons.thumb_up_alt_outlined,
            gradient: PremiumTheme.tealGradient,
          ),
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
                  'Pending CEO Approval',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _pendingApprovals.isEmpty
                      ? 'No proposals pending your approval.'
                      : '${_pendingApprovals.length} proposal${_pendingApprovals.length == 1 ? '' : 's'} awaiting your review and approval.',
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
                'Approvals',
                'assets/images/Time Allocation_Approval_Blue.png',
                _currentPage == 'Approvals',
                context),
            _buildNavItem('History', 'assets/images/analytics.png',
                _currentPage == 'History', context),
            const SizedBox(height: 20),
            if (!_isSidebarCollapsed)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 1,
                color: const Color(0xFF2C3E50),
              ),
            const SizedBox(height: 12),
            _buildNavItem('Settings', 'assets/images/analytics.png',
                _currentPage == 'Settings', context),
            _buildNavItem('Sign Out', 'assets/images/Logout_KhonoBuzz.png',
                false, context),
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
              'No proposals pending approval',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _pendingApprovals.map(_buildPendingApprovalCard).toList(),
    );
  }

  Widget _buildPendingApprovalCard(Map<String, dynamic> proposal) {
    final submittedDate = proposal['updated_at'] != null
        ? DateTime.tryParse(proposal['updated_at'].toString())
        : null;
    final value = proposal['budget'];
    final client = proposal['client_name'] ?? proposal['client'] ?? 'Unknown';

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
                    color: PremiumTheme.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: PremiumTheme.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Pending Approval',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PremiumTheme.orange,
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim());
    }
    return null;
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
      case 'Approvals':
        // Approvals use the same approver dashboard view
        Navigator.pushReplacementNamed(context, '/approver_dashboard');
        break;
      case 'History':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Settings':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings - Coming soon'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case 'Sign Out':
        AuthService.logout();
        Navigator.pushNamedAndRemoveUntil(
            context, '/login', (Route<dynamic> route) => false);
        break;
    }
  }
}
