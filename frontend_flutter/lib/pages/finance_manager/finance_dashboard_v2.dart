import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/footer.dart';
import '../creator/blank_document_editor_page.dart';
import 'finance_client_management_page.dart';

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

  bool _handledInitialOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final roleService = context.read<RoleService>();
      if (!roleService.isFinance()) {
        roleService.switchRole(UserRole.finance);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_handledInitialOpen) return;
    _handledInitialOpen = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final dynamic openIdRaw = args['openProposalId'] ?? args['proposalId'];
    final String? openProposalId =
        openIdRaw?.toString().trim().isNotEmpty == true
            ? openIdRaw.toString().trim()
            : null;

    if (openProposalId == null) return;

    final Map<String, dynamic>? aiGeneratedSections =
        (args['aiGeneratedSections'] is Map)
            ? Map<String, dynamic>.from(args['aiGeneratedSections'] as Map)
            : null;
    final String? initialTitle = args['initialTitle']?.toString();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlankDocumentEditorPage(
            proposalId: openProposalId,
            proposalTitle: args['proposalTitle']?.toString(),
            initialTitle: initialTitle,
            aiGeneratedSections: aiGeneratedSections,
            readOnly: false,
          ),
        ),
      );
    });
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
    } catch (e) {
      debugPrint('Finance dashboard load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

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
                      child: _currentTab == 'proposals'
                          ? CustomScrollbar(
                              controller: _scrollController,
                              child: RefreshIndicator(
                                onRefresh: _loadData,
                                color: PremiumTheme.teal,
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
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
                            )
                          : const FinanceClientManagementPage(),
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
    Widget navIcon({
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
      String? tooltip,
    }) {
      final child = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: active
                ? PremiumTheme.teal.withOpacity(0.18)
                : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: active
                  ? PremiumTheme.teal.withOpacity(0.9)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Icon(
            icon,
            color: active ? PremiumTheme.teal : Colors.white70,
          ),
        ),
      );

      if (tooltip == null) return child;
      return Tooltip(message: tooltip, child: child);
    }

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
        children: [
          const SizedBox(height: 16),
          navIcon(
            icon: Icons.description,
            active: _currentTab == 'proposals',
            tooltip: 'Proposals',
            onTap: () => setState(() => _currentTab = 'proposals'),
          ),
          const SizedBox(height: 10),
          navIcon(
            icon: Icons.business,
            active: _currentTab == 'clients',
            tooltip: 'Client Management',
            onTap: () => setState(() => _currentTab = 'clients'),
          ),
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
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
