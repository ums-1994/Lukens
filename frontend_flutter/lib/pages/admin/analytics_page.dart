// ignore_for_file: unused_field, unused_element, unused_local_variable

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
import '../../widgets/fixed_sidebar.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with TickerProviderStateMixin {
  String _selectedPeriod = 'Last 30 Days';
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
      if (app.proposals.isEmpty) {
        app.fetchProposals();
      }
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _exportAsCSV() {
    try {
      final app = context.read<AppState>();
      final analytics = _calculateAnalytics(app.proposals);
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
      final analytics = _calculateAnalytics(app.proposals);
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

  Widget _buildMetricCard(_MetricCardData metric) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
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
                metric.title,
                style: PremiumTheme.bodyMedium.copyWith(
                  color: PremiumTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                metric.value,
                style: PremiumTheme.displayMedium.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    metric.isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: metric.isPositive
                        ? PremiumTheme.success
                        : PremiumTheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metric.change,
                    style: TextStyle(
                      color: metric.isPositive
                          ? PremiumTheme.success
                          : PremiumTheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    metric.subtitle,
                    style: TextStyle(
                      color: PremiumTheme.textSecondary,
                      fontSize: 11,
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

  Widget _buildLineChart(_AnalyticsSnapshot analytics) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                );
                return Text('Day ${value.toInt()}', style: style);
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: 10000,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                );
                return Text(_formatCurrency(value), style: style);
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        minX: 0,
        maxX: 30,
        minY: 0,
        maxY: 50000,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(30, (index) {
              final value = 10000 + (math.Random().nextDouble() * 30000);
              return FlSpot(index.toDouble(), value);
            }),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3498DB).withValues(alpha: 0.3),
                  const Color(0xFF3498DB).withValues(alpha: 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(_AnalyticsSnapshot analytics) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {},
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: [
          PieChartSectionData(
            color: const Color(0xFF3498DB),
            value: (analytics.statusCounts['Draft'] ?? 0).toDouble(),
            title: '${analytics.statusCounts['Draft'] ?? 0}',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: const Color(0xFF2ECC71),
            value: (analytics.statusCounts['Sent'] ?? 0).toDouble(),
            title: '${analytics.statusCounts['Sent'] ?? 0}',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: const Color(0xFFE74C3C),
            value: (analytics.statusCounts['Won'] ?? 0).toDouble(),
            title: '${analytics.statusCounts['Won'] ?? 0}',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: const Color(0xFFF39C12),
            value: (analytics.statusCounts['Lost'] ?? 0).toDouble(),
            title: '${analytics.statusCounts['Lost'] ?? 0}',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(_AnalyticsSnapshot analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegendItem('Draft', const Color(0xFF3498DB),
            analytics.statusCounts['Draft'] ?? 0),
        const SizedBox(height: 8),
        _buildLegendItem('Sent', const Color(0xFF2ECC71),
            analytics.statusCounts['Sent'] ?? 0),
        const SizedBox(height: 8),
        _buildLegendItem(
            'Won', const Color(0xFFE74C3C), analytics.statusCounts['Won'] ?? 0),
        const SizedBox(height: 8),
        _buildLegendItem('Lost', const Color(0xFFF39C12),
            analytics.statusCounts['Lost'] ?? 0),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeFilterButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          // Update selected time filter
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3498DB) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3498DB)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(_AnalyticsSnapshot analytics) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 40000,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                _formatCurrency(rod.toY),
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                );
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                if (value.toInt() >= 0 && value.toInt() < months.length) {
                  return Text(months[value.toInt()], style: style);
                }
                return const Text('', style: style);
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                );
                return Text(_formatCurrency(value), style: style);
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(6, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: 10000 + math.Random().nextDouble() * 30000,
                color: const Color(0xFF3498DB),
                width: 22,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _navigateToPage(BuildContext context, String label) {
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
        // Already on analytics page
        break;
      case 'Logout':
        _handleLogout(context);
        break;
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final app = Provider.of<AppState>(context, listen: false);
                app.logout();
                AuthService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // Show loading state if proposals are empty
    if (app.proposals.isEmpty) {
      return Scaffold(
        body: Container(
          color: Colors.transparent,
          child: Row(
            children: [
              // Fixed Sidebar - Full Height
              FixedSidebar(
                currentPage: 'Analytics (My Pipeline)',
                isCollapsed: _isSidebarCollapsed,
                onToggle: _toggleSidebar,
                onNavigate: (label) => _navigateToPage(context, label),
                onLogout: () => _handleLogout(context),
              ),

              // Main Content Area - Empty State
              Expanded(
                child: Column(
                  children: [
                    // Header
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Analytics Dashboard',
                              style: PremiumTheme.titleLarge
                                  .copyWith(fontSize: 22),
                            ),
                            Row(
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
                                      'A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Admin User',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Content Area - Empty State
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No proposals available',
                              style: PremiumTheme.titleMedium.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create proposals to see analytics here',
                              style: PremiumTheme.bodyMedium.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/proposals');
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create Proposal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3498DB),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
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

    final analytics = _calculateAnalytics(app.proposals);
    final metrics = _buildMetricCards(analytics);
    final userName = _getUserName(app.currentUser);
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final isAdminUser = _isAdminUser();
    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            // Fixed Sidebar - Full Height
            FixedSidebar(
              currentPage: 'Analytics (My Pipeline)',
              isCollapsed: _isSidebarCollapsed,
              onToggle: _toggleSidebar,
              onNavigate: (label) => _navigateToPage(context, label),
              onLogout: () => _handleLogout(context),
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Header
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Analytics Dashboard',
                            style:
                                PremiumTheme.titleLarge.copyWith(fontSize: 22),
                          ),
                          Row(
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
                              Text(
                                userName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.white),
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
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CustomScrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(right: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Metrics Cards
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: metrics
                                        .map((metric) =>
                                            _buildMetricCard(metric))
                                        .toList(),
                                  ),
                                ),
                              ),

                              // Charts Section
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column - Line Chart
                                  Expanded(
                                    flex: 2,
                                    child: GlassContainer(
                                      borderRadius: 20,
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Proposal Pipeline',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF3498DB)
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  'Last 30 Days',
                                                  style: TextStyle(
                                                    color: Color(0xFF3498DB),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          SizedBox(
                                            height: 300,
                                            child: _buildLineChart(analytics),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Right Column - Pie Chart
                                  Expanded(
                                    child: GlassContainer(
                                      borderRadius: 20,
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Status Distribution',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          SizedBox(
                                            height: 200,
                                            child: _buildPieChart(analytics),
                                          ),
                                          const SizedBox(height: 20),
                                          _buildLegend(analytics),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Bottom Section - Bar Chart
                              GlassContainer(
                                borderRadius: 20,
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Monthly Performance',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            _buildTimeFilterButton(
                                                'Month', true),
                                            const SizedBox(width: 8),
                                            _buildTimeFilterButton(
                                                'Quarter', false),
                                            const SizedBox(width: 8),
                                            _buildTimeFilterButton(
                                                'Year', false),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      height: 300,
                                      child: _buildBarChart(analytics),
                                    ),
                                  ],
                                ),
                              ),
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
                  setState(() => _selectedPeriod = newValue!);
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
                  Text(
                    change,
                    style: TextStyle(
                      fontSize: 14,
                      color: isPositive
                          ? PremiumTheme.success
                          : PremiumTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
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
