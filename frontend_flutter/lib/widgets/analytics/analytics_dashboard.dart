import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../../api.dart';
import '../../theme/premium_theme.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({
    super.key,
    required this.title,
    required this.scope,
    required this.showOwnerFilter,
  });

  final String title;
  final String scope;
  final bool showOwnerFilter;

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _pipeline;
  Map<String, dynamic>? _pipelinePrev;
  Map<String, dynamic>? _cycleTime;
  Map<String, dynamic>? _cycleTimePrev;
  Map<String, dynamic>? _completion;
  Map<String, dynamic>? _completionPrev;
  Map<String, dynamic>? _sowMetrics;
  Map<String, dynamic>? _sowMetricsPrev;
  Map<String, dynamic>? _riskSummary;
  Map<String, dynamic>? _riskSummaryPrev;
  List<Map<String, dynamic>> _riskBlocked = [];
  List<Map<String, dynamic>> _riskReview = [];

  String _range = '30d';
  final TextEditingController _ownerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    super.dispose();
  }

  DateTime _startForRange(DateTime end) {
    switch (_range) {
      case '7d':
        return end.subtract(const Duration(days: 7));
      case '90d':
        return end.subtract(const Duration(days: 90));
      case '30d':
      default:
        return end.subtract(const Duration(days: 30));
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final app = context.read<AppState>();
      final now = DateTime.now();
      final fmt = DateFormat('yyyy-MM-dd');
      final startDt = _startForRange(now);
      final endDt = now;
      final startDate = fmt.format(startDt);
      final endDate = fmt.format(endDt);

      final rangeDays = endDt.difference(startDt).inDays;
      final prevEndDt = startDt;
      final prevStartDt = prevEndDt.subtract(Duration(days: rangeDays));
      final prevStartDate = fmt.format(prevStartDt);
      final prevEndDate = fmt.format(prevEndDt);
      final owner = _ownerCtrl.text.trim();

      final currentResults = await Future.wait([
        app.getProposalPipelineAnalytics(
          scope: widget.scope,
          startDate: startDate,
          endDate: endDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getCycleTimeAnalytics(
          scope: widget.scope,
          startDate: startDate,
          endDate: endDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getCompletionRatesAnalytics(
          scope: widget.scope,
          startDate: startDate,
          endDate: endDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getSowMetricsAnalytics(
          scope: widget.scope,
          startDate: startDate,
          endDate: endDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getRiskGateSummary(
          scope: widget.scope,
          startDate: startDate,
          endDate: endDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getRiskGateProposals(
          riskStatus: 'BLOCK',
          scope: widget.scope,
          startDate: startDate,
          endDate: endDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
          limit: 5,
        ),
        app.getRiskGateProposals(
          riskStatus: 'REVIEW',
          scope: widget.scope,
          startDate: startDate,
          endDate: endDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
          limit: 5,
        ),
      ]);

      final prevResults = await Future.wait([
        app.getProposalPipelineAnalytics(
          scope: widget.scope,
          startDate: prevStartDate,
          endDate: prevEndDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getCycleTimeAnalytics(
          scope: widget.scope,
          startDate: prevStartDate,
          endDate: prevEndDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getCompletionRatesAnalytics(
          scope: widget.scope,
          startDate: prevStartDate,
          endDate: prevEndDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getSowMetricsAnalytics(
          scope: widget.scope,
          startDate: prevStartDate,
          endDate: prevEndDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
        app.getRiskGateSummary(
          scope: widget.scope,
          startDate: prevStartDate,
          endDate: prevEndDate,
          owner: widget.showOwnerFilter && owner.isNotEmpty ? owner : null,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _pipeline = currentResults[0];
        _cycleTime = currentResults[1];
        _completion = currentResults[2];
        _sowMetrics = currentResults[3];
        _riskSummary = currentResults[4];
        _riskBlocked = _riskListFromResponse(currentResults[5]);
        _riskReview = _riskListFromResponse(currentResults[6]);

        _pipelinePrev = prevResults[0];
        _cycleTimePrev = prevResults[1];
        _completionPrev = prevResults[2];
        _sowMetricsPrev = prevResults[3];
        _riskSummaryPrev = prevResults[4];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int _stageCount(String stage) {
    final stages = (_pipeline?['stages'] as List?) ?? const [];
    for (final s in stages) {
      if (s is Map && (s['stage']?.toString() ?? '') == stage) {
        final v = s['count'];
        if (v is int) return v;
        return int.tryParse(v?.toString() ?? '') ?? 0;
      }
    }
    return 0;
  }

  int _totalProposals() {
    return _totalProposalsFrom(_pipeline);
  }

  int _totalProposalsPrev() {
    return _totalProposalsFrom(_pipelinePrev);
  }

  int _totalProposalsFrom(Map<String, dynamic>? pipeline) {
    final stages = (pipeline?['stages'] as List?) ?? const [];
    int total = 0;
    for (final s in stages) {
      if (s is! Map) continue;
      final v = s['count'];
      final n = (v is int) ? v : int.tryParse(v?.toString() ?? '') ?? 0;
      total += n;
    }
    return total;
  }

  String _avgCycleTimeDays() {
    final v = _avgCycleTimeValue(_cycleTime);
    if (v == null) return '—';
    return v.toStringAsFixed(1);
  }

  double? _avgCycleTimeValue(Map<String, dynamic>? cycleTime) {
    final byStage = (cycleTime?['by_stage'] as List?) ?? const [];
    if (byStage.isEmpty) return null;

    double total = 0;
    int n = 0;
    for (final row in byStage) {
      if (row is! Map) continue;
      final v = row['avg_cycle_time_days'] ?? row['avg_days'];
      final d = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      if (d == null) continue;
      total += d;
      n += 1;
    }
    if (n == 0) return null;
    return (total / n);
  }

  String _approvalRate() {
    final v = _approvalRateValue(_completion);
    if (v == null) return '—';
    return '${v.toStringAsFixed(0)}%';
  }

  double? _approvalRateValue(Map<String, dynamic>? completion) {
    final totals = completion?['totals'];
    if (totals is Map) {
      final passedRaw = totals['passed'];
      final failedRaw = totals['failed'];
      final passed = (passedRaw is int)
          ? passedRaw
          : int.tryParse(passedRaw?.toString() ?? '') ?? 0;
      final failed = (failedRaw is int)
          ? failedRaw
          : int.tryParse(failedRaw?.toString() ?? '') ?? 0;
      final denom = passed + failed;
      if (denom <= 0) return null;
      return (passed / denom) * 100.0;
    }

    final proposals = (completion?['proposals'] as List?) ?? const [];
    if (proposals.isEmpty) return null;

    int approved = 0;
    int total = 0;
    for (final row in proposals) {
      if (row is! Map) continue;
      final status = (row['status'] ?? '').toString().toLowerCase();
      total += 1;
      if (status.contains('approved') || status.contains('signed')) {
        approved += 1;
      }
    }
    if (total == 0) return null;
    return (approved / total) * 100.0;
  }

  String _pipelineValue() {
    final n = _pipelineValueNumber(_pipeline);
    if (n == null) return '—';
    final fmt = NumberFormat.compactCurrency(symbol: '\$');
    return fmt.format(n);
  }

  String _pipelineValuePrev() {
    final n = _pipelineValueNumber(_pipelinePrev);
    if (n == null) return '—';
    final fmt = NumberFormat.compactCurrency(symbol: '\$');
    return fmt.format(n);
  }

  double? _pipelineValueNumber(Map<String, dynamic>? pipeline) {
    final v = pipeline?['total_value'] ??
        pipeline?['total_pipeline_value'] ??
        pipeline?['pipeline_value'];
    if (v == null) return null;
    return (v is num) ? v.toDouble() : double.tryParse(v.toString());
  }

  String _sowGenerated() {
    return _sowGeneratedFrom(_sowMetrics);
  }

  String _sowGeneratedPrev() {
    return _sowGeneratedFrom(_sowMetricsPrev);
  }

  String _sowGeneratedFrom(Map<String, dynamic>? sowMetrics) {
    final v = sowMetrics?['sows_generated'];
    if (v == null) return '—';
    if (v is int) return v.toString();
    return int.tryParse(v.toString())?.toString() ?? '—';
  }

  String _sowConversionRate() {
    final n = _sowConversionRateValue(_sowMetrics);
    if (n == null) return '—';
    return '${n.toStringAsFixed(0)}%';
  }

  double? _sowConversionRateValue(Map<String, dynamic>? sowMetrics) {
    final v = sowMetrics?['conversion_rate_percent'];
    if (v == null) return null;
    return (v is num) ? v.toDouble() : double.tryParse(v.toString());
  }

  double? _sowConversionRatePrevValue() {
    return _sowConversionRateValue(_sowMetricsPrev);
  }

  String _sowAvgTimeToSignDays() {
    final n = _sowAvgTimeToSignValue(_sowMetrics);
    if (n == null) return '—';
    return n.toStringAsFixed(1);
  }

  double? _sowAvgTimeToSignValue(Map<String, dynamic>? sowMetrics) {
    final t = sowMetrics?['time_to_sign'];
    dynamic v;
    if (t is Map) {
      v = t['avg_days'];
    } else {
      v = sowMetrics?['time_to_sign_avg_days'];
    }
    if (v == null) return null;
    return (v is num) ? v.toDouble() : double.tryParse(v.toString());
  }

  double? _sowAvgTimeToSignPrevValue() {
    return _sowAvgTimeToSignValue(_sowMetricsPrev);
  }

  int _riskCountValue(Map<String, dynamic>? riskSummary, String key) {
    final counts = riskSummary?['counts'];
    if (counts is! Map) return 0;
    final v = counts[key];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _deltaIntSubtitle(String base, int current, int previous) {
    final delta = current - previous;
    if (delta == 0) return base;
    final sign = delta > 0 ? '+' : '';
    return '$base · $sign$delta vs prior';
  }

  String _deltaPercentSubtitle(String base, double? current, double? previous) {
    if (current == null || previous == null) return base;
    final delta = current - previous;
    if (delta.abs() < 0.01) return base;
    final sign = delta > 0 ? '+' : '';
    return '$base · $sign${delta.toStringAsFixed(0)}% vs prior';
  }

  String _deltaDaysSubtitle(String base, double? current, double? previous) {
    if (current == null || previous == null) return base;
    final delta = current - previous;
    if (delta.abs() < 0.05) return base;
    final sign = delta > 0 ? '+' : '';
    return '$base · $sign${delta.toStringAsFixed(1)}d vs prior';
  }

  String _deltaCurrencySubtitle(String base, double? current, double? previous) {
    if (current == null || previous == null) return base;
    final delta = current - previous;
    if (delta.abs() < 0.01) return base;
    final fmt = NumberFormat.compactCurrency(symbol: '\$');
    final sign = delta > 0 ? '+' : '';
    return '$base · $sign${fmt.format(delta)} vs prior';
  }

  String _riskCount(String key) {
    final v = _riskSummary?['counts']?[key];
    if (v == null) return '—';
    if (v is int) return v.toString();
    return v.toString();
  }

  List<Map<String, dynamic>> _riskListFromResponse(dynamic resp) {
    try {
      if (resp is! Map) return const [];
      final proposals = resp['proposals'];
      if (proposals is! List) return const [];
      return proposals
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Widget _buildRiskList() {
    Widget section(String title, List<Map<String, dynamic>> items,
        {required Color accent}) {
      if (items.isEmpty) {
        return _glassPanel(
          padding: const EdgeInsets.all(14),
          child: Text(
            'No $title items for this period.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
        );
      }

      String rowTitle(Map<String, dynamic> p) {
        final v = (p['title'] ?? p['name'] ?? p['proposal_title'] ?? '').toString();
        return v.trim().isEmpty ? 'Untitled proposal' : v.trim();
      }

      String rowMeta(Map<String, dynamic> p) {
        final client = (p['client'] ?? p['client_name'] ?? '').toString().trim();
        final stage = (p['stage'] ?? p['status'] ?? '').toString().trim();
        final parts = <String>[];
        if (client.isNotEmpty) parts.add(client);
        if (stage.isNotEmpty) parts.add(stage);
        return parts.join(' · ');
      }

      return _glassPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final p in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rowTitle(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PremiumTheme.bodyMedium
                                .copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rowMeta(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PremiumTheme.labelMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      (p['days_in_stage'] ?? p['age_days'] ?? p['days_open'] ?? '')
                          .toString(),
                      style: PremiumTheme.labelMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 820;
        final blocked = section('Blocked', _riskBlocked, accent: PremiumTheme.error);
        final review = section('Needs review', _riskReview, accent: PremiumTheme.purple);
        if (narrow) {
          return Column(
            children: [
              blocked,
              const SizedBox(height: 12),
              review,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: blocked),
            const SizedBox(width: 12),
            Expanded(child: review),
          ],
        );
      },
    );
  }

  Map<String, int> _pipelineCounts() {
    final counts = <String, int>{
      'Draft': 0,
      'Submitted': 0,
      'In Review': 0,
      'Approved': 0,
      'Rejected': 0,
    };
    final stages = (_pipeline?['stages'] as List?) ?? const [];
    for (final s in stages) {
      if (s is! Map) continue;
      final name = (s['stage'] ?? '').toString();
      final v = s['count'];
      final n = (v is int) ? v : int.tryParse(v?.toString() ?? '') ?? 0;
      if (counts.containsKey(name)) {
        counts[name] = n;
      }
    }
    return counts;
  }

  List<MapEntry<String, double>> _cycleTimePoints() {
    final byStage = (_cycleTime?['by_stage'] as List?) ?? const [];
    final out = <MapEntry<String, double>>[];
    for (final row in byStage) {
      if (row is! Map) continue;
      final stage = (row['stage'] ?? row['status'] ?? '').toString();
      if (stage.isEmpty) continue;
      final v = row['avg_cycle_time_days'] ?? row['avg_days'];
      final d = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      if (d == null) continue;
      out.add(MapEntry(stage, d));
    }
    return out;
  }

  ({int approved, int rejected, int other}) _completionBreakdown() {
    final totals = _completion?['totals'];
    if (totals is Map) {
      final passedRaw = totals['passed'];
      final failedRaw = totals['failed'];
      final otherRaw = totals['other'];
      final approved = (passedRaw is int)
          ? passedRaw
          : int.tryParse(passedRaw?.toString() ?? '') ?? 0;
      final rejected = (failedRaw is int)
          ? failedRaw
          : int.tryParse(failedRaw?.toString() ?? '') ?? 0;
      final other = (otherRaw is int)
          ? otherRaw
          : int.tryParse(otherRaw?.toString() ?? '') ?? 0;
      return (approved: approved, rejected: rejected, other: other);
    }

    final proposals = (_completion?['proposals'] as List?) ?? const [];
    int approved = 0;
    int rejected = 0;
    int other = 0;
    for (final row in proposals) {
      if (row is! Map) continue;
      final status = (row['status'] ?? '').toString().toLowerCase();
      if (status.contains('reject')) {
        rejected += 1;
      } else if (status.contains('approved') || status.contains('signed')) {
        approved += 1;
      } else {
        other += 1;
      }
    }
    return (approved: approved, rejected: rejected, other: other);
  }

  Widget _glassPanel({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: PremiumTheme.glassCard(borderRadius: 20),
      child: child,
    );
  }

  Widget _buildPipelineFunnel() {
    final counts = _pipelineCounts();
    final ordered = [
      ('Draft', counts['Draft'] ?? 0, PremiumTheme.blueGradient),
      ('Submitted', counts['Submitted'] ?? 0, PremiumTheme.tealGradient),
      ('In Review', counts['In Review'] ?? 0, PremiumTheme.purpleGradient),
      ('Approved', counts['Approved'] ?? 0, PremiumTheme.tealGradient),
      ('Rejected', counts['Rejected'] ?? 0, PremiumTheme.redGradient),
    ];

    final maxVal = ordered.map((e) => e.$2).fold<int>(0, math.max);
    if (maxVal <= 0) {
      return _glassPanel(
        child: Text(
          'No pipeline data for this period.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
      );
    }

    Widget row(String label, int value, Gradient gradient) {
      final pct = maxVal == 0 ? 0.0 : (value / maxVal);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 14,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: gradient),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              child: Text(
                value.toString(),
                textAlign: TextAlign.right,
                style: PremiumTheme.labelMedium.copyWith(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return _glassPanel(
      child: Column(
        children: [
          for (final it in ordered) row(it.$1, it.$2, it.$3),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Insight: you have ${(counts['In Review'] ?? 0)} proposals in review.',
              style: PremiumTheme.labelMedium
                  .copyWith(color: Colors.white.withValues(alpha: 0.70)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleTimeChart() {
    final points = _cycleTimePoints();
    if (points.isEmpty) {
      return _glassPanel(
        child: Text(
          'No cycle time data for this period.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
      );
    }

    final maxY = points.map((e) => e.value).fold<double>(0, math.max);
    final lineColor = PremiumTheme.teal;

    return _glassPanel(
      child: SizedBox(
        height: 260,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            minY: 0,
            maxY: (maxY <= 0 ? 1 : maxY) * 1.2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: Colors.white.withValues(alpha: 0.08), strokeWidth: 1),
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
                  getTitlesWidget: (value, meta) {
                    if (value == 0 || value == meta.max) {
                      return Text(
                        '${value.toStringAsFixed(0)}d',
                        style: PremiumTheme.labelMedium
                            .copyWith(color: Colors.white54, fontSize: 10),
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
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    final label = points[i].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        label.length > 8 ? label.substring(0, 8) : label,
                        style: PremiumTheme.labelMedium
                            .copyWith(color: Colors.white54, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (touchedSpot) =>
                    Colors.black.withValues(alpha: 0.86),
                getTooltipItems: (touchedSpots) {
                  if (touchedSpots.isEmpty) return [];
                  return touchedSpots.map((s) {
                    final idx = s.x.round().clamp(0, points.length - 1);
                    final label = points[idx].key;
                    final v = points[idx].value;
                    return LineTooltipItem(
                      '$label\n${v.toStringAsFixed(1)} days',
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  points.length,
                  (i) => FlSpot(i.toDouble(), points[i].value),
                ),
                isCurved: true,
                color: lineColor,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: lineColor.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionDonut() {
    final b = _completionBreakdown();
    final total = b.approved + b.rejected + b.other;
    if (total <= 0) {
      return _glassPanel(
        child: Text(
          'No completion data for this period.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
      );
    }

    final approvedColor = PremiumTheme.teal;
    final rejectedColor = PremiumTheme.error;
    final otherColor = PremiumTheme.info;

    Widget legendDot(Color c, String label, int value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: PremiumTheme.labelMedium
                .copyWith(color: Colors.white.withValues(alpha: 0.80)),
          ),
        ],
      );
    }

    return _glassPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final chart = SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 70,
                    sections: [
                      PieChartSectionData(
                        color: approvedColor,
                        value: b.approved.toDouble(),
                        showTitle: false,
                        radius: 26,
                      ),
                      PieChartSectionData(
                        color: rejectedColor,
                        value: b.rejected.toDouble(),
                        showTitle: false,
                        radius: 26,
                      ),
                      PieChartSectionData(
                        color: otherColor,
                        value: b.other.toDouble(),
                        showTitle: false,
                        radius: 26,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _approvalRate(),
                      style: PremiumTheme.displayMedium
                          .copyWith(color: Colors.white, fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Approval rate',
                      style: PremiumTheme.labelMedium
                          .copyWith(color: Colors.white.withValues(alpha: 0.70)),
                    ),
                  ],
                ),
              ],
            ),
          );

          final legend = Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              legendDot(approvedColor, 'Approved', b.approved),
              legendDot(rejectedColor, 'Rejected', b.rejected),
              legendDot(otherColor, 'Other', b.other),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chart,
                const SizedBox(height: 12),
                legend,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: chart),
              const SizedBox(width: 18),
              SizedBox(width: 240, child: legend),
            ],
          );
        },
      ),
    );
  }

  Widget _filterBar() {
    final rangeItems = const <DropdownMenuItem<String>>[
      DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
      DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
      DropdownMenuItem(value: '90d', child: Text('Last 90 days')),
    ];

    Widget glass({required Widget child}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: child,
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: glass(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _range,
                isDense: true,
                dropdownColor: PremiumTheme.darkBg2,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                items: rangeItems,
                onChanged: _loading
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _range = v);
                        _refresh();
                      },
              ),
            ),
          ),
        ),
        if (widget.showOwnerFilter)
          SizedBox(
            width: 260,
            child: glass(
              child: TextField(
                controller: _ownerCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Owner (optional)',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                onSubmitted: (_) => _refresh(),
              ),
            ),
          ),
        glass(
          child: IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.darkBg1,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filterBar(),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _sectionTitle('Overview'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width < 900 ? 2 : 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  PremiumStatCard(
                    title: 'Total Proposals',
                    value: _totalProposals().toString(),
                    subtitle: _deltaIntSubtitle(
                      'In range',
                      _totalProposals(),
                      _totalProposalsPrev(),
                    ),
                    icon: Icons.description_outlined,
                    gradient: PremiumTheme.blueGradient,
                  ),
                  PremiumStatCard(
                    title: 'Total Pipeline Value',
                    value: _pipelineValue(),
                    subtitle: _deltaCurrencySubtitle(
                      'In range',
                      _pipelineValueNumber(_pipeline),
                      _pipelineValueNumber(_pipelinePrev),
                    ),
                    icon: Icons.payments_outlined,
                    gradient: PremiumTheme.tealGradient,
                  ),
                  PremiumStatCard(
                    title: 'Approval Rate',
                    value: _approvalRate(),
                    subtitle: _deltaPercentSubtitle(
                      'In range',
                      _approvalRateValue(_completion),
                      _approvalRateValue(_completionPrev),
                    ),
                    icon: Icons.check_circle_outline,
                    gradient: PremiumTheme.purpleGradient,
                  ),
                  PremiumStatCard(
                    title: 'Avg Cycle Time',
                    value: _avgCycleTimeDays(),
                    subtitle: _deltaDaysSubtitle(
                      'Days',
                      _avgCycleTimeValue(_cycleTime),
                      _avgCycleTimeValue(_cycleTimePrev),
                    ),
                    icon: Icons.timelapse,
                    gradient: PremiumTheme.blueGradient,
                  ),
                  PremiumStatCard(
                    title: 'At Risk Deals',
                    value: _riskCount('BLOCK'),
                    subtitle: _deltaIntSubtitle(
                      'Blocked',
                      _riskCountValue(_riskSummary, 'BLOCK'),
                      _riskCountValue(_riskSummaryPrev, 'BLOCK'),
                    ),
                    icon: Icons.warning_amber_outlined,
                    gradient: PremiumTheme.redGradient,
                  ),
                  PremiumStatCard(
                    title: 'SOWs Generated',
                    value: _sowGenerated(),
                    subtitle: _deltaIntSubtitle(
                      'In range',
                      int.tryParse(_sowGenerated()) ?? 0,
                      int.tryParse(_sowGeneratedPrev()) ?? 0,
                    ),
                    icon: Icons.article_outlined,
                    gradient: PremiumTheme.tealGradient,
                  ),
                  PremiumStatCard(
                    title: 'SOW Conversion',
                    value: _sowConversionRate(),
                    subtitle: _deltaPercentSubtitle(
                      'Signed / Released',
                      _sowConversionRateValue(_sowMetrics),
                      _sowConversionRatePrevValue(),
                    ),
                    icon: Icons.trending_up,
                    gradient: PremiumTheme.purpleGradient,
                  ),
                  PremiumStatCard(
                    title: 'SOW Time to Sign',
                    value: _sowAvgTimeToSignDays(),
                    subtitle: _deltaDaysSubtitle(
                      'Avg days',
                      _sowAvgTimeToSignValue(_sowMetrics),
                      _sowAvgTimeToSignPrevValue(),
                    ),
                    icon: Icons.timelapse,
                    gradient: PremiumTheme.blueGradient,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('Proposal Pipeline'),
              const SizedBox(height: 12),
              _buildPipelineFunnel(),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width < 900 ? 2 : 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  PremiumStatCard(
                    title: 'Draft',
                    value: _stageCount('Draft').toString(),
                    icon: Icons.edit_note,
                    gradient: PremiumTheme.blueGradient,
                  ),
                  PremiumStatCard(
                    title: 'Submitted',
                    value: _stageCount('Submitted').toString(),
                    icon: Icons.send_outlined,
                    gradient: PremiumTheme.tealGradient,
                  ),
                  PremiumStatCard(
                    title: 'In Review',
                    value: _stageCount('In Review').toString(),
                    icon: Icons.rule_folder_outlined,
                    gradient: PremiumTheme.purpleGradient,
                  ),
                  PremiumStatCard(
                    title: 'Approved',
                    value: _stageCount('Approved').toString(),
                    icon: Icons.verified_outlined,
                    gradient: PremiumTheme.tealGradient,
                  ),
                  PremiumStatCard(
                    title: 'Rejected',
                    value: _stageCount('Rejected').toString(),
                    icon: Icons.block_outlined,
                    gradient: PremiumTheme.redGradient,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle('Cycle Time'),
              const SizedBox(height: 12),
              _buildCycleTimeChart(),
              const SizedBox(height: 20),
              _sectionTitle('Approval / Completion Rates'),
              const SizedBox(height: 12),
              _buildCompletionDonut(),
              const SizedBox(height: 20),
              _sectionTitle('Risk / Bottlenecks'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width < 900 ? 2 : 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  PremiumStatCard(
                    title: 'Risk Gate',
                    value: _riskCount('BLOCK'),
                    subtitle: 'Blocked',
                    icon: Icons.cancel_outlined,
                    gradient: PremiumTheme.redGradient,
                  ),
                  PremiumStatCard(
                    title: 'Risk Gate',
                    value: _riskCount('REVIEW'),
                    subtitle: 'Review',
                    icon: Icons.error_outline,
                    gradient: PremiumTheme.purpleGradient,
                  ),
                  PremiumStatCard(
                    title: 'Risk Gate',
                    value: _riskCount('WARN'),
                    subtitle: 'Warn',
                    icon: Icons.warning_amber_outlined,
                    gradient: PremiumTheme.blueGradient,
                  ),
                  PremiumStatCard(
                    title: 'Risk Gate',
                    value: _riskCount('OK'),
                    subtitle: 'OK',
                    icon: Icons.check_circle_outline,
                    gradient: PremiumTheme.tealGradient,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRiskList(),
            ],
          ],
        ),
      ),
    );
  }
}
