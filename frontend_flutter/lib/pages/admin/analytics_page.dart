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
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  static const String _currencySymbol = 'R';
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(symbol: _currencySymbol, decimalDigits: 0);
  final NumberFormat _compactCurrencyFormatter =
      NumberFormat.compactCurrency(symbol: _currencySymbol, decimalDigits: 1);
  Map<String, dynamic>? _cycleTimeAnalytics;
  
  // Cycle Time filters
  DateTime? _cycleTimeStartDate;
  DateTime? _cycleTimeEndDate;
  String? _cycleTimeStatus;
  String? _cycleTimeOwner;
  String? _cycleTimeProposalType;

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
      _loadCycleTimeAnalytics(app);
    });
  }

  Future<void> _loadCycleTimeAnalytics(AppState app) async {
    final data = await app.getCycleTimeAnalytics(
      startDate: _cycleTimeStartDate != null
          ? '${_cycleTimeStartDate!.year}-${_cycleTimeStartDate!.month.toString().padLeft(2, '0')}-${_cycleTimeStartDate!.day.toString().padLeft(2, '0')}'
          : null,
      endDate: _cycleTimeEndDate != null
          ? '${_cycleTimeEndDate!.year}-${_cycleTimeEndDate!.month.toString().padLeft(2, '0')}-${_cycleTimeEndDate!.day.toString().padLeft(2, '0')}'
          : null,
      status: _cycleTimeStatus,
      owner: _cycleTimeOwner,
      proposalType: _cycleTimeProposalType,
    );
    if (!mounted) return;
    setState(() {
      _cycleTimeAnalytics = data ?? {
        'by_stage': [],
        'bottleneck': null,
        'metric': 'cycle_time',
      };
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
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
    
    // Calculate completion rate from completed_steps
    double totalCompletionRate = 0.0;
    int proposalsWithSteps = 0;
    const List<String> allSteps = ['compose', 'govern', 'risk']; // Typical workflow steps

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
      
      // Calculate completion rate for this proposal
      final completedSteps = proposal['completed_steps'];
      if (completedSteps != null) {
        List<String> steps = [];
        if (completedSteps is List) {
          steps = completedSteps.map((e) => e.toString().toLowerCase()).toList();
        }
        final completedCount = steps.length;
        final completionRate = allSteps.isNotEmpty 
            ? (completedCount / allSteps.length) * 100 
            : 0.0;
        totalCompletionRate += completionRate;
        proposalsWithSteps++;
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

    final double averageCompletionRate = proposalsWithSteps > 0
        ? totalCompletionRate / proposalsWithSteps
        : 0.0;

    return _AnalyticsSnapshot(
      totalPipelineValue: totalRevenue,
      totalProposals: normalized.length,
      activeProposals: activeCount,
      averageDealSize: averageDealSize,
      winRate: winRate,
      lossRate: lossRate,
      completionRate: averageCompletionRate,
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

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final analytics = _calculateAnalytics(app.proposals);
    final metrics = _buildMetricCards(analytics);
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
                    final isNarrow = constraints.maxWidth < 520;
                    final title = Text(
                      'Analytics Dashboard',
                      style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
                    );

                    final userControls = Row(
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

                    if (!isNarrow) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          title,
                          userControls,
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 8),
                        userControls,
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
                              Row(
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
                                        style: PremiumTheme.bodyLarge.copyWith(
                                          color: PremiumTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrow = constraints.maxWidth < 420;
                                      final controls = [
                                        _buildGlassDropdown(),
                                        _buildGlassButton(
                                          'Export',
                                          Icons.download,
                                          _showExportDialog,
                                        ),
                                      ];

                                      if (!isNarrow) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            controls[0],
                                            const SizedBox(width: 12),
                                            controls[1],
                                          ],
                                        );
                                      }

                                      return Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        alignment: WrapAlignment.end,
                                        children: controls,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  const minCardWidth = 240.0;
                                  const spacing = 20.0;
                                  final maxWidth = constraints.maxWidth;
                                  final columns = (maxWidth / (minCardWidth + spacing))
                                      .floor()
                                      .clamp(1, 4);
                                  final cardWidth = (maxWidth - (spacing * (columns - 1))) / columns;

                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children: [
                                      for (final m in metrics)
                                        SizedBox(
                                          width: cardWidth,
                                          child: _buildGlassMetricCard(
                                            m.title,
                                            m.value,
                                            m.change,
                                            m.isPositive,
                                            m.subtitle,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              _buildGlassChartCard(
                                'Cycle Time by Stage',
                                Column(
                                  children: [
                                    _buildCycleTimeFilters(),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: _buildCycleTimeContent(_cycleTimeAnalytics),
                                    ),
                                  ],
                                ),
                                height: 280,
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildGlassChartCard(
                                      'Completion Rate',
                                      _buildCompletionRateGauge(analytics.completionRate),
                                      height: 320,
                                    ),
                                  ),
                                ],
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
                  mainAxisSize: MainAxisSize.min,
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

  Widget _buildCompletionRateGauge(double completionRate) {
    // Clamp completion rate between 0 and 100
    final rate = completionRate.clamp(0.0, 100.0);
    
    // Determine color based on completion rate
    Color gaugeColor;
    if (rate >= 80) {
      gaugeColor = PremiumTheme.success;
    } else if (rate >= 50) {
      gaugeColor = PremiumTheme.warning;
    } else {
      gaugeColor = PremiumTheme.error;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gauge visualization (circular progress)
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: rate / 100,
                    strokeWidth: 20,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                  ),
                ),
                // Percentage text
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${rate.toStringAsFixed(0)}%',
                      style: PremiumTheme.displayLarge.copyWith(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete',
                      style: PremiumTheme.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: gaugeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: gaugeColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: gaugeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rate >= 80
                      ? 'Ready'
                      : rate >= 50
                          ? 'In Progress'
                          : 'Needs Attention',
                  style: TextStyle(
                    color: gaugeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProposalPipelineFunnel(Map<String, int> statusCounts) {
    // Define the pipeline stages in order (funnel flow)
    final pipelineStages = [
      'Draft',
      'In Review',
      'Released',
      'Signed',
    ];

    // Normalize status counts to match pipeline stages
    final normalizedCounts = <String, int>{};
    for (final stage in pipelineStages) {
      // Try exact match first
      if (statusCounts.containsKey(stage)) {
        normalizedCounts[stage] = statusCounts[stage]!;
      } else {
        // Try case-insensitive match
        final matchingKey = statusCounts.keys.firstWhere(
          (key) => key.toLowerCase() == stage.toLowerCase(),
          orElse: () => '',
        );
        if (matchingKey.isNotEmpty) {
          normalizedCounts[stage] = statusCounts[matchingKey]!;
        } else {
          // Map similar statuses
          if (stage == 'Released') {
            // Check for "Sent To Client", "Sent to Client", etc.
            final releasedKey = statusCounts.keys.firstWhere(
              (key) => key.toLowerCase().contains('sent') ||
                  key.toLowerCase().contains('released'),
              orElse: () => '',
            );
            if (releasedKey.isNotEmpty) {
              normalizedCounts[stage] = statusCounts[releasedKey]!;
            } else {
              normalizedCounts[stage] = 0;
            }
          } else if (stage == 'In Review') {
            // Check for "Pending Ceo Approval", etc.
            final reviewKey = statusCounts.keys.firstWhere(
              (key) => key.toLowerCase().contains('review') ||
                  key.toLowerCase().contains('pending'),
              orElse: () => '',
            );
            if (reviewKey.isNotEmpty) {
              normalizedCounts[stage] = statusCounts[reviewKey]!;
            } else {
              normalizedCounts[stage] = 0;
            }
          } else {
            normalizedCounts[stage] = 0;
          }
        }
      }
    }

    // Get max count for scaling
    final maxCount = normalizedCounts.values.fold<int>(
      0,
      (prev, count) => math.max(prev, count),
    );

    if (maxCount == 0) {
      return const Center(
        child: Text(
          'No pipeline data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Build funnel segments
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: pipelineStages.asMap().entries.map((entry) {
        final index = entry.key;
        final stage = entry.value;
        final count = normalizedCounts[stage] ?? 0;
        
        // Calculate width as percentage of max (funnel effect)
        // Each stage should be progressively narrower
        final widthPercent = maxCount > 0 ? (count / maxCount) : 0.0;
        // Minimum width to ensure visibility
        final minWidthPercent = 0.15;
        final finalWidthPercent = math.max(widthPercent, minWidthPercent);

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < pipelineStages.length - 1 ? 12.0 : 0,
          ),
          child: Row(
            children: [
              // Stage label
              SizedBox(
                width: 100,
                child: Text(
                  stage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Funnel bar
              Expanded(
                child: Stack(
                  children: [
                    // Background bar
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // Filled portion
                    FractionallySizedBox(
                      widthFactor: finalWidthPercent,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: _statusColor(stage.toLowerCase()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
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

  Widget _buildCycleTimeFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Builder(
        builder: (context) {
          final app = context.watch<AppState>();

          final owners = <String>{};
          for (final p in app.proposals) {
            if (p is Map) {
              final o = (p['owner_id'] ?? p['user_id'])?.toString();
              if (o != null && o.isNotEmpty) owners.add(o);
            }
          }
          final ownerItems = owners.toList()..sort();

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: InkWell(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _cycleTimeStartDate != null && _cycleTimeEndDate != null
                      ? DateTimeRange(start: _cycleTimeStartDate!, end: _cycleTimeEndDate!)
                      : null,
                );
                if (picked != null) {
                  setState(() {
                    _cycleTimeStartDate = picked.start;
                    _cycleTimeEndDate = picked.end;
                  });
                  _loadCycleTimeAnalytics(app);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      _cycleTimeStartDate != null && _cycleTimeEndDate != null
                          ? '${DateFormat('MMM d').format(_cycleTimeStartDate!)} - ${DateFormat('MMM d').format(_cycleTimeEndDate!)}'
                          : 'Date Range',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
              value: _cycleTimeStatus,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: const Color(0xFF1A1F2E),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              hint: const Text('Status', style: TextStyle(color: Colors.white70, fontSize: 12)),
              items: ['', 'Draft', 'In Review', 'Released', 'Signed'].map((status) {
                return DropdownMenuItem<String>(
                  value: status.isEmpty ? null : status,
                  child: Text(status.isEmpty ? 'All Statuses' : status),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _cycleTimeStatus = value;
                });
                _loadCycleTimeAnalytics(app);
              },
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  value: _cycleTimeOwner,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: const Color(0xFF1A1F2E),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  hint: const Text('Owner', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  items: [null, ...ownerItems].map((o) {
                    return DropdownMenuItem<String>(
                      value: o,
                      child: Text(o == null ? 'All Owners' : o),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _cycleTimeOwner = value;
                    });
                    _loadCycleTimeAnalytics(app);
                  },
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
              value: _cycleTimeProposalType,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: const Color(0xFF1A1F2E),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              hint: const Text('Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
              items: ['', 'proposal', 'sow', 'rfi'].map((type) {
                return DropdownMenuItem<String>(
                  value: type.isEmpty ? null : type,
                  child: Text(type.isEmpty ? 'All Types' : type.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _cycleTimeProposalType = value;
                });
                _loadCycleTimeAnalytics(app);
              },
                ),
              ),
              if (_cycleTimeStartDate != null || _cycleTimeEndDate != null || _cycleTimeStatus != null || _cycleTimeProposalType != null || _cycleTimeOwner != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _cycleTimeStartDate = null;
                      _cycleTimeEndDate = null;
                      _cycleTimeStatus = null;
                      _cycleTimeOwner = null;
                      _cycleTimeProposalType = null;
                    });
                    _loadCycleTimeAnalytics(app);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCycleTimeContent(Map<String, dynamic>? cycleTimeAnalytics) {
    final byStage = (cycleTimeAnalytics?['by_stage'] as List?) ?? [];
    if (byStage.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timeline_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No cycle time data available yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start sending proposals to see stage metrics here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
        if (cycleTimeAnalytics?['bottleneck'] != null) ...[
          Text(
            'Current Bottleneck: ${cycleTimeAnalytics!['bottleneck']['stage']}',
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

              final bottleneckStage = cycleTimeAnalytics?['bottleneck']?['stage']?.toString();
              final isBottleneck = bottleneckStage != null && bottleneckStage == stage;

              return Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isBottleneck
                        ? PremiumTheme.warning.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.08),
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
}

class _AnalyticsSnapshot {
  final double totalPipelineValue;
  final int totalProposals;
  final int activeProposals;
  final double averageDealSize;
  final double winRate;
  final double lossRate;
  final double completionRate;
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
    required this.completionRate,
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
