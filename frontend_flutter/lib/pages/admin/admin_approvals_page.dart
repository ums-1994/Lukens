import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js_interop';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/asset_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/custom_scrollbar.dart';
import 'package:web/web.dart' as web;

class AdminApprovalsPage extends StatefulWidget {
  const AdminApprovalsPage({super.key});

  @override
  State<AdminApprovalsPage> createState() => _AdminApprovalsPageState();
}

class _AdminApprovalsPageState extends State<AdminApprovalsPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _approvedProposals = [];
  bool _isLoading = true;
  double _totalApprovedValue = 0;
  DateTime? _lastApprovedDate;
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: 'R', decimalDigits: 0);
  String _currentPage = 'Admin Approvals';

  // Admin approvals inbox state
  List<Map<String, dynamic>> _allProposals = [];
  List<Map<String, dynamic>> _pendingProposals = [];
  List<Map<String, dynamic>> _rejectedProposals = [];
  String _activeFilter = 'all'; // all, pending, approved, rejected
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enforceAccessAndLoad();
      if (!mounted) return;
      context.read<AppState>().setCurrentNavLabel('Approvals');
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      AuthService.restoreSessionFromStorage();

      var token = AuthService.token;
      if (token == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        token = AuthService.token;
      }

      if (token == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('âš ï¸ Session expired. Please login again.'),
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
      final proposals = await ApiService.getProposals(token).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      // 3) Combine and categorise proposals into All / Pending / Approved / Rejected
      final List<Map<String, dynamic>> all = [];
      final List<Map<String, dynamic>> pending = [];
      final List<Map<String, dynamic>> approved = [];
      final List<Map<String, dynamic>> rejected = [];
      final Set<String> seenIds = {};

      void addProposal(Map<String, dynamic> proposal) {
        final id = proposal['id']?.toString();
        if (id != null) {
          if (seenIds.contains(id)) return;
          seenIds.add(id);
        }
        all.add(proposal);

        final status =
            (proposal['status'] ?? '').toString().toLowerCase().trim();

        // Anything with a pending-style status should surface in Pending
        if (status.contains('pending')) {
          pending.add(proposal);
        }

        // Approved bucket (used both for tab and summary metrics)
        if (status == 'signed' ||
            status == 'client signed' ||
            status == 'approved' ||
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
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.35),
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
                        Consumer<AppState>(
                          builder: (context, app, _) {
                            final user =
                                AuthService.currentUser ?? app.currentUser;
                            final role = (user?['role'] ?? '')
                                .toString()
                                .toLowerCase()
                                .trim();
                            final isAdmin = role == 'admin' || role == 'ceo';
                            return AppSideNav(
                              isCollapsed: app.isSidebarCollapsed,
                              currentLabel: app.currentNavLabel,
                              isAdmin: isAdmin,
                              isLightMode: app.isLightMode,
                              onToggleThemeMode: app.toggleThemeMode,
                              onToggle: app.toggleSidebar,
                              onSelect: (label) {
                                app.setCurrentNavLabel(label);
                                _navigateToPage(context, label);
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: GlassContainer(
                            borderRadius: 32,
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
    final email = user['email']?.toString() ?? 'admin@example.com';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        final title = Column(
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
        );

        final userControls = Row(
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
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
            ),
          ],
        );

        if (!isNarrow) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              title,
              userControls,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            userControls,
          ],
        );
      },
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

  Widget _buildApprovalsToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        final title = Column(
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
        );

        final search = SizedBox(
          width: isNarrow ? constraints.maxWidth : 260,
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
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF3498DB), width: 1.2),
              ),
            ),
          ),
        );

        final filterButton = Container(
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
        );

        if (!isNarrow) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              search,
              const SizedBox(width: 8),
              filterButton,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                search,
                filterButton,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusTab('All', 'all', _allProposals.length),
          const SizedBox(width: 8),
          _buildStatusTab(
              'Pending Approval', 'pending', _pendingProposals.length),
          const SizedBox(width: 8),
          _buildStatusTab('Approved', 'approved', _approvedProposals.length),
          const SizedBox(width: 8),
          _buildStatusTab('Rejected', 'rejected', _rejectedProposals.length),
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
          color: isActive ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
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
    List<Map<String, dynamic>> source;
    switch (_activeFilter) {
      case 'pending':
        source = _pendingProposals;
        break;
      case 'approved':
        source = _approvedProposals;
        break;
      case 'rejected':
        source = _rejectedProposals;
        break;
      default:
        source = _allProposals;
    }

    if (_searchQuery.isEmpty) {
      return List<Map<String, dynamic>>.from(source);
    }

    final query = _searchQuery.toLowerCase();
    return source.where((proposal) {
      final id = proposal['id']?.toString().toLowerCase() ?? '';
      final title = proposal['title']?.toString().toLowerCase() ?? '';
      final client = (proposal['client_name'] ?? proposal['client'] ?? '')
          .toString()
          .toLowerCase();
      return id.contains(query) ||
          title.contains(query) ||
          client.contains(query);
    }).toList();
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
      return GlassContainer(
        borderRadius: 24,
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

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTableHeader(),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Row(
      children: const [
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
          flex: 4,
          child: Text(
            'Proposal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            'Client',
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
            'Created',
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
            'Status',
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
            'Risk',
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
              'Action',
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
    final id = proposal['id']?.toString() ?? 'â€”';
    final title = proposal['title']?.toString() ?? 'Untitled Proposal';
    final client =
        (proposal['client_name'] ?? proposal['client'] ?? 'Unknown').toString();
    final created = _formatProposalDate(
      proposal['created_at'] ?? proposal['createdAt'],
    );
    final rawStatus = (proposal['status'] ?? '').toString();
    final statusLabel = _formatStatusLabel(rawStatus);
    final statusColor = _getStatusColor(rawStatus);
    final riskLabel = _getRiskLabel(proposal);
    final riskColor = _getRiskColor(proposal);
    final owner =
        (proposal['owner_email'] ?? proposal['owner'] ?? '').toString().trim();

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
              child: _buildStatusChip(statusLabel, statusColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildRiskChip(riskLabel, riskColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _openReview(proposal),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3498DB),
                ),
                child: const Text(
                  'Review',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    final status = rawStatus.toLowerCase().trim();
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'in review':
        return 'In Review';
      case 'pending':
      case 'pending approval':
      case 'pending ceo approval':
        return 'Pending Approval';
      case 'sent':
        return 'Sent';
      case 'sent to client':
        return 'Sent to Client';
      case 'signed':
        return 'Signed';
      case 'client signed':
        return 'Client Signed';
      case 'completed':
        return 'Completed';
      case 'declined':
        return 'Declined';
      case 'rejected':
        return 'Rejected';
      default:
        if (status.isEmpty) return 'â€”';
        return status
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0].toUpperCase() + p.substring(1))
            .join(' ');
    }
  }

  Color _getStatusColor(String rawStatus) {
    final status = rawStatus.toLowerCase().trim();
    switch (status) {
      case 'draft':
        return PremiumTheme.purple;
      case 'pending':
      case 'pending approval':
      case 'pending ceo approval':
        return PremiumTheme.orange;
      case 'sent':
      case 'sent to client':
        return PremiumTheme.pink;
      case 'approved':
      case 'signed':
      case 'client signed':
      case 'completed':
        return PremiumTheme.teal;
      case 'declined':
      case 'rejected':
        return PremiumTheme.error;
      default:
        return Colors.white70;
    }
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
    );
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
            : 'â€”',
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
          final blob = web.Blob(
            [response.bodyBytes.toJS].toJS,
            web.BlobPropertyBag(type: 'application/pdf'),
          );
          final url = web.URL.createObjectURL(blob);
          web.window.open(url, '_blank');
          Future.delayed(const Duration(minutes: 1), () {
            web.URL.revokeObjectURL(url);
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

    final blob = web.Blob([buffer.toString().toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.setAttribute(
      'download',
      'approved_proposals_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    anchor.click();
    web.URL.revokeObjectURL(url);
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

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/approver_dashboard');
        break;
      case 'Approvals':
        // Already here
        break;
      case 'Analytics':
        Navigator.pushReplacementNamed(context, '/analytics');
        break;
      case 'Logout':
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
