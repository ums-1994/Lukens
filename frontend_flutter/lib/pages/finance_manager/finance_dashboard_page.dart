import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/footer.dart';

/// Finance dashboard for reviewing proposal pipeline and financials.
///
/// This page intentionally uses only real data loaded via [AppState.fetchProposals]
/// (which calls the backend `/api/proposals` endpoint). No mock data is used.
class FinanceDashboardPage extends StatefulWidget {
  const FinanceDashboardPage({Key? key}) : super(key: key);

  @override
  State<FinanceDashboardPage> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardPage> {
  bool _isLoading = false;
  String _statusFilter = 'all'; // all, pending, approved, other
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final app = context.read<AppState>();

    // Ensure token is synced from AuthService
    if (app.authToken == null && AuthService.token != null) {
      app.authToken = AuthService.token;
      app.currentUser = AuthService.currentUser;
    }

    if (app.authToken == null && AuthService.token == null) {
      // Not authenticated; nothing to load
      return;
    }

    setState(() => _isLoading = true);
    try {
      await app.fetchProposals();
      await app.fetchDashboard();
    } catch (e) {
      debugPrint('Error loading finance dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> _filteredProposals(List<dynamic> proposals) {
    final query = _searchController.text.toLowerCase().trim();

    return proposals.where((raw) {
      if (raw is! Map) return false;
      final p = raw;

      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client_name'] ?? p['client'] ?? '').toString().toLowerCase();
      final statusRaw = (p['status'] ?? '').toString();
      final status = statusRaw.toLowerCase();

      if (query.isNotEmpty &&
          !(title.contains(query) || client.contains(query))) {
        return false;
      }

      switch (_statusFilter) {
        case 'pending':
          // Anything that looks like it still needs internal approval
          return status.contains('pending') || status.contains('review');
        case 'approved':
          // Approved / signed / released
          return status.contains('approved') ||
              status.contains('signed') ||
              status.contains('released');
        case 'other':
          return !status.contains('pending') &&
              !status.contains('review') &&
              !status.contains('approved') &&
              !status.contains('signed') &&
              !status.contains('released');
        case 'all':
        default:
          return true;
      }
    }).toList();
  }

  double _extractAmount(dynamic raw) {
    if (raw is! Map) return 0;
    final p = raw;
    const keys = [
      'budget',
      'amount',
      'total',
      'value',
      'price',
    ];

    for (final k in keys) {
      final v = p[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final s = v.toString();
      final cleaned = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
      final parsed = double.tryParse(cleaned);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _formatCurrency(double amount) {
    if (amount <= 0) return '--';
    // Simple thousands separator for readability
    final rounded = amount.round();
    final s = rounded.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buf.write(',');
      }
    }
    return 'R${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    final proposals = _filteredProposals(app.proposals);
    final totalCount = proposals.length;
    final pendingCount = proposals
        .where((p) => (p is Map &&
            ((p['status'] ?? '').toString().toLowerCase().contains('pending') ||
                (p['status'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains('review'))))
        .length;
    final approvedCount = proposals
        .where((p) => (p is Map &&
            ((p['status'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains('approved') ||
                (p['status'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains('signed'))))
        .length;

    double totalAmount = 0;
    for (final p in proposals) {
      totalAmount += _extractAmount(p);
    }

    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            _buildHeader(app, isMobile),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CustomScrollbar(
                        controller: _scrollController,
                        child: RefreshIndicator(
                          onRefresh: _loadData,
                          color: PremiumTheme.teal,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSummaryRow(
                                  totalCount: totalCount,
                                  pendingCount: pendingCount,
                                  approvedCount: approvedCount,
                                  totalAmount: totalAmount,
                                ),
                                const SizedBox(height: 16),
                                _buildFilters(),
                                const SizedBox(height: 16),
                                _buildTable(proposals),
                                const SizedBox(height: 24),
                                const Footer(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppState app, bool isMobile) {
    final userName = app.currentUser?['full_name'] ??
        app.currentUser?['first_name'] ??
        app.currentUser?['email'] ??
        'Finance User';

    return Container(
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
            Expanded(
              child: Text(
                'Finance Dashboard',
                style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoading ? null : _loadData,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
                ClipOval(
                  child: Image.asset(
                    'assets/images/User_Profile.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Finance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
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
    );
  }

  Widget _buildSidebar() {
    // Simple, non-collapsible sidebar to stay consistent with other dashboards.
    return Container(
      width: 90,
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
      child: Column(
        children: const [
          SizedBox(height: 16),
          Icon(Icons.account_balance, color: Colors.white),
          SizedBox(height: 8),
          Icon(Icons.receipt_long, color: Colors.white70),
          SizedBox(height: 8),
          Icon(Icons.trending_up, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required int totalCount,
    required int pendingCount,
    required int approvedCount,
    required double totalAmount,
  }) {
    final cards = <Widget>[
      _buildSummaryCard(
        label: 'Total Proposals',
        value: totalCount.toString(),
        subtitle: 'Across all statuses',
        icon: Icons.folder_open,
        color: PremiumTheme.teal,
      ),
      _buildSummaryCard(
        label: 'Pending Internal',
        value: pendingCount.toString(),
        subtitle: 'Need review / approval',
        icon: Icons.hourglass_empty,
        color: Colors.orange,
      ),
      _buildSummaryCard(
        label: 'Approved / Signed',
        value: approvedCount.toString(),
        subtitle: 'Approved or client-signed',
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      _buildSummaryCard(
        label: 'Total Value',
        value: _formatCurrency(totalAmount),
        subtitle: 'Sum of budgets / amounts',
        icon: Icons.attach_money,
        color: PremiumTheme.info,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 900;
        if (isNarrow) {
          return Column(
            children: [
              for (final c in cards) ...[
                c,
                const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (final c in cards) ...[
              Expanded(child: c),
              if (c != cards.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: PremiumTheme.darkBg2.withOpacity(0.85),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: PremiumTheme.displayMedium.copyWith(
              fontSize: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: PremiumTheme.labelMedium.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final dateFilterDisabledText = 'Date filter uses live data only';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: PremiumTheme.darkBg2.withOpacity(0.85),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          final searchField = Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search proposals or clients…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: PremiumTheme.teal),
                ),
              ),
            ),
          );

          final statusDropdown = Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              dropdownColor: PremiumTheme.darkBg1,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Status',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(
                    value: 'approved', child: Text('Approved / Signed')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
            ),
          );

          final clearButton = TextButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _statusFilter = 'all';
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          );

          final dateHint = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date range',
                  style: PremiumTheme.labelMedium.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFilterDisabledText,
                  style: PremiumTheme.labelMedium.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [searchField]),
                const SizedBox(height: 12),
                Row(children: [statusDropdown]),
                const SizedBox(height: 12),
                Row(children: [dateHint]),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: clearButton),
              ],
            );
          }

          return Row(
            children: [
              searchField,
              const SizedBox(width: 12),
              statusDropdown,
              const SizedBox(width: 12),
              dateHint,
              const SizedBox(width: 12),
              clearButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTable(List<dynamic> proposals) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: PremiumTheme.teal),
        ),
      );
    }

    if (proposals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, color: Colors.white54, size: 40),
            const SizedBox(height: 8),
            Text(
              'No proposals match your filters.',
              style: PremiumTheme.bodyMedium.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: PremiumTheme.darkBg2.withOpacity(0.9),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proposals overview',
            style: PremiumTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildTableHeader(),
          const Divider(height: 16, color: Colors.white24),
          ...proposals.map(_buildTableRow),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
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
          Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
          Expanded(flex: 2, child: Text('AMOUNT', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildTableRow(dynamic raw) {
    if (raw is! Map) return const SizedBox.shrink();
    final p = raw;

    final title = (p['title'] ?? 'Untitled Proposal').toString();
    final client = (p['client_name'] ?? p['client'] ?? 'Unknown').toString();
    final status = (p['status'] ?? 'Draft').toString();
    final amount = _extractAmount(p);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              client,
              style: PremiumTheme.bodyMedium.copyWith(
                color: PremiumTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildStatusChip(status),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatCurrency(amount),
                style: PremiumTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;

    if (lower.contains('pending') || lower.contains('review')) {
      bg = Colors.orange.withOpacity(0.15);
      fg = Colors.orange;
    } else if (lower.contains('approved') ||
        lower.contains('signed') ||
        lower.contains('released')) {
      bg = Colors.green.withOpacity(0.15);
      fg = Colors.green;
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
      ),
    );
  }

  // NOTE: Duplicate/unfinished dashboard implementation below was causing a
  // duplicate `build()` method error and many undefined references.
  // It’s commented out to keep this page compiling; remove if not needed.
  /*
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;
    final isDesktop = size.width >= 1100;

    final filteredPending = _filtered(_pendingProposals);
    final filteredApproved = _filtered(_approvedProposals);
    final filteredRejected = _filtered(_rejectedProposals);

    final pendingSum = _sumAmount(filteredPending);
    final approvedSum = _sumAmount(filteredApproved);
    final rejectedSum = _sumAmount(filteredRejected);
    final avgDeal = _avgAmount(_filtered(_allProposals));

    final totalDecided = filteredApproved.length + filteredRejected.length;
    final approvalRate = totalDecided == 0
        ? 0.0
        : (filteredApproved.length / totalDecided).clamp(0.0, 1.0);

    final userRole = 'Finance';
    final userName = app.currentUser?['full_name'] ?? 'Finance User';

    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Column(
          children: [
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
                    Expanded(
                      child: Text(
                        'Finance Dashboard',
                        style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _isLoading ? null : _loadFinanceData,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                        ClipOval(
                          child: Image.asset(
                            'assets/images/User_Profile.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userRole,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
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
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: PremiumTheme.teal),
                    )
                  : _loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _loadError!,
                                  textAlign: TextAlign.center,
                                  style: PremiumTheme.bodyMedium.copyWith(
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _loadFinanceData,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: PremiumTheme.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            _buildSidebar(),
                            Expanded(
                              child: CustomScrollbar(
                                controller: _scrollController,
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxWidth: 1280),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Review proposals pending financial approval.',
                                              style: PremiumTheme.bodyMedium
                                                  .copyWith(
                                                color:
                                                    PremiumTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            _buildKpiRow(
                                              pendingCount:
                                                  filteredPending.length,
                                              approvedCount:
                                                  filteredApproved.length,
                                              rejectedCount:
                                                  filteredRejected.length,
                                              pendingSum: pendingSum,
                                              approvedSum: approvedSum,
                                              rejectedSum: rejectedSum,
                                              avgDeal: avgDeal,
                                            ),
                                            const SizedBox(height: 20),
                                            _buildFiltersCard(),
                                            const SizedBox(height: 20),
                                            _buildChartsRow(
                                              pendingSum: pendingSum,
                                              approvedSum: approvedSum,
                                              rejectedSum: rejectedSum,
                                              approvalRate: approvalRate,
                                            ),
                                            const SizedBox(height: 28),
                                            Builder(
                                              builder: (context) {
                                                void openProposal(
                                                    Map<String, dynamic>
                                                        proposal) {
                                                  _selectProposal(proposal);
                                                }

                                                final leftColumn = Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    _buildProposalSection(
                                                      title:
                                                          'Pending Finance Review',
                                                      subtitle:
                                                          'Awaiting finance decision',
                                                      color: Colors.orange,
                                                      icon:
                                                          Icons.hourglass_empty,
                                                      proposals:
                                                          filteredPending,
                                                      onOpen: openProposal,
                                                    ),
                                                    const SizedBox(height: 20),
                                                    _buildProposalSection(
                                                      title:
                                                          'Recently Approved',
                                                      subtitle:
                                                          'Latest finance approvals',
                                                      color: Colors.green,
                                                      icon: Icons.check_circle,
                                                      proposals:
                                                          filteredApproved
                                                              .take(6)
                                                              .toList(),
                                                      onOpen: openProposal,
                                                    ),
                                                    const SizedBox(height: 20),
                                                    _buildProposalSection(
                                                      title:
                                                          'Recently Rejected',
                                                      subtitle:
                                                          'Latest finance rejections',
                                                      color: Colors.red,
                                                      icon: Icons.cancel,
                                                      proposals:
                                                          filteredRejected
                                                              .take(6)
                                                              .toList(),
                                                      onOpen: openProposal,
                                                    ),
                                                  ],
                                                );

                                                if (isDesktop) {
                                                  return Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                          flex: 7,
                                                          child: leftColumn),
                                                      const SizedBox(width: 18),
                                                      Expanded(
                                                        flex: 5,
                                                        child:
                                                            _buildDetailsPanel(),
                                                      ),
                                                    ],
                                                  );
                                                }

                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    leftColumn,
                                                    const SizedBox(height: 20),
                                                    _buildDetailsPanel(),
                                                  ],
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 24),
                                            const Footer(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectProposal(Map<String, dynamic> proposal) {
    final amount = _extractAmount(proposal);
    setState(() {
      _selectedProposal = proposal;
      _selectedProposalId = proposal['id']?.toString();
      _commentController.text = '';
      _priceController.text = amount <= 0 ? '' : amount.toStringAsFixed(2);
    });
  }

  Widget _buildKpiRow({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
    required double pendingSum,
    required double approvedSum,
    required double rejectedSum,
    required double avgDeal,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final kpis = [
          _KpiData(
            label: 'Pending',
            value: pendingCount,
            subValue: _formatMoney(pendingSum),
            icon: Icons.hourglass_top,
            color: Colors.orange,
          ),
          _KpiData(
            label: 'Approved',
            value: approvedCount,
            subValue: _formatMoney(approvedSum),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          _KpiData(
            label: 'Rejected',
            value: rejectedCount,
            subValue: _formatMoney(rejectedSum),
            icon: Icons.cancel,
            color: Colors.red,
          ),
          _KpiData(
            label: 'Avg Deal',
            value: 0,
            subValue: _formatMoney(avgDeal),
            icon: Icons.trending_up,
            color: PremiumTheme.teal,
          ),
        ];

        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final columns = width >= 1150
            ? 4
            : width >= 820
                ? 2
                : 1;
        const spacing = 12.0;
        final usableWidth = (width.isFinite ? width : 1200.0);
        final safeWidth = usableWidth <= 0 ? 1200.0 : usableWidth;
        final itemWidth = columns == 1
            ? safeWidth
            : ((safeWidth - (spacing * (columns - 1))) / columns);
        final safeItemWidth =
            itemWidth.isFinite && itemWidth > 0 ? itemWidth : 280.0;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final kpi in kpis)
              SizedBox(
                width: safeItemWidth,
                child: _buildKpiCard(kpi),
              ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    Gradient gradient;
    switch (data.label) {
      case 'Pending':
        gradient = PremiumTheme.orangeGradient;
        break;
      case 'Approved':
        gradient = PremiumTheme.tealGradient;
        break;
      case 'Rejected':
        gradient = PremiumTheme.redGradient;
        break;
      case 'Avg Deal':
        gradient = PremiumTheme.blueGradient;
        break;
      default:
        gradient = PremiumTheme.blueGradient;
    }

    final title = data.label;
    final hasCount = data.value > 0;

    final valueText =
        hasCount ? data.value.toString() : (data.subValue ?? '--');
    final subtitleText = hasCount
        ? ((data.subValue ?? '').isNotEmpty ? data.subValue : null)
        : (data.label == 'Avg Deal' ? 'Average' : null);

    final linearGradient = gradient is LinearGradient ? gradient : null;
    final glassGradient = linearGradient == null
        ? null
        : LinearGradient(
            colors: linearGradient.colors
                .map((c) => c.withOpacity(0.40))
                .toList(growable: false),
            begin: linearGradient.begin,
            end: linearGradient.end,
            stops: linearGradient.stops,
            tileMode: linearGradient.tileMode,
            transform: linearGradient.transform,
          );

    return SizedBox(
      height: 170,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: glassGradient,
              color:
                  glassGradient == null ? Colors.white.withOpacity(0.06) : null,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withOpacity(0.10), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: PremiumTheme.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Icon(data.icon, color: Colors.white, size: 20),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  valueText,
                  style: PremiumTheme.displayMedium.copyWith(
                    fontSize: 32,
                    color: Colors.white,
                  ),
                ),
                if (subtitleText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: PremiumTheme.labelMedium.copyWith(
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    final dateLabel = _dateRange == null
        ? 'Any date'
        : '${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')} '
            '→ ${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          final search = TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            cursorColor: PremiumTheme.teal,
            decoration: InputDecoration(
              hintText: 'Search proposals or clients…',
              prefixIcon: const Icon(Icons.search),
              prefixIconColor: Colors.white.withOpacity(0.8),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: PremiumTheme.teal.withOpacity(0.7)),
              ),
            ),
          );

          final status = DropdownButtonFormField<String>(
            value: _statusFilter,
            dropdownColor: PremiumTheme.darkBg1,
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All statuses')),
              DropdownMenuItem(value: 'Pending', child: Text('Pending')),
              DropdownMenuItem(value: 'Approved', child: Text('Approved')),
              DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              labelText: 'Status',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: PremiumTheme.teal.withOpacity(0.7)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            iconEnabledColor: Colors.white,
          );

          final date = OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDateRange: _dateRange,
              );
              if (picked == null) return;
              setState(() => _dateRange = picked);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.12)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.date_range),
            label: Text(dateLabel, overflow: TextOverflow.ellipsis),
          );

          final clear = TextButton.icon(
            onPressed: () {
              setState(() {
                _searchController.text = '';
                _statusFilter = 'All';
                _dateRange = null;
              });
            },
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          );

          if (isNarrow) {
            return Column(
              children: [
                search,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 12),
                    Expanded(child: date),
                  ],
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: clear),
              ],
            );
          }

          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width;

          final safeAvailableWidth =
              availableWidth.isFinite && availableWidth > 0
                  ? availableWidth
                  : 1200.0;

          final searchMax = math.min(640.0, safeAvailableWidth).toDouble();
          final searchMin = math.min(320.0, searchMax).toDouble();

          final statusMax = math.min(320.0, safeAvailableWidth).toDouble();
          final statusMin = math.min(220.0, statusMax).toDouble();

          final dateMax = math.min(420.0, safeAvailableWidth).toDouble();
          final dateMin = math.min(240.0, dateMax).toDouble();

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: searchMin,
                  maxWidth: searchMax,
                ),
                child: search,
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: statusMin,
                  maxWidth: statusMax,
                ),
                child: status,
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: dateMin,
                  maxWidth: dateMax,
                ),
                child: date,
              ),
              clear,
            ],
          );
        },
      ),
    );
  }

  Widget _buildChartsRow({
    required double pendingSum,
    required double approvedSum,
    required double rejectedSum,
    required double approvalRate,
  }) {
    final series = _buildWeeklySeries();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final left = _buildWeeklyChartCard(series);
        final right = _buildApprovalRateCard(
            approvalRate, pendingSum, approvedSum, rejectedSum);

        if (isNarrow) {
          return Column(
            children: [
              left,
              const SizedBox(height: 12),
              right,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  List<_ChartPoint> _buildWeeklySeries() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7 * 5));
    final points = <_ChartPoint>[];

    for (int i = 0; i < 6; i++) {
      final weekStart = DateTime(start.year, start.month, start.day)
          .add(Duration(days: 7 * i));
      final weekEnd = weekStart.add(const Duration(days: 7));
      double total = 0;
      int count = 0;

      for (final p in _allProposals) {
        final dt = _extractDate(p);
        if (dt == null) continue;
        if (dt.isBefore(weekStart) || !dt.isBefore(weekEnd)) continue;
        if (!_matchesFilters(p)) continue;
        final amt = _extractAmount(p);
        if (amt > 0) total += amt;
        count += 1;
      }

      final value = total > 0 ? total : count.toDouble();
      final label = '${weekStart.month}/${weekStart.day}';
      points.add(_ChartPoint(label: label, value: value));
    }

    return points;
  }

  Widget _buildWeeklyChartCard(List<_ChartPoint> points) {
    final maxValue = points.isEmpty
        ? 0.0
        : points.map((p) => p.value).reduce((a, b) => math.max(a, b));
    final hasMoney = points.any((p) => p.value >= 1000);
    final subtitle = hasMoney ? 'Weekly volume (sum)' : 'Weekly volume (count)';

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Volume', style: PremiumTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: PremiumTheme.bodyMedium
                .copyWith(color: PremiumTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _BarChartPainter(
                points: points,
                maxValue: maxValue,
                color: PremiumTheme.teal,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalRateCard(
    double approvalRate,
    double pendingSum,
    double approvedSum,
    double rejectedSum,
  ) {
    final pct = (approvalRate * 100).round();
    final totalSum = pendingSum + approvedSum + rejectedSum;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Approval Rate', style: PremiumTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Approved vs rejected (filtered)',
            style: PremiumTheme.bodyMedium
                .copyWith(color: PremiumTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: approvalRate,
                      strokeWidth: 10,
                      color: Colors.green,
                      backgroundColor: Colors.white.withOpacity(0.08),
                    ),
                    Text(
                      '$pct%',
                      style: PremiumTheme.titleMedium.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _metricRow(
                        'Approved', _formatMoney(approvedSum), Colors.green),
                    const SizedBox(height: 6),
                    _metricRow(
                        'Pending', _formatMoney(pendingSum), Colors.orange),
                    const SizedBox(height: 6),
                    _metricRow(
                        'Rejected', _formatMoney(rejectedSum), Colors.red),
                    if (totalSum > 0) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: (approvedSum / totalSum).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: Colors.green,
                        backgroundColor: Colors.white.withOpacity(0.08),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: PremiumTheme.bodyMedium
                .copyWith(color: PremiumTheme.textSecondary),
          ),
        ),
        Text(
          value,
          style: PremiumTheme.bodyMedium.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildProposalSection({
    required List<Map<String, dynamic>> proposals,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required void Function(Map<String, dynamic>) onOpen,
  }) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PremiumTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: PremiumTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withOpacity(0.06),
                ),
                child: Text(
                  proposals.length.toString(),
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (proposals.isEmpty)
            _buildEmptySectionState(color: color)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: proposals.length,
              separatorBuilder: (_, __) => Divider(
                height: 16,
                color: Colors.white.withOpacity(0.08),
              ),
              itemBuilder: (context, index) {
                final proposal = proposals[index];
                return _buildProposalRow(proposal, onOpen);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySectionState({required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(Icons.inbox_outlined, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nothing to review here yet.',
              style: PremiumTheme.bodyMedium.copyWith(
                color: PremiumTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadFinanceData,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalRow(
    Map<String, dynamic> proposal,
    void Function(Map<String, dynamic>) onOpen,
  ) {
    final proposalName = (proposal['title'] ?? 'Untitled').toString();
    final clientName =
        (proposal['client_name'] ?? proposal['client'] ?? 'Unknown').toString();
    final status = (proposal['status'] ?? 'Unknown').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onOpen(proposal),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proposalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: PremiumTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildStatusBadge(status),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => onOpen(proposal),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsPanel() {
    final proposal = _selectedProposal;
    final roleService = RoleService();
    final canEditPricing = roleService.canEditPricing();

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: proposal == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Review Panel', style: PremiumTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Select a proposal from the list to review and approve/reject.',
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: PremiumTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Icon(
                      Icons.rule_folder_outlined,
                      color: Colors.white.withOpacity(0.25),
                      size: 64,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (proposal['title'] ?? 'Proposal').toString(),
                        style: PremiumTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(
                        (proposal['status'] ?? 'Unknown').toString()),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  (proposal['client_name'] ?? proposal['client'] ?? 'Unknown')
                      .toString(),
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: PremiumTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _priceController,
                  enabled: canEditPricing,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: canEditPricing
                        ? Colors.white
                        : Colors.white.withOpacity(0.6),
                  ),
                  cursorColor: PremiumTheme.teal,
                  decoration: InputDecoration(
                    labelText: 'Proposed price',
                    labelStyle:
                        TextStyle(color: Colors.white.withOpacity(0.85)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: PremiumTheme.teal.withOpacity(0.7)),
                    ),
                    hintText: 'Enter price (e.g. 12500.00)',
                    helperText: canEditPricing
                        ? 'Finance can update pricing before approving/rejecting.'
                        : 'You do not have permission to edit pricing.',
                    helperStyle:
                        TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: PremiumTheme.teal,
                  decoration: InputDecoration(
                    labelText: 'Finance comment',
                    labelStyle:
                        TextStyle(color: Colors.white.withOpacity(0.85)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: PremiumTheme.teal.withOpacity(0.7)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedProposalId == null
                            ? null
                            : () => _handleFinanceAction(
                                  proposalId: _selectedProposalId!,
                                  action: 'approve',
                                ),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedProposalId == null
                            ? null
                            : () => _handleFinanceAction(
                                  proposalId: _selectedProposalId!,
                                  action: 'reject',
                                ),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedProposal = null;
                      _selectedProposalId = null;
                      _commentController.text = '';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withOpacity(0.12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear selection'),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending_finance':
        color = Colors.orange;
        text = 'Pending Finance';
        icon = Icons.hourglass_empty;
        break;
      case 'approved':
      case 'finance_approved':
        color = Colors.green;
        text = 'Finance Approved';
        icon = Icons.check_circle;
        break;
      case 'rejected':
      case 'finance_rejected':
        color = Colors.red;
        text = 'Finance Rejected';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showProposalDetails(Map<String, dynamic> proposal) {
    _selectProposal(proposal);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    proposal['title'] ?? 'Proposal Details',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client: ${proposal['client_name'] ?? proposal['client'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          labelText: 'Finance Comment',
                          hintText: 'Add comments about approval/rejection...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectedProposalId == null
                                  ? null
                                  : () => _handleFinanceAction(
                                        proposalId: _selectedProposalId!,
                                        action: 'approve',
                                      ),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectedProposalId == null
                                  ? null
                                  : () => _handleFinanceAction(
                                        proposalId: _selectedProposalId!,
                                        action: 'reject',
                                      ),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}

class _KpiData {
  final String label;
  final int value;
  final String? subValue;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.label,
    required this.value,
    this.subValue,
    required this.icon,
    required this.color,
  });
}

class _ChartPoint {
  final String label;
  final double value;

  const _ChartPoint({
    required this.label,
    required this.value,
  });
}

class _BarChartPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final double maxValue;
  final Color color;

  const _BarChartPainter({
    required this.points,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final barPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;

    final radius = Radius.circular(10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      bgPaint,
    );

    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final paddingTop = 10.0;
    final paddingBottom = 26.0;
    final paddingX = 10.0;
    final chartHeight = math.max(0.0, size.height - paddingTop - paddingBottom);
    final chartWidth = math.max(0.0, size.width - 2 * paddingX);

    for (int i = 1; i <= 3; i++) {
      final y = paddingTop + chartHeight * (i / 3.0);
      canvas.drawLine(
          Offset(paddingX, y), Offset(paddingX + chartWidth, y), gridPaint);
    }

    if (points.isEmpty) return;

    final n = points.length;
    final slot = chartWidth / n;
    final barW = math.max(8.0, slot * 0.45);

    for (int i = 0; i < n; i++) {
      final p = points[i];
      final t = (p.value / safeMax).clamp(0.0, 1.0);
      final h = chartHeight * t;
      final xCenter = paddingX + slot * (i + 0.5);
      final rect = Rect.fromLTWH(
        xCenter - barW / 2,
        paddingTop + (chartHeight - h),
        barW,
        h,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, barPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: p.label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: slot);

      tp.paint(
        canvas,
        Offset(
          xCenter - tp.width / 2,
          paddingTop + chartHeight + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.color != color;
  }
}

*/
}
