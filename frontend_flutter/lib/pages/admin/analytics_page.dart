import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/custom_scrollbar.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _loading = true;
  String _scope = 'self';
  String _period = '30d';

  final TextEditingController _ownerCtrl = TextEditingController();
  final TextEditingController _clientCtrl = TextEditingController();
  final TextEditingController _proposalTypeCtrl = TextEditingController();

  DateTime? _customStart;
  DateTime? _customEnd;
  bool _useCustomDates = false;

  Map<String, dynamic>? _pipeline;
  Map<String, dynamic>? _cycleTime;
  Map<String, dynamic>? _completion;
  Map<String, dynamic>? _engagement;
  Map<String, dynamic>? _collaboration;
  Map<String, dynamic>? _riskGateSummary;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _clientCtrl.dispose();
    _proposalTypeCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime? _periodStart(DateTime now) {
    switch (_period) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case '90d':
        return now.subtract(const Duration(days: 90));
      case 'ytd':
        return DateTime(now.year, 1, 1);
      case 'all':
        return null;
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
    });

    try {
      final app = context.read<AppState>();
      final now = DateTime.now();
      final fmt = DateFormat('yyyy-MM-dd');

      final owner = _ownerCtrl.text.trim();
      final client = _clientCtrl.text.trim();
      final proposalType = _proposalTypeCtrl.text.trim();

      final DateTime? start = _useCustomDates ? _customStart : _periodStart(now);
      final DateTime end = _useCustomDates ? (_customEnd ?? now) : now;
      final startDate = start == null ? null : fmt.format(start);
      final endDate = fmt.format(end);

      final user = AuthService.currentUser ?? app.currentUser;
      final department = (user?['department'] ?? '').toString().trim();

      final results = await Future.wait([
        app.getProposalPipelineAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          client: client.isEmpty ? null : client,
          proposalType: proposalType.isEmpty ? null : proposalType,
          scope: _scope,
          department: department.isEmpty ? null : department,
        ),
        app.getCycleTimeAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          client: client.isEmpty ? null : client,
          proposalType: proposalType.isEmpty ? null : proposalType,
          scope: _scope,
          department: department.isEmpty ? null : department,
        ),
        app.getCompletionRatesAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          client: client.isEmpty ? null : client,
          proposalType: proposalType.isEmpty ? null : proposalType,
          scope: _scope,
          department: department.isEmpty ? null : department,
        ),
        app.getClientEngagementAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          client: client.isEmpty ? null : client,
          proposalType: proposalType.isEmpty ? null : proposalType,
          scope: _scope,
          department: department.isEmpty ? null : department,
        ),
        app.getCollaborationLoadAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          client: client.isEmpty ? null : client,
          proposalType: proposalType.isEmpty ? null : proposalType,
          scope: _scope,
          department: department.isEmpty ? null : department,
        ),
        app.getRiskGateSummary(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          client: client.isEmpty ? null : client,
          proposalType: proposalType.isEmpty ? null : proposalType,
          scope: _scope,
          department: department.isEmpty ? null : department,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _pipeline = results[0];
        _cycleTime = results[1];
        _completion = results[2];
        _engagement = results[3];
        _collaboration = results[4];
        _riskGateSummary = results[5];
      });
    } catch (e) {
      // Keep UI alive even if a call fails.
      if (!mounted) return;
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PremiumTheme.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: PremiumTheme.labelMedium.copyWith(color: Colors.white60),
          ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _coerceListOfMaps(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(item);
      } else if (item is Map) {
        out.add(item.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  Color _riskColor(String level) {
    final v = level.trim().toUpperCase();
    if (v == 'BLOCK') return const Color(0xFFEF4444);
    if (v == 'REVIEW') return const Color(0xFFF59E0B);
    if (v == 'PASS') return const Color(0xFF22C55E);
    return Colors.white54;
  }

  String _formatDateLabel(DateTime d) {
    return DateFormat('yyyy-MM-dd').format(d);
  }

  Future<void> _pickStartDate() async {
    final initial = _customStart ?? DateTime.now().subtract(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2018, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _customStart = picked;
      _useCustomDates = true;
    });
  }

  Future<void> _pickEndDate() async {
    final initial = _customEnd ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2018, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _customEnd = picked;
      _useCustomDates = true;
    });
  }

  Future<void> _exportReport() async {
    final payload = {
      'filters': {
        'scope': _scope,
        'period': _period,
        'owner': _ownerCtrl.text.trim(),
        'client': _clientCtrl.text.trim(),
        'proposal_type': _proposalTypeCtrl.text.trim(),
        'custom_start': _customStart?.toIso8601String(),
        'custom_end': _customEnd?.toIso8601String(),
        'use_custom_dates': _useCustomDates,
      },
      'pipeline': _pipeline,
      'cycle_time': _cycleTime,
      'completion_rates': _completion,
      'client_engagement': _engagement,
      'collaboration_load': _collaboration,
      'risk_gate_summary': _riskGateSummary,
      'exported_at': DateTime.now().toIso8601String(),
    };

    final text = payload.toString();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analytics report copied to clipboard')),
    );
  }

  Widget _buildFiltersBar() {
    final startLabel = _customStart == null ? 'Start date' : _formatDateLabel(_customStart!);
    final endLabel = _customEnd == null ? 'End date' : _formatDateLabel(_customEnd!);

    InputDecoration deco(String hint) {
      return InputDecoration(
        hintText: hint,
        hintStyle: PremiumTheme.labelMedium.copyWith(color: Colors.white38),
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      );
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Filters', subtitle: 'Slice by owner, client, type, or date range'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _ownerCtrl,
                  style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                  decoration: deco('Owner (username/email/id)'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _clientCtrl,
                  style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                  decoration: deco('Client'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _proposalTypeCtrl,
                  style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                  decoration: deco('Proposal type'),
                ),
              ),
              SizedBox(
                width: 170,
                child: ElevatedButton.icon(
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(startLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: ElevatedButton.icon(
                  onPressed: _pickEndDate,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(endLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(
                width: 130,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _useCustomDates = false;
                      _customStart = null;
                      _customEnd = null;
                    });
                    _refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    foregroundColor: Colors.white70,
                  ),
                  child: const Text('Reset dates'),
                ),
              ),
              SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: _refresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskGateCard() {
    final overall = (_riskGateSummary?['overall_level'] ?? 'NONE').toString();
    final counts = (_riskGateSummary?['counts'] is Map) ? (_riskGateSummary?['counts'] as Map) : const {};
    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final pass = n(counts['PASS']);
    final review = n(counts['REVIEW']);
    final block = n(counts['BLOCK']);
    final none = n(counts['NONE']);
    final total = (_riskGateSummary?['total_proposals'] is num)
        ? (_riskGateSummary?['total_proposals'] as num).toInt()
        : (pass + review + block + none);
    final analyzed = (_riskGateSummary?['analyzed_proposals'] is num)
        ? (_riskGateSummary?['analyzed_proposals'] as num).toInt()
        : (pass + review + block);

    final color = _riskColor(overall);

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Risk Gate', subtitle: 'Governance risk status summary'),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  overall.toUpperCase(),
                  style: PremiumTheme.labelMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Analyzed: $analyzed / $total',
                  style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpiTile(label: 'PASS', value: pass.toString()),
              _kpiTile(label: 'REVIEW', value: review.toString()),
              _kpiTile(label: 'BLOCK', value: block.toString()),
              _kpiTile(label: 'NONE', value: none.toString()),
            ].map((w) => SizedBox(width: 160, child: w)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCollaborationHeatmap() {
    final heatmap = (_collaboration?['heatmap'] is Map)
        ? (_collaboration?['heatmap'] as Map)
        : null;
    final byDay = _coerceListOfMaps(heatmap?['by_day']);
    if (byDay.isEmpty) {
      return Text(
        'No collaboration heatmap data yet.',
        style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
      );
    }

    final counts = <String, int>{};
    for (final p in byDay) {
      final date = (p['date'] ?? '').toString();
      final interactions = (p['interactions'] is num)
          ? (p['interactions'] as num).toInt()
          : 0;
      if (date.isEmpty) continue;
      counts[date] = interactions;
    }

    final keys = counts.keys.toList()..sort();
    final lastKeys = keys.length <= 28 ? keys : keys.sublist(keys.length - 28);
    final maxVal = counts.values.fold<int>(0, (p, e) => math.max(p, e));

    Color cellColor(int v) {
      if (v <= 0) return Colors.white.withValues(alpha: 0.06);
      final denom = maxVal <= 0 ? 1 : maxVal;
      final t = (v / denom).clamp(0.0, 1.0);
      final a = 0.16 + (0.62 * t);
      return const Color(0xFF06B6D4).withValues(alpha: a);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final k in lastKeys)
          Tooltip(
            message: '$k: ${counts[k] ?? 0} interactions',
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: cellColor(counts[k] ?? 0),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPipelineFunnel() {
    final stages = _coerceListOfMaps(_pipeline?['stages']);
    final items = <Map<String, dynamic>>[];
    for (final s in stages) {
      final stage = (s['stage'] ?? '').toString();
      final count = (s['count'] is num) ? (s['count'] as num).toInt() : 0;
      if (stage.isEmpty) continue;
      items.add({'stage': stage, 'count': count});
    }
    if (items.isEmpty) {
      return Text(
        'No pipeline data yet for this period.',
        style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
      );
    }

    final maxCount = items.fold<int>(1, (p, e) => math.max(p, (e['count'] as int?) ?? 0));

    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth;
        final baseWidth = math.max(220.0, math.min(full, 720.0));

        return Column(
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FunnelStage(
                  label: items[i]['stage'] as String,
                  value: items[i]['count'] as int,
                  width: baseWidth * (((items[i]['count'] as int) / maxCount).clamp(0.15, 1.0)),
                  color: const Color(0xFF06B6D4),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPipelineChart() {
    return _buildPipelineFunnel();
  }

  Widget _buildCycleTimeChart() {
    final byStage = _coerceListOfMaps(_cycleTime?['by_stage']);
    final labels = <String>[];
    final values = <double>[];
    for (final s in byStage) {
      final stage = (s['stage'] ?? s['status'] ?? '').toString();
      final avg = (s['avg_days'] is num)
          ? (s['avg_days'] as num).toDouble()
          : (s['avg'] is num)
              ? (s['avg'] as num).toDouble()
              : null;
      if (stage.isEmpty || avg == null) continue;
      labels.add(stage);
      values.add(avg);
    }
    if (labels.isEmpty) {
      return Text(
        'No cycle time data yet for this period.',
        style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
      );
    }

    final maxY = values.fold<double>(0, (p, e) => math.max(p, e));
    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY <= 0 ? 1 : maxY * 1.25,
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: PremiumTheme.labelMedium.copyWith(
                      color: Colors.white54,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[i],
                      style: PremiumTheme.labelMedium.copyWith(
                        color: Colors.white54,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                  toY: values[i],
                  width: 18,
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCompletionSummary() {
    final totals = (_completion?['totals'] is Map) ? (_completion?['totals'] as Map) : null;
    final passRate = totals?['pass_rate'];
    final passed = totals?['passed'] ?? 0;
    final total = totals?['total'] ?? 0;

    final rateLabel = passRate is num ? '${passRate.toStringAsFixed(0)}%' : '--';
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Completion rate', subtitle: 'Readiness score pass rate'),
          const SizedBox(height: 10),
          Text(
            rateLabel,
            style: PremiumTheme.displayMedium.copyWith(
              color: Colors.white,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$passed / $total',
            style: PremiumTheme.labelMedium.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _kpiTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: PremiumTheme.labelMedium.copyWith(color: Colors.white60)),
          const SizedBox(height: 6),
          Text(
            value,
            style: PremiumTheme.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementSection() {
    final viewsTotal = (_engagement?['views_total'] is num)
        ? (_engagement?['views_total'] as num).toInt()
        : 0;
    final uniqueClients = (_engagement?['unique_clients'] is num)
        ? (_engagement?['unique_clients'] as num).toInt()
        : 0;
    final sessions = (_engagement?['sessions_count'] is num)
        ? (_engagement?['sessions_count'] as num).toInt()
        : 0;
    final timeSpentSeconds = (_engagement?['time_spent_seconds'] is num)
        ? (_engagement?['time_spent_seconds'] as num).toInt()
        : 0;
    final timeToSign = (_engagement?['time_to_sign'] is Map)
        ? (_engagement?['time_to_sign'] as Map)
        : null;
    final ttsSamples = (timeToSign?['samples'] is num)
        ? (timeToSign?['samples'] as num).toInt()
        : 0;
    final ttsAvgDays = (timeToSign?['avg_days'] is num)
        ? (timeToSign?['avg_days'] as num).toDouble()
        : null;

    final conversion = (_engagement?['conversion'] is Map)
        ? (_engagement?['conversion'] as Map)
        : null;
    final released = (conversion?['released'] is num)
        ? (conversion?['released'] as num).toInt()
        : 0;
    final signed = (conversion?['signed'] is num)
        ? (conversion?['signed'] as num).toInt()
        : 0;
    final convRate = (conversion?['rate_percent'] is num)
        ? (conversion?['rate_percent'] as num).toDouble()
        : null;

    String fmtHours(int secs) {
      if (secs <= 0) return '0h';
      final hours = secs / 3600.0;
      if (hours >= 1.0) return '${hours.toStringAsFixed(1)}h';
      final mins = secs / 60.0;
      return '${mins.toStringAsFixed(0)}m';
    }

    final rawByDay = _coerceListOfMaps(_engagement?['views_by_day']);
    final spots = <FlSpot>[];
    for (var i = 0; i < rawByDay.length; i++) {
      final m = rawByDay[i];
      final v = (m['views'] is num)
          ? (m['views'] as num).toDouble()
          : (m['count'] is num)
              ? (m['count'] as num).toDouble()
              : 0.0;
      spots.add(FlSpot(i.toDouble(), v));
    }
    final maxY = spots.isEmpty
        ? 1.0
        : spots.fold<double>(0.0, (p, e) => math.max(p, e.y)) * 1.25;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Client engagement',
              subtitle: 'Views, time spent, and conversion'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 760;
              final tiles = [
                _kpiTile(label: 'Views', value: viewsTotal.toString()),
                _kpiTile(label: 'Unique clients', value: uniqueClients.toString()),
                _kpiTile(label: 'Sessions', value: sessions.toString()),
                _kpiTile(label: 'Time spent', value: fmtHours(timeSpentSeconds)),
                _kpiTile(
                  label: 'Time to sign',
                  value: ttsAvgDays == null
                      ? '--'
                      : '${ttsAvgDays.toStringAsFixed(1)}d ($ttsSamples)',
                ),
                _kpiTile(
                  label: 'Conversion',
                  value: convRate == null
                      ? '$signed/$released'
                      : '${convRate.toStringAsFixed(1)}% ($signed/$released)',
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: [
                    for (final t in tiles) ...[
                      t,
                      const SizedBox(height: 10),
                    ]
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tiles
                    .map((t) => SizedBox(width: 230, child: t))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: rawByDay.isEmpty
                ? Text(
                    'No daily views yet for this period.',
                    style:
                        PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withValues(alpha: 0.08),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles:
                            AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      minY: 0,
                      maxY: maxY <= 0 ? 1 : maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 3,
                          color: const Color(0xFF22C55E),
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: 0.12),
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

  Widget _buildCollaborationSection() {
    final totals = (_collaboration?['totals'] is Map)
        ? (_collaboration?['totals'] as Map)
        : null;
    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    final totalProposals = n(_collaboration?['total_proposals']);
    final comments = n(totals?['comments']);
    final versions = n(totals?['versions']);
    final approvals = n(totals?['approvals']);
    final reviewers = n(totals?['reviewers']);
    final activity = n(totals?['activity_events']);
    final interactions = n(totals?['interactions']);

    final turnaround = (_collaboration?['reviewer_turnaround'] is Map)
        ? (_collaboration?['reviewer_turnaround'] as Map)
        : null;
    final turnaroundSamples = n(turnaround?['samples']);
    final turnaroundAvgDays = (turnaround?['avg_days'] is num)
        ? (turnaround?['avg_days'] as num).toDouble()
        : null;

    final highLoad = (_collaboration?['high_load'] is Map)
        ? (_collaboration?['high_load'] as Map)
        : null;
    final highLoadCount = n(highLoad?['count']);
    final highLoadThreshold = n(highLoad?['threshold']);

    final top = _coerceListOfMaps(_collaboration?['top_proposals']);

    String fmtDays(double? days) {
      if (days == null) return '--';
      if (days >= 1) return '${days.toStringAsFixed(1)}d';
      final hours = days * 24.0;
      if (hours >= 1) return '${hours.toStringAsFixed(1)}h';
      final minutes = hours * 60.0;
      return '${minutes.toStringAsFixed(0)}m';
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Collaboration load',
              subtitle: 'Comments, versions, approvals, activity'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                  width: 220,
                  child: _kpiTile(label: 'Proposals', value: '$totalProposals')),
              SizedBox(
                  width: 220,
                  child: _kpiTile(label: 'Interactions', value: '$interactions')),
              SizedBox(
                  width: 220,
                  child: _kpiTile(label: 'Comments', value: '$comments')),
              SizedBox(
                  width: 220,
                  child: _kpiTile(label: 'Versions', value: '$versions')),
              SizedBox(
                  width: 220,
                  child: _kpiTile(label: 'Approvals', value: '$approvals')),
              SizedBox(
                  width: 220,
                  child: _kpiTile(label: 'Reviewers', value: '$reviewers')),
              SizedBox(
                  width: 220,
                  child: _kpiTile(label: 'Activity', value: '$activity')),
              SizedBox(
                width: 220,
                child: _kpiTile(
                  label: 'Turnaround',
                  value: '${fmtDays(turnaroundAvgDays)} ($turnaroundSamples)',
                ),
              ),
              SizedBox(
                width: 220,
                child: _kpiTile(
                  label: 'High-load',
                  value: highLoadCount <= 0
                      ? '0'
                      : '$highLoadCount (≥$highLoadThreshold)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Heatmap (last 28 days)',
            style: PremiumTheme.titleMedium.copyWith(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildCollaborationHeatmap(),
          const SizedBox(height: 14),
          Text(
            'Top active proposals',
            style: PremiumTheme.titleMedium.copyWith(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (top.isEmpty)
            Text(
              'No collaboration activity found for this period.',
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
            )
          else
            Column(
              children: [
                for (final p in top.take(8))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (p['title'] ?? 'Untitled').toString(),
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(p['interactions'] ?? 0)} interactions',
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = AuthService.currentUser ?? app.currentUser;
    final role = (user?['role'] ?? '').toString().toLowerCase().trim();
    final isAdmin = role == 'admin' || role == 'ceo';

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Row(
        children: [
          AppSideNav(
            isCollapsed: app.isSidebarCollapsed,
            currentLabel: app.currentNavLabel,
            isAdmin: isAdmin,
            isLightMode: app.isLightMode,
            onToggleThemeMode: app.toggleThemeMode,
            onToggle: app.toggleSidebar,
            onSelect: (label) {
              app.setCurrentNavLabel(label);
              if (label.toLowerCase().contains('analytics')) {
                Navigator.pushNamed(context, '/analytics');
              }
            },
          ),
          Expanded(
            child: CustomScrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Analytics',
                            style: PremiumTheme.displayMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _scope,
                            dropdownColor: const Color(0xFF0B1220),
                            style: PremiumTheme.labelMedium
                                .copyWith(color: Colors.white),
                            items: const [
                              DropdownMenuItem(
                                  value: 'self', child: Text('My data')),
                              DropdownMenuItem(
                                  value: 'team', child: Text('Team')),
                              DropdownMenuItem(
                                  value: 'all', child: Text('All')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _scope = v;
                              });
                              _refresh();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _period,
                            dropdownColor: const Color(0xFF0B1220),
                            style: PremiumTheme.labelMedium
                                .copyWith(color: Colors.white),
                            items: const [
                              DropdownMenuItem(
                                  value: '7d', child: Text('7 days')),
                              DropdownMenuItem(
                                  value: '30d', child: Text('30 days')),
                              DropdownMenuItem(
                                  value: '90d', child: Text('90 days')),
                              DropdownMenuItem(
                                  value: 'ytd', child: Text('YTD')),
                              DropdownMenuItem(
                                  value: 'all', child: Text('All time')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _period = v;
                              });
                              _refresh();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/new-proposal');
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Proposal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _exportReport,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Export'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _refresh,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BCD4),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildFiltersBar(),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 860) {
                          return Column(
                            children: [
                              _buildCompletionSummary(),
                              const SizedBox(height: 18),
                              _buildRiskGateCard(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildCompletionSummary()),
                            const SizedBox(width: 18),
                            Expanded(child: _buildRiskGateCard()),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Pipeline',
                              subtitle: 'Proposals by stage'),
                          const SizedBox(height: 12),
                          _buildPipelineChart(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Cycle time',
                              subtitle: 'Average days by stage'),
                          const SizedBox(height: 12),
                          _buildCycleTimeChart(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildEngagementSection(),
                    const SizedBox(height: 18),
                    _buildCollaborationSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelStage extends StatelessWidget {
  const _FunnelStage({
    required this.label,
    required this.value,
    required this.width,
    required this.color,
  });

  final String label;
  final int value;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/*

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final industry = _globalIndustryCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getCollaborationLoadAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            industry: industry.isEmpty ? null : industry,
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
    final approvals = n(totals['approvals']);
    final reviewers = n(totals['reviewers']);
    final events = n(totals['activity_events']);
    final interactions = n(totals['interactions']);

    final top = (data?['top_proposals'] as List?) ?? [];

    final reviewerTurnaround = (data?['reviewer_turnaround'] as Map?) ?? {};
    final turnaroundSamples = n(reviewerTurnaround['samples']);
    final turnaroundAvgDays = (reviewerTurnaround['avg_days'] is num)
        ? (reviewerTurnaround['avg_days'] as num).toDouble()
        : null;

    final heatmap = (data?['heatmap'] as Map?) ?? {};
    final heatmapByDay = (heatmap['by_day'] as List?) ?? const [];

    final highLoad = (data?['high_load'] as Map?) ?? {};
    final highLoadThreshold = n(highLoad['threshold']);
    final highLoadCount = n(highLoad['count']);
    final highLoadProposals = (highLoad['proposals'] as List?) ?? const [];

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

    String fmtDays(double? days) {
      if (days == null) return '--';
      if (days >= 1.0) return '${days.toStringAsFixed(1)}d';
      final hours = days * 24.0;
      if (hours >= 1.0) return '${hours.toStringAsFixed(1)}h';
      final minutes = hours * 60.0;
      return '${minutes.toStringAsFixed(0)}m';
    }

    Widget buildHeatmap() {
      if (heatmapByDay.isEmpty) {
        return Text(
          'No collaboration heatmap data yet.',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        );
      }

      final points = <Map<String, dynamic>>[];
      for (final raw in heatmapByDay) {
        if (raw is Map) {
          points.add({
            'date': (raw['date'] ?? '').toString(),
            'interactions': n(raw['interactions']),
          });
        }
      }
      if (points.isEmpty) {
        return Text(
          'No collaboration heatmap data yet.',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        );
      }

      final maxVal =
          points.fold<int>(0, (p, e) => math.max(p, n(e['interactions'])));
      final squares = points.take(28).toList();

      Color cellColor(int v) {
        if (v <= 0) return Colors.white.withValues(alpha: 0.06);
        final denom = maxVal <= 0 ? 1 : maxVal;
        final t = (v / denom).clamp(0.0, 1.0);
        final a = 0.14 + (0.55 * t);
        return PremiumTheme.teal.withValues(alpha: a);
      }

      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final p in squares)
            Tooltip(
              message: '${p['date']}: ${n(p['interactions'])} interactions',
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: cellColor(n(p['interactions'])),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
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
              statChip('Approvals', approvals, PremiumTheme.success),
              statChip('Reviewers', reviewers, Colors.white70),
              statChip('Activity', events, PremiumTheme.info),
              statChip('Proposals', totalProposals, Colors.white70),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reviewer turnaround: ${fmtDays(turnaroundAvgDays)}'
                  ' (${turnaroundSamples.toString()} sample${turnaroundSamples == 1 ? '' : 's'})',
                  style:
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              if (highLoadCount > 0)
                Text(
                  'High-load: $highLoadCount (≥$highLoadThreshold)',
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: PremiumTheme.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          buildHeatmap(),
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
                  final rowComments = n(row['comments']);
                  final rowVersions = n(row['versions']);
                  final rowApprovals = n(row['approvals']);
                  final rowReviewers = n(row['reviewers']);
                  final isHighLoad = (row['high_load'] == true);

                  return InkWell(
                    onTap: () {
                      _openProposalFromAnalytics(id: id, title: title);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
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
                            width: 170,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  rowInteractions.toString(),
                                  style: PremiumTheme.bodyMedium.copyWith(
                                    color: isHighLoad
                                        ? PremiumTheme.warning
                                        : Colors.white70,
                                    fontWeight: isHighLoad
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'C$rowComments  V$rowVersions  A$rowApprovals  R$rowReviewers',
                                  style: PremiumTheme.bodySmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (highLoadProposals.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'High-load proposals',
              style: PremiumTheme.titleMedium.copyWith(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                itemCount: math.min(5, highLoadProposals.length),
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                itemBuilder: (context, i) {
                  final row = highLoadProposals[i];
                  final title = (row['title'] ?? 'Untitled').toString();
                  final value = n(row['interactions']);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: PremiumTheme.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          value.toString(),
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: PremiumTheme.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cycleTimeRefreshTimer?.cancel();
    _cycleTimeOwnerCtrl.dispose();
    _cycleTimeProposalTypeCtrl.dispose();
    _globalClientCtrl.dispose();
    _globalRegionCtrl.dispose();
    _globalIndustryCtrl.dispose();
    _globalOwnerCtrl.dispose();
    _globalProposalTypeCtrl.dispose();
    super.dispose();
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
      final industry = _globalIndustryCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getRiskGateSummary(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            industry: industry.isEmpty ? null : industry,
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
      final industry = _globalIndustryCtrl.text.trim();
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
                                industry: industry.isEmpty ? null : industry,
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
                                final readiness = p['readiness_score'];
                                final issuesCount = p['issues_count'];
                                final canRelease = (p['can_release'] == true);

                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _openProposalFromAnalytics(
                                      id: id,
                                      title: title,
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
                                              color: canRelease
                                                  ? Colors.white70
                                                  : PremiumTheme.error,
                                              fontWeight: canRelease
                                                  ? FontWeight.w500
                                                  : FontWeight.w700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 160,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
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
                                              const SizedBox(height: 2),
                                              Text(
                                                'Ready: ${readiness ?? '--'}%  •  Issues: ${issuesCount ?? 0}',
                                                style: PremiumTheme.bodySmall
                                                    .copyWith(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.55),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                              ),
                                            ],
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

    final avgReadiness = (data?['avg_readiness_score'] is num)
        ? (data?['avg_readiness_score'] as num).toInt()
        : null;
    final issuesSummary = (data?['issues_summary'] as Map?) ?? {};
    final issuesTotal = (issuesSummary['total'] is num)
        ? (issuesSummary['total'] as num).toInt()
        : 0;
    final proposalsWithIssues = (issuesSummary['proposals_with_issues'] is num)
        ? (issuesSummary['proposals_with_issues'] as num).toInt()
        : 0;

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
          'Readiness: ${avgReadiness == null ? "--" : "$avgReadiness%"}  •  Issues: $issuesTotal'
          '${proposalsWithIssues > 0 ? " across $proposalsWithIssues proposal${proposalsWithIssues == 1 ? "" : "s"}" : ""}',
          style: PremiumTheme.bodyMedium.copyWith(
            color: Colors.white70,
          ),
          overflow: TextOverflow.ellipsis,
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
    final industryQ = _globalIndustryCtrl.text.trim().toLowerCase();

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

      if (industryQ.isNotEmpty) {
        final ok = matchesAny(p['industry'], industryQ) ||
            matchesAny(p['client_industry'], industryQ) ||
            matchesAny(p['clientIndustry'], industryQ);
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
        SizedBox(
          width: 220,
          child: glassField(
            child: TextField(
              controller: _globalRegionCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Region (optional)',
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
              controller: _globalIndustryCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Industry (optional)',
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
                    _globalRegionCtrl.clear();
                    _globalIndustryCtrl.clear();
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

  Widget _buildCompletionRateGauge(Map<String, dynamic>? data) {
    final totals = (data?['totals'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final total =
        (totals['total'] is num) ? (totals['total'] as num).toInt() : 0;
    final passed =
        (totals['passed'] is num) ? (totals['passed'] as num).toInt() : 0;
    final passRateRaw = totals['pass_rate'];
    int passRate = 0;
    if (passRateRaw is num) {
      final v = passRateRaw.toDouble();
      passRate = (v <= 1.0) ? (v * 100).round() : v.round();
    }
    final ratio = (passRate / 100.0).clamp(0.0, 1.0);

    return Center(
      child: InkWell(
        onTap: () => _showCompletionRatesDialog(data),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 180.0;
            final maxH =
                constraints.maxHeight.isFinite ? constraints.maxHeight : 180.0;
            final size = math.max(48.0, math.min(180.0, math.min(maxW, maxH)));
            final compact = size < 140;

            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: compact ? 10 : 12,
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        passRate >= 90
                            ? PremiumTheme.success
                            : passRate >= 60
                                ? PremiumTheme.warning
                                : PremiumTheme.error,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(compact ? 6 : 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$passRate%',
                            style: PremiumTheme.displayMedium
                                .copyWith(fontSize: compact ? 26 : 34),
                          ),
                        ),
                        SizedBox(height: compact ? 4 : 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$passed of $total passing',
                            style: PremiumTheme.bodyMedium.copyWith(
                              color: PremiumTheme.textSecondary,
                              fontSize: compact ? 11 : null,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 4 : 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Tap to drill down',
                            style: PremiumTheme.bodySmall.copyWith(
                              color: Colors.white70,
                              fontSize: compact ? 10 : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 900;
                                  if (compact) {
                                    return Column(
                                      children: [
                                        for (int i = 0;
                                            i < metrics.length;
                                            i++) ...[
                                          _buildGlassMetricCard(
                                            metrics[i].title,
                                            metrics[i].value,
                                            metrics[i].change,
                                            metrics[i].isPositive,
                                            metrics[i].subtitle,
                                          ),
                                          if (i != metrics.length - 1)
                                            const SizedBox(height: 20),
                                        ],
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      for (int i = 0;
                                          i < metrics.length;
                                          i++) ...[
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
                                  );
                                },
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
                                    child: FutureBuilder<Map<String, dynamic>?>(
                                      key: ValueKey(
                                          'pipeline_bundle_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_cycleTimeScope}_${_globalClientCtrl.text}_${_globalIndustryCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}_${_pipelineStageFilter ?? ''}'),
                                      future: _fetchPipelineBundle(),
                                      builder: (context, snapshot) {
                                        final waiting =
                                            snapshot.connectionState ==
                                                ConnectionState.waiting;
                                        final hasError = snapshot.hasError;
                                        final bundle = snapshot.data;
                                        final pipelineData =
                                            (bundle?['pipeline'] as Map?)
                                                ?.cast<String, dynamic>();
                                        final completionData =
                                            (bundle?['completion_rates']
                                                    as Map?)
                                                ?.cast<String, dynamic>();

                                        Widget pipelineBody;
                                        if (waiting) {
                                          pipelineBody = const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        } else if (hasError) {
                                          pipelineBody = Center(
                                            child: Text(
                                              'Failed to load pipeline view.',
                                              style: PremiumTheme.bodyMedium
                                                  .copyWith(
                                                      color: Colors.white70),
                                            ),
                                          );
                                        } else if (pipelineData == null) {
                                          pipelineBody = Center(
                                            child: Text(
                                              'Failed to load pipeline view.',
                                              style: PremiumTheme.bodyMedium
                                                  .copyWith(
                                                      color: Colors.white70),
                                            ),
                                          );
                                        } else {
                                          pipelineBody =
                                              _buildProposalPipelineView(
                                                  pipelineData);
                                        }

                                        Widget completionBody;
                                        if (waiting) {
                                          completionBody = const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        } else if (hasError ||
                                            completionData == null) {
                                          completionBody = Center(
                                            child: Text(
                                              'Failed to load completion rates.',
                                              style: PremiumTheme.bodyMedium
                                                  .copyWith(
                                                      color: Colors.white70),
                                            ),
                                          );
                                        } else {
                                          completionBody =
                                              _buildCompletionRateGauge(
                                                  completionData);
                                        }

                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: _buildGlassChartCard(
                                                'Proposal Pipeline View',
                                                pipelineBody,
                                                height: 520,
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: _buildGlassChartCard(
                                                'Completion Rate',
                                                completionBody,
                                                height: 520,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
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
                                      'risk_gate_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalIndustryCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}'),
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
                                      'collab_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalIndustryCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}'),
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
                                      'engagement_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_globalClientCtrl.text}_${_globalIndustryCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}'),
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

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
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
              Icons.analytics,
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
                  'Analytics Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
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

  Widget _buildAnalyticsContent() {
    if (_proposals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'No proposal data available',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Proposal data will appear here once available.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
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
      final client = _globalClientCtrl.text.trim();
      final industry = _globalIndustryCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      final data = await context.read<AppState>().getCycleTimeAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            industry: industry.isEmpty ? null : industry,
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
              dropdownColor: const Color(0xFF1A1F26),
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'signed':
      case 'approved':
        return Colors.green;
      case 'in review':
      case 'pending':
        return Colors.orange;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
*/
