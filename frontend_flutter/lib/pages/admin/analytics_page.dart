import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

import '../../api.dart';
import '../../services/asset_service.dart';
import '../../services/auth_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with TickerProviderStateMixin {
  String _selectedPeriod = 'Last 30 Days';
  String _cycleTimeScope = 'team';
  bool _cycleTimeAutoRefresh = true;
  int _cycleTimeRefreshTick = 0;
  Timer? _cycleTimeRefreshTimer;
  final TextEditingController _cycleTimeOwnerCtrl = TextEditingController();
  final TextEditingController _cycleTimeProposalTypeCtrl =
      TextEditingController();
  final TextEditingController _globalClientCtrl = TextEditingController();
  final TextEditingController _globalOwnerCtrl = TextEditingController();
  final TextEditingController _globalProposalTypeCtrl = TextEditingController();
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  static const String _currencySymbol = 'R';
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: _currencySymbol, decimalDigits: 0);
  final NumberFormat _compactCurrencyFormatter =
      NumberFormat.compactCurrency(symbol: _currencySymbol, decimalDigits: 1);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.value = 1.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      app.fetchProposals();
    });

    _cycleTimeRefreshTimer =
        Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!mounted) return;
      if (!_cycleTimeAutoRefresh) return;
      setState(() => _cycleTimeRefreshTick++);
    });
  }

  Future<Map<String, dynamic>?> _fetchClientEngagement() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getClientEngagementAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            scope: _cycleTimeScope,
            department: department.isEmpty ? null : department,
          );
      return data;
    } catch (e) {
      print('Client engagement exception: $e');
      return null;
    }
  }

  String _formatDurationSeconds(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    if (m > 0) {
      return '${m}m';
    }
    return '${seconds}s';
  }

  Widget _buildClientEngagementChart(List<Map<String, dynamic>> points) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No client engagement data yet',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final maxValue = points.fold<double>(
      0,
      (p, e) => math.max(
          p, (e['views'] is num) ? (e['views'] as num).toDouble() : 0.0),
    );
    final yMax = maxValue == 0 ? 1.0 : maxValue * 1.2;
    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(
          i.toDouble(),
          (points[i]['views'] is num)
              ? (points[i]['views'] as num).toDouble()
              : 0.0,
        )
    ];

    String _labelForIndex(int index) {
      if (index < 0 || index >= points.length) return '';
      final raw = (points[index]['date'] ?? '').toString();
      if (raw.length >= 10) {
        final mmdd = raw.substring(5, 10);
        return mmdd.replaceAll('-', '/');
      }
      return raw;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF2D3748),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (points.length / 6).clamp(1, 999).toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _labelForIndex(index),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: yMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF06B6D4),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF06B6D4),
                  strokeWidth: 2,
                  strokeColor: Colors.black.withValues(alpha: 0.3),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: 0.3),
                  const Color(0xFF06B6D4).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientEngagementCard(Map<String, dynamic>? data) {
    final viewsByDayRaw = (data?['views_by_day'] as List?) ?? [];
    final points = <Map<String, dynamic>>[
      for (final item in viewsByDayRaw)
        if (item is Map)
          {
            'date': item['date'],
            'views': item['views'],
          }
    ];

    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final viewsTotal = n(data?['views_total']);
    final uniqueClients = n(data?['unique_clients']);
    final timeSpentSeconds = n(data?['time_spent_seconds']);
    final sessionsCount = n(data?['sessions_count']);

    final timeToSign = (data?['time_to_sign'] as Map?) ?? {};
    final ttsSamples = n(timeToSign['samples']);
    final avgDaysRaw = timeToSign['avg_days'];
    final avgDays = (avgDaysRaw is num) ? avgDaysRaw.toDouble() : null;
    final avgDaysLabel =
        avgDays == null ? '--' : '${avgDays.toStringAsFixed(1)} days';

    Widget statChip(String label, String value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            statChip('Views', viewsTotal.toString(),
                Colors.white.withValues(alpha: 0.9)),
            statChip(
                'Unique Clients', uniqueClients.toString(), PremiumTheme.cyan),
            statChip('Time Spent', _formatDurationSeconds(timeSpentSeconds),
                PremiumTheme.teal),
            statChip('Sessions', sessionsCount.toString(), PremiumTheme.info),
            statChip('Avg Time To Sign', avgDaysLabel, PremiumTheme.purple),
            statChip('Samples', ttsSamples.toString(), Colors.white70),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(child: _buildClientEngagementChart(points)),
      ],
    );
  }

  Future<Map<String, dynamic>?> _fetchCollaborationLoad() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getCollaborationLoadAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            scope: _cycleTimeScope,
            department: department.isEmpty ? null : department,
          );
      return data;
    } catch (e) {
      print('Collaboration load exception: $e');
      return null;
    }
  }

  Widget _buildCollaborationLoadCard(Map<String, dynamic>? data) {
    final totals = (data?['totals'] as Map?) ?? {};
    final totalProposals = (data?['total_proposals'] is num)
        ? (data?['total_proposals'] as num).toInt()
        : 0;

    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final comments = n(totals['comments']);
    final versions = n(totals['versions']);
    final events = n(totals['activity_events']);
    final interactions = n(totals['interactions']);

    final top = (data?['top_proposals'] as List?) ?? [];

    Widget statChip(String label, int value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            statChip('Interactions', interactions,
                Colors.white.withValues(alpha: 0.9)),
            statChip('Comments', comments, PremiumTheme.teal),
            statChip('Versions', versions, PremiumTheme.purple),
            statChip('Activity', events, PremiumTheme.info),
            statChip('Proposals', totalProposals, Colors.white70),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Top active proposals',
          style: PremiumTheme.titleMedium.copyWith(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (top.isEmpty)
          Text(
            'No collaboration activity found in this period.',
            style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
          )
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              itemCount: top.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, i) {
                final row = top[i];
                final id = (row['proposal_id'] ?? '').toString();
                final title = (row['title'] ?? 'Untitled').toString();
                final client = (row['client'] ?? '').toString();
                final status = (row['status'] ?? '').toString();
                final rowInteractions = n(row['interactions']);

                return InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/proposal_review',
                      arguments: {
                        'id': id,
                        'title': title,
                      },
                    );
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            title,
                            style: PremiumTheme.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            client.isEmpty ? '-' : client,
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            status.isEmpty ? '-' : status,
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            rowInteractions.toString(),
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white70),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _cycleTimeRefreshTimer?.cancel();
    _cycleTimeOwnerCtrl.dispose();
    _cycleTimeProposalTypeCtrl.dispose();
    _globalClientCtrl.dispose();
    _globalOwnerCtrl.dispose();
    _globalProposalTypeCtrl.dispose();
    super.dispose();
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

  void _exportAsCSV() {
    try {
      final app = context.read<AppState>();
      final filtered = _filterProposals(app.proposals);
      final analytics = _calculateAnalytics(filtered);
      final metrics = _buildMetricCards(analytics);
      final csvContent = StringBuffer();
      csvContent.writeln('Analytics Report - $_selectedPeriod');
      csvContent.writeln(
          'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      csvContent.writeln('');
      csvContent.writeln('KEY METRICS');
      csvContent.writeln('Metric,Value,Change');
      for (final metric in metrics) {
        csvContent.writeln(
            '${metric.title},"${metric.value}",${metric.change.isEmpty ? "--" : metric.change}');
      }
      csvContent.writeln('');
      csvContent.writeln('RECENT PROPOSALS');
      csvContent.writeln('Proposal,Value,Status,Days,Win Probability');
      for (final proposal in analytics.recentProposals) {
        csvContent.writeln('"${proposal.title}",'
            '"${proposal.valueLabel}",'
            '"${proposal.status}",'
            '${proposal.daysOpen},'
            '${proposal.probabilityLabel}');
      }

      final blob = web.Blob([csvContent.toString().toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download =
          'analytics_${DateTime.now().millisecondsSinceEpoch}.csv';
      anchor.click();
      web.URL.revokeObjectURL(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar('CSV exported successfully!'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Export failed: $e'),
        );
      }
    }
  }

  void _exportAsJSON() {
    try {
      final app = context.read<AppState>();
      final filtered = _filterProposals(app.proposals);
      final analytics = _calculateAnalytics(filtered);
      final data = {
        'export_date': DateTime.now().toIso8601String(),
        'period': _selectedPeriod,
        'metrics': {
          'total_pipeline_value': analytics.totalPipelineValue,
          'active_proposals': analytics.activeProposals,
          'conversion_rate_percent': analytics.winRate,
          'average_deal_size': analytics.averageDealSize,
          'revenue_change_percent': analytics.revenueChangePercent,
          'active_change_percent': analytics.activeChangePercent,
          'conversion_change_percent': analytics.conversionChangePercent,
          'average_deal_change_percent': analytics.averageDealChangePercent,
        },
        'recent_proposals': analytics.recentProposals
            .map((proposal) => {
                  'title': proposal.title,
                  'value': proposal.value,
                  'status': proposal.status,
                  'days_open': proposal.daysOpen,
                  'win_probability_percent':
                      (proposal.probability * 100).round(),
                })
            .toList(),
      };

      final jsonContent = const JsonEncoder.withIndent('  ').convert(data);
      final blob = web.Blob([jsonContent.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download =
          'analytics_${DateTime.now().millisecondsSinceEpoch}.json';
      anchor.click();
      web.URL.revokeObjectURL(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSuccessSnackBar('JSON exported successfully!'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar('Export failed: $e'),
        );
      }
    }
  }

  SnackBar _buildSuccessSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1A1F26),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
      duration: const Duration(seconds: 3),
    );
  }

  Future<Map<String, dynamic>?> _fetchRiskGateSummary() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getRiskGateSummary(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            scope: _cycleTimeScope,
            department: department.isEmpty ? null : department,
          );
      return data;
    } catch (e) {
      print('Risk gate summary exception: $e');
      return null;
    }
  }

  Future<void> _showRiskGateProposalsDialog(String riskStatus) async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      await showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: 980, maxHeight: 720),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PremiumTheme.glassWhiteBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Risk Gate: $riskStatus',
                              style: PremiumTheme.titleLarge
                                  .copyWith(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: context.read<AppState>().getRiskGateProposals(
                                riskStatus: riskStatus,
                                startDate: startDate,
                                endDate: endDate,
                                owner: owner.isEmpty ? null : owner,
                                proposalType:
                                    proposalType.isEmpty ? null : proposalType,
                                client: client.isEmpty ? null : client,
                                scope: _cycleTimeScope,
                                department:
                                    department.isEmpty ? null : department,
                                limit: 250,
                              ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final data = snapshot.data;
                            final proposals =
                                (data?['proposals'] as List?) ?? [];

                            if (proposals.isEmpty) {
                              return Center(
                                child: Text(
                                  'No proposals match this bucket under the current filters.',
                                  style: PremiumTheme.bodyMedium,
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: proposals.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              itemBuilder: (context, i) {
                                final p = proposals[i];
                                final id = (p['proposal_id'] ?? '').toString();
                                final title =
                                    (p['proposal_title'] ?? 'Untitled')
                                        .toString();
                                final clientName =
                                    (p['client'] ?? '').toString();
                                final status =
                                    (p['proposal_status'] ?? '').toString();
                                final risk =
                                    (p['risk_status'] ?? 'NONE').toString();
                                final score = p['risk_score'];

                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(
                                      this.context,
                                      '/proposal_review',
                                      arguments: {
                                        'id': id,
                                        'title': title,
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            title,
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            clientName.isEmpty
                                                ? '-'
                                                : clientName,
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.left,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            status.isEmpty ? '-' : status,
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            risk,
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            score == null
                                                ? '-'
                                                : score.toString(),
                                            style: PremiumTheme.bodyMedium
                                                .copyWith(
                                              color: Colors.white70,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Risk gate drill-down dialog error: $e');
    }
  }

  Widget _buildRiskGateIndicator(Map<String, dynamic>? data) {
    final overall = (data?['overall_level'] ?? 'NONE').toString().toUpperCase();
    final countsMap = data?['counts'];
    final counts = <String, int>{'PASS': 0, 'REVIEW': 0, 'BLOCK': 0, 'NONE': 0};
    if (countsMap is Map) {
      for (final k in counts.keys) {
        final v = countsMap[k];
        if (v is int) {
          counts[k] = v;
        } else if (v is num) {
          counts[k] = v.toInt();
        }
      }
    }

    Color levelColor() {
      switch (overall) {
        case 'BLOCK':
          return PremiumTheme.error;
        case 'REVIEW':
          return PremiumTheme.warning;
        case 'PASS':
          return PremiumTheme.success;
        default:
          return Colors.white.withValues(alpha: 0.6);
      }
    }

    String levelLabel() {
      switch (overall) {
        case 'BLOCK':
          return 'High Risk';
        case 'REVIEW':
          return 'Needs Review';
        case 'PASS':
          return 'Low Risk';
        default:
          return 'Not Analyzed';
      }
    }

    Widget chip(String label, int value, Color color) {
      return InkWell(
        onTap: () => _showRiskGateProposalsDialog(label),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: levelColor(),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              levelLabel(),
              style: PremiumTheme.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            chip('PASS', counts['PASS'] ?? 0, PremiumTheme.success),
            chip('REVIEW', counts['REVIEW'] ?? 0, PremiumTheme.warning),
            chip('BLOCK', counts['BLOCK'] ?? 0, PremiumTheme.error),
            chip('NONE', counts['NONE'] ?? 0,
                Colors.white.withValues(alpha: 0.7)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Latest run per proposal',
          style: PremiumTheme.bodyMedium.copyWith(
            color: PremiumTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  SnackBar _buildErrorSnackBar(String message) {
    return SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0x33FFFFFF), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        size: 48,
                        color: Color(0xFF06B6D4),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Export Analytics Report',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose your preferred export format',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildExportButton(
                          'CSV',
                          Icons.table_chart,
                          const Color(0xFF10B981),
                          _exportAsCSV,
                        ),
                        const SizedBox(width: 16),
                        _buildExportButton(
                          'JSON',
                          Icons.code,
                          const Color(0xFF06B6D4),
                          _exportAsJSON,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).pop();
        onPressed();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  _AnalyticsSnapshot _calculateAnalytics(List<dynamic> rawProposals) {
    final now = DateTime.now();
    final normalized = <Map<String, dynamic>>[];
    for (final proposal in rawProposals) {
      if (proposal is Map<String, dynamic>) {
        normalized.add(proposal);
      } else if (proposal is Map) {
        try {
          normalized.add(proposal.cast<String, dynamic>());
        } catch (_) {
          continue;
        }
      }
    }

    final monthlyPoints = List.generate(6, (index) {
      final monthDate = DateTime(now.year, now.month - (5 - index), 1);
      return _MonthlyPoint(monthDate);
    });

    double totalRevenue = 0;
    int proposalsWithBudget = 0;
    int winCount = 0;
    int lossCount = 0;
    int activeCount = 0;
    final Map<String, int> statusCounts = {};
    final List<_ProposalPerformanceRow> performanceRows = [];

    for (final proposal in normalized) {
      final statusRaw = (proposal['status'] ?? 'Draft').toString();
      final statusLabel = _formatStatusLabel(statusRaw);
      final statusLower = statusRaw.toLowerCase();
      statusCounts[statusLabel] = (statusCounts[statusLabel] ?? 0) + 1;

      final budget = _parseBudget(proposal['budget'] ??
          proposal['estimated_value'] ??
          proposal['estimatedValue']);
      if (budget > 0) {
        totalRevenue += budget;
        proposalsWithBudget++;
      }

      final isWin = _isWinStatus(statusLower);
      final isLoss = _isLossStatus(statusLower);
      if (isWin) {
        winCount++;
      } else if (isLoss) {
        lossCount++;
      }
      if (!_isClosedStatus(statusLower)) {
        activeCount++;
      }

      final created =
          _parseDate(proposal['created_at'] ?? proposal['createdAt']);
      if (created != null) {
        final diffMonths =
            (now.year - created.year) * 12 + (now.month - created.month);
        if (diffMonths >= 0 && diffMonths < monthlyPoints.length) {
          final idx = monthlyPoints.length - 1 - diffMonths;
          monthlyPoints[idx].revenue += budget;
          monthlyPoints[idx].proposals += 1;
          if (isWin) {
            monthlyPoints[idx].wins += 1;
          } else if (isLoss) {
            monthlyPoints[idx].losses += 1;
          }
        }
      }

      final updated =
          _parseDate(proposal['updated_at'] ?? proposal['updatedAt']) ??
              created;
      performanceRows.add(
        _ProposalPerformanceRow(
          title: proposal['title']?.toString().isNotEmpty == true
              ? proposal['title'].toString()
              : 'Untitled',
          value: budget > 0 ? budget : null,
          valueLabel: budget > 0 ? _formatCurrency(budget) : '—',
          status: statusLabel,
          daysOpen:
              updated != null ? DateTime.now().difference(updated).inDays : 0,
          probability: _probabilityForStatus(statusLower),
          statusColor: _statusColor(statusLower),
          updatedAt: updated,
        ),
      );
    }

    performanceRows.sort((a, b) {
      final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    final recentProposals = performanceRows.take(5).toList();

    final double winRate = winCount + lossCount > 0
        ? (winCount / (winCount + lossCount)) * 100
        : 0.0;
    final double lossRate = winCount + lossCount > 0
        ? (lossCount / (winCount + lossCount)) * 100
        : 0.0;
    final double averageDealSize =
        proposalsWithBudget > 0 ? totalRevenue / proposalsWithBudget : 0.0;

    double? revenueChangePercent;
    double? activeChangePercent;
    double? conversionChangePercent;
    double? averageDealChangePercent;

    if (monthlyPoints.length >= 2) {
      final currentMonth = monthlyPoints.last;
      final previousMonth = monthlyPoints[monthlyPoints.length - 2];
      revenueChangePercent =
          _percentChange(previousMonth.revenue, currentMonth.revenue);
      activeChangePercent = _percentChange(
        previousMonth.proposals.toDouble(),
        currentMonth.proposals.toDouble(),
      );

      final currentDecisions = currentMonth.wins + currentMonth.losses;
      final previousDecisions = previousMonth.wins + previousMonth.losses;
      final currentConversion = currentDecisions > 0
          ? (currentMonth.wins / currentDecisions) * 100
          : null;
      final previousConversion = previousDecisions > 0
          ? (previousMonth.wins / previousDecisions) * 100
          : null;
      if (currentConversion != null && previousConversion != null) {
        conversionChangePercent =
            _percentChange(previousConversion, currentConversion);
      }

      final currentAvg = currentMonth.proposals > 0
          ? currentMonth.revenue / currentMonth.proposals
          : null;
      final previousAvg = previousMonth.proposals > 0
          ? previousMonth.revenue / previousMonth.proposals
          : null;
      if (currentAvg != null && previousAvg != null) {
        averageDealChangePercent = _percentChange(previousAvg, currentAvg);
      }
    }

    return _AnalyticsSnapshot(
      totalPipelineValue: totalRevenue,
      totalProposals: normalized.length,
      activeProposals: activeCount,
      averageDealSize: averageDealSize,
      winRate: winRate,
      lossRate: lossRate,
      statusCounts: statusCounts,
      monthlyPoints: monthlyPoints,
      recentProposals: recentProposals,
      revenueChangePercent: revenueChangePercent,
      activeChangePercent: activeChangePercent,
      conversionChangePercent: conversionChangePercent,
      averageDealChangePercent: averageDealChangePercent,
    );
  }

  List<_MetricCardData> _buildMetricCards(_AnalyticsSnapshot analytics) {
    final metrics = <_MetricCardData>[];
    metrics.add(
      _MetricCardData(
        title: 'Total Revenue',
        value: _formatCurrency(analytics.totalPipelineValue, compact: true),
        change: _formatChange(analytics.revenueChangePercent),
        isPositive: _isPositiveChange(analytics.revenueChangePercent),
        subtitle: 'vs last month',
      ),
    );
    metrics.add(
      _MetricCardData(
        title: 'Active Proposals',
        value: analytics.activeProposals.toString(),
        change: _formatChange(analytics.activeChangePercent),
        isPositive: _isPositiveChange(analytics.activeChangePercent),
        subtitle: 'vs last month',
      ),
    );
    metrics.add(
      _MetricCardData(
        title: 'Conversion Rate',
        value: '${analytics.winRate.toStringAsFixed(1)}%',
        change: _formatChange(analytics.conversionChangePercent),
        isPositive: _isPositiveChange(analytics.conversionChangePercent),
        subtitle: 'vs last month',
      ),
    );
    metrics.add(
      _MetricCardData(
        title: 'Avg Deal Size',
        value: _formatCurrency(analytics.averageDealSize, compact: true),
        change: _formatChange(analytics.averageDealChangePercent),
        isPositive: _isPositiveChange(analytics.averageDealChangePercent),
        subtitle: 'vs last month',
      ),
    );
    return metrics;
  }

  double _parseBudget(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    final cleaned = value.toString().replaceAll(RegExp(r'[^\d\.-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime? _periodStart(DateTime now) {
    if (_selectedPeriod == 'Last 7 Days') {
      return now.subtract(const Duration(days: 7));
    }
    if (_selectedPeriod == 'Last 30 Days') {
      return now.subtract(const Duration(days: 30));
    }
    if (_selectedPeriod == 'Last 90 Days') {
      return now.subtract(const Duration(days: 90));
    }
    if (_selectedPeriod == 'This Year') {
      return DateTime(now.year, 1, 1);
    }
    return null;
  }

  List<Map<String, dynamic>> _filterProposals(List<dynamic> rawProposals) {
    final normalized = <Map<String, dynamic>>[];
    for (final proposal in rawProposals) {
      if (proposal is Map<String, dynamic>) {
        normalized.add(proposal);
      } else if (proposal is Map) {
        try {
          normalized.add(proposal.cast<String, dynamic>());
        } catch (_) {
          continue;
        }
      }
    }

    final now = DateTime.now();
    final start = _periodStart(now);
    final clientQ = _globalClientCtrl.text.trim().toLowerCase();
    final ownerQ = _globalOwnerCtrl.text.trim().toLowerCase();
    final typeQ = _globalProposalTypeCtrl.text.trim().toLowerCase();

    bool matchesAny(dynamic value, String query) {
      if (query.isEmpty) return true;
      if (value == null) return false;
      return value.toString().toLowerCase().contains(query);
    }

    return normalized.where((p) {
      if (clientQ.isNotEmpty) {
        final ok = matchesAny(p['client'], clientQ) ||
            matchesAny(p['client_name'], clientQ) ||
            matchesAny(p['clientName'], clientQ) ||
            matchesAny(p['client_email'], clientQ) ||
            matchesAny(p['clientEmail'], clientQ);
        if (!ok) return false;
      }

      if (ownerQ.isNotEmpty) {
        final ok = matchesAny(p['owner_id'], ownerQ) ||
            matchesAny(p['ownerId'], ownerQ) ||
            matchesAny(p['user_id'], ownerQ) ||
            matchesAny(p['userId'], ownerQ) ||
            matchesAny(p['owner'], ownerQ) ||
            matchesAny(p['owner_name'], ownerQ) ||
            matchesAny(p['ownerName'], ownerQ) ||
            matchesAny(p['owner_email'], ownerQ) ||
            matchesAny(p['ownerEmail'], ownerQ);
        if (!ok) return false;
      }

      if (typeQ.isNotEmpty) {
        final ok = matchesAny(p['template_type'], typeQ) ||
            matchesAny(p['templateType'], typeQ) ||
            matchesAny(p['template_key'], typeQ) ||
            matchesAny(p['templateKey'], typeQ);
        if (!ok) return false;
      }

      if (start != null) {
        final created = _parseDate(p['created_at'] ?? p['createdAt']);
        final updated = _parseDate(p['updated_at'] ?? p['updatedAt']);
        final probe = created ?? updated;
        if (probe == null) return false;
        if (probe.isBefore(start) || probe.isAfter(now)) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildGlobalFilterBar() {
    Widget glassField({required Widget child}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: child,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: glassField(
            child: TextField(
              controller: _globalClientCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Client (optional)',
                hintStyle: TextStyle(color: Colors.white54),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        ),
        SizedBox(
          width: 240,
          child: glassField(
            child: TextField(
              controller: _globalOwnerCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Owner (optional)',
                hintStyle: TextStyle(color: Colors.white54),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        ),
        SizedBox(
          width: 260,
          child: glassField(
            child: TextField(
              controller: _globalProposalTypeCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Proposal type (optional)',
                hintStyle: TextStyle(color: Colors.white54),
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
        ),
        glassField(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white, size: 18),
                tooltip: 'Clear filters',
                onPressed: () {
                  setState(() {
                    _globalClientCtrl.clear();
                    _globalOwnerCtrl.clear();
                    _globalProposalTypeCtrl.clear();
                    _cycleTimeRefreshTick++;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  double? _percentChange(double previous, double current) {
    if (previous == 0) {
      if (current == 0) return 0;
      return null;
    }
    return ((current - previous) / previous) * 100;
  }

  String _formatCurrency(double value, {bool compact = false}) {
    if (value == 0) return '${_currencySymbol}0';
    return compact
        ? _compactCurrencyFormatter.format(value)
        : _currencyFormatter.format(value);
  }

  String _formatChange(double? percent) {
    if (percent == null) return '--';
    final formatted = percent.abs() >= 1000
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return percent >= 0 ? '+$formatted%' : '$formatted%';
  }

  bool _isPositiveChange(double? percent) {
    if (percent == null) return true;
    return percent >= 0;
  }

  bool _isWinStatus(String status) {
    return status.contains('signed') || status.contains('won');
  }

  bool _isLossStatus(String status) {
    return status.contains('lost') || status.contains('declined');
  }

  bool _isClosedStatus(String status) {
    return _isWinStatus(status) || _isLossStatus(status);
  }

  double _probabilityForStatus(String status) {
    if (_isWinStatus(status)) return 1;
    if (_isLossStatus(status)) return 0;
    if (status.contains('sent to client')) return 0.8;
    if (status.contains('pending ceo') || status.contains('in review')) {
      return 0.6;
    }
    if (status.contains('draft')) return 0.3;
    return 0.5;
  }

  Color _statusColor(String status) {
    if (_isWinStatus(status)) return PremiumTheme.success;
    if (_isLossStatus(status)) return PremiumTheme.error;
    if (status.contains('sent to client')) return PremiumTheme.info;
    if (status.contains('pending') || status.contains('review')) {
      return PremiumTheme.warning;
    }
    return PremiumTheme.orange;
  }

  String _formatStatusLabel(String status) {
    if (status.isEmpty) return 'Draft';
    final parts = status
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .toList();
    return parts.isEmpty ? 'Draft' : parts.join(' ');
  }

  String _getUserName(Map<String, dynamic>? user) {
    if (user == null) return 'User';

    String? name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['email']?.split('@')[0];

    return name ?? 'User';
  }

  bool _isAdminUser() {
    final user = AuthService.currentUser;
    final backendRole = user?['role']?.toString().toLowerCase() ?? 'manager';
    return backendRole == 'admin' || backendRole == 'ceo';
  }

  String? _pipelineStageForStatus(String statusLower) {
    final s = statusLower.trim();
    if (s.isEmpty || s.contains('draft')) return 'Draft';
    if (s.contains('signed') || s.contains('won')) return 'Signed';
    if (s.contains('sent to client') || s.contains('released'))
      return 'Released';
    if (s.contains('review') ||
        (s.contains('pending') && s.contains('ceo')) ||
        s.contains('approved')) {
      return 'In Review';
    }
    return null;
  }

  Map<String, int> _calculatePipelineCounts(List<dynamic> rawProposals) {
    final counts = <String, int>{
      'Draft': 0,
      'In Review': 0,
      'Released': 0,
      'Signed': 0,
    };

    for (final proposal in rawProposals) {
      Map<String, dynamic>? p;
      if (proposal is Map<String, dynamic>) {
        p = proposal;
      } else if (proposal is Map) {
        try {
          p = proposal.cast<String, dynamic>();
        } catch (_) {
          p = null;
        }
      }
      if (p == null) continue;

      final statusLower = (p['status'] ?? '').toString().toLowerCase();
      final stage = _pipelineStageForStatus(statusLower);
      if (stage == null) continue;
      counts[stage] = (counts[stage] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildProposalPipelineFunnel(Map<String, int> counts) {
    final stages = const ['Draft', 'In Review', 'Released', 'Signed'];
    final maxCount = counts.values.fold<int>(0, (m, v) => v > m ? v : m);
    final safeMax = math.max(maxCount, 1);

    Color stageColor(String stage) {
      switch (stage) {
        case 'Signed':
          return PremiumTheme.success;
        case 'Released':
          return PremiumTheme.info;
        case 'In Review':
          return PremiumTheme.warning;
        default:
          return PremiumTheme.orange;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            for (final stage in stages)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          stage,
                          overflow: TextOverflow.ellipsis,
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (counts[stage] ?? 0) / safeMax,
                              child: Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  color:
                                      stageColor(stage).withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 44,
                        child: Text(
                          (counts[stage] ?? 0).toString(),
                          textAlign: TextAlign.right,
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCompletionRateGauge({required int signed, required int total}) {
    final ratio = total <= 0 ? 0.0 : (signed / total).clamp(0.0, 1.0);
    final percent = ratio * 100;
    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(
                  ratio >= 0.75
                      ? PremiumTheme.success
                      : ratio >= 0.4
                          ? PremiumTheme.warning
                          : PremiumTheme.error,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: PremiumTheme.displayMedium.copyWith(fontSize: 34),
                ),
                const SizedBox(height: 6),
                Text(
                  '$signed of $total signed',
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: PremiumTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final filtered = _filterProposals(app.proposals);
    final analytics = _calculateAnalytics(filtered);
    final metrics = _buildMetricCards(analytics);
    final pipelineCounts = _calculatePipelineCounts(filtered);
    final pipelineTotal =
        pipelineCounts.values.fold<int>(0, (sum, v) => sum + v);
    final signedCount = pipelineCounts['Signed'] ?? 0;
    final userName = _getUserName(app.currentUser);
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final isAdminUser = _isAdminUser();
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
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 720;
                    final userWidget = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 35,
                          height: 35,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3498DB),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              userInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            userName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PopupMenuButton<String>(
                          icon:
                              const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'logout') {
                              Navigator.pushNamed(context, '/login');
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
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
                    );

                    if (compact) {
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Analytics Dashboard',
                              overflow: TextOverflow.ellipsis,
                              style: PremiumTheme.titleLarge
                                  .copyWith(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(child: userWidget),
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Analytics Dashboard',
                          style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
                        ),
                        userWidget,
                      ],
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isSidebarCollapsed ? 90.0 : 250.0,
                    color: const Color(0xFF34495E),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: InkWell(
                              onTap: _toggleSidebar,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C3E50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: _isSidebarCollapsed
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (!_isSidebarCollapsed)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          'Navigation',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: _isSidebarCollapsed ? 0 : 8,
                                      ),
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
                          if (isAdminUser) ...[
                            _buildNavItem(
                              'Dashboard',
                              'assets/images/Dahboard.png',
                              false,
                              context,
                            ),
                            _buildNavItem(
                              'Approvals',
                              'assets/images/Time Allocation_Approval_Blue.png',
                              false,
                              context,
                            ),
                            _buildNavItem(
                              'Analytics',
                              'assets/images/analytics.png',
                              true,
                              context,
                            ),
                          ] else ...[
                            _buildNavItem(
                              'Dashboard',
                              'assets/images/Dahboard.png',
                              false,
                              context,
                            ),
                            _buildNavItem(
                              'My Proposals',
                              'assets/images/My_Proposals.png',
                              false,
                              context,
                            ),
                            _buildNavItem(
                              'Templates',
                              'assets/images/content_library.png',
                              false,
                              context,
                            ),
                            _buildNavItem(
                              'Content Library',
                              'assets/images/content_library.png',
                              false,
                              context,
                            ),
                            _buildNavItem(
                              'Client Management',
                              'assets/images/collaborations.png',
                              false,
                              context,
                            ),
                            _buildNavItem(
                              'Approved Proposals',
                              'assets/images/Time Allocation_Approval_Blue.png',
                              false,
                              context,
                            ),
                            _buildNavItem(
                              'Analytics (My Pipeline)',
                              'assets/images/analytics.png',
                              true,
                              context,
                            ),
                          ],
                          const SizedBox(height: 20),
                          if (!_isSidebarCollapsed)
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              height: 1,
                              color: const Color(0xFF2C3E50),
                            ),
                          const SizedBox(height: 12),
                          _buildNavItem(
                            'Logout',
                            'assets/images/Logout_KhonoBuzz.png',
                            false,
                            context,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(right: 24),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 900;
                                  final actions = Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _buildGlassDropdown(),
                                      _buildGlassButton(
                                        'Refresh',
                                        Icons.refresh,
                                        () async {
                                          await context
                                              .read<AppState>()
                                              .fetchProposals();
                                          if (!mounted) return;
                                          setState(() {
                                            _cycleTimeRefreshTick++;
                                          });
                                        },
                                      ),
                                      _buildGlassButton(
                                        'Export',
                                        Icons.download,
                                        _showExportDialog,
                                      ),
                                    ],
                                  );

                                  if (compact) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Analytics Dashboard',
                                          style: PremiumTheme.displayMedium
                                              .copyWith(fontSize: 28),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Comprehensive business intelligence and performance metrics',
                                          style:
                                              PremiumTheme.bodyLarge.copyWith(
                                            color: PremiumTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        actions,
                                      ],
                                    );
                                  }

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Analytics Dashboard',
                                            style: PremiumTheme.displayMedium
                                                .copyWith(fontSize: 28),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Comprehensive business intelligence and performance metrics',
                                            style:
                                                PremiumTheme.bodyLarge.copyWith(
                                              color: PremiumTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions,
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                              _buildGlobalFilterBar(),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  for (int i = 0; i < metrics.length; i++) ...[
                                    Expanded(
                                      child: _buildGlassMetricCard(
                                        metrics[i].title,
                                        metrics[i].value,
                                        metrics[i].change,
                                        metrics[i].isPositive,
                                        metrics[i].subtitle,
                                      ),
                                    ),
                                    if (i != metrics.length - 1)
                                      const SizedBox(width: 20),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 32),
                              _buildGlassChartCard(
                                'Revenue Analytics',
                                _buildRevenueChart(analytics.monthlyPoints),
                                height: 350,
                              ),
                              const SizedBox(height: 32),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildGlassChartCard(
                                      'Proposal Pipeline',
                                      _buildProposalPipelineFunnel(
                                          pipelineCounts),
                                      height: 220,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildGlassChartCard(
                                      'Completion Rate',
                                      _buildCompletionRateGauge(
                                        signed: signedCount,
                                        total: pipelineTotal,
                                      ),
                                      height: 220,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildGlassChartCard(
                                      'Proposal Status',
                                      _buildProposalStatusChart(
                                          analytics.statusCounts),
                                      height: 320,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildGlassChartCard(
                                      'Win Rate',
                                      _buildWinRatePieChart(analytics.winRate,
                                          analytics.lossRate),
                                      height: 320,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              _buildGlassChartCard(
                                'Risk Gate',
                                FutureBuilder<Map<String, dynamic>?>(
                                  key: ValueKey(
                                      'risk_gate_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}'),
                                  future: _fetchRiskGateSummary(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Failed to load risk gate summary.',
                                          style:
                                              PremiumTheme.bodyMedium.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      );
                                    }
                                    final data = snapshot.data;
                                    return _buildRiskGateIndicator(data);
                                  },
                                ),
                                height: 220,
                              ),
                              const SizedBox(height: 32),
                              _buildGlassChartCard(
                                'Collaboration Load',
                                FutureBuilder<Map<String, dynamic>?>(
                                  key: ValueKey(
                                      'collab_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}'),
                                  future: _fetchCollaborationLoad(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Failed to load collaboration metrics.',
                                          style:
                                              PremiumTheme.bodyMedium.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      );
                                    }
                                    return _buildCollaborationLoadCard(
                                        snapshot.data);
                                  },
                                ),
                                height: 360,
                              ),
                              const SizedBox(height: 32),
                              _buildGlassChartCard(
                                'Client Engagement',
                                FutureBuilder<Map<String, dynamic>?>(
                                  key: ValueKey(
                                      'engagement_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}'),
                                  future: _fetchClientEngagement(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Failed to load client engagement.',
                                          style:
                                              PremiumTheme.bodyMedium.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      );
                                    }
                                    return _buildClientEngagementCard(
                                        snapshot.data);
                                  },
                                ),
                                height: 360,
                              ),
                              const SizedBox(height: 32),
                              _buildGlassChartCard(
                                'Cycle Time Metrics',
                                _buildCycleTimeContent(null),
                                height: 320,
                              ),
                              const SizedBox(height: 32),
                              _buildGlassPerformanceTable(
                                  analytics.recentProposals),
                              const SizedBox(height: 32),
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

  Widget _buildNavItem(
    String label,
    String assetPath,
    bool isActive,
    BuildContext context,
  ) {
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              _navigateToPage(context, label);
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
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
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          _navigateToPage(context, label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: const Color(0xFF2980B9), width: 1)
                : null,
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFECF0F1),
                    fontSize: 13,
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

  Widget _buildGlassDropdown() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: const Color(0x33FFFFFF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                dropdownColor: const Color(0xFF1A1F26),
                style: const TextStyle(color: Colors.white),
                icon:
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                items: [
                  'Last 7 Days',
                  'Last 30 Days',
                  'Last 90 Days',
                  'This Year'
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedPeriod = newValue!;
                    _cycleTimeRefreshTick++;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton(
      String label, IconData icon, VoidCallback onPressed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: const Color(0x33FFFFFF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassMetricCard(
    String title,
    String value,
    String change,
    bool isPositive,
    String subtitle,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PremiumTheme.glassWhiteBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: PremiumTheme.bodyMedium.copyWith(
                  color: PremiumTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: PremiumTheme.displayMedium.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color:
                        isPositive ? PremiumTheme.success : PremiumTheme.error,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      change,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: isPositive
                            ? PremiumTheme.success
                            : PremiumTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassChartCard(
    String title,
    Widget chart, {
    double height = 300,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PremiumTheme.glassWhiteBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PremiumTheme.titleMedium),
              const SizedBox(height: 24),
              SizedBox(height: height, child: chart),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<_MonthlyPoint> points) {
    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No revenue data yet',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final maxValue = points.fold<double>(0,
        (previousValue, element) => math.max(previousValue, element.revenue));
    final yMax = maxValue == 0 ? 1.0 : maxValue * 1.2;
    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].revenue)
    ];
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF2D3748),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    _compactCurrencyFormatter.format(value),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < points.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      points[index].label,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: yMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF06B6D4),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: const Color(0xFF06B6D4),
                  strokeWidth: 2,
                  strokeColor: Colors.black.withValues(alpha: 0.3),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF06B6D4).withValues(alpha: 0.3),
                  const Color(0xFF06B6D4).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalStatusChart(Map<String, int> statusCounts) {
    final statuses = [
      'Draft',
      'In Review',
      'Pending Ceo Approval',
      'Sent To Client',
      'Signed',
      'Lost',
    ];

    // Map declined statuses to "Lost"
    final normalizedCounts = <String, int>{};
    int lostCount = 0;
    for (final entry in statusCounts.entries) {
      final status = entry.key.toLowerCase();
      if (status.contains('declined') ||
          status.contains('lost') ||
          status.contains('rejected')) {
        lostCount += entry.value;
      } else {
        normalizedCounts[entry.key] = entry.value;
      }
    }
    if (lostCount > 0) {
      normalizedCounts['Lost'] = lostCount;
    }

    final bars = <BarChartGroupData>[];
    int maxCount = 0;
    for (int i = 0; i < statuses.length; i++) {
      final label = statuses[i];
      final count = normalizedCounts[label] ?? 0;
      maxCount = math.max(maxCount, count);
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: _statusColor(label.toLowerCase()),
              width: 28,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }
    final maxY = math.max(maxCount.toDouble(), 5.0);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} proposals',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < statuses.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      statuses[value.toInt()],
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(maxY / 4, 1.0),
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF2D3748),
            strokeWidth: 1,
          ),
        ),
        barGroups: bars,
      ),
    );
  }

  Widget _buildWinRatePieChart(double winRate, double lossRate) {
    final sections = <PieChartSectionData>[];
    final pendingRate = math.max(0.0, 100 - winRate - lossRate);
    if (winRate > 0) {
      sections.add(
        PieChartSectionData(
          color: PremiumTheme.success,
          value: winRate,
          title: '${winRate.toStringAsFixed(1)}%',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (lossRate > 0) {
      sections.add(
        PieChartSectionData(
          color: PremiumTheme.error,
          value: lossRate,
          title: '${lossRate.toStringAsFixed(1)}%',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (pendingRate > 0 && pendingRate < 100) {
      sections.add(
        PieChartSectionData(
          color: PremiumTheme.warning,
          value: pendingRate,
          title: '${pendingRate.toStringAsFixed(1)}%',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: Colors.white.withValues(alpha: 0.2),
          value: 100,
          title: 'No data',
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: sections,
      ),
    );
  }

  Widget _buildGlassPerformanceTable(List<_ProposalPerformanceRow> rows) {
    if (rows.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No recent proposals yet',
            style: PremiumTheme.bodyMedium,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PremiumTheme.glassWhiteBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent Proposals', style: PremiumTheme.titleMedium),
              const SizedBox(height: 24),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF2D3748),
                          width: 2,
                        ),
                      ),
                    ),
                    children: [
                      _buildTableHeader('PROPOSAL'),
                      _buildTableHeader('VALUE'),
                      _buildTableHeader('STATUS'),
                      _buildTableHeader('DAYS'),
                      _buildTableHeader('WIN PROBABILITY'),
                    ],
                  ),
                  for (final proposal in rows) _buildTableRow(proposal),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Text(
        text,
        style: PremiumTheme.labelMedium
            .copyWith(color: PremiumTheme.textSecondary),
      ),
    );
  }

  TableRow _buildTableRow(_ProposalPerformanceRow data) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2D3748), width: 1)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(
            data.title,
            style: PremiumTheme.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(data.valueLabel, style: PremiumTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: data.statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: data.statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              data.status,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: data.statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(data.daysOpen.toString(), style: PremiumTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: data.probability.clamp(0, 1),
                  backgroundColor: const Color(0xFF2D3748),
                  valueColor: AlwaysStoppedAnimation<Color>(data.statusColor),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                data.probabilityLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: data.statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _fetchCycleTimeAnalytics() async {
    try {
      final now = DateTime.now();
      DateTime? start;
      if (_selectedPeriod == 'Last 7 Days') {
        start = now.subtract(const Duration(days: 7));
      } else if (_selectedPeriod == 'Last 30 Days') {
        start = now.subtract(const Duration(days: 30));
      } else if (_selectedPeriod == 'Last 90 Days') {
        start = now.subtract(const Duration(days: 90));
      } else if (_selectedPeriod == 'This Year') {
        start = DateTime(now.year, 1, 1);
      }

      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _cycleTimeOwnerCtrl.text.trim().isNotEmpty
          ? _cycleTimeOwnerCtrl.text.trim()
          : _globalOwnerCtrl.text.trim();
      final proposalType = _cycleTimeProposalTypeCtrl.text.trim().isNotEmpty
          ? _cycleTimeProposalTypeCtrl.text.trim()
          : _globalProposalTypeCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getCycleTimeAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            scope: _cycleTimeScope,
            department: department.isEmpty ? null : department,
          );
      return data;
    } catch (e) {
      print('Cycle time analytics exception: $e');
      return null;
    }
  }

  Widget _buildCycleTimeContent(Map<String, dynamic>? cycleTimeAnalytics) {
    _cycleTimeRefreshTick;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCycleTimeFilterBar(),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>?>(
            key: ValueKey(_cycleTimeRefreshTick),
            future: _fetchCycleTimeAnalytics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? cycleTimeAnalytics;
              final byStage = (data?['by_stage'] as List?) ?? [];

              final totalSamples = byStage.fold<int>(0, (sum, item) {
                if (item is Map) {
                  final s = item['samples'];
                  if (s is int) return sum + s;
                  if (s is num) return sum + s.toInt();
                }
                return sum;
              });

              if (byStage.isEmpty || totalSamples == 0) {
                return Center(
                  child: Text(
                    'No proposals found for these filters.',
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                );
              }

              return _buildCycleTimeCards(byStage, data?['bottleneck']);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCycleTimeFilterBar() {
    Widget glassField({required Widget child}) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: child,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        glassField(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _cycleTimeScope,
              dropdownColor: const Color(0xFF0A0E27),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'team', child: Text('Team')),
                DropdownMenuItem(value: 'self', child: Text('My')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _cycleTimeScope = v;
                  _cycleTimeRefreshTick++;
                });
              },
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: glassField(
            child: TextField(
              controller: _cycleTimeOwnerCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Owner (optional)',
                hintStyle: TextStyle(color: Colors.white54),
              ),
              onSubmitted: (_) => setState(() => _cycleTimeRefreshTick++),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: glassField(
            child: TextField(
              controller: _cycleTimeProposalTypeCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Proposal type (optional)',
                hintStyle: TextStyle(color: Colors.white54),
              ),
              onSubmitted: (_) => setState(() => _cycleTimeRefreshTick++),
            ),
          ),
        ),
        glassField(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Auto',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(width: 6),
              Switch(
                value: _cycleTimeAutoRefresh,
                onChanged: (v) {
                  setState(() {
                    _cycleTimeAutoRefresh = v;
                    _cycleTimeRefreshTick++;
                  });
                },
              ),
            ],
          ),
        ),
        glassField(
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
            onPressed: () => setState(() => _cycleTimeRefreshTick++),
            tooltip: 'Refresh',
          ),
        ),
      ],
    );
  }

  Widget _buildCycleTimeCards(
      List<dynamic> byStage, Map<String, dynamic>? bottleneck) {
    String formatDays(num? days) {
      if (days == null) return '-';
      if (days < 1) {
        final hours = days * 24;
        if (hours < 1) {
          final minutes = hours * 60;
          return '${minutes.toStringAsFixed(0)} min';
        }
        return '${hours.toStringAsFixed(1)} h';
      }
      return '${days.toStringAsFixed(1)} d';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bottleneck != null) ...[
          Text(
            'Current Bottleneck: ${bottleneck['stage']}',
            style: PremiumTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: byStage.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = byStage[index] as Map<String, dynamic>;
              final stage = item['stage']?.toString() ?? 'Unknown';
              final avgDays = item['avg_days'] as num?;
              final samples = item['samples'] as int? ?? 0;
              final bottleneckStage = bottleneck?['stage']?.toString();
              final isBottleneck =
                  bottleneckStage != null && bottleneckStage == stage;
              return Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isBottleneck
                        ? const Color(0xFFE74C3C)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isBottleneck ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatDays(avgDays),
                      style: PremiumTheme.displayMedium.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$samples samples',
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: PremiumTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToPage(BuildContext context, String label) {
    final isAdminUser = _isAdminUser();

    if (isAdminUser) {
      switch (label) {
        case 'Dashboard':
          Navigator.pushReplacementNamed(context, '/approver_dashboard');
          break;
        case 'Approvals':
          Navigator.pushReplacementNamed(context, '/admin_approvals');
          break;
        case 'My Proposals':
          Navigator.pushReplacementNamed(context, '/proposals');
          break;
        case 'Templates':
          Navigator.pushReplacementNamed(context, '/templates');
          break;
        case 'Content Library':
          Navigator.pushReplacementNamed(context, '/content_library');
          break;
        case 'Client Management':
          Navigator.pushReplacementNamed(context, '/client_management');
          break;
        case 'Analytics':
          // Already on analytics for admin
          break;
        case 'Approved Proposals':
          Navigator.pushReplacementNamed(context, '/admin_approvals');
          break;
        case 'Analytics (My Pipeline)':
          // Already here (legacy label)
          break;
        case 'Logout':
          AuthService.logout();
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (Route<dynamic> route) => false);
          break;
      }
    } else {
      switch (label) {
        case 'Dashboard':
          Navigator.pushReplacementNamed(context, '/creator_dashboard');
          break;
        case 'My Proposals':
          Navigator.pushReplacementNamed(context, '/proposals');
          break;
        case 'Templates':
          Navigator.pushReplacementNamed(context, '/templates');
          break;
        case 'Content Library':
          Navigator.pushReplacementNamed(context, '/content_library');
          break;
        case 'Client Management':
          Navigator.pushReplacementNamed(context, '/client_management');
          break;
        case 'Approved Proposals':
          Navigator.pushReplacementNamed(context, '/approved_proposals');
          break;
        case 'Analytics (My Pipeline)':
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
}

class _AnalyticsSnapshot {
  final double totalPipelineValue;
  final int totalProposals;
  final int activeProposals;
  final double averageDealSize;
  final double winRate;
  final double lossRate;
  final Map<String, int> statusCounts;
  final List<_MonthlyPoint> monthlyPoints;
  final List<_ProposalPerformanceRow> recentProposals;
  final double? revenueChangePercent;
  final double? activeChangePercent;
  final double? conversionChangePercent;
  final double? averageDealChangePercent;

  const _AnalyticsSnapshot({
    required this.totalPipelineValue,
    required this.totalProposals,
    required this.activeProposals,
    required this.averageDealSize,
    required this.winRate,
    required this.lossRate,
    required this.statusCounts,
    required this.monthlyPoints,
    required this.recentProposals,
    required this.revenueChangePercent,
    required this.activeChangePercent,
    required this.conversionChangePercent,
    required this.averageDealChangePercent,
  });
}

class _MonthlyPoint {
  final DateTime month;
  double revenue;
  int proposals;
  int wins;
  int losses;

  _MonthlyPoint(this.month)
      : revenue = 0,
        proposals = 0,
        wins = 0,
        losses = 0;

  String get label => DateFormat('MMM').format(month);
}

class _ProposalPerformanceRow {
  final String title;
  final double? value;
  final String valueLabel;
  final String status;
  final int daysOpen;
  final double probability;
  final Color statusColor;
  final DateTime? updatedAt;

  _ProposalPerformanceRow({
    required this.title,
    required this.value,
    required this.valueLabel,
    required this.status,
    required this.daysOpen,
    required this.probability,
    required this.statusColor,
    required this.updatedAt,
  });

  String get probabilityLabel => '${(probability * 100).round()}%';
}

class _MetricCardData {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final String subtitle;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.subtitle,
  });
}
