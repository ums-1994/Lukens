import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  String _selectedPeriod = 'Last 30 Days';
  final TextEditingController _clientCtrl = TextEditingController();
  final TextEditingController _ownerCtrl = TextEditingController();
  final TextEditingController _proposalTypeCtrl = TextEditingController();
  final TextEditingController _regionCtrl = TextEditingController();

  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  Map<String, dynamic>? _pipeline;
  Map<String, dynamic>? _cycleTime;
  Map<String, dynamic>? _completion;
  Map<String, dynamic>? _riskSummary;

  Future<void> _showCompletionRatesDialog() async {
    final data = _completion;
    final low = (data?['low_proposals'] as List?) ?? const [];
    final proposals = (data?['proposals'] as List?) ?? const [];

    List<Map<String, dynamic>> normalize(List raw) {
      final out = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          out.add(item.cast<String, dynamic>());
        }
      }
      return out;
    }

    final lowList = normalize(low.isNotEmpty ? low : proposals);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Completion Rates'),
          content: SizedBox(
            width: 900,
            child: lowList.isEmpty
                ? const Text('No completion rate data found for this period.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: lowList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = lowList[i];
                      final id = (p['proposal_id'] ?? p['id'] ?? '').toString();
                      final title = (p['title'] ?? 'Untitled').toString();
                      final client = (p['client'] ?? '').toString();
                      final status = (p['status'] ?? '').toString();
                      final scoreRaw = p['readiness_score'];
                      final score = (scoreRaw is num)
                          ? scoreRaw.toInt()
                          : int.tryParse(scoreRaw?.toString() ?? '') ?? 0;

                      return ListTile(
                        title: Text(title, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            if (client.isNotEmpty) client,
                            if (status.isNotEmpty) status,
                          ].join(' • '),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text('$score%'),
                        onTap: id.isEmpty
                            ? null
                            : () {
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
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _ownerCtrl.dispose();
    _proposalTypeCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
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

  String _s(dynamic v) => (v ?? '').toString();

  DateTime? _parseDate(dynamic v) {
    final raw = _s(v);
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  double _proposalValue(dynamic p) {
    if (p is! Map) return 0;
    final candidates = [
      p['total_value'],
      p['totalValue'],
      p['value'],
      p['amount'],
      p['deal_size'],
      p['dealSize'],
    ];
    for (final c in candidates) {
      if (c is num) return c.toDouble();
      final parsed = double.tryParse(_s(c).replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
    return 0;
  }

  bool _matchesFilter(String haystack, String needle) {
    if (needle.trim().isEmpty) return true;
    return haystack.toLowerCase().contains(needle.trim().toLowerCase());
  }

  List<dynamic> _filteredProposals(List<dynamic> proposals) {
    final now = DateTime.now();
    final start = _periodStart(now);
    return proposals.where((p) {
      if (p is! Map) return false;
      final client = _s(p['client']);
      final owner = _s(p['owner']);
      final type = _s(p['proposal_type'] ?? p['proposalType']);
      final region = _s(p['region']);
      if (!_matchesFilter(client, _clientCtrl.text)) return false;
      if (!_matchesFilter(owner, _ownerCtrl.text)) return false;
      if (!_matchesFilter(type, _proposalTypeCtrl.text)) return false;
      if (!_matchesFilter(region, _regionCtrl.text)) return false;

      if (start != null) {
        final created = _parseDate(p['created_at'] ?? p['createdAt']);
        final updated = _parseDate(p['updated_at'] ?? p['updatedAt']);
        final dt = updated ?? created;
        if (dt != null && dt.isBefore(start)) return false;
      }

      return true;
    }).toList();
  }

  Widget _glassField({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: child,
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PremiumTheme.bodyMedium.copyWith(
              color: PremiumTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: PremiumTheme.displayMedium.copyWith(fontSize: 28),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: PremiumTheme.bodySmall.copyWith(
              color: PremiumTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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
      final d =
          (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
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

  Widget _stat(String title, String value,
      {String? subtitle, VoidCallback? onTap}) {
    final card = PremiumStatCard(
      title: title,
      value: value,
      subtitle: subtitle,
      gradient: PremiumTheme.blueGradient,
      icon: Icons.analytics_outlined,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final filtered = _filteredProposals(app.proposals);
    final totalRevenue = filtered.fold<double>(
      0,
      (sum, p) => sum + _proposalValue(p),
    );
    final activeCount = filtered.length;
    final signedCount = filtered.where((p) {
      if (p is! Map) return false;
      final status = _s(p['status']).toLowerCase();
      return status.contains('signed') || status.contains('approved');
    }).length;
    final conversionRate = activeCount == 0
        ? 0.0
        : (signedCount / activeCount * 100).clamp(0, 100);
    final avgDeal = activeCount == 0 ? 0.0 : totalRevenue / activeCount;

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
              Text(
                'Comprehensive business intelligence and performance metrics',
                style: PremiumTheme.bodyLarge.copyWith(
                  color: PremiumTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _glassField(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPeriod,
                        dropdownColor: const Color(0xFF0A0E27),
                        style: const TextStyle(color: Colors.white),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white),
                        items: const [
                          DropdownMenuItem(
                              value: 'Last 7 Days', child: Text('Last 7 Days')),
                          DropdownMenuItem(
                              value: 'Last 30 Days',
                              child: Text('Last 30 Days')),
                          DropdownMenuItem(
                              value: 'Last 90 Days',
                              child: Text('Last 90 Days')),
                          DropdownMenuItem(
                              value: 'This Year', child: Text('This Year')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedPeriod = v);
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _glassField(
                      child: TextField(
                        controller: _clientCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Client (optional)',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _glassField(
                      child: TextField(
                        controller: _ownerCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Owner (optional)',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: _glassField(
                      child: TextField(
                        controller: _proposalTypeCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Proposal type (optional)',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _glassField(
                      child: TextField(
                        controller: _regionCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Region (optional)',
                          hintStyle: TextStyle(color: Colors.white54),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear filters',
                    onPressed: () {
                      _clientCtrl.clear();
                      _ownerCtrl.clear();
                      _proposalTypeCtrl.clear();
                      _regionCtrl.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final crossAxisCount = wide ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _metricCard(
                        title: 'Total Revenue',
                        value: _currencyFormatter.format(totalRevenue),
                        subtitle: 'vs last month',
                      ),
                      _metricCard(
                        title: 'Active Proposals',
                        value: activeCount.toString(),
                        subtitle: 'vs last month',
                      ),
                      _metricCard(
                        title: 'Conversion Rate',
                        value: '${conversionRate.toStringAsFixed(1)}%',
                        subtitle: 'vs last month',
                      ),
                      _metricCard(
                        title: 'Avg Deal Size',
                        value: _currencyFormatter.format(avgDeal),
                        subtitle: 'vs last month',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _stat(
                'Avg Readiness',
                _avgReadinessScore(),
                subtitle: 'Completion rates',
                onTap: _completion == null ? null : _showCompletionRatesDialog,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Revenue Analytics', style: PremiumTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 260,
                      child: Center(
                        child: Text(
                          'Chart coming soon',
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: PremiumTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pipeline Snapshot', style: PremiumTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _stat('Draft', _stageCount('Draft').toString()),
                        _stat('In Review', _stageCount('In Review').toString()),
                        _stat('Released', _stageCount('Released').toString()),
                        _stat('Signed', _stageCount('Signed').toString()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
