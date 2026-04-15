// ignore_for_file: unused_field, unused_element, unused_local_variable, deprecated_member_use

import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/asset_service.dart';
import '../../theme/premium_theme.dart';
import '../../utils/proposal_status_vocabulary.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/admin/admin_sidebar.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AdminApprovalsPage extends StatefulWidget {
  const AdminApprovalsPage({super.key});

  @override
  State<AdminApprovalsPage> createState() => _AdminApprovalsPageState();
}

class _AdminApprovalsPageState extends State<AdminApprovalsPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _approvedProposals = [];
  bool _isLoading = true;
  double _totalApprovedValue = 0;
  DateTime? _lastApprovedDate;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: 'R', decimalDigits: 0);
  late AnimationController _animationController;

  // Admin approvals inbox state
  List<Map<String, dynamic>> _allProposals = [];
  List<Map<String, dynamic>> _pendingProposals = [];
  List<Map<String, dynamic>> _rejectedProposals = [];
  String _activeFilter = 'all'; // all, pending, approved, rejected
  String _searchQuery = '';
  bool _initialArgsApplied = false;

  int? _staleDays;
  double? _minRiskScore;

  String? _pipelineStage;
  int? _recentDays;

  bool _isSidebarCollapsed = false;
  String _currentPage = 'Approvals';
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  static const String _filterAll = 'all';
  static const String _filterReady = 'ready';
  static const String _filterBlocked = 'blocked';
  static const String _filterChangesRequested = 'changes_requested';
  static const String _filterApproved = 'approved';
  static const String _filterDeclined = 'declined';

  static const Color _adminBlockBase = Color(0xFF252525);

  BoxDecoration _adminBlockDecoration(double radius) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          _adminBlockBase.withValues(alpha: 0.55),
          _adminBlockBase.withValues(alpha: 0.32),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _adminFrostedBlock({
    required Widget child,
    required double radius,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: _adminBlockDecoration(radius),
          child: child,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.value = 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceAccessAndLoad();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialArgsApplied) return;
    _initialArgsApplied = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['initialFilter'];
      final filter = raw is String ? raw.toLowerCase().trim() : null;
      final mapped = _normalizeInitialFilter(filter);
      if (mapped != null) {
        setState(() {
          _activeFilter = mapped;
          _currentPage = mapped == _filterApproved ? 'History' : 'Approvals';
        });
      }

      final staleRaw = args['staleDays'];
      final riskRaw = args['minRiskScore'];
      final pipelineStageRaw = args['pipelineStage'];
      final recentDaysRaw = args['recentDays'];
      final stale = staleRaw is int ? staleRaw : int.tryParse(staleRaw?.toString() ?? '');
      final minRisk = riskRaw is num ? riskRaw.toDouble() : double.tryParse(riskRaw?.toString() ?? '');
      final recentDays = recentDaysRaw is int
          ? recentDaysRaw
          : int.tryParse(recentDaysRaw?.toString() ?? '');
      setState(() {
        _staleDays = stale;
        _minRiskScore = minRisk;
        _pipelineStage = pipelineStageRaw?.toString().trim().toLowerCase();
        _recentDays = recentDays;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _normalizeInitialFilter(String? value) {
    final v = (value ?? '').toLowerCase().trim();
    switch (v) {
      case 'all':
        return _filterAll;
      case 'pending':
        return _filterReady;
      case 'approved':
        return _filterApproved;
      case 'rejected':
        return _filterDeclined;
      default:
        return null;
    }
  }

  String _getDecisionKey(Map<String, dynamic> proposal) {
    final blockers = _getBlockers(proposal);
    if (blockers.isNotEmpty) {
      return _filterBlocked;
    }
    final status = (proposal['status'] ?? '')
        .toString()
        .toLowerCase()
        .trim()
        .replaceAll('_', ' ');
    if (status.contains('changes requested')) {
      return _filterChangesRequested;
    }
    if (status == 'rejected' || status == 'declined' || status == 'lost') {
      return _filterDeclined;
    }

    if (status == 'approved' ||
        status == 'signed' ||
        status == 'client signed' ||
        status == 'client approved' ||
        status == 'released' ||
        status == 'sent to client' ||
        status == 'sent for signature' ||
        status.contains('sent to client') ||
        status.contains('sent for signature') ||
        status == 'completed') {
      return _filterApproved;
    }

    if (_hasAllRequiredFields(proposal)) {
      return _filterReady;
    }

    return _filterReady;
  }

  List<String> _getBlockers(Map<String, dynamic> proposal) {
    final blockers = <String>[];

    final budgetRaw = proposal['budget'];
    final budget = budgetRaw is num
        ? budgetRaw.toDouble()
        : double.tryParse(
            budgetRaw?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
          );
    if (budget == null || budget <= 0) {
      blockers.add('Missing budget');
    }

    final client = (proposal['client_name'] ?? proposal['client'] ?? '')
        .toString()
        .trim();
    if (client.isEmpty) {
      blockers.add('Missing client');
    }

    final title = (proposal['title'] ?? '').toString().trim();
    if (title.isEmpty) {
      blockers.add('Missing title');
    }

    final risk = _parseDouble(proposal['risk_score'] ?? proposal['riskScore']);
    if (risk != null && risk >= 80) {
      blockers.add('High risk');
    }

    final updatedAt = _parseDate(proposal['updated_at'] ?? proposal['updatedAt']);
    if (_staleDays != null && _staleDays! > 0 && updatedAt != null) {
      final now = DateTime.now();
      if (now.difference(updatedAt).inDays >= _staleDays!) {
        blockers.add('Stalled');
      }
    }

    return blockers;
  }

  bool _hasAllRequiredFields(Map<String, dynamic> proposal) {
    return _getBlockers(proposal).isEmpty;
  }

  bool _matchesPipelineStage(Map<String, dynamic> proposal) {
    final stage = (_pipelineStage ?? '').trim().toLowerCase();
    if (stage.isEmpty) return true;

    final raw = (proposal['engagement_stage'] ??
            proposal['pipeline_stage'] ??
            proposal['pipelineStage'] ??
            proposal['stage'] ??
            '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ');
    if (raw.isEmpty) return false;
    return raw.contains(stage);
  }

  String _decisionLabel(String decisionKey) {
    switch (decisionKey) {
      case _filterReady:
        return 'Ready for approval';
      case _filterBlocked:
        return 'Blocked';
      case _filterChangesRequested:
        return 'Changes requested';
      case _filterApproved:
        return 'Approved';
      case _filterDeclined:
        return 'Declined';
      default:
        return '—';
    }
  }

  Color _decisionColor(String decisionKey) {
    switch (decisionKey) {
      case _filterReady:
        return PremiumTheme.teal;
      case _filterBlocked:
        return PremiumTheme.orange;
      case _filterChangesRequested:
        return PremiumTheme.pink;
      case _filterApproved:
        return PremiumTheme.teal;
      case _filterDeclined:
        return PremiumTheme.error;
      default:
        return Colors.white70;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(silent: true);
    }
  }

  Future<void> _enforceAccessAndLoad() async {
    final userRole =
        AuthService.currentUser?['role']?.toString().toLowerCase() ?? 'manager';

    if (userRole != 'admin' && userRole != 'ceo') {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/creator_dashboard');
      return;
    }

    await _loadData();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (_isRefreshing) return;
    _isRefreshing = true;

    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      AuthService.restoreSessionFromStorage();

      var token = AuthService.token;
      if (token == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        token = AuthService.token;
      }

      if (token == null) {
        if (mounted) {
          if (!silent) {
            setState(() => _isLoading = false);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Session expired. Please login again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 1) Fetch proposals pending admin/CEO approval from dedicated endpoint
      final pendingResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/proposals/pending_approval'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      final List<Map<String, dynamic>> pendingFromApi = [];
      if (pendingResponse.statusCode == 200) {
        final data = json.decode(pendingResponse.body);
        final List<dynamic> items = data['proposals'] as List? ?? [];
        for (final raw in items) {
          if (raw is Map) {
            pendingFromApi.add(Map<String, dynamic>.from(raw));
          }
        }
      }

      // 2) Fetch general proposals for additional context (e.g. history)
      // Use the admin/approver endpoint so admins can see proposals across all users.
      List<dynamic> proposals = [];
      try {
        final allResponse = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/proposals/all'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Request timed out');
          },
        );

        if (allResponse.statusCode == 200) {
          final decoded = json.decode(allResponse.body);
          if (decoded is Map && decoded['proposals'] is List) {
            proposals = decoded['proposals'] as List;
          }
        }
      } catch (_) {
        // Fall back to creator-scoped proposals endpoint.
      }

      if (proposals.isEmpty) {
        proposals = await ApiService.getProposals(token).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Request timed out');
          },
        );
      }

      // 3) Combine and categorise proposals into All / Pending / Approved / Rejected
      final List<Map<String, dynamic>> all = [];
      final List<Map<String, dynamic>> pending = [];
      final List<Map<String, dynamic>> approved = [];
      final List<Map<String, dynamic>> rejected = [];
      final Set<String> seenIds = {};

      void addProposal(Map<String, dynamic> proposal) {
        final id = proposal['id']?.toString();
        if (id == null || id.isEmpty) return;
        if (seenIds.contains(id)) return;
        seenIds.add(id);
        all.add(proposal);

        final status = (proposal['status'] ?? '')
            .toString()
            .toLowerCase()
            .trim()
            .replaceAll('_', ' ');

        // Anything with a pending-style status should surface in Pending
        if (status.contains('pending')) {
          pending.add(proposal);
        }

        // Approved bucket (used both for tab and summary metrics)
        if (status == 'signed' ||
            status == 'client signed' ||
            status == 'client approved' ||
            status == 'approved' ||
            status == 'released' ||
            status == 'sent to client' ||
            status == 'sent for signature' ||
            status.contains('sent to client') ||
            status.contains('sent for signature') ||
            status == 'completed') {
          approved.add(proposal);
        }

        // Rejected / lost deals
        if (status == 'rejected' || status == 'declined' || status == 'lost') {
          rejected.add(proposal);
        }
      }

      for (final proposal in pendingFromApi) {
        addProposal(proposal);
      }

      for (final raw in proposals) {
        if (raw is! Map) continue;
        addProposal(Map<String, dynamic>.from(raw));
      }

      // Compute approved summary metrics for snapshot cards
      double totalValue = 0;
      DateTime? latestApproved;
      for (final proposal in approved) {
        final budget = proposal['budget'];
        if (budget is num) {
          totalValue += budget.toDouble();
        } else if (budget is String) {
          final cleaned = budget.replaceAll(RegExp(r'[^\d.]'), '');
          totalValue += double.tryParse(cleaned) ?? 0;
        }

        final approvedDate = proposal['updated_at'] != null
            ? DateTime.tryParse(proposal['updated_at'].toString())
            : null;
        if (approvedDate != null) {
          latestApproved =
              (latestApproved == null || approvedDate.isAfter(latestApproved))
                  ? approvedDate
                  : latestApproved;
        }
      }

      // Sort lists by most recent activity
      int compareByRecent(Map<String, dynamic> a, Map<String, dynamic> b) {
        DateTime? parseDate(dynamic value) {
          if (value == null) return null;
          final s = value.toString();
          if (s.isEmpty) return null;
          return DateTime.tryParse(s);
        }

        final aUpdated = parseDate(a['updated_at']);
        final bUpdated = parseDate(b['updated_at']);
        if (aUpdated != null && bUpdated != null) {
          return bUpdated.compareTo(aUpdated);
        }
        if (aUpdated != null) return -1;
        if (bUpdated != null) return 1;

        final aCreated = parseDate(a['created_at']);
        final bCreated = parseDate(b['created_at']);
        if (aCreated != null && bCreated != null) {
          return bCreated.compareTo(aCreated);
        }
        if (aCreated != null) return -1;
        if (bCreated != null) return 1;
        return 0;
      }

      all.sort(compareByRecent);
      pending.sort(compareByRecent);
      approved.sort(compareByRecent);
      rejected.sort(compareByRecent);

      if (mounted) {
        setState(() {
          _allProposals = all;
          _pendingProposals = pending;
          _approvedProposals = approved;
          _rejectedProposals = rejected;
          _totalApprovedValue = totalValue;
          _lastApprovedDate = latestApproved;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (!silent) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      _isRefreshing = false;
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
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.35),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  child: AdminSidebar(
                    isCollapsed: app.isAdminSidebarCollapsed,
                    currentPage: _currentPage,
                    onToggle: _toggleSidebar,
                    onSelect: (label) {
                      setState(() => _currentPage = label);
                      _navigateToPage(label);
                    },
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(app),
                        const SizedBox(height: 24),
                        Expanded(
                          child: _adminFrostedBlock(
                            radius: 32,
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildApprovalsToolbar(),
                                const SizedBox(height: 16),
                                _buildStatusTabs(),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: CustomScrollbar(
                                    controller: _scrollController,
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      child: _buildApprovalsTable(),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppState app) {
    final user = AuthService.currentUser ?? app.currentUser ?? {};
    final email = user['email']?.toString() ?? 'admin@example.com';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Admin Approvals',
              style: PremiumTheme.titleLarge,
            ),
            SizedBox(height: 4),
            Text(
              'Manage and review all proposal requests across your team',
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
                const Text(
                  'Admin',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle,
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
                  'Client-Approved Proposals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _approvedProposals.isEmpty
                      ? 'No proposals have been approved by clients yet.'
                      : '${_approvedProposals.length} proposal${_approvedProposals.length == 1 ? '' : 's'} approved by clients${_lastApprovedDate != null ? ' (last approved ${_formatRelativeDate(_lastApprovedDate!)})' : ''}.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Export List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: PremiumTheme.teal,
            ),
            onPressed:
                _approvedProposals.isEmpty ? null : _exportApprovedProposals,
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
        color: const Color(0xFF252525),
        border: Border(
          right: BorderSide(
            color: PremiumTheme.glassWhiteBorder,
            width: 1,
          ),
        ),
      ),
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildNavItem('Dashboard', 'assets/images/Dahboard.png',
                      _currentPage == 'Dashboard', context),
                  _buildNavItem(
                      'Approvals',
                      'assets/images/Time Allocation_Approval_Blue.png',
                      _currentPage == 'Admin Approvals' ||
                          _currentPage == 'Approvals',
                      context),
                  _buildNavItem('Analytics', 'assets/images/analytics.png',
                      _currentPage == 'Analytics', context),
                  _buildNavItem('History', 'assets/images/analytics.png',
                      _currentPage == 'History', context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
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
                _navigateToPage(label);
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
            _navigateToPage(label);
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
      ),
    );
  }

  void _toggleSidebar() {
    final app = context.read<AppState>();
    app.setAdminSidebarCollapsed(!app.isAdminSidebarCollapsed);
  }

  Widget _buildApprovalsToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Approvals Inbox',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Review, approve, or reject proposals awaiting your decision',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 260,
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by title, client, or ID',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white70,
                size: 18,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF3498DB), width: 1.2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Icon(
            Icons.filter_alt_outlined,
            color: Colors.white70,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabs() {
    final counts = <String, int>{
      _filterAll: 0,
      _filterReady: 0,
      _filterBlocked: 0,
      _filterChangesRequested: 0,
      _filterApproved: 0,
      _filterDeclined: 0,
    };

    for (final proposal in _allProposals) {
      counts[_filterAll] = (counts[_filterAll] ?? 0) + 1;
      final key = _getDecisionKey(proposal);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusTab('All', _filterAll, counts[_filterAll] ?? 0),
          const SizedBox(width: 8),
          _buildStatusTab(
              'Ready for approval', _filterReady, counts[_filterReady] ?? 0),
          const SizedBox(width: 8),
          _buildStatusTab('Blocked', _filterBlocked, counts[_filterBlocked] ?? 0),
          const SizedBox(width: 8),
          _buildStatusTab(
              'Changes requested', _filterChangesRequested, counts[_filterChangesRequested] ?? 0),
          const SizedBox(width: 8),
          _buildStatusTab('Approved', _filterApproved, counts[_filterApproved] ?? 0),
          const SizedBox(width: 8),
          _buildStatusTab('Declined', _filterDeclined, counts[_filterDeclined] ?? 0),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, String value, int count) {
    final bool isActive = _activeFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive
                ? const Color(0xFF3498DB)
                : Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF3498DB).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getVisibleProposals() {
    final source = _allProposals;

    final query = _searchQuery.toLowerCase();
    final now = DateTime.now();

    return source.where((proposal) {
      if (_activeFilter != _filterAll) {
        if (_getDecisionKey(proposal) != _activeFilter) return false;
      }

      if (!_matchesPipelineStage(proposal)) return false;

      if (query.isNotEmpty) {
        final id = proposal['id']?.toString().toLowerCase() ?? '';
        final title = proposal['title']?.toString().toLowerCase() ?? '';
        final client = (proposal['client_name'] ?? proposal['client'] ?? '')
            .toString()
            .toLowerCase();
        final matches = id.contains(query) || title.contains(query) || client.contains(query);
        if (!matches) return false;
      }

      if (_minRiskScore != null) {
        final risk = _parseDouble(proposal['risk_score'] ?? proposal['riskScore']);
        if (risk == null || risk < _minRiskScore!) return false;
      }

      if (_staleDays != null && _staleDays! > 0) {
        final updatedAt = _parseDate(proposal['updated_at'] ?? proposal['updatedAt']);
        if (updatedAt == null) return false;
        if (now.difference(updatedAt).inDays < _staleDays!) return false;
      }

      return true;
    }).toList();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  Widget _buildApprovalsTable() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final proposals = _getVisibleProposals();

    if (proposals.isEmpty) {
      return _adminFrostedBlock(
        radius: 24,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.white70),
            SizedBox(height: 12),
            Text(
              'No proposals found for this filter',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try switching tabs or clearing your search.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < proposals.length; i++) {
      rows.add(_buildTableRow(i + 1, proposals[i]));
      if (i < proposals.length - 1) {
        rows.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        );
      }
    }

    return _adminFrostedBlock(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTableHeader(),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.10),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            '#',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Decision',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Blockers',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Actions',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(int index, Map<String, dynamic> proposal) {
    final id = proposal['id']?.toString() ?? '—';
    final title = proposal['title']?.toString() ?? 'Untitled Proposal';
    final client =
        (proposal['client_name'] ?? proposal['client'] ?? 'Unknown').toString();
    final created = _formatProposalDate(
      proposal['created_at'] ?? proposal['createdAt'],
    );
    final decisionKey = _getDecisionKey(proposal);
    final decisionLabel = _decisionLabel(decisionKey);
    final decisionColor = _decisionColor(decisionKey);
    final blockers = _getBlockers(proposal);
    final owner =
        (proposal['owner_email'] ?? proposal['owner'] ?? '').toString().trim();

    void showBlockersDialog() {
      showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1F2840),
            title: const Text('Blockers', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: blockers
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• $b',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '#$id',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (owner.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Owner: $owner',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              client,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              created,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusChip(decisionLabel, decisionColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: blockers.isEmpty
                  ? _buildStatusChip('—', Colors.white70)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: _buildRiskChip(
                            blockers.first,
                            blockers.any((b) =>
                                        b.toLowerCase().contains('missing') ||
                                        b.toLowerCase().contains('stalled') ||
                                        b.toLowerCase().contains('high risk'))
                                ? PremiumTheme.orange
                                : Colors.white70,
                          ),
                        ),
                        if (blockers.length > 1) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: showBlockersDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.expand_more,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _openReview(proposal),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3498DB),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

  Future<void> _approveFromRow(Map<String, dynamic> proposal) async {
    final id = proposal['id']?.toString();
    if (id == null || id.isEmpty) return;

    final token = AuthService.token;
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Session expired. Please login again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/proposals/$id/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Approved'),
            backgroundColor: PremiumTheme.teal,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineFromRow(Map<String, dynamic> proposal) async {
    final id = proposal['id']?.toString();
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline proposal?'),
        content: const Text('This will return the proposal to Draft.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = AuthService.token;
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Session expired. Please login again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/proposals/$id/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Declined'),
            backgroundColor: PremiumTheme.error,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error declining: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestChangesFromRow(Map<String, dynamic> proposal) async {
    final id = proposal['id']?.toString();
    if (id == null || id.isEmpty) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request changes from'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Manager'),
              onTap: () => Navigator.pop(context, 'manager'),
            ),
            ListTile(
              title: const Text('Finance Manager'),
              onTap: () => Navigator.pop(context, 'finance'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    final token = AuthService.token;
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Session expired. Please login again.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/proposals/$id/request-changes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'target': selected}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Changes requested'),
            backgroundColor: PremiumTheme.pink,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request changes: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatProposalDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      if (date is String) {
        if (date.isEmpty) return 'Unknown';
        final parsed = DateTime.parse(date);
        return DateFormat('dd MMM yyyy').format(parsed);
      }
      if (date is DateTime) {
        return DateFormat('dd MMM yyyy').format(date);
      }
    } catch (_) {
      return date.toString();
    }
    return date.toString();
  }

  String _formatStatusLabel(String rawStatus) {
    return ProposalStatusVocabulary.titleCase(rawStatus, emptyLabel: '—');
  }

  Color _getStatusColor(String rawStatus) {
    final normalized = ProposalStatusVocabulary.normalize(rawStatus);
    final stage = ProposalStatusVocabulary.lifecycleStageFromStatus(normalized);
    return ProposalStatusVocabulary.lifecycleStageColor(stage);
  }

  Widget _buildStatusChip(String label, Color color) {
    final bgColor = color == Colors.white70
        ? Colors.white.withValues(alpha: 0.08)
        : color.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getRiskLabel(Map<String, dynamic> proposal) {
    final dynamic risk = proposal['risk_score'] ?? proposal['riskScore'];
    if (risk is num) {
      final score = risk.toDouble();
      if (score >= 70) {
        return 'High (${score.round()})';
      } else if (score >= 40) {
        return 'Medium (${score.round()})';
      } else {
        return 'Low (${score.round()})';
      }
    }
    return 'Not evaluated';
  }

  Color _getRiskColor(Map<String, dynamic> proposal) {
    final dynamic risk = proposal['risk_score'] ?? proposal['riskScore'];
    if (risk is num) {
      final score = risk.toDouble();
      if (score >= 70) {
        return PremiumTheme.error;
      } else if (score >= 40) {
        return PremiumTheme.orange;
      } else {
        return PremiumTheme.teal;
      }
    }
    return Colors.white70;
  }

  Widget _buildRiskChip(String label, Color color) {
    final bgColor = color == Colors.white70
        ? Colors.white.withValues(alpha: 0.08)
        : color.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _openReview(Map<String, dynamic> proposal) {
    final id = proposal['id']?.toString();
    if (id == null) return;

    Navigator.pushNamed(
      context,
      '/proposal_review',
      arguments: {
        'id': id,
        'title': proposal['title'],
      },
    ).then((result) async {
      if (result == 'approved') {
        setState(() => _activeFilter = _filterApproved);
      } else if (result == 'rejected') {
        setState(() => _activeFilter = _filterDeclined);
      }
      await _loadData();
    });
  }

  Widget _buildSnapshotMetrics() {
    final cards = [
      _SnapshotMetric(
        title: 'Approved Proposals',
        value: _approvedProposals.length.toString(),
        subtitle: 'Client-approved',
        gradient: PremiumTheme.blueGradient,
      ),
      _SnapshotMetric(
        title: 'Total Approved Value',
        value: _formatCurrency(_totalApprovedValue),
        subtitle: 'All-time',
        gradient: PremiumTheme.purpleGradient,
      ),
      _SnapshotMetric(
        title: 'Last Approved',
        value: _lastApprovedDate != null
            ? _formatRelativeDate(_lastApprovedDate!)
            : '—',
        subtitle: _lastApprovedDate != null
            ? DateFormat('dd MMM yyyy').format(_lastApprovedDate!)
            : 'Awaiting approvals',
        gradient: PremiumTheme.orangeGradient,
      ),
      _SnapshotMetric(
        title: 'Average Deal Size',
        value: _approvedProposals.isEmpty
            ? _formatCurrency(0)
            : _formatCurrency(_totalApprovedValue / _approvedProposals.length),
        subtitle: 'Based on approved deals',
        gradient: PremiumTheme.tealGradient,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.6,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      children: cards
          .map((metric) => PremiumStatCard(
                title: metric.title,
                value: metric.value,
                subtitle: metric.subtitle,
                gradient: metric.gradient,
              ))
          .toList(),
    );
  }

  Widget _buildApprovedList() {
    if (_approvedProposals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, size: 54, color: PremiumTheme.teal),
            SizedBox(height: 12),
            Text(
              'No proposals have been approved yet',
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
      children: _approvedProposals.map(_buildApprovedCard).toList(),
    );
  }

  Widget _buildApprovedCard(Map<String, dynamic> proposal) {
    final approvedDate = proposal['updated_at'] != null
        ? DateTime.tryParse(proposal['updated_at'].toString())
        : null;
    final value = proposal['budget'];
    final client = proposal['client_name'] ?? proposal['client'] ?? 'Unknown';
    final owner = proposal['owner_email'] ??
        proposal['owner'] ??
        proposal['user_id']?.toString() ??
        '';

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
                Text(
                  _formatCurrency(_parseBudget(value)),
                  style: PremiumTheme.titleMedium.copyWith(fontSize: 18),
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
                    approvedDate != null
                        ? DateFormat('dd MMM yyyy').format(approvedDate)
                        : 'Unknown'),
                if (owner.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _buildInfoChip(Icons.person, owner),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openProposal(proposal),
                icon: const Icon(Icons.open_in_new),
                label: const Text('View Proposal'),
              ),
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
        color: Colors.white.withValues(alpha: 0.08),
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

  void _openProposal(Map<String, dynamic> proposal) async {
    final id = proposal['id']?.toString();
    if (id == null) return;

    final status = (proposal['status'] ?? '').toString().toLowerCase();
    final isSigned = status == 'signed' ||
        status == 'client signed' ||
        status == 'completed';

    if (isSigned) {
      final token = AuthService.token;
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/proposals/$id/signed-document'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final blob = html.Blob([response.bodyBytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.window.open(url, '_blank');
          Future.delayed(const Duration(minutes: 1), () {
            html.Url.revokeObjectUrl(url);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to load signed document: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading signed document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      Navigator.pushNamed(
        context,
        '/compose',
        arguments: {
          'id': id,
          'title': proposal['title'],
          'readOnly': true,
        },
      );
    }
  }

  void _exportApprovedProposals() {
    final buffer = StringBuffer()
      ..writeln('Title,Client,Value,Approved Date,Owner');
    for (final proposal in _approvedProposals) {
      final title = proposal['title']?.toString().replaceAll(',', ' ') ?? '';
      final client =
          proposal['client_name']?.toString().replaceAll(',', ' ') ?? '';
      final value = _formatCurrency(_parseBudget(proposal['budget']));
      final approvedDate = proposal['updated_at'] != null
          ? DateFormat('yyyy-MM-dd')
              .format(DateTime.parse(proposal['updated_at'].toString()))
          : '';
      final owner = proposal['owner_email'] ?? proposal['owner'] ?? '';
      buffer.writeln('"$title","$client","$value","$approvedDate","$owner"');
    }

    final blob = html.Blob([buffer.toString()]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download',
          'approved_proposals_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  double _parseBudget(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return 0;
      final cleaned = trimmed
          .replaceAll(RegExp(r'[^\d.,-]'), '')
          .replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  double _inferBudget(Map<String, dynamic> proposal) {
    final direct = _parseBudget(
      proposal['budget'] ??
          proposal['deal_value'] ??
          proposal['dealValue'] ??
          proposal['value'] ??
          proposal['amount'],
    );
    if (direct > 0) return direct;

    final content = proposal['content'];
    if (content == null) return 0;

    dynamic tryDecode(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            return jsonDecode(trimmed);
          } catch (_) {
            return value;
          }
        }
      }
      return value;
    }

    double sumFromPriceTable(dynamic table) {
      if (table is! Map) return 0;
      if ((table['type'] ?? '').toString().toLowerCase() != 'price') return 0;

      final cells = table['cells'];
      if (cells is! List || cells.isEmpty) return 0;

      final header = cells.first;
      if (header is! List) return 0;

      int totalIndex = -1;
      for (int i = 0; i < header.length; i++) {
        final h = (header[i] ?? '').toString().toLowerCase().trim();
        if (h == 'total') {
          totalIndex = i;
          break;
        }
      }

      double sum = 0;
      for (int r = 1; r < cells.length; r++) {
        final row = cells[r];
        if (row is! List || row.isEmpty) continue;

        dynamic v;
        if (totalIndex >= 0 && totalIndex < row.length) {
          v = row[totalIndex];
        } else {
          v = row.last;
        }
        sum += _parseBudget(v);
      }
      return sum;
    }

    double scan(dynamic node) {
      node = tryDecode(node);

      if (node is Map) {
        double total = 0;

        // Common wrappers used by the editor
        final positioned = node['positionedPricingTables'];
        if (positioned is List) {
          for (final item in positioned) {
            final it = tryDecode(item);
            if (it is Map && it['table'] != null) {
              total += sumFromPriceTable(tryDecode(it['table']));
            }
          }
        }

        final tables = node['tables'];
        if (tables is List) {
          for (final t in tables) {
            total += sumFromPriceTable(tryDecode(t));
          }
        }

        // If the node itself looks like a table
        total += sumFromPriceTable(node);

        // Recurse into all values (handles nested content, double-encoded JSON, etc.)
        for (final v in node.values) {
          total += scan(v);
        }
        return total;
      }

      if (node is List) {
        double total = 0;
        for (final item in node) {
          total += scan(item);
        }
        return total;
      }

      return 0;
    }

    return scan(content);
  }

  String _formatCurrency(double value) {
    if (value == 0) return 'R0';
    return _currencyFormatter.format(value);
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${diff.inDays} days ago';
  }

  void _navigateToPage(String page) {
    setState(() => _currentPage = page);

    switch (page) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/approver_dashboard');
        break;
      case 'Approvals':
        setState(() => _activeFilter = _filterReady);
        break;
      case 'Analytics':
      case 'All analytics':
      case 'My analytics':
        Navigator.pushReplacementNamed(context, '/admin_analytics');
        break;
      case 'History':
        Navigator.pushReplacementNamed(context, '/admin_history');
        break;
      case 'Sign Out':
        AuthService.logout();
        Navigator.pushNamedAndRemoveUntil(
            context, '/login', (Route<dynamic> route) => false);
        break;
    }
  }
}

class _SnapshotMetric {
  final String title;
  final String value;
  final String subtitle;
  final Gradient gradient;

  _SnapshotMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.gradient,
  });
}
