// ignore_for_file: unused_field, unused_element, unused_local_variable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:ui';
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

        // Combine pending approvals and general proposals into a single list
        // so that admins who don't author proposals still see recent items.
        final List<Map<String, dynamic>> combined = [];
        final Set<String> seenIds = {};

        void addCombined(Map<String, dynamic> proposal) {
          final id = proposal['id']?.toString();
          if (id != null) {
            if (seenIds.contains(id)) return;
            seenIds.add(id);
          }
          combined.add(proposal);
        }

        // Seed with pending approvals from the dedicated endpoint
        for (final proposal in pending) {
          addCombined(Map<String, dynamic>.from(proposal));
        }

        // Add any additional proposals returned by the generic /api/proposals
        for (final raw in allProposals) {
          if (raw is! Map) continue;
          addCombined(Map<String, dynamic>.from(raw));
        }

        // Compute dashboard metrics from the combined set
        for (final proposal in combined) {
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

        // Build recent approvals list from the combined proposals
        recentApprovals = List<Map<String, dynamic>>.from(combined);
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
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 860 || size.width < 1200;

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
              padding: EdgeInsets.all(compact ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(app),
                  SizedBox(height: compact ? 16 : 24),
                  Expanded(
                    child: Row(
                      children: [
                        Material(
                          child: _buildSidebar(context),
                        ),
                        SizedBox(width: compact ? 16 : 24),
                        Expanded(
                          child: _buildDarkGlass(
                            borderRadius: 32,
                            padding: EdgeInsets.all(compact ? 16 : 24),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Avoid bottom overflows on shorter viewports by
                                // making the entire dashboard panel scrollable.
                                return CustomScrollbar(
                                  controller: _scrollController,
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildDashboardWelcome(),
                                        SizedBox(height: compact ? 16 : 24),
                                        _buildSummaryCardsRow(),
                                        SizedBox(height: compact ? 12 : 16),
                                        _buildSecondaryCardsRow(),
                                        SizedBox(height: compact ? 16 : 24),
                                        _buildHeroSection(),
                                        SizedBox(height: compact ? 16 : 24),
                                        _buildSection(
                                          'Proposals Awaiting Your Approval',
                                          _isLoading
                                              ? const Center(
                                                  child:
                                                      CircularProgressIndicator())
                                              : _buildPendingApprovalsList(),
                                        ),
                                        SizedBox(height: compact ? 16 : 24),
                                        _buildSection(
                                          'Recent Proposals',
                                          _buildRecentProposalsTable(),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
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
      final compact = MediaQuery.sizeOf(context).height < 860;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 16 : 24),
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
              'Approver Dashboard',
              style: PremiumTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Review and approve proposals assigned to you',
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
    final compact = MediaQuery.sizeOf(context).height < 860;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $firstName',
          style: PremiumTheme.titleLarge.copyWith(fontSize: compact ? 20 : 22),
        ),
        const SizedBox(height: 4),
        const Text(
          'Here is what needs your attention today.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  static const Color _cardAccent = Color(0xFFC10D00);

  BoxDecoration _darkGlassDecoration(double borderRadius) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.black.withValues(alpha: 0.40),
          Colors.black.withValues(alpha: 0.20),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.10),
        width: 1,
      ),
    );
  }

  Widget _buildDarkGlass({
    required Widget child,
    double borderRadius = 24,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: _darkGlassDecoration(borderRadius),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color accentColor = _cardAccent,
  }) {
    final compact = MediaQuery.sizeOf(context).height < 860;
    return _buildDarkGlass(
      borderRadius: 18,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: compact ? 18 : 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: PremiumTheme.displayMedium.copyWith(
              fontSize: compact ? 24 : 28,
              color: accentColor,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: PremiumTheme.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassStatCard(
            title: 'Pending Approvals',
            value: _pendingApprovals.length.toString(),
            subtitle: 'Awaiting review',
            icon: Icons.pending_actions,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassStatCard(
            title: 'High Risk Items',
            value: _highRiskCount.toString(),
            subtitle: 'Flagged by risk analysis',
            icon: Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassStatCard(
            title: 'Sent to Client',
            value: _sentToClientCount.toString(),
            subtitle: 'Released to client',
            icon: Icons.send,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassStatCard(
            title: 'Client Approved',
            value: _clientApprovedCount.toString(),
            subtitle: 'Client signed',
            icon: Icons.thumb_up_alt_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    final compact = MediaQuery.sizeOf(context).height < 860;
    return _buildDarkGlass(
      borderRadius: 24,
      padding: EdgeInsets.all(compact ? 18 : 24),
      child: Row(
        children: [
          Container(
            width: compact ? 48 : 56,
            height: compact ? 48 : 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.pending_actions,
              color: _cardAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Approval',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 18 : 20,
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
    final compact = MediaQuery.sizeOf(context).height < 860;
    return _buildDarkGlass(
      borderRadius: 24,
      padding: EdgeInsets.all(compact ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PremiumTheme.titleMedium.copyWith(
              fontSize: compact ? 18 : PremiumTheme.titleMedium.fontSize,
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
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
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
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
          child: Material(
            color: Colors.transparent,
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
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? _cardAccent
                        : Colors.white.withValues(alpha: 0.18),
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _currentPage = label);
            _navigateToPage(context, label);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? _cardAccent.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? _cardAccent
                          : Colors.white.withValues(alpha: 0.18),
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
      final compact = MediaQuery.sizeOf(context).height < 860;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 18 : 36),
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

    final compact = MediaQuery.sizeOf(context).height < 860;
    final maxItems = compact ? 3 : 6;
    final shown = _pendingApprovals.take(maxItems).toList();

    return Column(
      children: [
        ...shown.map(_buildPendingApprovalCard),
        if (_pendingApprovals.length > shown.length)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _currentPage = 'Approvals');
                _navigateToPage(context, 'Approvals');
              },
              child: Text(
                'View all (${_pendingApprovals.length})',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPendingApprovalCard(Map<String, dynamic> proposal) {
    final submittedDate = proposal['updated_at'] != null
        ? DateTime.tryParse(proposal['updated_at'].toString())
        : null;
    final value = proposal['budget'];
    final client = proposal['client_name'] ?? proposal['client'] ?? 'Unknown';

    final compact = MediaQuery.sizeOf(context).height < 860;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 12 : 16),
      child: _buildDarkGlass(
        borderRadius: 20,
        padding: EdgeInsets.all(compact ? 14 : 20),
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
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: PremiumTheme.orange.withValues(alpha: 0.35),
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
            SizedBox(height: compact ? 10 : 12),
            Row(
              children: [
                _buildInfoChip(Icons.business, client),
                SizedBox(width: compact ? 8 : 12),
                _buildInfoChip(
                    Icons.calendar_today,
                    submittedDate != null
                        ? DateFormat('dd MMM yyyy').format(submittedDate)
                        : 'Unknown'),
                if (value != null && value != 0) ...[
                  SizedBox(width: compact ? 8 : 12),
                  _buildInfoChip(
                      Icons.attach_money, _formatCurrency(_parseBudget(value))),
                ],
              ],
            ),
            SizedBox(height: compact ? 12 : 16),
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
                    backgroundColor: Colors.black.withValues(alpha: 0.22),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: PremiumTheme.teal.withValues(alpha: 0.65),
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _rejectProposal(proposal),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cardAccent,
                    side:
                        BorderSide(color: _cardAccent.withValues(alpha: 0.85)),
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
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
        // Go to the dedicated admin approvals view
        Navigator.pushReplacementNamed(context, '/admin_approvals');
        break;
      case 'History':
        // History of approvals also uses the admin approvals view
        Navigator.pushReplacementNamed(context, '/admin_approvals');
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
