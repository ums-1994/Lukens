import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/role_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/footer.dart';
import 'finance_client_management_page.dart';

class FinanceAnalyticsPage extends StatefulWidget {
  const FinanceAnalyticsPage({super.key});

  @override
  State<FinanceAnalyticsPage> createState() => _FinanceAnalyticsPageState();
}

class _FinanceAnalyticsPageState extends State<FinanceAnalyticsPage> {
  bool _isSidebarCollapsed = false;
  final ScrollController _scrollController = ScrollController();
  String _currentTab = 'analytics';
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: 'R', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final roleService = context.read<RoleService>();
      if (!roleService.isFinance()) {
        roleService.switchRole(UserRole.finance);
      }
      context.read<AppState>().fetchProposals();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isDraft(String status) => status.trim().toLowerCase() == 'draft';

  DateTime? _parseDate(dynamic value) {
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

  double _extractAmount(Map<String, dynamic> p) {
    final keys = ['budget', 'amount', 'value', 'total', 'total_amount'];
    for (final k in keys) {
      final v = p[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
        final d = double.tryParse(cleaned);
        if (d != null) return d;
      }
    }
    return 0;
  }

  List<Map<String, dynamic>> _financeProposals(AppState app) {
    final List<Map<String, dynamic>> normalized = [];
    for (final raw in app.proposals) {
      if (raw is! Map) continue;
      final p = raw is Map<String, dynamic>
          ? raw
          : raw.map((k, v) => MapEntry(k.toString(), v));
      final status = (p['status'] ?? '').toString();
      if (_isDraft(status)) continue;
      normalized.add(p);
    }

    normalized.sort((a, b) {
      final ad = _parseDate(a['created_at'] ?? a['createdAt']);
      final bd = _parseDate(b['created_at'] ?? b['createdAt']);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return normalized;
  }

  DateTime _quarterStart(DateTime now) {
    final quarter = ((now.month - 1) ~/ 3) + 1;
    final startMonth = (quarter - 1) * 3 + 1;
    return DateTime(now.year, startMonth, 1);
  }

  Widget _kpiCard({
    required String label,
    required String value,
    String? subtitle,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: PremiumTheme.labelMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
              if (icon != null) Icon(icon, size: 18, color: Colors.white60),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: PremiumTheme.displayMedium.copyWith(
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: PremiumTheme.labelMedium.copyWith(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel(
      {required String title,
      required String subtitle,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PremiumTheme.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: PremiumTheme.labelMedium.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildRevenueProjectionsChart() {
    final months = ['Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb'];
    final projected = [1.9, 2.2, 2.9, 2.4, 3.2, 3.8];
    final actual = [1.7, 2.1, 2.85, 2.3, 3.1, 3.0];

    final maxY = math.max(projected.reduce(math.max), actual.reduce(math.max));
    final gridColor = Colors.white.withOpacity(0.08);

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (months.length - 1).toDouble(),
          minY: 0,
          maxY: maxY + 0.4,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 0.9,
            verticalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: gridColor, strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
                FlLine(color: gridColor, strokeWidth: 1),
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
                reservedSize: 44,
                interval: 0.9,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'R${value.toStringAsFixed(1)}M',
                    style: PremiumTheme.labelMedium
                        .copyWith(color: Colors.white54),
                  );
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
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      months[i],
                      style: PremiumTheme.labelMedium
                          .copyWith(color: Colors.white54),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.black.withOpacity(0.86),
              getTooltipItems: (touchedSpots) {
                if (touchedSpots.isEmpty) return [];
                final x = touchedSpots.first.x.round();
                final month = (x >= 0 && x < months.length) ? months[x] : '';
                final proj = projected[x];
                final act = actual[x];
                return [
                  LineTooltipItem(
                    '$month\n',
                    PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                  ),
                  LineTooltipItem(
                    'Projected: R${proj.toStringAsFixed(1)}M\n',
                    PremiumTheme.bodyMedium.copyWith(color: PremiumTheme.teal),
                  ),
                  LineTooltipItem(
                    'Actual: R${act.toStringAsFixed(1)}M',
                    PremiumTheme.bodyMedium
                        .copyWith(color: Colors.lightBlueAccent),
                  ),
                ];
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                months.length,
                (i) => FlSpot(i.toDouble(), projected[i]),
              ),
              isCurved: true,
              barWidth: 3,
              color: PremiumTheme.teal,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3.6,
                  color: PremiumTheme.teal,
                  strokeWidth: 2,
                  strokeColor: Colors.black.withOpacity(0.35),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: PremiumTheme.teal.withOpacity(0.12),
              ),
            ),
            LineChartBarData(
              spots: List.generate(
                months.length,
                (i) => FlSpot(i.toDouble(), actual[i]),
              ),
              isCurved: true,
              barWidth: 2,
              color: Colors.lightBlueAccent,
              dashArray: [6, 6],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleTimeByStageChart(Map<String, double> stageDays) {
    final entries = stageDays.entries.toList();
    final maxY =
        entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce(math.max);
    final barColor = PremiumTheme.teal;

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: maxY + 0.6,
          alignment: BarChartAlignment.spaceBetween,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 0.75,
            verticalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.white.withOpacity(0.08), strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
                FlLine(color: Colors.white.withOpacity(0.08), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: 0.75,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toStringAsFixed(2)} days',
                    style: PremiumTheme.labelMedium
                        .copyWith(color: Colors.white54),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(entries.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  color: barColor,
                  width: 14,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.black.withOpacity(0.86),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = entries[group.x.toInt()].key;
                return BarTooltipItem(
                  '$label\n${rod.toY.toStringAsFixed(2)} days',
                  PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalFunnel({
    required int submitted,
    required int inReview,
    required int approved,
    required int released,
  }) {
    final maxVal =
        [submitted, inReview, approved, released].fold<int>(0, math.max);
    final items = [
      ('Submitted', submitted, PremiumTheme.teal),
      ('In Review', inReview, Colors.tealAccent.shade400),
      ('Approved', approved, Colors.lightBlueAccent),
      ('Released', released, Colors.blueAccent),
    ];

    Widget row(String label, int value, Color color) {
      final pct = maxVal <= 0 ? 0.0 : (value / maxVal);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 14,
                  color: Colors.white.withOpacity(0.08),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(color: color.withOpacity(0.8)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              child: Text(
                '$value (${(pct * 100).round()}%)',
                textAlign: TextAlign.right,
                style: PremiumTheme.labelMedium.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final it in items) row(it.$1, it.$2, it.$3),
      ],
    );
  }

  Widget _buildHeader(AppState app, bool isMobile) {
    final userName = app.currentUser?['full_name'] ??
        app.currentUser?['first_name'] ??
        app.currentUser?['email'] ??
        'Finance User';

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Financial Analytics',
              style: PremiumTheme.titleLarge.copyWith(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
    final pendingBadge = _financeProposals(app)
        .where((p) =>
            (p['status'] ?? '').toString().toLowerCase().contains('pricing'))
        .length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _isSidebarCollapsed ? 76 : 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.35),
            Colors.black.withOpacity(0.18),
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
        padding: EdgeInsets.fromLTRB(
          _isSidebarCollapsed ? 10 : 16,
          18,
          _isSidebarCollapsed ? 10 : 16,
          16,
        ),
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
              onTap: () => Navigator.pushNamed(context, '/finance_dashboard'),
            ),
            const SizedBox(height: 10),
            navItem(
              icon: Icons.description_outlined,
              label: 'Proposals',
              badge: pendingBadge > 0 ? pendingBadge : null,
              active: _currentTab == 'proposals',
              onTap: () => Navigator.pushNamed(context, '/finance_dashboard'),
            ),
            const SizedBox(height: 10),
            navItem(
              icon: Icons.business_outlined,
              label: 'Client Management',
              active: _currentTab == 'clients',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FinanceClientManagementPage(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            navItem(
              icon: Icons.analytics_outlined,
              label: 'Analytics',
              active: true,
              onTap: () {},
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final proposals = _financeProposals(app);

    final now = DateTime.now();
    final quarterStart = _quarterStart(now);
    final proposalsThisQuarter = proposals.where((p) {
      final created = _parseDate(p['created_at'] ?? p['createdAt']);
      if (created == null) return false;
      return !created.isBefore(quarterStart);
    }).toList();

    final approvedOrReleased = proposals.where((p) {
      final s = (p['status'] ?? '').toString().toLowerCase();
      return s.contains('approved') ||
          s.contains('signed') ||
          s.contains('released') ||
          s.contains('sent to client');
    }).length;

    final conversionRate =
        proposals.isEmpty ? 0.0 : approvedOrReleased / proposals.length;

    double totalValue = 0;
    int valueCount = 0;
    final Map<String, double> clientTotals = {};
    for (final p in proposals) {
      final amt = _extractAmount(p);
      if (amt > 0) {
        totalValue += amt;
        valueCount += 1;
      }
      final client = (p['client'] ?? p['client_name'] ?? '').toString().trim();
      if (client.isNotEmpty && amt > 0) {
        clientTotals[client] = (clientTotals[client] ?? 0) + amt;
      }
    }
    final avgDeal = valueCount == 0 ? 0.0 : (totalValue / valueCount);

    String topClient = '--';
    double topClientValue = 0;
    for (final e in clientTotals.entries) {
      if (e.value > topClientValue) {
        topClientValue = e.value;
        topClient = e.key;
      }
    }

    final stageDays = <String, List<double>>{};
    for (final p in proposals) {
      final created = _parseDate(p['created_at'] ?? p['createdAt']);
      final updated = _parseDate(p['updated_at'] ?? p['updatedAt']);
      if (created == null || updated == null) continue;
      final days = updated.difference(created).inMinutes / (60 * 24);
      if (days < 0) continue;
      final s = (p['status'] ?? '').toString().toLowerCase();
      final stage = s.contains('pricing')
          ? 'Pricing'
          : (s.contains('pending review') || s.contains('pending approval'))
              ? 'Finance Review'
              : s.contains('changes requested')
                  ? 'Pricing Adjustment'
                  : (s.contains('released') || s.contains('sent to client'))
                      ? 'Client Release'
                      : (s.contains('approved') || s.contains('signed'))
                          ? 'Final Approval'
                          : 'Submission';
      stageDays.putIfAbsent(stage, () => []).add(days);
    }
    final stageAvg = <String, double>{};
    for (final e in stageDays.entries) {
      final v = e.value;
      if (v.isEmpty) continue;
      stageAvg[e.key] = v.reduce((a, b) => a + b) / v.length;
    }
    if (stageAvg.isEmpty) {
      stageAvg.addAll({
        'Submission': 0.9,
        'Finance Review': 3.0,
        'Pricing Adjustment': 1.9,
        'Final Approval': 1.5,
        'Client Release': 0.6,
      });
    }

    final submitted = proposals.length;
    final inReview = proposals.where((p) {
      final s = (p['status'] ?? '').toString().toLowerCase();
      return s.contains('pending') ||
          s.contains('review') ||
          s.contains('pricing');
    }).length;
    final approved = proposals.where((p) {
      final s = (p['status'] ?? '').toString().toLowerCase();
      return s.contains('approved') || s.contains('signed');
    }).length;
    final released = proposals.where((p) {
      final s = (p['status'] ?? '').toString().toLowerCase();
      return s.contains('released') || s.contains('sent to client');
    }).length;

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
                      child: CustomScrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Revenue projections, cycle metrics, and proposal performance insights',
                                style: PremiumTheme.bodyMedium
                                    .copyWith(color: Colors.white60),
                              ),
                              const SizedBox(height: 18),
                              LayoutBuilder(
                                builder: (context, c) {
                                  final narrow = c.maxWidth < 980;
                                  final cards = [
                                    _kpiCard(
                                      label: 'Proposals This Quarter',
                                      value: proposalsThisQuarter.length
                                          .toString(),
                                      subtitle:
                                          'Q${((now.month - 1) ~/ 3) + 1} ${now.year}',
                                      icon: Icons.bar_chart,
                                    ),
                                    _kpiCard(
                                      label: 'Conversion Rate',
                                      value:
                                          '${(conversionRate * 100).round()}%',
                                      subtitle: 'Approved or released',
                                      icon: Icons.ads_click,
                                    ),
                                    _kpiCard(
                                      label: 'Avg. Deal Size',
                                      value: avgDeal <= 0
                                          ? '--'
                                          : _currencyFormatter.format(avgDeal),
                                      subtitle: 'Across all proposals',
                                      icon: Icons.trending_up,
                                    ),
                                    _kpiCard(
                                      label: 'Top Client by Value',
                                      value: topClient,
                                      subtitle: topClientValue <= 0
                                          ? null
                                          : _currencyFormatter
                                              .format(topClientValue),
                                      icon: Icons.person_search,
                                    ),
                                  ];

                                  if (narrow) {
                                    return Column(
                                      children: [
                                        for (int i = 0;
                                            i < cards.length;
                                            i++) ...[
                                          cards[i],
                                          if (i != cards.length - 1)
                                            const SizedBox(height: 12),
                                        ],
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      for (int i = 0;
                                          i < cards.length;
                                          i++) ...[
                                        Expanded(child: cards[i]),
                                        if (i != cards.length - 1)
                                          const SizedBox(width: 12),
                                      ],
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 18),
                              LayoutBuilder(
                                builder: (context, c) {
                                  final narrow = c.maxWidth < 980;
                                  final revenue = _panel(
                                    title: 'Revenue Projections',
                                    subtitle:
                                        'Projected vs actual monthly revenue',
                                    child: _buildRevenueProjectionsChart(),
                                  );
                                  final cycle = _panel(
                                    title: 'Cycle Time by Stage',
                                    subtitle:
                                        'Average days spent in each approval stage',
                                    child:
                                        _buildCycleTimeByStageChart(stageAvg),
                                  );

                                  if (narrow) {
                                    return Column(
                                      children: [
                                        revenue,
                                        const SizedBox(height: 12),
                                        cycle,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: revenue),
                                      const SizedBox(width: 12),
                                      Expanded(child: cycle),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 18),
                              _panel(
                                title: 'Approval Funnel',
                                subtitle:
                                    'Proposal progression through the approval pipeline',
                                child: _buildApprovalFunnel(
                                  submitted: submitted,
                                  inReview: inReview,
                                  approved: approved,
                                  released: released,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Footer(),
                            ],
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
}
