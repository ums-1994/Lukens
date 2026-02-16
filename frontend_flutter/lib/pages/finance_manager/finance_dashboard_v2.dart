import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/footer.dart';
import '../creator/client_management_page.dart';

/// Simplified Finance dashboard that uses real proposal data from `/api/proposals`.
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
  String _currentTab = 'proposals'; // 'proposals' or 'clients'

  bool _isMetricsLoading = false;
  String? _metricsError;
  Map<String, dynamic>? _financeMetrics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Widget _buildNeedsAttention(List<Map<String, dynamic>> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: PremiumTheme.darkBg2.withValues(alpha: 0.85),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Needs Attention',
                  style: PremiumTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'High value proposals stuck in finance queue',
            style: PremiumTheme.bodyMedium
                .copyWith(color: PremiumTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final it in items.take(6)) ...[
            _attentionRow(it),
            if (it != items.take(6).last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _attentionRow(Map<String, dynamic> it) {
    final title = (it['title'] ?? 'Untitled').toString();
    final client = (it['client_name'] ?? it['client'] ?? '').toString();
    final days = (it['days_in_stage'] is num)
        ? (it['days_in_stage'] as num).toInt()
        : int.tryParse((it['days_in_stage'] ?? '').toString());
    final budget = (it['budget'] is num)
        ? (it['budget'] as num).toDouble()
        : double.tryParse((it['budget'] ?? '').toString()) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTheme.bodyMedium
                      .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  client.isEmpty
                      ? (days != null ? '$days days in queue' : 'In queue')
                      : (days != null ? '$client • $days days in queue' : client),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTheme.bodySmall
                      .copyWith(color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatCurrency(budget),
            style: PremiumTheme.bodyMedium
                .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    if (!mounted) return;

    final app = context.read<AppState>();

    // Sync token from AuthService if needed
    if (app.authToken == null && AuthService.token != null) {
      app.authToken = AuthService.token;
      app.currentUser = AuthService.currentUser;
    }

    if (app.authToken == null && AuthService.token == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Future.wait([
        app.fetchProposals(),
        app.fetchDashboard(),
      ]);

      await _fetchFinanceMetrics(app);
    } catch (e) {
      debugPrint('Finance dashboard load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFinanceMetrics(AppState app) async {
    if (_isMetricsLoading) return;
    final token = app.authToken ?? AuthService.token;
    if (token == null || token.isEmpty) return;

    setState(() {
      _isMetricsLoading = true;
      _metricsError = null;
    });

    try {
      final r = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/finance/metrics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (r.statusCode >= 200 && r.statusCode < 300) {
        final decoded = jsonDecode(r.body);
        if (decoded is Map) {
          setState(() => _financeMetrics = decoded.cast<String, dynamic>());
        } else {
          setState(() => _metricsError = 'Unexpected response format');
        }
      } else {
        setState(() => _metricsError = 'Failed to load finance metrics (${r.statusCode})');
      }
    } catch (e) {
      setState(() => _metricsError = 'Failed to load finance metrics');
    } finally {
      if (mounted) {
        setState(() => _isMetricsLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredProposals(AppState app) {
    final query = _searchController.text.toLowerCase().trim();
    final List<Map<String, dynamic>> result = [];

    for (final raw in app.proposals) {
      if (raw is! Map) continue;
      final Map<String, dynamic> p = raw is Map<String, dynamic>
          ? raw
          : raw.map((k, v) => MapEntry(k.toString(), v));

      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client_name'] ?? p['client'] ?? '').toString().toLowerCase();
      final status = (p['status'] ?? '').toString().toLowerCase();

      if (query.isNotEmpty &&
          !(title.contains(query) || client.contains(query))) {
        continue;
      }

      switch (_statusFilter) {
        case 'pending':
          if (!(status.contains('pending') || status.contains('review'))) {
            continue;
          }
          break;
        case 'approved':
          if (!(status.contains('approved') ||
              status.contains('signed') ||
              status.contains('released'))) {
            continue;
          }
          break;
        case 'other':
          if (status.contains('pending') ||
              status.contains('review') ||
              status.contains('approved') ||
              status.contains('signed') ||
              status.contains('released')) {
            continue;
          }
          break;
        case 'all':
        default:
          break;
      }

      result.add(p);
    }

    return result;
  }

  double _extractAmount(Map<String, dynamic> p) {
    const keys = ['budget', 'amount', 'total', 'value', 'price'];
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
    final proposals = _getFilteredProposals(app);

    final queue = (_financeMetrics?['queue'] as Map?)?.cast<String, dynamic>();
    final decisions =
        (_financeMetrics?['decisions'] as Map?)?.cast<String, dynamic>();
    final approvedDecision =
        (decisions?['approved'] as Map?)?.cast<String, dynamic>();
    final rejectedDecision =
        (decisions?['rejected'] as Map?)?.cast<String, dynamic>();

    final attentionRaw = _financeMetrics?['attention'];
    final List<Map<String, dynamic>> attention = attentionRaw is List
        ? attentionRaw
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final queueItemsRaw = (_financeMetrics?['items'] as Map?)?['queue'];
    final List<Map<String, dynamic>> queueItems = queueItemsRaw is List
        ? queueItemsRaw
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final totalCount = proposals.length;
    final pendingCount = proposals
        .where((p) => ((p['status'] ?? '')
                .toString()
                .toLowerCase()
                .contains('pending') ||
            (p['status'] ?? '').toString().toLowerCase().contains('review')))
        .length;
    final approvedCount = proposals
        .where((p) => ((p['status'] ?? '')
                .toString()
                .toLowerCase()
                .contains('approved') ||
            (p['status'] ?? '').toString().toLowerCase().contains('signed')))
        .length;

    double totalAmount = 0;
    for (final p in proposals) {
      totalAmount += _extractAmount(p);
    }

    final queueCount = (queue?['count'] is num)
        ? (queue!['count'] as num).toInt()
        : null;
    final queueValue = (queue?['value'] is num)
        ? (queue!['value'] as num).toDouble()
        : null;
    final financeApprovedCount = (approvedDecision?['count'] is num)
        ? (approvedDecision!['count'] as num).toInt()
        : null;
    final financeRejectedCount = (rejectedDecision?['count'] is num)
        ? (rejectedDecision!['count'] as num).toInt()
        : null;

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    final tableRows = queueItems.isNotEmpty ? queueItems : proposals;

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
                                _buildTabSelector(),
                                const SizedBox(height: 16),
                                if (_isMetricsLoading)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: LinearProgressIndicator(
                                      minHeight: 3,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.08),
                                      valueColor:
                                          AlwaysStoppedAnimation(PremiumTheme.teal),
                                    ),
                                  ),
                                if (_metricsError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              Colors.red.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Colors.redAccent, size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _metricsError!,
                                              style: PremiumTheme.bodyMedium.copyWith(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: _isMetricsLoading
                                                ? null
                                                : () => _fetchFinanceMetrics(app),
                                            child: Text(
                                              'Retry',
                                              style: PremiumTheme.bodyMedium.copyWith(
                                                color: PremiumTheme.teal,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_currentTab == 'proposals') ...[
                                  _buildSummaryRow(
                                    totalCount: queueCount ?? totalCount,
                                    pendingCount: financeRejectedCount ?? pendingCount,
                                    approvedCount: financeApprovedCount ?? approvedCount,
                                    totalAmount: queueValue ?? totalAmount,
                                  ),
                                  const SizedBox(height: 16),
                                  if (attention.isNotEmpty) ...[
                                    _buildNeedsAttention(attention),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildFilters(),
                                  const SizedBox(height: 16),
                                  _buildTable(tableRows),
                                ] else ...[
                                  Expanded(
                                    child: ClientManagementPage(),
                                  ),
                                ],
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
            Colors.black.withValues(alpha: 0.3),
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
    return Container(
      width: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.2),
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
        children: [
          const SizedBox(height: 16),
          Icon(Icons.account_balance, color: Colors.white),
          const SizedBox(height: 8),
          Icon(Icons.receipt_long, color: Colors.white70),
          const SizedBox(height: 8),
          Icon(Icons.trending_up, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: PremiumTheme.darkBg2.withValues(alpha: 0.85),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              'Proposals',
              Icons.description,
              _currentTab == 'proposals',
              () => setState(() => _currentTab = 'proposals'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTabButton(
              'Client Management',
              Icons.business,
              _currentTab == 'clients',
              () => setState(() => _currentTab = 'clients'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
      String label, IconData icon, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive
              ? PremiumTheme.teal.withValues(alpha: 0.2)
              : Colors.transparent,
          border:
              isActive ? Border.all(color: PremiumTheme.teal, width: 1) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? PremiumTheme.teal : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: PremiumTheme.bodyMedium.copyWith(
                color: isActive ? PremiumTheme.teal : Colors.white70,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
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
        label: 'Finance Queue',
        value: totalCount.toString(),
        subtitle: 'Approved, not yet released/signed',
        icon: Icons.folder_open,
        color: PremiumTheme.teal,
      ),
      _buildSummaryCard(
        label: 'Rejected',
        value: pendingCount.toString(),
        subtitle: 'Rejected by finance',
        icon: Icons.hourglass_empty,
        color: Colors.orange,
      ),
      _buildSummaryCard(
        label: 'Approved',
        value: approvedCount.toString(),
        subtitle: 'Approved by finance',
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      _buildSummaryCard(
        label: 'Queue Value',
        value: _formatCurrency(totalAmount),
        subtitle: 'Total value awaiting finance',
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
        color: PremiumTheme.darkBg2.withValues(alpha: 0.85),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
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
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: PremiumTheme.darkBg2.withValues(alpha: 0.85),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                hintText: 'Search proposals or clientsâ€¦',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [searchField]),
                const SizedBox(height: 12),
                Row(children: [statusDropdown]),
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
              clearButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> proposals) {
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
                color: Colors.white.withValues(alpha: 0.8),
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
        color: PremiumTheme.darkBg2.withValues(alpha: 0.9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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

  Widget _buildTableRow(Map<String, dynamic> p) {
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
      bg = Colors.orange.withValues(alpha: 0.15);
      fg = Colors.orange;
    } else if (lower.contains('approved') ||
        lower.contains('signed') ||
        lower.contains('released')) {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.green;
    } else {
      bg = Colors.white.withValues(alpha: 0.08);
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
}
