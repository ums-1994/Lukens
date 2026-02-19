import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/footer.dart';
import '../creator/blank_document_editor_page.dart';
import 'finance_client_management_page.dart';

/// Simplified Finance dashboard that uses real proposal data from `/api/proposals`.
class FinanceDashboardV2Page extends StatefulWidget {
  const FinanceDashboardV2Page({Key? key}) : super(key: key);

  @override
  State<FinanceDashboardV2Page> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardV2Page> {
  bool _isLoading = false;
  String _statusFilter = 'all'; // all, pending, approved, other
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentTab = 'dashboard'; // dashboard, proposals, clients
  bool _isSidebarCollapsed = false;

  String _financePipelineBucket(String rawStatus) {
    final s = rawStatus.toLowerCase();
    if (_isPricingInProgressStatus(s)) return 'In Pricing';
    if (s.contains('pending review') || s.contains('pending approval')) {
      return 'Pending Review';
    }
    if (s.contains('changes requested') || s.contains('needs changes')) {
      return 'Changes Requested';
    }
    if (s.contains('released') || s.contains('sent to client')) {
      return 'Released';
    }
    if (s.contains('signed') || s.contains('approved')) return 'Signed';
    return '';
  }

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

  List<Map<String, dynamic>> _getFilteredProposals(
    AppState app, {
    bool ignoreStatusFilter = false,
  }) {
    final query = _searchController.text.toLowerCase().trim();
    final List<Map<String, dynamic>> result = [];

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      final s = value.toString().trim();
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }

    final List<Map<String, dynamic>> normalized = [];
    for (final raw in app.proposals) {
      if (raw is! Map) continue;
      final p = raw is Map<String, dynamic>
          ? raw
          : raw.map((k, v) => MapEntry(k.toString(), v));
      normalized.add(p);
    }

    normalized.sort((a, b) {
      final ad = parseDate(a['created_at'] ?? a['createdAt']);
      final bd = parseDate(b['created_at'] ?? b['createdAt']);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    final recent = normalized.take(25).toList();

    for (final p in recent) {
      final statusLower = (p['status'] ?? '').toString().trim().toLowerCase();
      if (statusLower == 'draft') continue;

      final bucket = _financePipelineBucket(statusLower);
      if (bucket.isEmpty) continue;

      final title = (p['title'] ?? '').toString().toLowerCase();
      final client =
          (p['client'] ?? p['client_name'] ?? '').toString().toLowerCase();
      final status = statusLower;

      if (query.isNotEmpty &&
          !(title.contains(query) || client.contains(query))) {
        continue;
      }

      final isPendingReview = status.contains('pending review') ||
          status.contains('pending approval');
      final isReleased =
          status.contains('released') || status.contains('sent to client');
      final isSigned = status.contains('signed') || status.contains('approved');

      if (!ignoreStatusFilter) {
        switch (_statusFilter) {
          case 'pending_review':
            if (!isPendingReview) {
              continue;
            }
            break;
          case 'in_pricing':
            if (!_isPricingInProgressStatus(status)) {
              continue;
            }
            break;
          case 'released':
            if (!isReleased) {
              continue;
            }
            break;
          case 'signed':
            if (!isSigned) {
              continue;
            }
            break;
          case 'all':
          default:
            break;
        }
      }

      result.add(p);
    }

    return result;
  }

  bool _isPricingInProgressStatus(String raw) {
    final s = raw.toLowerCase();
    return s.contains('pricing in progress') || s.contains('in pricing');
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

  String _formatPercent(double value) {
    final pct = (value * 100).clamp(0, 999);
    if (pct.isNaN || pct.isInfinite) return '--';
    return '${pct.toStringAsFixed(0)}%';
  }

  double _computeAvgCycleTimeDays(List<Map<String, dynamic>> proposals) {
    double sumDays = 0;
    int n = 0;

    for (final p in proposals) {
      final createdRaw = p['created_at'] ?? p['createdAt'];
      final updatedRaw = p['updated_at'] ?? p['updatedAt'];

      if (createdRaw == null || updatedRaw == null) continue;
      final created = DateTime.tryParse(createdRaw.toString());
      final updated = DateTime.tryParse(updatedRaw.toString());
      if (created == null || updated == null) continue;

      final diff = updated.difference(created);
      final days = diff.inMinutes / (60 * 24);
      if (days.isNaN || days.isInfinite || days < 0) continue;

      sumDays += days;
      n += 1;
    }

    if (n == 0) return 0;
    return sumDays / n;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dashboardProposals =
        _getFilteredProposals(app, ignoreStatusFilter: true);
    final proposalsTabProposals = _getFilteredProposals(app);
    final proposals =
        _currentTab == 'dashboard' ? dashboardProposals : proposalsTabProposals;

    final pricingCount = proposals
        .where(
            (p) => _isPricingInProgressStatus((p['status'] ?? '').toString()))
        .length;
    final approvedCount = proposals
        .where((p) => ((p['status'] ?? '')
                .toString()
                .toLowerCase()
                .contains('approved') ||
            (p['status'] ?? '').toString().toLowerCase().contains('signed')))
        .length;

    final sentToClientCount = proposals
        .where((p) => (p['status'] ?? '')
            .toString()
            .toLowerCase()
            .contains('sent to client'))
        .length;

    double totalAmount = 0;
    for (final p in proposals) {
      totalAmount += _extractAmount(p);
    }

    final requiresAttention = proposals
        .where(
            (p) => _isPricingInProgressStatus((p['status'] ?? '').toString()))
        .toList();

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
                      child: _currentTab == 'clients'
                          ? const FinanceClientManagementPage()
                          : CustomScrollbar(
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
                                      _buildBreadcrumb(),
                                      const SizedBox(height: 16),
                                      if (_currentTab == 'dashboard') ...[
                                        _buildDashboardTitle(),
                                        const SizedBox(height: 16),
                                        _buildSummaryRow(
                                          proposals: dashboardProposals,
                                          pendingCount: pricingCount,
                                          approvedCount: approvedCount,
                                          sentToClientCount: sentToClientCount,
                                          totalAmount: totalAmount,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildDashboardPanels(),
                                        const SizedBox(height: 12),
                                        _buildRequiresAttention(
                                            requiresAttention),
                                        const SizedBox(height: 24),
                                        const Footer(),
                                      ] else ...[
                                        _buildFilters(),
                                        const SizedBox(height: 16),
                                        _buildTable(proposalsTabProposals),
                                        const SizedBox(height: 24),
                                        const Footer(),
                                      ],
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

  Widget _buildBreadcrumb() {
    final label = _currentTab == 'dashboard'
        ? 'Dashboard'
        : (_currentTab == 'clients' ? 'Client Management' : 'Proposals');
    return Row(
      children: [
        Text(
          'Finance',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        ),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDashboardTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finance Dashboard',
          style: PremiumTheme.titleLarge.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          'Overview of proposal pipeline and financial performance',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildDashboardPanels() {
    Widget panel(String title, String subtitle) {
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
            Text(title, style: PremiumTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: title == 'Proposal Pipeline'
                  ? _buildPipelineChart()
                  : _buildRevenueForecastChart(),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final left = panel('Proposal Pipeline', 'Current proposals by status');
        final right = panel('Revenue Forecast', 'Projected vs actual revenue');

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

  Widget _buildPipelineChart() {
    final app = context.read<AppState>();
    final proposals = _getFilteredProposals(app, ignoreStatusFilter: true);

    int inPricing = 0;
    int pendingReview = 0;
    int changesRequested = 0;
    int released = 0;
    int signed = 0;

    for (final p in proposals) {
      final bucket = _financePipelineBucket((p['status'] ?? '').toString());
      switch (bucket) {
        case 'In Pricing':
          inPricing += 1;
          break;
        case 'Pending Review':
          pendingReview += 1;
          break;
        case 'Changes Requested':
          changesRequested += 1;
          break;
        case 'Released':
          released += 1;
          break;
        case 'Signed':
          signed += 1;
          break;
        default:
          break;
      }
    }

    final labels = <String>[
      'In Pricing',
      'Pending Review',
      'Changes\nRequested',
      'Released',
      'Signed',
    ];
    final ys = <double>[
      inPricing.toDouble(),
      pendingReview.toDouble(),
      changesRequested.toDouble(),
      released.toDouble(),
      signed.toDouble(),
    ];
    final colors = <Color>[
      Colors.orange,
      const Color(0xFF0F9D58),
      const Color(0xFF34A853),
      const Color(0xFFEA4335),
      const Color(0xFF4285F4),
    ];

    final maxY = (ys.fold<double>(0, (a, b) => a > b ? a : b)).clamp(1, 999);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          groupsSpace: 18,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              tooltipMargin: 12,
              getTooltipColor: (group) => Colors.white.withOpacity(0.92),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = groupIndex >= 0 && groupIndex < labels.length
                    ? labels[groupIndex]
                    : '';
                final count = rod.toY.round();
                return BarTooltipItem(
                  '$label\ncount : $count',
                  PremiumTheme.bodyMedium.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: PremiumTheme.labelMedium.copyWith(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: PremiumTheme.labelMedium.copyWith(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(labels.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: ys[i],
                  color: colors[i],
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRevenueForecastChart() {
    final app = context.read<AppState>();
    final proposals = app.proposals
        .whereType<Map>()
        .map((raw) => raw is Map<String, dynamic>
            ? raw
            : raw.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    double pipelineValue = 0;
    for (final p in proposals) {
      pipelineValue += _extractAmount(p);
    }

    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i), 1);
      return DateFormat('MMM').format(d);
    });

    final base = pipelineValue <= 0 ? 1000000.0 : pipelineValue;
    final projected = List.generate(6, (i) => base * (0.55 + i * 0.09));
    final actual = List.generate(
      6,
      (i) => base * (0.52 + i * 0.085) * (i < 4 ? 1.0 : 0.92),
    );

    double maxY = 0;
    for (final v in [...projected, ...actual]) {
      if (v > maxY) maxY = v;
    }

    String fmt(double v) {
      if (v >= 1000000) return 'R${(v / 1000000).toStringAsFixed(1)}M';
      if (v >= 1000) return 'R${(v / 1000).toStringAsFixed(0)}K';
      return 'R${v.toStringAsFixed(0)}';
    }

    final teal = PremiumTheme.teal;
    final blue = PremiumTheme.info;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: 5,
          minY: 0,
          maxY: maxY * 1.1,
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipMargin: 12,
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              getTooltipColor: (touchedSpot) => Colors.white.withOpacity(0.96),
              getTooltipItems: (touchedSpots) {
                if (touchedSpots.isEmpty) return [];

                final idx = touchedSpots.first.x.round().clamp(0, 5);
                final month =
                    idx >= 0 && idx < months.length ? months[idx] : '';
                final proj = projected[idx];
                final act = actual[idx];

                final headerStyle = PremiumTheme.bodyMedium.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                );
                final bodyStyle = PremiumTheme.bodyMedium.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                );

                return List.generate(touchedSpots.length, (i) {
                  final spot = touchedSpots[i];
                  if (spot.barIndex != 0) {
                    return const LineTooltipItem('', TextStyle());
                  }

                  return LineTooltipItem(
                    '$month\n',
                    headerStyle,
                    children: [
                      TextSpan(
                        text: 'Projected : ${_formatCurrency(proj)}\n',
                        style: bodyStyle.copyWith(color: teal),
                      ),
                      TextSpan(
                        text: 'Actual : ${_formatCurrency(act)}',
                        style: bodyStyle.copyWith(color: blue),
                      ),
                    ],
                  );
                });
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withOpacity(0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return Text(
                      'R0',
                      style: PremiumTheme.labelMedium.copyWith(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    );
                  }
                  if (value == meta.max) {
                    return Text(
                      fmt(value),
                      style: PremiumTheme.labelMedium.copyWith(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= months.length)
                    return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      months[i],
                      style: PremiumTheme.labelMedium.copyWith(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                6,
                (i) => FlSpot(i.toDouble(), projected[i]),
              ),
              isCurved: true,
              color: teal,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: teal.withOpacity(0.12),
              ),
            ),
            LineChartBarData(
              spots: List.generate(
                6,
                (i) => FlSpot(i.toDouble(), actual[i]),
              ),
              isCurved: true,
              color: blue,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: blue.withOpacity(0.08),
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
    Widget navItem({
      required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap,
      int? badge,
    }) {
      final color = active ? PremiumTheme.teal : Colors.white70;
      return Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarCollapsed ? 10 : 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: active
                  ? PremiumTheme.teal.withOpacity(0.14)
                  : Colors.transparent,
              border: Border.all(
                color: active
                    ? PremiumTheme.teal.withOpacity(0.6)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              mainAxisAlignment: _isSidebarCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 18, color: color),
                    if (badge != null && _isSidebarCollapsed)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Text(
                            badge > 99 ? '99+' : badge.toString(),
                            style: PremiumTheme.labelMedium.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge.toString(),
                        style: PremiumTheme.labelMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final app = context.watch<AppState>();
    final pendingBadge = app.proposals
        .where((p) =>
            (p is Map) &&
            _isPricingInProgressStatus((p['status'] ?? '').toString()))
        .length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _isSidebarCollapsed ? 76 : 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.2),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          right: BorderSide(
            color: PremiumTheme.glassWhiteBorder,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(_isSidebarCollapsed ? 10 : 16, 18,
            _isSidebarCollapsed ? 10 : 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PremiumTheme.teal.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: PremiumTheme.teal.withOpacity(0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: PremiumTheme.teal,
                    size: 18,
                  ),
                ),
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finance Portal',
                          style: PremiumTheme.bodyLarge
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          'Navigation',
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                ],
                IconButton(
                  tooltip: _isSidebarCollapsed
                      ? 'Expand sidebar'
                      : 'Collapse sidebar',
                  onPressed: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                  icon: Icon(
                    _isSidebarCollapsed
                        ? Icons.keyboard_double_arrow_right
                        : Icons.keyboard_double_arrow_left,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            navItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              active: _currentTab == 'dashboard',
              onTap: () => setState(() => _currentTab = 'dashboard'),
            ),
            const SizedBox(height: 10),
            navItem(
              icon: Icons.description_outlined,
              label: 'Proposals',
              badge: pendingBadge > 0 ? pendingBadge : null,
              active: _currentTab == 'proposals',
              onTap: () => setState(() => _currentTab = 'proposals'),
            ),
            const SizedBox(height: 10),
            navItem(
              icon: Icons.business_outlined,
              label: 'Client Management',
              active: _currentTab == 'clients',
              onTap: () => setState(() => _currentTab = 'clients'),
            ),
            const SizedBox(height: 10),
            navItem(
              icon: Icons.analytics_outlined,
              label: 'Analytics',
              active: false,
              onTap: () => Navigator.pushNamed(context, '/analytics'),
            ),
            const SizedBox(height: 10),
            navItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              active: false,
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisAlignment: _isSidebarCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.person, color: Colors.white70),
                  ),
                  if (!_isSidebarCollapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (app.currentUser?['full_name'] ??
                                app.currentUser?['first_name'] ??
                                app.currentUser?['email'] ??
                                'Finance User')
                            .toString(),
                        style: PremiumTheme.bodyMedium
                            .copyWith(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: () {
                      app.logout();
                      AuthService.logout();
                      Navigator.pushNamed(context, '/login');
                    },
                    icon: const Icon(Icons.logout, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required List<Map<String, dynamic>> proposals,
    required int pendingCount,
    required int approvedCount,
    required int sentToClientCount,
    required double totalAmount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 900;
        final avgCycle = _computeAvgCycleTimeDays(proposals);
        final proposalsCount = proposals.length;

        final denom = (approvedCount + pendingCount);
        final approvalRate = denom <= 0 ? 0.0 : (approvedCount / denom);

        if (isNarrow) {
          return Column(
            children: [
              _buildSummaryCard(
                label: 'Pipeline Value',
                value: _formatCurrency(totalAmount),
                subtitle: '$proposalsCount proposals',
                icon: Icons.attach_money,
                color: PremiumTheme.info,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                label: 'Pending Reviews',
                value: pendingCount.toString(),
                subtitle: 'Awaiting finance action',
                icon: Icons.hourglass_empty,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                label: 'Avg. Cycle Time',
                value: avgCycle <= 0
                    ? '--'
                    : '${avgCycle.toStringAsFixed(1)} days',
                subtitle: 'Created to last update',
                icon: Icons.timelapse,
                color: PremiumTheme.purple,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                label: 'Approval Rate',
                value: _formatPercent(approvalRate),
                subtitle: '$approvedCount of $denom completed',
                icon: Icons.verified,
                color: PremiumTheme.teal,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                label: 'Pipeline Value',
                value: _formatCurrency(totalAmount),
                subtitle: '$proposalsCount proposals',
                icon: Icons.attach_money,
                color: PremiumTheme.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'Pending Reviews',
                value: pendingCount.toString(),
                subtitle: 'Awaiting finance action',
                icon: Icons.hourglass_empty,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'Avg. Cycle Time',
                value: avgCycle <= 0
                    ? '--'
                    : '${avgCycle.toStringAsFixed(1)} days',
                subtitle: 'Created to last update',
                icon: Icons.timelapse,
                color: PremiumTheme.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                label: 'Approval Rate',
                value: _formatPercent(approvalRate),
                subtitle: '$approvedCount of $denom completed',
                icon: Icons.verified,
                color: PremiumTheme.teal,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequiresAttention(List<Map<String, dynamic>> proposals) {
    Widget initialsCircle(String value) {
      final trimmed = value.trim();
      final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
      final chars =
          parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
      final label = chars.isNotEmpty ? chars : 'P';

      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: PremiumTheme.teal.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: PremiumTheme.labelMedium.copyWith(color: Colors.white),
        ),
      );
    }

    Widget item(Map<String, dynamic> p) {
      final title = (p['title'] ?? 'Untitled Proposal').toString();
      final client = (p['client_name'] ?? p['client'] ?? '').toString();
      final status = (p['status'] ?? '').toString();
      final amount = _extractAmount(p);
      final proposalId = p['id']?.toString();

      final content = Row(
        children: [
          initialsCircle(title),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  client.isEmpty ? '—' : client,
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatCurrency(amount),
            style: PremiumTheme.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          _buildStatusChip(status.isEmpty ? 'In Pricing' : status),
        ],
      );

      final child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: content,
      );

      if (proposalId == null || proposalId.isEmpty) return child;

      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlankDocumentEditorPage(
                proposalId: proposalId,
                proposalTitle: title,
                readOnly: false,
              ),
            ),
          );
        },
        child: child,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Requires Attention', style: PremiumTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Proposals awaiting finance review or action',
                      style: PremiumTheme.bodyMedium
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentTab = 'proposals';
                    _statusFilter = 'pending';
                  });
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View all'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (proposals.isEmpty)
            Text(
              'No proposals currently in pricing.',
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < proposals.take(5).length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      child: item(proposals[i]),
                    ),
                    if (i != proposals.take(5).length - 1)
                      Divider(
                        height: 1,
                        color: Colors.white.withOpacity(0.08),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
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
                hintText: 'Search proposals or clients…',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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
                labelStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                DropdownMenuItem(
                    value: 'pending_review', child: Text('Pending Review')),
                DropdownMenuItem(
                    value: 'in_pricing', child: Text('In Pricing')),
                DropdownMenuItem(value: 'released', child: Text('Released')),
                DropdownMenuItem(value: 'signed', child: Text('Signed')),
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

    final proposalId = p['id']?.toString();

    final row = Padding(
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

    if (proposalId == null || proposalId.isEmpty) return row;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlankDocumentEditorPage(
              proposalId: proposalId,
              proposalTitle: title,
              readOnly: false,
            ),
          ),
        );
      },
      child: row,
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
