import 'dart:async';
import 'dart:math' as math;

import 'dart:convert';
import 'dart:html' as html;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../api.dart';
import '../../services/auth_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../widgets/finance/finance_sidebar.dart';
import '../../widgets/footer.dart';

class FinanceAnalyticsPage extends StatefulWidget {
  const FinanceAnalyticsPage({super.key});

  @override
  State<FinanceAnalyticsPage> createState() => _FinanceAnalyticsPageState();
}

class _FinanceAnalyticsPageState extends State<FinanceAnalyticsPage> {
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: 'R', decimalDigits: 0);
  Timer? _aiUsageRefreshTimer;
  int _aiUsageRefreshTick = 0;

  Future<List<Map<String, dynamic>>>? _pipelineFunnelFuture;
  Future<List<Map<String, dynamic>>>? _alertsFuture;

  Future<List<Map<String, dynamic>>> _fetchPipelineFunnel() async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;

    if (token == null) return [];

    try {
      final uri = Uri.parse('$baseUrl/api/finance/funnel');
      final r = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      if (r.statusCode != 200) return [];
      final decoded = jsonDecode(r.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  String _formatCurrency(double value) {
    return _currencyFormatter.format(value);
  }

  Widget _buildPipelineFunnelChart() {
    final future = _pipelineFunnelFuture ?? _fetchPipelineFunnel();
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
                      if (i < 0 || i >= stages.length) {
                        return const SizedBox.shrink();
                      }
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

  bool _canAccessAudit(AppState app) {
    final role = (app.currentUser?['role'] ?? '').toString().toLowerCase();
    return role == 'finance_manager' || role == 'admin' || role == 'ceo';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().fetchProposals();
    });
    _aiUsageRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() => _aiUsageRefreshTick++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pipelineFunnelFuture ??= _fetchPipelineFunnel();
    _alertsFuture ??= _fetchAlerts(year: DateTime.now().year);
  }

  Future<List<Map<String, dynamic>>> _fetchAlerts({required int year}) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;
    if (token == null) return [];

    try {
      final uri = Uri.parse('$baseUrl/api/finance/alerts')
          .replace(queryParameters: {'year': year.toString()});
      final r = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (r.statusCode != 200) return [];
      final decoded = jsonDecode(r.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Color _alertColor(String severity) {
    final s = severity.toLowerCase();
    if (s == 'warning') return Colors.orange;
    if (s == 'critical') return Colors.redAccent;
    return PremiumTheme.info;
  }

  Widget _buildFinancialAlertsPanel() {
    final year = DateTime.now().year;
    final future = _alertsFuture ?? _fetchAlerts(year: year);
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
              child: Text(
                'No alerts',
                style: PremiumTheme.bodyMedium.copyWith(color: Colors.white60),
              ),
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

  @override
  void dispose() {
    _aiUsageRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
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

  Widget _buildAiUsagePanel(Map<String, dynamic>? data) {
    if (data == null) {
      return const Center(child: Text('AI usage data unavailable'));
    }
    if (data['error_status'] != null) {
      return Center(
        child: Text('Unable to load AI usage (${data['error_status']})'),
      );
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
    final averageSpendZar = (usageSummary['average_spend_zar'] is num)
        ? usageSummary['average_spend_zar'] as num
        : 0;
    final averageSpendReason =
        (usageSummary['average_spend_reason'] ?? '').toString();

    int n(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    final chips = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _statPill('Requests', n(totals['total_requests']).toString()),
        _statPill('Success', n(totals['success_count']).toString()),
        _statPill('Failed', n(totals['failed_count']).toString()),
        _statPill('Blocked', n(totals['blocked_count']).toString()),
        _statPill(
          'Acceptance',
          '${((totals['acceptance_rate'] as num?) ?? 0).toStringAsFixed(1)}%',
        ),
        _statPill('Tokens',
            NumberFormat.compact().format(n(usageSummary['total_tokens']))),
        _statPill('Average Spent', 'R ${averageSpendZar.toStringAsFixed(2)}'),
      ],
    );

    Widget listCard(
        String title, List<Map<String, dynamic>> rows, String lk, String rk) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: PremiumTheme.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text('No data',
                  style: PremiumTheme.bodySmall.copyWith(color: Colors.white60))
            else
              ...rows.take(8).map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (r[lk] ?? '-').toString(),
                            overflow: TextOverflow.ellipsis,
                            style: PremiumTheme.bodySmall,
                          ),
                        ),
                        Text((r[rk] ?? '0').toString(),
                            style: PremiumTheme.bodySmall),
                      ],
                    ),
                  )),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chips,
        if (averageSpendReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Reason: $averageSpendReason',
            style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: listCard(
                    'By Endpoint', endpointSplit, 'endpoint', 'requests')),
            const SizedBox(width: 12),
            Expanded(
                child: listCard('Top Users', topUsers, 'username', 'requests')),
          ],
        ),
      ],
    );
  }

  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text('$label: $value', style: PremiumTheme.bodySmall),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedReport = 'proposal_summary';
        String selectedFormat = 'csv';
        bool isExporting = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Export Financial Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select report type and format:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Report Type Selection
                  const Text(
                    'Report Type:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('Proposal Financial Summary'),
                    subtitle:
                        const Text('Individual proposal details with amounts'),
                    value: 'proposal_summary',
                    groupValue: selectedReport,
                    onChanged: (value) {
                      setState(() {
                        selectedReport = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('Client Financial Report'),
                    subtitle: const Text('Aggregated data by client'),
                    value: 'client_report',
                    groupValue: selectedReport,
                    onChanged: (value) {
                      setState(() {
                        selectedReport = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  // Format Selection
                  const Text(
                    'Export Format:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('Excel (.xlsx)'),
                    subtitle: const Text(
                        'Native Excel format, structured columns and sheets'),
                    value: 'xlsx',
                    groupValue: selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('CSV'),
                    subtitle: const Text(
                        'Comma-separated values, opens in Excel with columns'),
                    value: 'csv',
                    groupValue: selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('PDF'),
                    subtitle: const Text('Printable report'),
                    value: 'pdf',
                    groupValue: selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('PDF'),
                    subtitle: const Text('Printable report'),
                    value: 'pdf',
                    groupValue: selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        selectedFormat = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isExporting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isExporting
                      ? null
                      : () async {
                          setState(() {
                            isExporting = true;
                          });

                          try {
                            await _performExport(
                                selectedReport, selectedFormat);
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Export completed successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Export failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setState(() {
                              isExporting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performExport(String reportType, String format) async {
    final app = context.read<AppState>();
    final token = app.authToken ?? AuthService.token;

    if (token == null) {
      throw Exception('Authentication required');
    }

    String endpoint;
    if (reportType == 'proposal_summary') {
      endpoint = '/api/finance/export/proposal-summary';
    } else if (reportType == 'client_report') {
      endpoint = '/api/finance/export/client-report';
    } else {
      throw Exception('Invalid report type');
    }

    final uri = Uri.parse('${baseUrl}$endpoint').replace(queryParameters: {
      'format': format,
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': format == 'pdf' ? 'application/pdf' : 'text/csv',
      },
    ).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception('Export request timed out'),
    );

    if (response.statusCode == 200) {
      // Create download link
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('Export returned empty data');
      }
      final ext = format == 'pdf' ? 'pdf' : 'csv';
      final fileName =
          '${reportType}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // For web, create download link
      if (kIsWeb) {
        final contentType =
            response.headers['content-type'] ?? 'application/octet-stream';
        final blob = html.Blob([bytes], contentType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..download = fileName
          ..style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        // Delay revoke so the browser has time to start the download
        Future.delayed(const Duration(milliseconds: 1200), () {
          html.Url.revokeObjectUrl(url);
        });
      } else {
        // For mobile/desktop, save to file
        // You might want to use path_provider package here
        print('Export saved: $fileName (${bytes.length} bytes)');
      }
    } else {
      final body = response.body;
      throw Exception(
          'Export failed: ${response.statusCode}${body.isNotEmpty ? ' - $body' : ''}');
    }
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
    return PremiumStatCard(
      title: label,
      value: value,
      subtitle: subtitle,
      icon: icon,
      gradient: PremiumTheme.tealGradient,
    );
  }

  Widget _panel(
      {required String title,
      required String subtitle,
      required Widget child}) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PremiumTheme.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: PremiumTheme.bodyMedium.copyWith(color: Colors.white70),
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
              IconButton(
                tooltip: 'Export Financial Data',
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: _showExportDialog,
              ),
              const SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isSidebarCollapsed = app.isFinanceSidebarCollapsed;
    final proposals = _financeProposals(app);
    final showAudit = _canAccessAudit(app);
    final pendingBadge = proposals
        .where((p) =>
            (p['status'] ?? '').toString().toLowerCase().contains('pricing'))
        .length;

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
                  FinanceSidebar(
                    isCollapsed: isSidebarCollapsed,
                    currentPage: 'Analytics',
                    showAudit: showAudit,
                    pendingBadge: pendingBadge > 0 ? pendingBadge : null,
                    onToggle: app.toggleFinanceSidebar,
                    onSelect: (label) {
                      if (label == 'Dashboard' || label == 'Proposals') {
                        Navigator.pushNamed(context, '/finance_dashboard');
                        return;
                      }
                      if (label == 'Client Management') {
                        Navigator.pushNamed(
                          context,
                          '/finance_dashboard',
                          arguments: const {'initialTab': 'clients'},
                        );
                        return;
                      }
                      if (label == 'Audit') {
                        Navigator.pushNamed(
                          context,
                          '/finance_dashboard',
                          arguments: const {'initialTab': 'audit'},
                        );
                        return;
                      }
                      if (label == 'Analytics') {
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
                              const SizedBox(height: 18),
                              _panel(
                                title: 'AI Usage',
                                subtitle:
                                    'Live usage across AI Assistant and Risk Gate (auto-refresh every 20s)',
                                child: FutureBuilder<Map<String, dynamic>?>(
                                  key: ValueKey(
                                      'finance_ai_usage_$_aiUsageRefreshTick'),
                                  future: _fetchAiUsageAnalytics(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }
                                    if (snapshot.hasError) {
                                      return const Center(
                                          child: Text(
                                              'Failed to load AI usage analytics.'));
                                    }
                                    return _buildAiUsagePanel(snapshot.data);
                                  },
                                ),
                              ),
                              const SizedBox(height: 18),
                              _panel(
                                title: 'Pipeline Funnel Chart',
                                subtitle: 'Proposal value by stage',
                                child: _buildPipelineFunnelChart(),
                              ),
                              const SizedBox(height: 18),
                              _panel(
                                title: 'Financial Alerts',
                                subtitle: 'Deals requiring attention',
                                child: _buildFinancialAlertsPanel(),
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
