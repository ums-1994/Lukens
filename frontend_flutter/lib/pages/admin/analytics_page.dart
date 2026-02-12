import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

import '../../api.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with TickerProviderStateMixin {
  String _selectedPeriod = 'Last 30 Days';
  bool _cycleTimeAutoRefresh = true;
  int _cycleTimeRefreshTick = 0;
  Timer? _cycleTimeRefreshTimer;
  final TextEditingController _cycleTimeOwnerCtrl = TextEditingController();
  final TextEditingController _cycleTimeProposalTypeCtrl =
      TextEditingController();
  final TextEditingController _globalClientCtrl = TextEditingController();
  final TextEditingController _globalRegionCtrl = TextEditingController();
  final TextEditingController _globalIndustryCtrl = TextEditingController();
  final TextEditingController _globalOwnerCtrl = TextEditingController();
  final TextEditingController _globalProposalTypeCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchProposals();
    });

    _cycleTimeRefreshTimer =
        Timer.periodic(const Duration(seconds: 60), (timer) {
      if (!mounted) return;
      if (!_cycleTimeAutoRefresh) return;
      setState(() => _cycleTimeRefreshTick++);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Navigation label setting removed - not available in AppState
    });
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

  void _navigateToPage(BuildContext context, String label) {
    switch (label) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/creator_dashboard');
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
      case 'Approved Proposals':
        Navigator.pushReplacementNamed(context, '/approved_proposals');
        break;
      case 'Analytics (My Pipeline)':
        break;
      case 'Logout':
        Navigator.pushReplacementNamed(context, '/login');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
            ],
          ),
        ),
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                border: Border(
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    height: 70,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.cyan, Colors.blue],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.analytics,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Navigation Items
                  _buildNavItem('Dashboard', Icons.dashboard, false),
                  _buildNavItem('My Proposals', Icons.description, false),
                  _buildNavItem(
                      'Analytics (My Pipeline)', Icons.analytics, true),
                  _buildNavItem(
                      'Templates', Icons.insert_drive_file_outlined, false),
                  _buildNavItem('Content Library', Icons.folder, false),
                  _buildNavItem('Client Management', Icons.people, false),
                  _buildNavItem(
                      'Approved Proposals', Icons.check_circle, false),

                  const Spacer(),

                  // Logout
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: InkWell(
                      onTap: () => _navigateToPage(context, 'Logout'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.logout, color: Colors.white70, size: 18),
                            SizedBox(width: 12),
                            Text(
                              'Logout',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Column(
                children: [
                  // Top Bar
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Analytics Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),

                        // Period Selector
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedPeriod,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                            ),
                            underline: const SizedBox(),
                            items: [
                              'Last 7 Days',
                              'Last 30 Days',
                              'Last 90 Days',
                              'This Year',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedPeriod = newValue;
                                  _cycleTimeRefreshTick++;
                                });
                              }
                            },
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Export Button
                        ElevatedButton.icon(
                          onPressed: _exportAsCSV,
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Metrics Cards
                          _buildMetricsSection(),
                          const SizedBox(height: 24),

                          // Charts Section
                          _buildChartsSection(),
                          const SizedBox(height: 24),

                          // Recent Proposals Table
                          _buildRecentProposalsSection(),
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

  Widget _buildNavItem(String label, IconData icon, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _navigateToPage(context, label),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.cyan.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: Colors.cyan) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.cyan : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.cyan : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    final proposals = context.watch<AppState>().proposals;

    // Calculate basic metrics
    final totalProposals = proposals.length;
    final activeProposals = proposals
        .where((p) => !['Signed', 'Lost', 'Archived'].contains(p['status']))
        .length;
    final signedProposals =
        proposals.where((p) => p['status'] == 'Signed').length;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Proposals',
            totalProposals.toString(),
            'All time',
            Icons.description,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Active Proposals',
            activeProposals.toString(),
            'In progress',
            Icons.pending,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Signed Proposals',
            signedProposals.toString(),
            'Completed',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            'Conversion Rate',
            totalProposals > 0
                ? '${((signedProposals / totalProposals) * 100).toStringAsFixed(1)}%'
                : '0%',
            'Success rate',
            Icons.trending_up,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildChartCard(
            'Proposal Status Distribution',
            _buildStatusChart(),
            height: 300,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildChartCard(
            'Monthly Trend',
            _buildTrendChart(),
            height: 300,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart, {double height = 300}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildStatusChart() {
    final app = context.watch<AppState>();
    final proposals = app.proposals;

    final statusCounts = <String, int>{};
    for (final proposal in proposals) {
      final status = proposal['status']?.toString() ?? 'Draft';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    final data = statusCounts.entries.map((entry) {
      Color color;
      switch (entry.key.toLowerCase()) {
        case 'signed':
          color = Colors.green;
          break;
        case 'sent to client':
          color = Colors.blue;
          break;
        case 'pending ceo approval':
          color = Colors.orange;
          break;
        case 'in review':
          color = Colors.yellow;
          break;
        default:
          color = Colors.grey;
      }

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        radius: 100,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();

    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: data,
      ),
    );
  }

  Widget _buildTrendChart() {
    final app = context.watch<AppState>();
    final proposals = app.proposals;

    // Generate sample trend data
    final now = DateTime.now();
    final points = <FlSpot>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i * 30));
      final count = proposals.where((p) {
        final createdAt = DateTime.tryParse(p['created_at']?.toString() ?? '');
        return createdAt != null &&
            createdAt.month == date.month &&
            createdAt.year == date.year;
      }).length;
      points.add(FlSpot((6 - i).toDouble(), count.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.1),
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
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final months = ['6m', '5m', '4m', '3m', '2m', '1m', 'Now'];
                final index = value.toInt();
                if (index >= 0 && index < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      months[index],
                      style: const TextStyle(
                        color: Colors.white70,
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
        maxX: 6,
        minY: 0,
        maxY: points.isNotEmpty
            ? points.map((p) => p.y).reduce(math.max) * 1.2
            : 5,
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            color: Colors.cyan,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.cyan,
                  strokeWidth: 2,
                  strokeColor: Colors.white.withValues(alpha: 0.3),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.cyan.withValues(alpha: 0.3),
                  Colors.cyan.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProposalsSection() {
    final app = context.watch<AppState>();
    final proposals = app.proposals.take(10).toList();

    if (proposals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: Colors.white54,
              ),
              SizedBox(height: 16),
              Text(
                'No proposals yet',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Create your first proposal to see analytics here',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: const Text(
              'Recent Proposals',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                children: [
                  _buildTableHeader('Title'),
                  _buildTableHeader('Status'),
                  _buildTableHeader('Client'),
                  _buildTableHeader('Date'),
                ],
              ),
              // Data rows
              for (final proposal in proposals)
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  children: [
                    _buildTableCell(
                        proposal['title']?.toString() ?? 'Untitled'),
                    _buildStatusTableCell(
                        proposal['status']?.toString() ?? 'Draft'),
                    _buildTableCell(proposal['client']?.toString() ?? 'N/A'),
                    _buildTableCell(
                      _formatDate(proposal['created_at']?.toString()),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildStatusTableCell(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'signed':
        color = Colors.green;
        break;
      case 'sent to client':
        color = Colors.blue;
        break;
      case 'pending ceo approval':
        color = Colors.orange;
        break;
      case 'in review':
        color = Colors.yellow;
        break;
      default:
        color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _exportAsCSV() {
    try {
      final app = context.read<AppState>();
      final proposals = app.proposals;

      final csvContent = StringBuffer();
      csvContent.writeln('Analytics Report - $_selectedPeriod');
      csvContent.writeln(
          'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      csvContent.writeln('');
      csvContent.writeln('Title,Status,Client,Created At');

      for (final proposal in proposals) {
        final title =
            (proposal['title'] ?? '').toString().replaceAll('"', '""');
        final status = proposal['status']?.toString() ?? '';
        final client =
            (proposal['client'] ?? '').toString().replaceAll('"', '""');
        final createdAt = proposal['created_at']?.toString() ?? '';

        csvContent.writeln('"$title","$status","$client","$createdAt"');
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
          const SnackBar(
            content: Text('CSV exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
