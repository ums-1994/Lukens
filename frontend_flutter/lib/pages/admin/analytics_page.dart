import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../theme/premium_theme.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _pipeline;
  Map<String, dynamic>? _cycleTime;
  Map<String, dynamic>? _completion;
  Map<String, dynamic>? _riskSummary;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final app = context.read<AppState>();
      final results = await Future.wait([
        app.getProposalPipelineAnalytics(scope: 'all'),
        app.getCycleTimeAnalytics(scope: 'all'),
        app.getCompletionRatesAnalytics(),
        app.getRiskGateSummary(),
      ]);

      setState(() {
        _pipeline = results[0];
        _cycleTime = results[1];
        _completion = results[2];
        _riskSummary = results[3];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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

  String _avgCycleTimeDays() {
    final byStage = (_cycleTime?['by_stage'] as List?) ?? const [];
    if (byStage.isEmpty) return '—';

    double total = 0;
    int n = 0;
    for (final row in byStage) {
      if (row is! Map) continue;
      final v = row['avg_cycle_time_days'];
      final d = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      if (d == null) continue;
      total += d;
      n += 1;
    }
    if (n == 0) return '—';
    return (total / n).toStringAsFixed(1);
  }

  String _avgReadinessScore() {
    final rows = (_completion?['proposals'] as List?) ?? const [];
    if (rows.isEmpty) return '—';
    double total = 0;
    int n = 0;
    for (final row in rows) {
      if (row is! Map) continue;
      final v = row['readiness_score'];
      final score =
          (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      if (score == null) continue;
      total += score;
      n += 1;
    }
    if (n == 0) return '—';
    return (total / n).toStringAsFixed(0);
  }

  Widget _stat(String title, String value, {String? subtitle}) {
    return PremiumStatCard(
      title: title,
      value: value,
      subtitle: subtitle,
      gradient: PremiumTheme.blueGradient,
      icon: Icons.analytics_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.darkBg1,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              const Text(
                'Pipeline (All)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width < 900 ? 2 : 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stat('Draft', _stageCount('Draft').toString()),
                  _stat('In Review', _stageCount('In Review').toString()),
                  _stat('Released', _stageCount('Released').toString()),
                  _stat('Signed', _stageCount('Signed').toString()),
                ],
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width < 900 ? 2 : 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stat('Avg Cycle Time (days)', _avgCycleTimeDays()),
                  _stat('Avg Readiness', _avgReadinessScore(),
                      subtitle: 'Completion rates'),
                  _stat(
                    'Risk Gate',
                    (_riskSummary?['counts']?['BLOCK']?.toString() ??
                        '—'),
                    subtitle: 'Blocked count',
                  ),
                  _stat(
                    'Risk Gate',
                    (_riskSummary?['counts']?['REVIEW']?.toString() ??
                        '—'),
                    subtitle: 'Review count',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This page reads from backend analytics endpoints: pipeline, cycle time, completion rates, and risk gate summary.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
