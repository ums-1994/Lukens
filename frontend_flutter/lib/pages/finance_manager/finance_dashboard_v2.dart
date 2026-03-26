import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:html' as html;

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/finance/finance_sidebar.dart';
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
  static const List<String> _validStatusFilters = [
    'all',
    'pending_review',
    'in_pricing',
    'released',
    'signed',
  ];
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _currentTab = 'dashboard'; // dashboard, proposals, clients

  int _selectedYear = DateTime.now().year;
  Future<Map<String, dynamic>>? _financeSummaryFuture;
  Future<List<Map<String, dynamic>>>? _monthlyForecastFuture;
  Future<List<Map<String, dynamic>>>? _funnelFuture;
  Future<List<Map<String, dynamic>>>? _growthFuture;
  Future<List<Map<String, dynamic>>>? _topClientsFuture;
  Future<List<Map<String, dynamic>>>? _recentSignedFuture;
  Future<List<Map<String, dynamic>>>? _agingFuture;
  Future<List<Map<String, dynamic>>>? _alertsFuture;

  bool _auditLoading = false;
  List<Map<String, dynamic>> _auditItems = [];
  DateTime? _auditFrom;
  DateTime? _auditTo;
  final TextEditingController _auditUserController = TextEditingController();
  final TextEditingController _auditEntityTypeController =
      TextEditingController();
  final TextEditingController _auditActionTypeController =
      TextEditingController();

  bool _handledInitialOpen = false;
  int _aiUsageRefreshTick = 0;
  Timer? _aiUsageRefreshTimer;
  Future<Map<String, dynamic>?>? _aiUsageFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _aiUsageFuture = _fetchAiUsageAnalytics();
    _aiUsageRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (_currentTab != 'dashboard') return;
      setState(() {
        _aiUsageRefreshTick++;
        _aiUsageFuture = _fetchAiUsageAnalytics();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Ensure forecast is loaded once we have an auth token in context.
    _monthlyForecastFuture ??= _fetchMonthlyForecast(year: _selectedYear);
    _financeSummaryFuture ??= _fetchFinanceSummary(year: _selectedYear);
    _funnelFuture ??= _fetchFunnel(year: _selectedYear);
    _growthFuture ??= _fetchGrowth(year: _selectedYear);
    _topClientsFuture ??= _fetchTopClients(year: _selectedYear);
    _recentSignedFuture ??= _fetchRecentSigned(year: _selectedYear);
    _agingFuture ??= _fetchAging(year: _selectedYear);
    _alertsFuture ??= _fetchAlerts(year: _selectedYear);

    if (_handledInitialOpen) return;
    _handledInitialOpen = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final String? initialTab = args['initialTab']?.toString();
    if (initialTab != null && initialTab.trim().isNotEmpty) {
      final t = initialTab.trim().toLowerCase();
      if (t == 'audit') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _currentTab = 'audit');
          _loadAuditLogs();
        });
      } else if (t == 'dashboard' || t == 'proposals' || t == 'clients') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _currentTab = t);
        });
      } else if (t == 'client management') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _currentTab = 'clients');
        });
      }
    }

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
    _aiUsageRefreshTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _auditUserController.dispose();
    _auditEntityTypeController.dispose();
    _auditActionTypeController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchMonthlyForecast(
      {required int year}) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return [];

    final uri = Uri.parse('${baseUrl}/api/finance/forecast/monthly')
        .replace(queryParameters: {'year': year.toString()});

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      debugPrint('Monthly forecast error: ${resp.statusCode} ${resp.body}');
      return [];
    }

    final decoded = jsonDecode(resp.body);
    final itemsAny = (decoded is Map) ? decoded['items'] : null;
    if (itemsAny is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final r in itemsAny) {
      if (r is Map<String, dynamic>) {
        out.add(r);
      } else if (r is Map) {
        out.add(r.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  Future<Map<String, dynamic>> _fetchFinanceSummary({required int year}) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return {};

    final uri = Uri.parse('${baseUrl}/api/finance/summary')
        .replace(queryParameters: {'year': year.toString()});

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      debugPrint('Finance summary error: ${resp.statusCode} ${resp.body}');
      return {};
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> _fetchListEndpoint(
    String path, {
    required int year,
    Map<String, String>? query,
    String itemsKey = 'items',
  }) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return [];

    final uri = Uri.parse('${baseUrl}$path').replace(
      queryParameters: {
        'year': year.toString(),
        ...?query,
      },
    );

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      debugPrint(
          'Finance endpoint error $path: ${resp.statusCode} ${resp.body}');
      return [];
    }

    final decoded = jsonDecode(resp.body);
    final itemsAny = (decoded is Map) ? decoded[itemsKey] : null;
    if (itemsAny is! List) return [];

    final out = <Map<String, dynamic>>[];
    for (final r in itemsAny) {
      if (r is Map<String, dynamic>) {
        out.add(r);
      } else if (r is Map) {
        out.add(r.map((k, v) => MapEntry(k.toString(), v)));
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _fetchFunnel({required int year}) async {
    return _fetchListEndpoint('/api/finance/funnel', year: year);
  }

  Future<List<Map<String, dynamic>>> _fetchGrowth({required int year}) async {
    return _fetchListEndpoint('/api/finance/revenue-growth', year: year);
  }

  Future<List<Map<String, dynamic>>> _fetchTopClients(
      {required int year}) async {
    return _fetchListEndpoint('/api/finance/top-clients',
        year: year, query: {'limit': '10'});
  }

  Future<List<Map<String, dynamic>>> _fetchRecentSigned(
      {required int year}) async {
    return _fetchListEndpoint('/api/finance/recent-signed',
        year: year, query: {'limit': '10'});
  }

  Future<List<Map<String, dynamic>>> _fetchAging({required int year}) async {
    return _fetchListEndpoint('/api/finance/deal-aging',
        year: year, query: {'threshold_days': '30'});
  }

  Future<List<Map<String, dynamic>>> _fetchAlerts({required int year}) async {
    return _fetchListEndpoint('/api/finance/alerts', year: year);
  }

  Widget _buildYearSelector() {
    final nowYear = DateTime.now().year;
    final years = List<int>.generate(5, (i) => nowYear - 2 + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          dropdownColor: const Color(0xFF0F0F0F),
          iconEnabledColor: Colors.white70,
          style: PremiumTheme.bodyMedium.copyWith(color: Colors.white),
          items: years
              .map(
                (y) => DropdownMenuItem<int>(
                  value: y,
                  child: Text(y.toString()),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _selectedYear = v;
              _monthlyForecastFuture =
                  _fetchMonthlyForecast(year: _selectedYear);
              _financeSummaryFuture = _fetchFinanceSummary(year: _selectedYear);
              _funnelFuture = _fetchFunnel(year: _selectedYear);
              _growthFuture = _fetchGrowth(year: _selectedYear);
              _topClientsFuture = _fetchTopClients(year: _selectedYear);
              _recentSignedFuture = _fetchRecentSigned(year: _selectedYear);
              _agingFuture = _fetchAging(year: _selectedYear);
              _alertsFuture = _fetchAlerts(year: _selectedYear);
            });
          },
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: PremiumTheme.darkBg2.withOpacity(0.9),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style:
                      PremiumTheme.labelMedium.copyWith(color: Colors.white60),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: PremiumTheme.titleMedium
                      .copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceKpis() {
    final future =
        _financeSummaryFuture ?? _fetchFinanceSummary(year: _selectedYear);
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final loading = snapshot.connectionState == ConnectionState.waiting;

        final pipeline = (data['pipeline_value'] is num)
            ? (data['pipeline_value'] as num).toDouble()
            : double.tryParse(data['pipeline_value']?.toString() ?? '') ?? 0.0;
        final expected = (data['expected_revenue'] is num)
            ? (data['expected_revenue'] as num).toDouble()
            : double.tryParse(data['expected_revenue']?.toString() ?? '') ??
                0.0;
        final signed = (data['signed_revenue'] is num)
            ? (data['signed_revenue'] as num).toDouble()
            : double.tryParse(data['signed_revenue']?.toString() ?? '') ?? 0.0;
        final winRate = (data['win_rate'] is num)
            ? (data['win_rate'] as num).toDouble()
            : double.tryParse(data['win_rate']?.toString() ?? '') ?? 0.0;
        final avgDeal = (data['average_deal_size'] is num)
            ? (data['average_deal_size'] as num).toDouble()
            : double.tryParse(data['average_deal_size']?.toString() ?? '') ??
                0.0;

        final cards = [
          _buildKpiCard(
            label: 'Total Pipeline Value',
            value: loading ? '--' : _formatCurrency(pipeline),
            icon: Icons.stacked_line_chart,
            color: PremiumTheme.info,
          ),
          _buildKpiCard(
            label: 'Expected Revenue',
            value: loading ? '--' : _formatCurrency(expected),
            icon: Icons.auto_graph,
            color: PremiumTheme.teal,
          ),
          _buildKpiCard(
            label: 'Signed Revenue',
            value: loading ? '--' : _formatCurrency(signed),
            icon: Icons.verified,
            color: const Color(0xFF34A853),
          ),
          _buildKpiCard(
            label: 'Win Rate',
            value: loading ? '--' : '${(winRate * 100).toStringAsFixed(1)}%',
            icon: Icons.trending_up,
            color: PremiumTheme.purple,
          ),
          _buildKpiCard(
            label: 'Average Deal Size',
            value: loading ? '--' : _formatCurrency(avgDeal),
            icon: Icons.payments,
            color: Colors.orange,
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            int columns;
            if (w >= 1300) {
              columns = 5;
            } else if (w >= 980) {
              columns = 5;
            } else if (w >= 760) {
              columns = 3;
            } else {
              columns = 2;
            }

            final spacing = 12.0;
            final cardWidth =
                ((w - (columns - 1) * spacing) / columns).clamp(160.0, 420.0);

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final c in cards)
                  SizedBox(
                    width: cardWidth,
                    child: c,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
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
          SizedBox(height: 240, child: child),
        ],
      ),
    );
  }

  Widget _buildFunnelChart() {
    final future = _funnelFuture ?? _fetchFunnel(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
            ),
          );
        }
        final items = snapshot.data ?? [];
        final stages = <String>[];
        final values = <double>[];
        for (final r in items) {
          final s = (r['stage'] ?? '').toString();
          if (s.isEmpty) continue;
          stages.add(s);
          values.add((r['value'] is num)
              ? (r['value'] as num).toDouble()
              : double.tryParse(r['value']?.toString() ?? '') ?? 0.0);
        }
        if (stages.isEmpty) {
          return Center(
            child: Text(
              'No data',
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
            ),
          );
        }

        final maxY = (values.fold<double>(0, (a, b) => a > b ? a : b))
            .clamp(1, double.infinity);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.1,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 18,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  tooltipMargin: 12,
                  getTooltipColor: (group) => Colors.white.withOpacity(0.92),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = groupIndex >= 0 && groupIndex < stages.length
                        ? stages[groupIndex]
                        : '';
                    return BarTooltipItem(
                      '$label\nvalue : ${_formatCurrency(rod.toY)}',
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
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) {
                        return Text(
                          'R0',
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        );
                      }
                      if (value == meta.max) {
                        return Text(
                          _formatCurrency(value),
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= stages.length)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          stages[i],
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(stages.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      color: PremiumTheme.teal,
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignedRevenueGrowthChart() {
    final future = _growthFuture ?? _fetchGrowth(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
            ),
          );
        }
        final items = snapshot.data ?? [];
        final months = <String>[];
        final values = <double>[];
        for (final r in items) {
          final m = (r['month'] ?? '').toString();
          if (m.length < 7) continue;
          months.add(m);
          values.add((r['signed_revenue'] is num)
              ? (r['signed_revenue'] as num).toDouble()
              : double.tryParse(r['signed_revenue']?.toString() ?? '') ?? 0.0);
        }
        if (months.isEmpty) {
          return Center(
            child: Text(
              'No data',
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
            ),
          );
        }

        final now = DateTime.now();
        int endIndex = months.length - 1;
        if (_selectedYear == now.year) {
          // Prefer to end at the current month so the chart doesn't jump to
          // Jul-Dec just because the API returns Jan-Dec buckets.
          final currentKey =
              '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
          final idx = months.indexOf(currentKey);
          if (idx >= 0) {
            endIndex = idx;
          }
        }

        final displayCount = (endIndex + 1) >= 6 ? 6 : (endIndex + 1);
        final startIndex = (endIndex - displayCount + 1).clamp(0, endIndex);
        final months6 = months.sublist(startIndex, endIndex + 1);
        final values6 = values.sublist(startIndex, endIndex + 1);

        double maxY = 0;
        for (final v in values6) {
          if (v > maxY) maxY = v;
        }

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
              maxX: (displayCount - 1).toDouble(),
              minY: 0,
              maxY: (maxY <= 0 ? 1 : maxY) * 1.1,
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipMargin: 12,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  getTooltipColor: (touchedSpot) =>
                      Colors.white.withOpacity(0.96),
                  getTooltipItems: (touchedSpots) {
                    if (touchedSpots.isEmpty) return [];
                    final idx =
                        touchedSpots.first.x.round().clamp(0, displayCount - 1);
                    final monthKey = months6[idx];
                    DateTime? parsed;
                    try {
                      final parts = monthKey.split('-');
                      parsed =
                          DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
                    } catch (_) {}
                    final monthLabel = parsed != null
                        ? DateFormat('MMM').format(parsed)
                        : monthKey;
                    final val = values6[idx];
                    final headerStyle = PremiumTheme.bodyMedium.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    );
                    final bodyStyle = PremiumTheme.bodyMedium.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    );
                    return [
                      LineTooltipItem(
                        '$monthLabel\n',
                        headerStyle,
                        children: [
                          TextSpan(
                            text: 'Signed : ${_formatCurrency(val)}',
                            style: bodyStyle.copyWith(color: PremiumTheme.info),
                          ),
                        ],
                      )
                    ];
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
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        );
                      }
                      if (value == meta.max) {
                        return Text(
                          _formatCurrency(value),
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
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
                      if (i < 0 || i >= months6.length)
                        return const SizedBox.shrink();
                      DateTime? parsed;
                      try {
                        final parts = months6[i].split('-');
                        parsed = DateTime(
                            int.parse(parts[0]), int.parse(parts[1]), 1);
                      } catch (_) {}
                      final label = parsed != null
                          ? DateFormat('MMM').format(parsed)
                          : months6[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label,
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                      displayCount, (i) => FlSpot(i.toDouble(), values6[i])),
                  isCurved: true,
                  color: PremiumTheme.info,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: PremiumTheme.info.withOpacity(0.10),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        final left = _buildPanel(
          title: 'Pipeline Funnel Chart',
          subtitle: 'Proposal value by stage',
          child: _buildFunnelChart(),
        );
        final mid = _buildPanel(
          title: 'Revenue Forecast Chart',
          subtitle: 'Forecasted revenue by month',
          child: _buildRevenueForecastChart(),
        );
        final right = _buildPanel(
          title: 'Signed Revenue Growth',
          subtitle: 'Signed revenue trend',
          child: _buildSignedRevenueGrowthChart(),
        );

        if (isNarrow) {
          return Column(
            children: [
              left,
              const SizedBox(height: 12),
              mid,
              const SizedBox(height: 12),
              right,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: mid),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildSimpleListPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
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
          Text(subtitle,
              style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchAiUsageAnalytics() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final fmt = DateFormat('yyyy-MM-dd');
    return context.read<AppState>().getAiUsageAnalytics(
          startDate: fmt.format(start),
          endDate: fmt.format(now),
        );
  }

  Widget _buildAiUsageDashboardPanel() {
    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('finance_dashboard_ai_usage_$_aiUsageRefreshTick'),
      future: _aiUsageFuture ?? _fetchAiUsageAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (snapshot.hasError || data == null) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Failed to load AI usage data.',
                style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
              ),
            ),
          );
        }

        if (data['error_status'] != null) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Unable to load AI usage (${data['error_status']}).',
                style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
              ),
            ),
          );
        }

        int n(dynamic v) {
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse((v ?? '').toString()) ?? 0;
        }

        final totals = (data['totals'] as Map?)?.cast<String, dynamic>() ?? {};
        final endpointSplit = ((data['endpoint_split'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final topUsers = ((data['top_users'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        final usageSummary =
            (data['usage_summary'] as Map?)?.cast<String, dynamic>() ?? {};
        final acceptanceRate = (totals['acceptance_rate'] is num)
            ? (totals['acceptance_rate'] as num).toDouble()
            : 0.0;
        final averageSpendZar = (usageSummary['average_spend_zar'] is num)
            ? (usageSummary['average_spend_zar'] as num).toDouble()
            : 0.0;
        final averageSpendReason =
            (usageSummary['average_spend_reason'] ?? '').toString();

        Widget chip(String label, String value) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              '$label: $value',
              style: PremiumTheme.labelMedium.copyWith(color: Colors.white70),
            ),
          );
        }

        Widget listColumn(String title, List<Map<String, dynamic>> rows,
            String leftKey, String rightKey) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PremiumTheme.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  Text(
                    'No data',
                    style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
                  )
                else
                  ...rows.take(8).map(
                        (row) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (row[leftKey] ?? '-').toString(),
                                  overflow: TextOverflow.ellipsis,
                                  style: PremiumTheme.bodyMedium
                                      .copyWith(color: Colors.white70),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                (row[rightKey] ?? '0').toString(),
                                style: PremiumTheme.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                chip('Requests', n(totals['total_requests']).toString()),
                chip('Success', n(totals['success_count']).toString()),
                chip('Failed', n(totals['failed_count']).toString()),
                chip('Blocked', n(totals['blocked_count']).toString()),
                chip('Acceptance', '${acceptanceRate.toStringAsFixed(1)}%'),
                chip(
                    'Tokens', NumberFormat.compact().format(n(usageSummary['total_tokens']))),
                chip('Cost',
                    'R ${((usageSummary['estimated_cost_zar'] as num?) ?? 0).toStringAsFixed(2)}'),
                chip('Average Spent', 'R ${averageSpendZar.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 12),
            if (averageSpendReason.isNotEmpty)
              Text(
                'Reason: $averageSpendReason',
                style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
              ),
            if (averageSpendReason.isNotEmpty) const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 980;
                final left =
                    listColumn('By Endpoint', endpointSplit, 'endpoint', 'requests');
                final right =
                    listColumn('Top Users', topUsers, 'username', 'requests');
                if (narrow) {
                  return Column(
                    children: [
                      left,
                      const SizedBox(height: 10),
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
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopClientsPanel() {
    final future = _topClientsFuture ?? _fetchTopClients(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text('No data',
                  style:
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white60)),
            ),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '#${i + 1}',
                      style: PremiumTheme.labelMedium
                          .copyWith(color: Colors.white60),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (items[i]['client'] ?? '').toString(),
                      style:
                          PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatCurrency((items[i]['revenue'] is num)
                        ? (items[i]['revenue'] as num).toDouble()
                        : double.tryParse(
                                items[i]['revenue']?.toString() ?? '') ??
                            0.0),
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (i != items.length - 1)
                Divider(color: Colors.white.withOpacity(0.06), height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRecentSignedPanel() {
    final future =
        _recentSignedFuture ?? _fetchRecentSigned(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text('No data',
                  style:
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white60)),
            ),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (items[i]['proposal'] ?? '').toString(),
                          style: PremiumTheme.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (items[i]['client'] ?? '').toString(),
                          style: PremiumTheme.labelMedium
                              .copyWith(color: Colors.white60),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatCurrency((items[i]['amount'] is num)
                        ? (items[i]['amount'] as num).toDouble()
                        : double.tryParse(
                                items[i]['amount']?.toString() ?? '') ??
                            0.0),
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (i != items.length - 1)
                Divider(color: Colors.white.withOpacity(0.06), height: 14),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAgingPanel() {
    final future = _agingFuture ?? _fetchAging(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text('No stalled deals > 30 days',
                  style:
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white60)),
            ),
          );
        }

        final shown = items.take(8).toList();
        return Column(
          children: [
            for (int i = 0; i < shown.length; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (shown[i]['proposal'] ?? '').toString(),
                      style:
                          PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${shown[i]['days_in_stage'] ?? ''}d',
                    style: PremiumTheme.bodyMedium.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (i != shown.length - 1)
                Divider(color: Colors.white.withOpacity(0.06), height: 14),
            ],
          ],
        );
      },
    );
  }

  Color _alertColor(String severity) {
    final s = severity.toLowerCase();
    if (s == 'warning') return Colors.orange;
    if (s == 'critical') return Colors.redAccent;
    return PremiumTheme.info;
  }

  Widget _buildAlertsPanel() {
    final future = _alertsFuture ?? _fetchAlerts(year: _selectedYear);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.7)),
              ),
            ),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return SizedBox(
            height: 80,
            child: Center(
              child: Text('No alerts',
                  style:
                      PremiumTheme.bodyMedium.copyWith(color: Colors.white60)),
            ),
          );
        }

        final shown = items.take(10).toList();
        return Column(
          children: [
            for (int i = 0; i < shown.length; i++) ...[
              Row(
                children: [
                  Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                      color: _alertColor(
                          (shown[i]['severity'] ?? 'info').toString()),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (shown[i]['type'] ?? '').toString().replaceAll('_', ' '),
                      style:
                          PremiumTheme.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    (shown[i]['client'] ?? '').toString(),
                    style: PremiumTheme.labelMedium
                        .copyWith(color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (i != shown.length - 1)
                Divider(color: Colors.white.withOpacity(0.06), height: 14),
            ],
          ],
        );
      },
    );
  }

  bool _canAccessAudit(AppState app) {
    final role = (app.currentUser?['role'] ?? '').toString().toLowerCase();
    return role == 'finance_manager' || role == 'admin' || role == 'ceo';
  }

  Map<String, String> _auditQueryParams({
    required int limit,
    required int offset,
  }) {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (_auditFrom != null) {
      params['date_from'] = _auditFrom!.toUtc().toIso8601String();
    }
    if (_auditTo != null) {
      params['date_to'] = _auditTo!.toUtc().toIso8601String();
    }
    final u = _auditUserController.text.trim();
    if (u.isNotEmpty) params['user'] = u;
    final et = _auditEntityTypeController.text.trim();
    if (et.isNotEmpty) params['entity_type'] = et;
    final at = _auditActionTypeController.text.trim();
    if (at.isNotEmpty) params['action_type'] = at;
    return params;
  }

  Future<void> _loadAuditLogs() async {
    if (_auditLoading) return;
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return;

    setState(() => _auditLoading = true);
    try {
      final uri = Uri.parse('${baseUrl}/api/finance/audit-logs').replace(
        queryParameters: _auditQueryParams(limit: 250, offset: 0),
      );

      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final itemsAny = (decoded is Map) ? decoded['items'] : null;
        final items = <Map<String, dynamic>>[];
        if (itemsAny is List) {
          for (final r in itemsAny) {
            if (r is Map<String, dynamic>) {
              items.add(r);
            } else if (r is Map) {
              items.add(r.map((k, v) => MapEntry(k.toString(), v)));
            }
          }
        }
        setState(() => _auditItems = items);
      } else {
        debugPrint('Audit logs error: ${resp.statusCode} ${resp.body}');
        setState(() => _auditItems = []);
      }
    } catch (e) {
      debugPrint('Audit logs exception: $e');
      setState(() => _auditItems = []);
    } finally {
      if (mounted) setState(() => _auditLoading = false);
    }
  }

  Future<void> _exportAuditLogs(String format) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return;

    final uri = Uri.parse('${baseUrl}/api/finance/audit-logs/export').replace(
      queryParameters: {
        ..._auditQueryParams(limit: 5000, offset: 0),
        'format': format,
      },
    );

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': format == 'pdf' ? 'application/pdf' : 'text/csv',
      },
    );

    if (resp.statusCode != 200) {
      debugPrint('Audit export failed: ${resp.statusCode} ${resp.body}');
      return;
    }

    if (kIsWeb) {
      final bytes = resp.bodyBytes;
      final mime = format == 'pdf' ? 'application/pdf' : 'text/csv';
      final fileName =
          'finance_audit_${DateTime.now().millisecondsSinceEpoch}.${format == 'pdf' ? 'pdf' : 'csv'}';
      final blob = html.Blob([bytes], mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      Future.delayed(const Duration(milliseconds: 500), () {
        html.Url.revokeObjectUrl(url);
      });
    }
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
        app.fetchNotifications(),
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

    // Use a large limit so finance sees all non-draft proposals (e.g. sent for pricing)
    const int maxProposals = 500;
    final recent = normalized.take(maxProposals).toList();

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
    return s.contains('pricing in progress') ||
        s.contains('in pricing') ||
        s == 'pricing in progress';
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

    double _parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      final cleaned = v.toString().replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned) ?? 0;
    }

    int? _findHeaderIndex(List<dynamic> headers, List<String> needles) {
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i].toString().toLowerCase().trim();
        for (final n in needles) {
          if (h == n || h.contains(n)) return i;
        }
      }
      return null;
    }

    double _tableSubtotalFromCells(List<dynamic> cellsRaw) {
      if (cellsRaw.isEmpty) return 0;
      final headerRow = cellsRaw.first;
      if (headerRow is! List) return 0;

      final totalCol =
          _findHeaderIndex(headerRow, ['total', 'amount', 'line total']) ?? 4;
      final qtyCol = _findHeaderIndex(headerRow, ['quantity', 'qty']) ?? 2;
      final unitCol = _findHeaderIndex(headerRow, ['unit price', 'price']) ?? 3;

      double subtotal = 0;
      for (int i = 1; i < cellsRaw.length; i++) {
        final rowAny = cellsRaw[i];
        if (rowAny is! List) continue;

        final row = rowAny;
        double rowTotal = 0;
        if (totalCol >= 0 && totalCol < row.length) {
          rowTotal = _parseNum(row[totalCol]);
        }

        if (rowTotal == 0) {
          final qty = (qtyCol >= 0 && qtyCol < row.length)
              ? _parseNum(row[qtyCol])
              : 0.0;
          final unit = (unitCol >= 0 && unitCol < row.length)
              ? _parseNum(row[unitCol])
              : 0.0;
          rowTotal = qty * unit;
        }

        subtotal += rowTotal;
      }
      return subtotal;
    }

    double _sumPriceTablesFromSections(dynamic sectionsAny) {
      final List<dynamic> sectionsList;
      if (sectionsAny is List) {
        sectionsList = sectionsAny;
      } else if (sectionsAny is Map && sectionsAny['sections'] is List) {
        sectionsList = sectionsAny['sections'] as List;
      } else {
        return 0;
      }

      double _sumPriceTablesFromSectionMap(Map sAny) {
        double total = 0;

        void sumTablesList(dynamic tablesAny) {
          if (tablesAny is! List) return;
          for (final tAny in tablesAny) {
            if (tAny is! Map) continue;
            final type = (tAny['type'] ?? '').toString().toLowerCase().trim();
            if (type != 'price') continue;
            final cellsAny = tAny['cells'];
            if (cellsAny is! List) continue;
            final subtotal = _tableSubtotalFromCells(cellsAny);
            final vatRate = _parseNum(tAny['vatRate']);
            final vat = vatRate > 0 ? subtotal * vatRate : 0;
            total += (subtotal + vat);
          }
        }

        void sumPositionedTables(dynamic positionedAny) {
          if (positionedAny is! List) return;
          for (final pAny in positionedAny) {
            if (pAny is! Map) continue;
            final tableAny = pAny['table'];
            if (tableAny is! Map) continue;
            sumTablesList([tableAny]);
          }
        }

        sumTablesList(sAny['tables']);
        sumPositionedTables(sAny['positionedPricingTables']);

        final bodyAny = sAny['body'] ?? sAny['content'];
        if (bodyAny is Map) {
          sumTablesList(bodyAny['tables']);
          sumPositionedTables(bodyAny['positionedPricingTables']);
        }

        return total;
      }

      double total = 0;
      for (final sAny in sectionsList) {
        if (sAny is! Map) continue;
        total += _sumPriceTablesFromSectionMap(sAny);
      }
      return total;
    }

    dynamic sectionsAny = p['sections'];
    if (sectionsAny == null) {
      final contentAny = p['content'];
      if (contentAny is Map) {
        sectionsAny = contentAny['sections'] ?? contentAny;
      } else if (contentAny is String) {
        try {
          final decoded = jsonDecode(contentAny);
          if (decoded is Map || decoded is List) {
            sectionsAny = decoded;
          }
        } catch (_) {}
      }
    }

    return _sumPriceTablesFromSections(sectionsAny);
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
    if (s.contains('signed') || s.contains('approved')) {
      return 'Signed';
    }
    return 'Unknown';
  }

  Widget _buildAuditPanel() {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final fromLabel = _auditFrom == null ? 'From' : dateFmt.format(_auditFrom!);
    final toLabel = _auditTo == null ? 'To' : dateFmt.format(_auditTo!);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Audit Logs', style: PremiumTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _exportAuditLogs('csv'),
                icon:
                    const Icon(Icons.download, color: Colors.white70, size: 18),
                label:
                    const Text('CSV', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _exportAuditLogs('pdf'),
                icon: const Icon(Icons.picture_as_pdf,
                    color: Colors.white70, size: 18),
                label:
                    const Text('PDF', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _auditFrom ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  setState(() => _auditFrom = picked);
                  _loadAuditLogs();
                },
                icon: const Icon(Icons.date_range, color: Colors.white70),
                label: Text(fromLabel,
                    style: const TextStyle(color: Colors.white70)),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _auditTo ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  setState(() => _auditTo = picked);
                  _loadAuditLogs();
                },
                icon: const Icon(Icons.date_range, color: Colors.white70),
                label: Text(toLabel,
                    style: const TextStyle(color: Colors.white70)),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _auditUserController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'User',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: PremiumTheme.teal),
                    ),
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _auditEntityTypeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Entity Type',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: PremiumTheme.teal),
                    ),
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _auditActionTypeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Action Type',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: PremiumTheme.teal),
                    ),
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_auditLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(color: PremiumTheme.teal),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('Entity')),
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('Field')),
                  DataColumn(label: Text('Old')),
                  DataColumn(label: Text('New')),
                ],
                rows: _auditItems.map((r) {
                  final createdAt = (r['created_at'] ?? '').toString();
                  final uname = (r['username'] ?? '').toString();
                  final entity =
                      '${(r['entity_type'] ?? '').toString()}#${(r['entity_id'] ?? '').toString()}';
                  final action = (r['action_type'] ?? '').toString();
                  final field = (r['field_name'] ?? '').toString();
                  final oldV = (r['old_value'] ?? '').toString();
                  final newV = (r['new_value'] ?? '').toString();

                  Text cell(String v) => Text(
                        v,
                        style: PremiumTheme.bodySmall
                            .copyWith(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      );

                  return DataRow(cells: [
                    DataCell(cell(createdAt)),
                    DataCell(cell(uname)),
                    DataCell(cell(entity)),
                    DataCell(cell(action)),
                    DataCell(cell(field)),
                    DataCell(cell(oldV)),
                    DataCell(cell(newV)),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(AppState app) {
    final unread = app.unreadNotifications;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: 'Notifications',
            icon: Icon(
              unread > 0
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              color: Colors.white,
            ),
            onPressed: () async {
              await app.fetchNotifications();
              if (!mounted) return;
              _showNotificationsSheet(app);
            },
          ),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFE74C3C),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsSheet(AppState app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final notifications = app.notifications;
              final unreadCount = app.unreadNotifications;

              return Container(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(bottomSheetContext).size.height * 0.8,
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFF2C3E50),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Notifications',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (unreadCount > 0)
                                TextButton(
                                  onPressed: () async {
                                    await app.markAllNotificationsRead();
                                    setModalState(() {});
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFF3498DB),
                                  ),
                                  child: const Text(
                                    'Mark all read',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: notifications.isEmpty
                            ? const Center(
                                child: Text(
                                  'No notifications yet.',
                                  style: TextStyle(
                                    color: Color(0xFF4A4A4A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                itemCount: notifications.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 16),
                                itemBuilder: (context, index) {
                                  final rawItem = notifications[index];
                                  final Map<String, dynamic> notification =
                                      rawItem is Map<String, dynamic>
                                          ? rawItem
                                          : (rawItem is Map
                                              ? <String, dynamic>{}
                                              : <String, dynamic>{});

                                  final title =
                                      notification['title']?.toString().trim();
                                  final message = notification['message']
                                          ?.toString()
                                          .trim() ??
                                      '';
                                  final proposalTitle =
                                      notification['proposal_title']
                                          ?.toString()
                                          .trim();
                                  final isRead =
                                      notification['is_read'] == true;
                                  final timeLabel =
                                      _formatNotificationTimestamp(
                                          notification['created_at']);

                                  final dynamic notificationIdRaw =
                                      notification['id'];
                                  final int? notificationId = notificationIdRaw
                                          is int
                                      ? notificationIdRaw
                                      : int.tryParse(
                                          notificationIdRaw?.toString() ?? '',
                                        );

                                  return ListTile(
                                    onTap: () async {
                                      Navigator.of(bottomSheetContext).pop();
                                      await _handleNotificationTap(
                                        app,
                                        notification,
                                        notificationId,
                                        isAlreadyRead: isRead,
                                      );
                                    },
                                    leading: Icon(
                                      isRead
                                          ? Icons.notifications_none_outlined
                                          : Icons.notifications_active,
                                      color: isRead
                                          ? const Color(0xFF95A5A6)
                                          : const Color(0xFF3498DB),
                                    ),
                                    title: Text(
                                      title?.isNotEmpty == true
                                          ? title!
                                          : 'Notification',
                                      style: TextStyle(
                                        color: const Color(0xFF2C3E50),
                                        fontWeight: isRead
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      message,
                                      style: TextStyle(
                                        color: const Color(0xFF64748B),
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleNotificationTap(
      AppState app, Map<String, dynamic> notification, int? notificationId,
      {required bool isAlreadyRead}) async {
    // Handle notification tap based on type
    final notificationType = notification['notification_type']?.toString();

    if (notificationType == 'changes_requested') {
      // Finance: open the proposal in edit mode so they can update pricing and submit back
      final proposalId = notification['proposal_id'];
      if (proposalId != null) {
        Navigator.of(context).pop();
        Navigator.pushNamed(
          context,
          '/blank-document',
          arguments: {'proposalId': proposalId.toString()},
        );
      }
    } else if (notificationType == 'proposal_approved' ||
        notificationType == 'proposal_resubmitted') {
      final proposalId = notification['proposal_id'];
      if (proposalId != null) {
        Navigator.of(context).pop();
        Navigator.pushNamed(
          context,
          '/blank-document',
          arguments: {'proposalId': proposalId.toString()},
        );
      }
    }

    // Mark as read if not already read
    if (!isAlreadyRead && notificationId != null) {
      try {
        await app.markNotificationRead(notificationId);
      } catch (e) {
        debugPrint('Error marking notification as read: $e');
      }
    }
  }

  String _formatNotificationTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
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
    final isSidebarCollapsed = app.isFinanceSidebarCollapsed;
    final dashboardProposals =
        _getFilteredProposals(app, ignoreStatusFilter: true);
    final proposalsTabProposals = _getFilteredProposals(app);
    final proposals =
        _currentTab == 'dashboard' ? dashboardProposals : proposalsTabProposals;

    final pendingBadge = app.proposals
        .where((p) =>
            (p is Map) &&
            _isPricingInProgressStatus((p['status'] ?? '').toString()))
        .length;

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
                  FinanceSidebar(
                    isCollapsed: isSidebarCollapsed,
                    currentPage: _currentTab == 'dashboard'
                        ? 'Dashboard'
                        : _currentTab == 'proposals'
                            ? 'Proposals'
                            : _currentTab == 'clients'
                                ? 'Client Management'
                                : _currentTab == 'audit'
                                    ? 'Audit'
                                    : 'Dashboard',
                    showAudit: _canAccessAudit(app),
                    pendingBadge: pendingBadge > 0 ? pendingBadge : null,
                    onToggle: app.toggleFinanceSidebar,
                    onSelect: (label) {
                      if (label == 'Dashboard') {
                        setState(() => _currentTab = 'dashboard');
                        return;
                      }
                      if (label == 'Proposals') {
                        setState(() => _currentTab = 'proposals');
                        return;
                      }
                      if (label == 'Client Management') {
                        setState(() => _currentTab = 'clients');
                        return;
                      }
                      if (label == 'Audit') {
                        setState(() => _currentTab = 'audit');
                        _loadAuditLogs();
                        return;
                      }
                      if (label == 'Analytics') {
                        Navigator.pushNamed(context, '/analytics');
                        return;
                      }
                      if (label == 'Settings') {
                        Navigator.pushNamed(context, '/settings');
                        return;
                      }
                      if (label == 'Sign Out') {
                        app.logout();
                        AuthService.logout();
                        Navigator.pushNamed(context, '/login');
                        return;
                      }
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _currentTab == 'clients'
                          ? const FinanceClientManagementPage()
                          : CustomScrollbar(
                              controller: _scrollController,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildBreadcrumb(),
                                    const SizedBox(height: 16),
                                    if (_currentTab == 'dashboard') ...[
                                      _buildDashboardTitle(),
                                      const SizedBox(height: 16),
                                      _buildFinanceKpis(),
                                      const SizedBox(height: 16),
                                      _buildChartsRow(),
                                      const SizedBox(height: 12),
                                      _buildSimpleListPanel(
                                        title: 'AI Usage',
                                        subtitle:
                                            'Live usage for AI Assistant + Risk Gate (last 30 days, auto-refresh)',
                                        child: _buildAiUsageDashboardPanel(),
                                      ),
                                      const SizedBox(height: 12),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final isNarrow =
                                              constraints.maxWidth < 1100;
                                          final left = _buildSimpleListPanel(
                                            title: 'Top Clients by Revenue',
                                            subtitle: 'Highest revenue clients',
                                            child: _buildTopClientsPanel(),
                                          );
                                          final mid = _buildSimpleListPanel(
                                            title: 'Recent Signed Deals',
                                            subtitle: 'Latest signed proposals',
                                            child: _buildRecentSignedPanel(),
                                          );
                                          final right = _buildSimpleListPanel(
                                            title: 'Pipeline Aging Report',
                                            subtitle: 'Deals stuck > 30 days',
                                            child: _buildAgingPanel(),
                                          );

                                          if (isNarrow) {
                                            return Column(
                                              children: [
                                                left,
                                                const SizedBox(height: 12),
                                                mid,
                                                const SizedBox(height: 12),
                                                right,
                                              ],
                                            );
                                          }

                                          return Row(
                                            children: [
                                              Expanded(child: left),
                                              const SizedBox(width: 12),
                                              Expanded(child: mid),
                                              const SizedBox(width: 12),
                                              Expanded(child: right),
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSimpleListPanel(
                                        title: 'Financial Alerts',
                                        subtitle: 'Deals requiring attention',
                                        child: _buildAlertsPanel(),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildRequiresAttention(
                                          requiresAttention),
                                      const SizedBox(height: 24),
                                      const Footer(),
                                    ] else if (_currentTab == 'audit') ...[
                                      _buildAuditPanel(),
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
        : (_currentTab == 'clients'
            ? 'Client Management'
            : (_currentTab == 'audit' ? 'Audit' : 'Proposals'));
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
    final future =
        _monthlyForecastFuture ?? _fetchMonthlyForecast(year: _selectedYear);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final items = snapshot.data ?? [];

        final months = <String>[];
        final projected = <double>[];

        for (final r in items) {
          final month = (r['month'] ?? '').toString();
          if (month.length < 7) continue;
          months.add(month);
          projected.add((r['forecast_revenue'] is num)
              ? (r['forecast_revenue'] as num).toDouble()
              : double.tryParse(r['forecast_revenue']?.toString() ?? '') ??
                  0.0);
        }

        // If no data, create a stable empty chart.
        if (months.isEmpty) {
          for (int m = 1; m <= 12; m++) {
            months.add(
                '${_selectedYear.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}');
            projected.add(0.0);
          }
        }

        final now = DateTime.now();
        int startIndex = 0;
        if (_selectedYear == now.year) {
          // Show from the current month forward when viewing the current year.
          startIndex =
              (now.month - 1).clamp(0, months.isEmpty ? 0 : months.length - 1);
        }
        if (startIndex >= months.length) {
          startIndex = 0;
        }
        final remaining = months.length - startIndex;
        final displayCount = remaining >= 6 ? 6 : remaining;
        final months6 = months.sublist(startIndex, startIndex + displayCount);
        final projected6 =
            projected.sublist(startIndex, startIndex + displayCount);

        double maxY = 0;
        for (final v in projected6) {
          if (v > maxY) maxY = v;
        }

        String fmt(double v) {
          if (v >= 1000000) return 'R${(v / 1000000).toStringAsFixed(1)}M';
          if (v >= 1000) return 'R${(v / 1000).toStringAsFixed(0)}K';
          return 'R${v.toStringAsFixed(0)}';
        }

        final teal = PremiumTheme.teal;

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Year',
                  style:
                      PremiumTheme.labelMedium.copyWith(color: Colors.white60),
                ),
                _buildYearSelector(),
              ],
            ),
            const SizedBox(height: 10),
            if (loading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.7)),
                  ),
                ),
              )
            else
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (displayCount - 1).toDouble(),
                      minY: 0,
                      maxY: (maxY <= 0 ? 1 : maxY) * 1.1,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipMargin: 12,
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          getTooltipColor: (touchedSpot) =>
                              Colors.white.withOpacity(0.96),
                          getTooltipItems: (touchedSpots) {
                            if (touchedSpots.isEmpty) return [];
                            final idx = touchedSpots.first.x
                                .round()
                                .clamp(0, displayCount - 1);
                            final monthKey = months6[idx];
                            DateTime? parsed;
                            try {
                              final parts = monthKey.split('-');
                              parsed = DateTime(
                                  int.parse(parts[0]), int.parse(parts[1]), 1);
                            } catch (_) {}
                            final monthLabel = parsed != null
                                ? DateFormat('MMM').format(parsed)
                                : monthKey;
                            final proj = projected6[idx];
                            final headerStyle =
                                PremiumTheme.bodyMedium.copyWith(
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
                                '$monthLabel\n',
                                headerStyle,
                                children: [
                                  TextSpan(
                                    text: 'Forecast : ${_formatCurrency(proj)}',
                                    style: bodyStyle.copyWith(color: teal),
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
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
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
                              if (i < 0 || i >= months6.length) {
                                return const SizedBox.shrink();
                              }
                              DateTime? parsed;
                              try {
                                final parts = months6[i].split('-');
                                parsed = DateTime(int.parse(parts[0]),
                                    int.parse(parts[1]), 1);
                              } catch (_) {}
                              final label = parsed != null
                                  ? DateFormat('MMM').format(parsed)
                                  : months6[i];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  label,
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
                            displayCount,
                            (i) => FlSpot(i.toDouble(), projected6[i]),
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
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
                _buildNotificationButton(app),
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
                    _statusFilter = 'pending_review';
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

          // Ensure value is one of the dropdown items to avoid assertion (e.g. never use 'pending')
          final effectiveStatusFilter =
              _validStatusFilters.contains(_statusFilter)
                  ? _statusFilter
                  : 'all';
          if (_statusFilter != effectiveStatusFilter) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted)
                setState(() => _statusFilter = effectiveStatusFilter);
            });
          }
          final statusDropdown = Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: effectiveStatusFilter,
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
