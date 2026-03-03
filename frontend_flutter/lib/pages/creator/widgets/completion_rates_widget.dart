// ignore_for_file: unused_field
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_service.dart';
import '../../../services/auth_service.dart'; // AuthService.token
import '../../../theme/premium_theme.dart';

/// Displays readiness scores, pass rates, sign-off funnel, 30-day trend,
/// and a drill-down list of low-scoring proposals for the manager dashboard.
class CompletionRatesWidget extends StatefulWidget {
  /// Called when the user taps a proposal row to open it in the editor.
  final void Function(int proposalId, String status)? onOpenProposal;

  const CompletionRatesWidget({super.key, this.onOpenProposal});

  @override
  State<CompletionRatesWidget> createState() => _CompletionRatesWidgetState();
}

class _CompletionRatesWidgetState extends State<CompletionRatesWidget>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<dynamic> _proposals = [];
  List<dynamic> _trend = [];
  Map<String, dynamic> _statusBreakdown = {};

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  // Drill-down: show only low-scoring proposals
  bool _showDrillDown = false;
  static const int _lowScoreThreshold = 60;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _fetch();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = AuthService.token;
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/proposals/completion-rates'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _summary = Map<String, dynamic>.from(data['summary'] ?? {});
          _proposals = List<dynamic>.from(data['proposals'] ?? []);
          _trend = List<dynamic>.from(data['trend'] ?? []);
          _statusBreakdown =
              Map<String, dynamic>.from(data['status_breakdown'] ?? {});
          _loading = false;
        });
        _animCtrl.forward(from: 0);
      } else {
        setState(() {
          _error = 'Failed to load completion rates (${resp.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    return FadeTransition(opacity: _fadeAnim, child: _buildContent());
  }

  // ── Main layout ────────────────────────────────────────────────────────────

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildKpiRow(),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (ctx, constraints) {
          final wide = constraints.maxWidth > 700;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildDonutCard()),
                const SizedBox(width: 16),
                Expanded(flex: 7, child: _buildTrendCard()),
              ],
            );
          }
          return Column(
            children: [
              _buildDonutCard(),
              const SizedBox(height: 16),
              _buildTrendCard(),
            ],
          );
        }),
        const SizedBox(height: 20),
        _buildDrillDownCard(),
      ],
    );
  }

  // ── KPI row ────────────────────────────────────────────────────────────────

  Widget _buildKpiRow() {
    final total = _summary['total_proposals'] ?? 0;
    final passing = _summary['passing_readiness'] ?? 0;
    final cr = (_summary['completion_rate'] ?? 0.0).toDouble();
    final sor = (_summary['sign_off_rate'] ?? 0.0).toDouble();
    final avg = (_summary['avg_readiness_score'] ?? 0.0).toDouble();

    final kpis = [
      _KpiData(
        label: 'Proposals',
        value: '$total',
        sub: 'Total',
        gradient: PremiumTheme.blueGradient,
        icon: Icons.description_outlined,
      ),
      _KpiData(
        label: 'Passing',
        value: '$passing',
        sub: 'Readiness checks',
        gradient: PremiumTheme.tealGradient,
        icon: Icons.check_circle_outline,
      ),
      _KpiData(
        label: 'Completion Rate',
        value: '${cr.toStringAsFixed(1)}%',
        sub: 'Pass threshold: ${_summary['pass_threshold'] ?? 80}%',
        gradient: PremiumTheme.purpleGradient,
        icon: Icons.pie_chart_outline,
      ),
      _KpiData(
        label: 'Sign-off Rate',
        value: '${sor.toStringAsFixed(1)}%',
        sub: 'Signed / Approved',
        gradient: PremiumTheme.orangeGradient,
        icon: Icons.task_alt,
      ),
      _KpiData(
        label: 'Avg Score',
        value: '${avg.toStringAsFixed(1)}%',
        sub: 'Readiness score',
        gradient: LinearGradient(
          colors: [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.speed_outlined,
      ),
    ];

    return LayoutBuilder(builder: (ctx, constraints) {
      final crossCount = constraints.maxWidth > 800
          ? 5
          : constraints.maxWidth > 500
              ? 3
              : 2;
      return GridView.count(
        crossAxisCount: crossCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
        children: kpis.map(_buildKpiCard).toList(),
      );
    });
  }

  Widget _buildKpiCard(_KpiData d) {
    return Container(
      decoration: BoxDecoration(
        gradient: d.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (d.gradient.colors.first).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(d.icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d.label,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            d.value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.1),
          ),
          Text(
            d.sub,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Donut chart (readiness breakdown) ─────────────────────────────────────

  Widget _buildDonutCard() {
    final total = (_summary['total_proposals'] ?? 0) as int;
    final passing = (_summary['passing_readiness'] ?? 0) as int;
    final failing = total - passing;

    final sections = <PieChartSectionData>[
      PieChartSectionData(
        value: passing.toDouble(),
        color: const Color(0xFF20E3B2),
        radius: 36,
        showTitle: false,
      ),
      PieChartSectionData(
        value: math.max(failing.toDouble(), 0),
        color: const Color(0xFFEF5350),
        radius: 36,
        showTitle: false,
      ),
    ];

    return _card(
      title: 'Readiness Breakdown',
      subtitle: 'Proposals passing vs. below threshold',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: total == 0
                        ? [
                            PieChartSectionData(
                                value: 1,
                                color: Colors.white12,
                                radius: 36,
                                showTitle: false)
                          ]
                        : sections,
                    centerSpaceRadius: 56,
                    sectionsSpace: 3,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_summary['completion_rate'] ?? 0.0).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold),
                    ),
                    const Text('passing',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(const Color(0xFF20E3B2), 'Passing ($passing)'),
              const SizedBox(width: 20),
              _legend(const Color(0xFFEF5350), 'Below threshold ($failing)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // ── Trend bar chart ────────────────────────────────────────────────────────

  Widget _buildTrendCard() {
    if (_trend.isEmpty) {
      return _card(
        title: '30-Day Trend',
        subtitle: 'Daily creation volume',
        child: const SizedBox(
          height: 180,
          child: Center(
              child: Text('No data yet',
                  style: TextStyle(color: Colors.white38))),
        ),
      );
    }

    final maxY = _trend
            .map((t) => ((t['created'] ?? 0) as num).toDouble())
            .reduce(math.max) +
        1;

    return _card(
      title: '30-Day Activity',
      subtitle: 'Proposals created per day',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.white.withOpacity(0.9),
                getTooltipItem: (group, gi, rod, ri) {
                  final item = _trend[gi];
                  final date = (item['date'] as String).substring(5);
                  final cr =
                      (item['completion_rate'] as num?)?.toStringAsFixed(0) ??
                          '0';
                  return BarTooltipItem(
                    '$date\n${rod.toY.round()} created · $cr% pass',
                    const TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withOpacity(0.07), strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (v, _) => v % 1 == 0
                      ? Text(v.toInt().toString(),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 9))
                      : const SizedBox.shrink(),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= _trend.length) {
                      return const SizedBox.shrink();
                    }
                    final date = (_trend[i]['date'] as String).substring(5);
                    // Show every 5th label to avoid crowding
                    if (i % 5 != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(date,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 8)),
                    );
                  },
                ),
              ),
            ),
            barGroups: _trend.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final created = ((item['created'] ?? 0) as num).toDouble();
              final cr = ((item['completion_rate'] ?? 0) as num).toDouble();
              // Bar color transitions from red → teal based on daily pass rate
              final barColor = Color.lerp(
                const Color(0xFFEF5350),
                const Color(0xFF20E3B2),
                (cr / 100).clamp(0.0, 1.0),
              )!;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: created,
                    color: barColor,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Drill-down list ────────────────────────────────────────────────────────

  Widget _buildDrillDownCard() {
    final lowScoring = _proposals
        .where((p) => (p['readiness_score'] as num) < _lowScoreThreshold)
        .toList()
      ..sort((a, b) =>
          (a['readiness_score'] as num).compareTo(b['readiness_score'] as num));

    final display = _showDrillDown ? _proposals : lowScoring.take(5).toList();
    final toggleLabel = _showDrillDown
        ? 'Show only low-scoring'
        : 'View all proposals (${_proposals.length})';

    return _card(
      title: 'Proposal Readiness',
      subtitle: _showDrillDown
          ? 'All proposals — tap to open and edit'
          : 'Low-scoring proposals — tap to fix missing sections',
      trailing: TextButton(
        onPressed: () => setState(() => _showDrillDown = !_showDrillDown),
        child: Text(toggleLabel,
            style: const TextStyle(
                color: Color(0xFF20E3B2),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
      child: _proposals.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text('No proposals yet',
                      style: TextStyle(color: Colors.white38))),
            )
          : Column(
              children: display.map((p) => _buildProposalRow(p)).toList(),
            ),
    );
  }

  Widget _buildProposalRow(Map<String, dynamic> p) {
    final score = (p['readiness_score'] as num).toInt();
    final complete = p['sections_complete'] as int? ?? 0;
    final total = p['sections_total'] as int? ?? 5;
    final missing = List<String>.from(p['missing_sections'] ?? []);
    final status = p['status'] as String? ?? 'draft';
    final isLow = score < _lowScoreThreshold;

    final scoreColor = score >= 80
        ? const Color(0xFF20E3B2)
        : score >= 50
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);

    return GestureDetector(
      onTap: () => widget.onOpenProposal?.call(p['id'] as int, status),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLow
                ? scoreColor.withOpacity(0.35)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String? ?? 'Untitled',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((p['client_name'] as String?)?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            p['client_name'] as String,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Score badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scoreColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    '$score%',
                    style: TextStyle(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: status),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    color: Colors.white24, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? complete / total : 0,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '$complete / $total sections complete',
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const Spacer(),
                if (missing.isNotEmpty)
                  Text(
                    'Missing: ${missing.join(', ')}',
                    style: TextStyle(color: scoreColor, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared card shell ──────────────────────────────────────────────────────

  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              IconButton(
                onPressed: _fetch,
                icon: const Icon(Icons.refresh,
                    color: Colors.white24, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ── Loading / error states ─────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFF20E3B2)),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFFEF5350).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFEF5350), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error ?? 'Unknown error',
                style: const TextStyle(
                    color: Color(0xFFEF5350), fontSize: 13)),
          ),
          TextButton(
            onPressed: _fetch,
            child: const Text('Retry',
                style: TextStyle(color: Color(0xFF20E3B2))),
          ),
        ],
      ),
    );
  }
}

// ── Small helper widgets ───────────────────────────────────────────────────

class _KpiData {
  final String label;
  final String value;
  final String sub;
  final LinearGradient gradient;
  final IconData icon;
  const _KpiData({
    required this.label,
    required this.value,
    required this.sub,
    required this.gradient,
    required this.icon,
  });
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color color;
    if (s == 'signed' || s == 'approved') {
      color = const Color(0xFF20E3B2);
    } else if (s.contains('pending') || s.contains('review')) {
      color = const Color(0xFFFFA726);
    } else if (s == 'rejected' || s == 'declined') {
      color = const Color(0xFFEF5350);
    } else if (s.contains('changes')) {
      color = const Color(0xFF9D4EDD);
    } else {
      color = const Color(0xFF42A5F5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
