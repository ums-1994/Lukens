import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui';
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../api.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/admin/admin_sidebar.dart';
import '../creator/widgets/completion_rates_widget.dart';

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
  String? _pipelineStageFilter;
  final TextEditingController _cycleTimeOwnerCtrl = TextEditingController();
  final TextEditingController _cycleTimeProposalTypeCtrl =
      TextEditingController();
  final TextEditingController _globalClientCtrl = TextEditingController();
  final TextEditingController _globalRegionCtrl = TextEditingController();
  final TextEditingController _globalOwnerCtrl = TextEditingController();
  final TextEditingController _globalProposalTypeCtrl = TextEditingController();
  Map<String, dynamic>? _selectedOwner;
  List<Map<String, dynamic>> _ownerSuggestions = const [];
  Timer? _ownerSearchDebounce;
  bool _isSidebarCollapsed = false;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  final _compactCurrencyFormatter = NumberFormat.compactCurrency(
    decimalDigits: 0,
    symbol: r'$',
    locale: 'en_US',
  );
  final _currencyFormatter = NumberFormat.currency(
    symbol: r'$',
    decimalDigits: 0,
    locale: 'en_US',
  );
  static const _currencySymbol = r'$';

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    final backendRole = user?['role']?.toString().toLowerCase() ?? 'manager';
    final isAdmin = backendRole == 'admin' || backendRole == 'ceo';
    if (!isAdmin) {
      _cycleTimeScope = 'self';
    }
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

  Future<void> _searchOwners(String query) async {
    _ownerSearchDebounce?.cancel();
    _ownerSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final token = AuthService.token;
        if (token == null) return;
        final q = query.trim();
        if (q.length < 2) {
          if (!mounted) return;
          setState(() => _ownerSuggestions = const []);
          return;
        }
        final users = await ApiService.searchUsersForMentions(
          token: token,
          query: q,
        );
        if (!mounted) return;
        setState(
          () => _ownerSuggestions = users
              .whereType<Map>()
              .map((u) => u.map((k, v) => MapEntry(k.toString(), v)))
              .cast<Map<String, dynamic>>()
              .toList(),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() => _ownerSuggestions = const []);
      }
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
      final region = _globalRegionCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();
      final departmentFilter = _isAdminUser() ? null : department;

      final data = await context.read<AppState>().getClientEngagementAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            region: region.isEmpty ? null : region,
            scope: _cycleTimeScope,
            department: (departmentFilter == null || departmentFilter.isEmpty)
                ? null
                : departmentFilter,
          );
      return data;
    } catch (e) {
      print('Client engagement exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchPipelineBundle() async {
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
      final departmentFilter = _isAdminUser() ? null : department;
      final app = context.read<AppState>();

      final results = await Future.wait([
        app.getProposalPipelineAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: _cycleTimeScope,
          department: (departmentFilter == null || departmentFilter.isEmpty)
              ? null
              : departmentFilter,
          stage: _pipelineStageFilter,
        ),
        app.getCompletionRatesAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: _cycleTimeScope,
          department: (departmentFilter == null || departmentFilter.isEmpty)
              ? null
              : departmentFilter,
        ),
        app.getApprovalsSummaryAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: _cycleTimeScope,
          department: (departmentFilter == null || departmentFilter.isEmpty)
              ? null
              : departmentFilter,
        ),
        app.getApprovalsBottlenecksAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: _cycleTimeScope,
          department: (departmentFilter == null || departmentFilter.isEmpty)
              ? null
              : departmentFilter,
        ),
        app.getReadinessGovernanceAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: _cycleTimeScope,
          department: (departmentFilter == null || departmentFilter.isEmpty)
              ? null
              : departmentFilter,
        ),
        app.getRiskGateDetailsAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: _cycleTimeScope,
          department: (departmentFilter == null || departmentFilter.isEmpty)
              ? null
              : departmentFilter,
        ),
        app.getStageAgingAnalytics(
          startDate: startDate,
          endDate: endDate,
          owner: owner.isEmpty ? null : owner,
          proposalType: proposalType.isEmpty ? null : proposalType,
          client: client.isEmpty ? null : client,
          scope: _cycleTimeScope,
          department: (departmentFilter == null || departmentFilter.isEmpty)
              ? null
              : departmentFilter,
        ),
      ]);

      return {
        'pipeline': results[0],
        'completion_rates': results[1],
        'approvals_summary': results[2],
        'approvals_bottlenecks': results[3],
        'readiness_governance': results[4],
        'risk_gate_details': results[5],
        'stage_aging': results[6],
      };
    } catch (e) {
      print('Pipeline bundle exception: $e');
      return null;
    }
  }

  Widget _buildMiniKpiRow(List<Map<String, dynamic>> items) {
    final safeItems = items.where((e) => (e['label'] ?? '').toString().trim().isNotEmpty);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final tileCount = math.max(safeItems.length, 1);
        final raw = (maxWidth - (spacing * (tileCount - 1))) / tileCount;
        final tileWidth = raw.clamp(120.0, 180.0);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: safeItems.map((item) {
            final accent = (item['accent'] is Color)
                ? item['accent'] as Color
                : Colors.white.withValues(alpha: 0.70);
            final iconData = item['icon'] is IconData
                ? item['icon'] as IconData
                : Icons.analytics_outlined;

            return ConstrainedBox(
              constraints: BoxConstraints.tightFor(width: tileWidth),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            iconData,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.90),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (item['label'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PremiumTheme.bodySmall.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (item['value'] ?? '--').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTheme.displayMedium.copyWith(
                        fontSize: 26,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKeyValueList({
    required String title,
    required List<Map> items,
    required String labelKey,
    required String valueKey,
    int maxItems = 6,
  }) {
    final rows = items.take(maxItems).toList();
    final maxValue = rows.fold<int>(0, (m, r) {
      final raw = r[valueKey];
      final v = (raw is num)
          ? raw.toInt()
          : (int.tryParse((raw ?? '0').toString()) ?? 0);
      return v > m ? v : m;
    });

    if (rows.isEmpty) {
      return Text(
        'No data for selected filters.',
        style: PremiumTheme.bodySmall.copyWith(color: Colors.white70),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PremiumTheme.bodyMedium.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (final r in rows)
            Builder(
              builder: (context) {
                final raw = r[valueKey];
                final v = (raw is num)
                    ? raw.toInt()
                    : (int.tryParse((raw ?? '0').toString()) ?? 0);
                final ratio = maxValue <= 0 ? 0.0 : (v / maxValue).clamp(0.0, 1.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (r[labelKey] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PremiumTheme.bodySmall
                                  .copyWith(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              v.toString(),
                              style: PremiumTheme.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 6,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: ratio,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        PremiumTheme.info
                                            .withValues(alpha: 0.85),
                                        PremiumTheme.info
                                            .withValues(alpha: 0.35),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildApprovalsCard(
    Map<String, dynamic>? summary,
    Map<String, dynamic>? bottlenecks,
  ) {
    final totals = (summary?['totals'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final pending = (totals['pending'] is num) ? (totals['pending'] as num).toInt() : 0;
    final approved = (totals['approved'] is num) ? (totals['approved'] as num).toInt() : 0;
    final avgHoursRaw = totals['avg_approval_hours'];
    final avgHours = (avgHoursRaw is num) ? avgHoursRaw.toDouble() : double.nan;

    final aging = (bottlenecks?['aging_buckets'] as List?) ?? const [];
    final topAging = aging.whereType<Map>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMiniKpiRow([
          {
            'label': 'Pending',
            'value': pending.toString(),
            'icon': Icons.hourglass_top_rounded,
            'accent': PremiumTheme.warning,
          },
          {
            'label': 'Approved',
            'value': approved.toString(),
            'icon': Icons.verified_rounded,
            'accent': PremiumTheme.success,
          },
          {
            'label': 'Avg approval (hrs)',
            'value': avgHours.isNaN ? '--' : avgHours.toStringAsFixed(1),
            'icon': Icons.schedule_rounded,
            'accent': PremiumTheme.info,
          },
        ]),
        const SizedBox(height: 16),
        _buildKeyValueList(
          title: 'Aging buckets',
          items: topAging,
          labelKey: 'bucket',
          valueKey: 'count',
          maxItems: 6,
        ),
      ],
    );
  }

  Widget _buildReadinessGovernanceCard(Map<String, dynamic>? data) {
    final totals = (data?['totals'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final blocked = (totals['blocked'] is num) ? (totals['blocked'] as num).toInt() : 0;
    final passRate = (totals['pass_rate'] is num) ? (totals['pass_rate'] as num).toInt() : 0;
    final missing = (data?['missing_sections'] as List?) ?? const [];
    final topMissing = missing.whereType<Map>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMiniKpiRow([
          {
            'label': 'Pass rate',
            'value': '$passRate%',
            'icon': Icons.insights_rounded,
            'accent': PremiumTheme.info,
          },
          {
            'label': 'Blocked',
            'value': blocked.toString(),
            'icon': Icons.block_rounded,
            'accent': PremiumTheme.error,
          },
        ]),
        const SizedBox(height: 16),
        _buildKeyValueList(
          title: 'Top missing sections',
          items: topMissing,
          labelKey: 'section',
          valueKey: 'count',
          maxItems: 6,
        ),
      ],
    );
  }

  Widget _buildRiskGateDetailsCard(Map<String, dynamic>? data) {
    final counts = (data?['counts'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final pass = (counts['PASS'] is num) ? (counts['PASS'] as num).toInt() : 0;
    final review = (counts['REVIEW'] is num) ? (counts['REVIEW'] as num).toInt() : 0;
    final block = (counts['BLOCK'] is num) ? (counts['BLOCK'] as num).toInt() : 0;
    final none = (counts['NONE'] is num) ? (counts['NONE'] as num).toInt() : 0;

    final issues = (data?['issues_histogram'] as List?) ?? const [];
    final topIssues = issues.whereType<Map>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMiniKpiRow([
          {
            'label': 'PASS',
            'value': pass.toString(),
            'icon': Icons.check_circle_rounded,
            'accent': PremiumTheme.success,
          },
          {
            'label': 'REVIEW',
            'value': review.toString(),
            'icon': Icons.report_rounded,
            'accent': PremiumTheme.warning,
          },
          {
            'label': 'BLOCK',
            'value': block.toString(),
            'icon': Icons.cancel_rounded,
            'accent': PremiumTheme.error,
          },
          {
            'label': 'NONE',
            'value': none.toString(),
            'icon': Icons.help_outline_rounded,
            'accent': Colors.white.withValues(alpha: 0.65),
          },
        ]),
        const SizedBox(height: 16),
        _buildKeyValueList(
          title: 'Top risk issues',
          items: topIssues,
          labelKey: 'issue',
          valueKey: 'count',
          maxItems: 6,
        ),
      ],
    );
  }

  Widget _buildStageAgingCard(Map<String, dynamic>? data) {
    final byStage = (data?['by_stage'] as List?) ?? const [];
    final rows = byStage.take(6).whereType<Map>().toList();

    if (rows.isEmpty) {
      return Text(
        'No stage aging data for selected filters.',
        style: PremiumTheme.bodySmall.copyWith(color: Colors.white70),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (r['stage'] ?? '').toString(),
                    overflow: TextOverflow.ellipsis,
                    style:
                        PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'stale ${(r['stale'] is num) ? (r['stale'] as num).toInt() : 0}',
                  style: PremiumTheme.bodySmall.copyWith(color: Colors.white70),
                ),
                const SizedBox(width: 12),
                Text(
                  '/ ${(r['total'] is num) ? (r['total'] as num).toInt() : 0}',
                  style: PremiumTheme.bodySmall.copyWith(color: Colors.white70),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(r['threshold_days'] is num) ? (r['threshold_days'] as num).toInt() : 0}d',
                  style: PremiumTheme.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Map<String, int> _pipelineCountsFromResponse(Map<String, dynamic>? data) {
    final counts = <String, int>{
      'Draft': 0,
      'In Review': 0,
      'Released': 0,
      'Signed': 0,
      'Archived': 0,
    };
    final stages = (data?['stages'] as List?) ?? [];
    for (final s in stages) {
      if (s is! Map) continue;
      final stageName = (s['stage'] ?? '').toString();
      final cnt = (s['count'] is num) ? (s['count'] as num).toInt() : 0;
      if (counts.containsKey(stageName)) {
        counts[stageName] = cnt;
      }
    }
    return counts;
  }

  Future<void> _showCompletionRatesDialog(Map<String, dynamic>? data) async {
    try {
      final low = (data?['low_proposals'] as List?) ?? [];
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
                              'Completion Rates: Low Readiness',
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
                      if (low.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              'All proposals are passing mandatory section checks under the current filters.',
                              style: PremiumTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: low.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            itemBuilder: (context, i) {
                              final p = (low[i] as Map).cast<String, dynamic>();
                              final id = (p['proposal_id'] ?? '').toString();
                              final title =
                                  (p['title'] ?? 'Untitled').toString();
                              final clientName = (p['client'] ?? '').toString();
                              final status = (p['status'] ?? '').toString();
                              final score = (p['readiness_score'] is num)
                                  ? (p['readiness_score'] as num).toInt()
                                  : int.tryParse((p['readiness_score'] ?? '')
                                          .toString()) ??
                                      0;
                              final issues =
                                  (p['readiness_issues'] as List?) ?? const [];

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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: PremiumTheme.bodyMedium
                                                  .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              issues.isEmpty
                                                  ? ''
                                                  : (issues
                                                      .take(2)
                                                      .join(' â€¢ ')),
                                              style: PremiumTheme.bodySmall
                                                  .copyWith(
                                                color: Colors.white70,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          clientName.isEmpty ? '-' : clientName,
                                          style:
                                              PremiumTheme.bodyMedium.copyWith(
                                            color: Colors.white70,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          status.isEmpty ? '-' : status,
                                          style:
                                              PremiumTheme.bodyMedium.copyWith(
                                            color: Colors.white70,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '$score%',
                                          textAlign: TextAlign.right,
                                          style:
                                              PremiumTheme.bodyMedium.copyWith(
                                            color: score >= 90
                                                ? PremiumTheme.success
                                                : score >= 60
                                                    ? PremiumTheme.warning
                                                    : PremiumTheme.error,
                                            fontWeight: FontWeight.w700,
                                          ),
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
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('Completion rates dialog error: $e');
    }
  }

  Widget _buildProposalPipelineView(Map<String, dynamic>? data) {
    final stagesRaw = (data?['stages'] as List?) ?? [];
    if (stagesRaw.isEmpty) {
      return Center(
        child: Text(
          'No pipeline proposals match these filters yet',
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
        ),
      );
    }

    final stages = <Map<String, dynamic>>[];
    for (final item in stagesRaw) {
      if (item is Map) {
        stages.add(item.cast<String, dynamic>());
      }
    }

    String formatDate(String? iso) {
      if (iso == null || iso.isEmpty) return '--';
      try {
        final dt = DateTime.parse(iso);
        return DateFormat('MMM d').format(dt);
      } catch (_) {
        return iso.length >= 10 ? iso.substring(0, 10) : iso;
      }
    }

    Color stageColor(String stage) {
      switch (stage) {
        case 'Signed':
          return PremiumTheme.success;
        case 'Released':
          return PremiumTheme.info;
        case 'In Review':
          return PremiumTheme.warning;
        case 'Archived':
          return Colors.white70;
        default:
          return PremiumTheme.orange;
      }
    }

    Widget stageHeader(String stage, int count) {
      final active =
          (_pipelineStageFilter ?? '').toLowerCase() == stage.toLowerCase();
      return InkWell(
        onTap: () {
          setState(() {
            if (active) {
              _pipelineStageFilter = null;
            } else {
              _pipelineStageFilter = stage;
            }
            _cycleTimeRefreshTick++;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: stageColor(stage).withValues(alpha: active ? 0.22 : 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: stageColor(stage).withValues(alpha: active ? 0.55 : 0.25),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  stage,
                  overflow: TextOverflow.ellipsis,
                  style: PremiumTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: PremiumTheme.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget proposalCard(Map<String, dynamic> p) {
      final id = (p['proposal_id'] ?? '').toString();
      final title = (p['title'] ?? 'Untitled').toString();
      final client = (p['client'] ?? '').toString();
      final owner = (p['owner'] ?? '').toString();
      final updated = (p['updated_at'] ?? p['created_at'])?.toString();
      final status = (p['status'] ?? '').toString();
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
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PremiumTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      client.isEmpty ? '-' : client,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    formatDate(updated),
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      owner.isEmpty ? '-' : owner,
                      overflow: TextOverflow.ellipsis,
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    status.isEmpty ? '-' : status,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget stageColumn(Map<String, dynamic> stage) {
      final stageName = (stage['stage'] ?? '').toString();
      final count =
          (stage['count'] is num) ? (stage['count'] as num).toInt() : 0;
      final proposals = (stage['proposals'] as List?) ?? [];
      final cards = <Map<String, dynamic>>[];
      for (final p in proposals) {
        if (p is Map) {
          cards.add(p.cast<String, dynamic>());
        }
      }
      return SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stageHeader(stageName, count),
            const SizedBox(height: 10),
            Expanded(
              child: cards.isEmpty
                  ? Center(
                      child: Text(
                        'No proposals',
                        style: PremiumTheme.bodyMedium.copyWith(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => proposalCard(cards[i]),
                    ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((_pipelineStageFilter ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    'Filtered: ${_pipelineStageFilter!}',
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                _buildGlassButton(
                  'Clear',
                  Icons.close,
                  () {
                    setState(() {
                      _pipelineStageFilter = null;
                      _cycleTimeRefreshTick++;
                    });
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(constraints.maxWidth,
                      260.0 * stages.length + 20.0 * (stages.length - 1)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < stages.length; i++) ...[
                        Expanded(
                          child: stageColumn(stages[i]),
                        ),
                        if (i != stages.length - 1) const SizedBox(width: 20),
                      ],
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

  Widget _buildOwnerAutocompleteDropdown() {
    if (!_isAdminUser()) return const SizedBox.shrink();

    return SizedBox(
      width: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: const Color(0x33FFFFFF)),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: TextField(
              controller: _globalOwnerCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Owner id/email/username',
                hintStyle: TextStyle(color: Colors.white54),
              ),
              onChanged: (v) {
                _searchOwners(v);
              },
              onSubmitted: (_) => setState(() => _cycleTimeRefreshTick++),
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchOwnerLeaderboard() async {
    try {
      final now = DateTime.now();
      final start = _periodStart(now);
      final fmt = DateFormat('yyyy-MM-dd');
      final startDate = start != null ? fmt.format(start) : null;
      final endDate = fmt.format(now);

      final owner = _globalOwnerCtrl.text.trim();
      final proposalType = _globalProposalTypeCtrl.text.trim();
      final client = _globalClientCtrl.text.trim();
      final region = _globalRegionCtrl.text.trim();
      final currentUser = context.read<AppState>().currentUser;
      final department = (currentUser?['department'] ?? '').toString().trim();

      return await context.read<AppState>().getOwnerLeaderboardAnalytics(
            startDate: startDate,
            endDate: endDate,
            owner: owner.isEmpty ? null : owner,
            proposalType: proposalType.isEmpty ? null : proposalType,
            client: client.isEmpty ? null : client,
            region: region.isEmpty ? null : region,
            scope: _cycleTimeScope,
            department: department.isEmpty ? null : department,
          );
    } catch (e) {
      print('Owner leaderboard exception: $e');
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

    final conversion = (data?['conversion'] as Map?) ?? {};
    final released = n(conversion['released']);
    final signed = n(conversion['signed']);
    final rateRaw = conversion['rate_percent'];
    final rate = (rateRaw is num) ? rateRaw.toDouble() : null;
    final conversionLabel =
        rate == null ? '--' : '${rate.toStringAsFixed(1)}% ($signed/$released)';

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
            statChip('Conversion', conversionLabel, PremiumTheme.success),
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
    _scrollController.dispose();
    _cycleTimeRefreshTimer?.cancel();
    _cycleTimeOwnerCtrl.dispose();
    _cycleTimeProposalTypeCtrl.dispose();
    _globalClientCtrl.dispose();
    _globalRegionCtrl.dispose();
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
    int sentCount = 0;
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

      final isSentLike = statusLower.contains('sent to client') ||
          statusLower.contains('released') ||
          statusLower.contains('in review') ||
          statusLower.contains('review') ||
          statusLower.contains('pending approval');
      if (isSentLike) {
        sentCount++;
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
          valueLabel: budget > 0 ? _formatCurrency(budget) : '--',
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

    final int decisions = winCount + lossCount;
    double winRate = decisions > 0 ? (winCount / decisions) * 100 : 0.0;
    double lossRate = decisions > 0 ? (lossCount / decisions) * 100 : 0.0;

    // If we don't have explicit loss statuses yet, fall back to a pipeline-style
    // conversion: Signed / Sent-to-Client (and similar "sent-like" stages).
    if (decisions == 0 && sentCount > 0) {
      winRate = (winCount / sentCount) * 100;
      lossRate = 100 - winRate;
    }
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

    Widget scopeToggle() {
      final isAdminUser = _isAdminUser();
      if (!isAdminUser) {
        if (_cycleTimeScope != 'self') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _cycleTimeScope = 'self');
          });
        }
        return glassField(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scope: Me',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.lock,
                size: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        );
      }

      return glassField(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _cycleTimeScope,
            dropdownColor: const Color(0xFF0A0E27),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'team', child: Text('Scope: Team')),
              DropdownMenuItem(value: 'self', child: Text('Scope: Me')),
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
      );
    }

    Widget ownerPicker() {
      if (!_isAdminUser()) {
        return const SizedBox.shrink();
      }

      String ownerLabelForUser(Map<String, dynamic> u) {
        final name = (u['full_name'] ?? u['name'] ?? '').toString().trim();
        final username = (u['username'] ?? '').toString().trim();
        final email = (u['email'] ?? '').toString().trim();
        if (name.isNotEmpty && username.isNotEmpty) return '$name (@$username)';
        if (name.isNotEmpty && email.isNotEmpty) return '$name ($email)';
        if (username.isNotEmpty) return '@$username';
        if (email.isNotEmpty) return email;
        return (u['id'] ?? '').toString();
      }

      String ownerQueryValue(Map<String, dynamic> u) {
        final username = (u['username'] ?? '').toString().trim();
        if (username.isNotEmpty) return username;
        final email = (u['email'] ?? '').toString().trim();
        if (email.isNotEmpty) return email;
        final id = (u['id'] ?? '').toString().trim();
        return id;
      }

      return SizedBox(
        width: 260,
        child: glassField(
          child: Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              final q = textEditingValue.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
              return _ownerSuggestions.where((u) {
                final label = ownerLabelForUser(u).toLowerCase();
                return label.contains(q);
              });
            },
            displayStringForOption: (u) => ownerLabelForUser(u),
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
              if (_selectedOwner != null &&
                  textEditingController.text.trim().isEmpty) {
                textEditingController.text = ownerLabelForUser(_selectedOwner!);
              }
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Owner (optional)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  suffixIcon: (_selectedOwner != null)
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 16, color: Colors.white70),
                          onPressed: () {
                            setState(() {
                              _selectedOwner = null;
                              _globalOwnerCtrl.clear();
                              _cycleTimeRefreshTick++;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  _searchOwners(v);
                },
                onSubmitted: (_) {
                  onFieldSubmitted();
                  setState(() => _cycleTimeRefreshTick++);
                },
              );
            },
            onSelected: (u) {
              final value = ownerQueryValue(u);
              setState(() {
                _selectedOwner = u;
                _globalOwnerCtrl.text = value;
                _cycleTimeRefreshTick++;
              });
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: const Color(0xFF0A0E27),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          dense: true,
                          title: Text(
                            ownerLabelForUser(option),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        scopeToggle(),
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
        ownerPicker(),
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
                    _globalOwnerCtrl.clear();
                    _selectedOwner = null;
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
    // Treat only true admin-style roles as admin here.
    // Managers/creators should keep the creator sidebar; admins get admin view.
    return backendRole == 'admin' ||
        backendRole == 'ceo' ||
        backendRole == 'finance_manager' ||
        backendRole == 'financial manager';
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
    final passRate =
        (totals['pass_rate'] is num) ? (totals['pass_rate'] as num).toInt() : 0;
    final ratio = total <= 0 ? 0.0 : (passed / total).clamp(0.0, 1.0);

    return Center(
      child: InkWell(
        onTap: () => _showCompletionRatesDialog(data),
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
                    passRate >= 90
                        ? PremiumTheme.success
                        : passRate >= 60
                            ? PremiumTheme.warning
                            : PremiumTheme.error,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$passRate%',
                    style: PremiumTheme.displayMedium.copyWith(fontSize: 34),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$passed of $total passing',
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: PremiumTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to drill down',
                    style: PremiumTheme.bodySmall.copyWith(
                      color: Colors.white70,
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
    final isAdminUser = _isAdminUser();
    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            if (isAdminUser)
              Material(
                child: AdminSidebar(
                  isCollapsed: _isSidebarCollapsed,
                  currentPage: 'Analytics',
                  onToggle: () => setState(
                    () => _isSidebarCollapsed = !_isSidebarCollapsed,
                  ),
                  onSelect: _navigatePage,
                ),
              )
            else
              AppSideNav(
                isCollapsed: _isSidebarCollapsed,
                currentLabel: 'Analytics (My Pipeline)',
                isAdmin: false,
                onToggle: () => setState(
                  () => _isSidebarCollapsed = !_isSidebarCollapsed,
                ),
                onSelect: _navigatePage,
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
                              const SizedBox(height: 18),
                              _buildGlobalFilterBar(),
                              if (isAdminUser) ...[
                                const SizedBox(height: 18),
                                FutureBuilder<Map<String, dynamic>?>(
                                  future: _fetchOwnerLeaderboard(),
                                  builder: (context, snapshot) {
                                    final rows =
                                        (snapshot.data?['rows'] as List?) ?? [];
                                    final detail =
                                        (snapshot.data?['detail'] ?? '').toString();

                                    Widget headerChip(String label) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.06),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.10),
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }

                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 15, sigmaY: 15),
                                        child: Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.10),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Owner Leaderboard',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: PremiumTheme
                                                          .titleLarge
                                                          .copyWith(
                                                              color: Colors
                                                                  .white),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  headerChip(
                                                      _cycleTimeScope == 'self'
                                                          ? 'Me'
                                                          : 'Team'),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Sent, signed, and conversion rate by owner',
                                                style: PremiumTheme.bodySmall
                                                    .copyWith(
                                                  color:
                                                      PremiumTheme.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              if (snapshot.connectionState ==
                                                      ConnectionState.waiting &&
                                                  rows.isEmpty)
                                                const LinearProgressIndicator(
                                                  minHeight: 2,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                )
                                              else if (snapshot.hasError)
                                                Text(
                                                  snapshot.error.toString(),
                                                  style: PremiumTheme.bodySmall
                                                      .copyWith(
                                                          color:
                                                              Colors.white70),
                                                )
                                              else if (detail.isNotEmpty)
                                                Text(
                                                  detail,
                                                  style: PremiumTheme.bodySmall
                                                      .copyWith(
                                                          color:
                                                              Colors.white70),
                                                )
                                              else if (rows.isEmpty)
                                                Text(
                                                  'No leaderboard data for selected filters.',
                                                  style: PremiumTheme.bodySmall
                                                      .copyWith(
                                                          color:
                                                              Colors.white70),
                                                )
                                              else
                                                Column(
                                                  children: rows
                                                      .take(8)
                                                      .map<Widget>((r) {
                                                    final owner =
                                                        (r['owner'] ?? '')
                                                            .toString();
                                                    final sent =
                                                        (r['sent'] ?? 0) as int;
                                                    final signed =
                                                        (r['signed'] ?? 0) as int;
                                                    final conv =
                                                        ((r['conversion_rate'] ??
                                                                    0.0)
                                                                as num)
                                                            .toDouble();
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 10),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              owner,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                  color:
                                                                      Colors.white,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight.w600),
                                                            ),
                                                          ),
                                                          Container(
                                                            width: 90,
                                                            alignment:
                                                                Alignment.centerRight,
                                                            child: Text(
                                                              '$sent',
                                                              style: const TextStyle(
                                                                  color:
                                                                      Colors.white70,
                                                                  fontSize: 13),
                                                            ),
                                                          ),
                                                          Container(
                                                            width: 90,
                                                            alignment:
                                                                Alignment.centerRight,
                                                            child: Text(
                                                              '$signed',
                                                              style: const TextStyle(
                                                                  color:
                                                                      Colors.white70,
                                                                  fontSize: 13),
                                                            ),
                                                          ),
                                                          Container(
                                                            width: 120,
                                                            alignment:
                                                                Alignment.centerRight,
                                                            child: Text(
                                                              '${(conv * 100).toStringAsFixed(1)}%',
                                                              style: const TextStyle(
                                                                  color:
                                                                      Colors.white70,
                                                                  fontSize: 13),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                              const SizedBox(height: 28),
                              const SizedBox(height: 4),
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
                                          'pipeline_bundle_${_cycleTimeRefreshTick}_${_selectedPeriod}_${_cycleTimeScope}_${_globalClientCtrl.text}_${_globalOwnerCtrl.text}_${_globalProposalTypeCtrl.text}_${_pipelineStageFilter ?? ''}'),
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
                                        final approvalsSummary =
                                            (bundle?['approvals_summary']
                                                    as Map?)
                                                ?.cast<String, dynamic>();
                                        final approvalsBottlenecks =
                                            (bundle?['approvals_bottlenecks']
                                                    as Map?)
                                                ?.cast<String, dynamic>();
                                        final readinessGovernance =
                                            (bundle?['readiness_governance']
                                                    as Map?)
                                                ?.cast<String, dynamic>();
                                        final riskGateDetails =
                                            (bundle?['risk_gate_details']
                                                    as Map?)
                                                ?.cast<String, dynamic>();
                                        final stageAging =
                                            (bundle?['stage_aging'] as Map?)
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

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _buildGlassChartCard(
                                              'Proposal Pipeline View',
                                              pipelineBody,
                                              height: 520,
                                            ),
                                            const SizedBox(height: 32),
                                            CompletionRatesWidget(
                                              onOpenProposal:
                                                  (id, status, title) =>
                                                      Navigator.pushNamed(
                                                context,
                                                '/blank-document',
                                                arguments: {
                                                  'proposalId':
                                                      id.toString(),
                                                  'proposalTitle': title,
                                                  'readOnly': false,
                                                },
                                              ),
                                              startDate: _periodStart(DateTime.now()),
                                              endDate: DateTime.now(),
                                              scope: _cycleTimeScope,
                                              owner: _globalOwnerCtrl.text.trim().isEmpty
                                                  ? null
                                                  : _globalOwnerCtrl.text.trim(),
                                              proposalType:
                                                  _globalProposalTypeCtrl.text.trim().isEmpty
                                                      ? null
                                                      : _globalProposalTypeCtrl.text.trim(),
                                              client: _globalClientCtrl.text.trim().isEmpty
                                                  ? null
                                                  : _globalClientCtrl.text.trim(),
                                              department: ((context
                                                              .read<AppState>()
                                                              .currentUser?['department'] ??
                                                          '')
                                                      .toString()
                                                      .trim()
                                                      .isEmpty)
                                                  ? null
                                                  : (context
                                                          .read<AppState>()
                                                          .currentUser?['department'] ??
                                                      '')
                                                      .toString()
                                                      .trim(),
                                            ),
                                            const SizedBox(height: 32),
                                            _buildGlassChartCard(
                                              'Approval Analytics',
                                              SingleChildScrollView(
                                                child: _buildApprovalsCard(
                                                  approvalsSummary,
                                                  approvalsBottlenecks,
                                                ),
                                              ),
                                              height: 260,
                                            ),
                                            const SizedBox(height: 32),
                                            _buildGlassChartCard(
                                              'Readiness & Governance',
                                              SingleChildScrollView(
                                                child:
                                                    _buildReadinessGovernanceCard(
                                                  readinessGovernance,
                                                ),
                                              ),
                                              height: 260,
                                            ),
                                            const SizedBox(height: 32),
                                            _buildGlassChartCard(
                                              'Risk Gate Details',
                                              SingleChildScrollView(
                                                child: _buildRiskGateDetailsCard(
                                                  riskGateDetails,
                                                ),
                                              ),
                                              height: 280,
                                            ),
                                            const SizedBox(height: 32),
                                            _buildGlassChartCard(
                                              'Stage Aging',
                                              SingleChildScrollView(
                                                child: _buildStageAgingCard(
                                                  stageAging,
                                                ),
                                              ),
                                              height: 240,
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  void _navigatePage(String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/approver_dashboard');
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
      case 'Approvals':
        Navigator.pushReplacementNamed(context, '/admin_approvals');
        break;
      case 'Analytics':
      case 'Analytics (My Pipeline)':
        break; // already on this page
      case 'History':
        Navigator.pushReplacementNamed(
          context,
          '/admin_approvals',
          arguments: const {'initialFilter': 'approved'},
        );
        break;
      case 'Logout':
        Navigator.pushReplacementNamed(context, '/login');
        break;
    }
  }

  Widget _buildGlassButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    String label,
    String iconAsset,
    bool isActive,
    BuildContext context,
  ) {
    final collapsed = _isSidebarCollapsed;
    return Tooltip(
      message: collapsed ? label : '',
      child: InkWell(
        onTap: () {
          switch (label) {
            case 'Logout':
              Navigator.pushReplacementNamed(context, '/login');
              break;
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
            case 'Approvals':
              Navigator.pushReplacementNamed(context, '/approved_proposals');
              break;
            case 'Analytics':
            case 'Analytics (My Pipeline)':
              Navigator.pushReplacementNamed(context, '/analytics');
              break;
            default:
              Navigator.pushReplacementNamed(context, '/creator_dashboard');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 10 : 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Image.asset(
                iconAsset,
                width: 22,
                height: 22,
                color: isActive ? Colors.white : Colors.white70,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.circle,
                  size: 20,
                  color: isActive ? Colors.white : Colors.white70,
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
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
} // end _AnalyticsPageState

// ---------------------------------------------------------------------------
// Data classes used by analytics charts / tables
// ---------------------------------------------------------------------------

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

  String get label =>
      DateFormat.MMM().format(month);
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

  const _ProposalPerformanceRow({
    required this.title,
    this.value,
    required this.valueLabel,
    required this.status,
    required this.daysOpen,
    required this.probability,
    required this.statusColor,
    this.updatedAt,
  });

  String get probabilityLabel =>
      '${(probability * 100).toStringAsFixed(0)}%';
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
    this.revenueChangePercent,
    this.activeChangePercent,
    this.conversionChangePercent,
    this.averageDealChangePercent,
  });
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
