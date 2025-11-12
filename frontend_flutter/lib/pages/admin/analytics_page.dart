import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../theme/premium_theme.dart';
import '../../services/asset_service.dart';
import '../../widgets/custom_scrollbar.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with TickerProviderStateMixin {
  String _selectedPeriod = 'Last 30 Days';
  String _currentPage = 'Analytics (My Pipeline)';
  bool _isSidebarCollapsed = true;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.value = 1.0; // Start collapsed
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

  // Export functionality
  void _exportAsCSV() {
    try {
      final csvContent = StringBuffer();
      csvContent.writeln('Analytics Report - $_selectedPeriod');
      csvContent.writeln('Generated: ${DateTime.now().toString().split('.')[0]}');
      csvContent.writeln('');
      csvContent.writeln('KEY METRICS');
      csvContent.writeln('Metric,Value,Change');
      csvContent.writeln('Total Revenue,\$2847392,+12.5%');
      csvContent.writeln('Active Proposals,47,+8.2%');
      csvContent.writeln('Conversion Rate,73.2%,-2.1%');
      csvContent.writeln('Avg Deal Size,\$60583,+5.7%');
      csvContent.writeln('');
      csvContent.writeln('RECENT PROPOSALS');
      csvContent.writeln('Proposal,Value,Status,Days,Win Probability');
      csvContent.writeln('Enterprise Cloud Migration,\$125000,In Review,8,85%');
      csvContent.writeln('Digital Transformation Initiative,\$89500,Approved,15,92%');
      csvContent.writeln('Cybersecurity Assessment,\$45200,Draft,3,65%');
      csvContent.writeln('Data Analytics Platform,\$156800,Won,22,100%');
      csvContent.writeln('Mobile App Development,\$78300,Lost,30,0%');
      
      final blob = web.Blob([csvContent.toString().toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = 'analytics_${DateTime.now().millisecondsSinceEpoch}.csv';
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
      final data = {
        'export_date': DateTime.now().toIso8601String(),
        'period': _selectedPeriod,
        'metrics': {
          'total_revenue': '\$2,847,392',
          'active_proposals': 47,
          'conversion_rate': '73.2%',
          'avg_deal_size': '\$60,583',
        },
        'proposals': [
          {'proposal': 'Enterprise Cloud Migration', 'value': '\$125,000', 'status': 'In Review', 'days': 8, 'probability': '85%'},
          {'proposal': 'Digital Transformation Initiative', 'value': '\$89,500', 'status': 'Approved', 'days': 15, 'probability': '92%'},
          {'proposal': 'Cybersecurity Assessment', 'value': '\$45,200', 'status': 'Draft', 'days': 3, 'probability': '65%'},
          {'proposal': 'Data Analytics Platform', 'value': '\$156,800', 'status': 'Won', 'days': 22, 'probability': '100%'},
          {'proposal': 'Mobile App Development', 'value': '\$78,300', 'status': 'Lost', 'days': 30, 'probability': '0%'},
        ],
      };
      
      final jsonContent = const JsonEncoder.withIndent('  ').convert(data);
      final blob = web.Blob([jsonContent.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = 'analytics_${DateTime.now().millisecondsSinceEpoch}.json';
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
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
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
                  border: Border.all(color: const Color(0x33FFFFFF), width: 1.5),
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
                      child: const Icon(Icons.download_rounded, size: 48, color: Color(0xFF06B6D4)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Export Analytics Report',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose your preferred export format',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildExportButton('CSV', Icons.table_chart, const Color(0xFF10B981), _exportAsCSV),
                        const SizedBox(width: 16),
                        _buildExportButton('JSON', Icons.code, const Color(0xFF06B6D4), _exportAsJSON),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF))),
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

  Widget _buildExportButton(String label, IconData icon, Color color, VoidCallback onPressed) {
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
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.transparent,
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
                      style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
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
                        child: const Center(
                            child: Text('U', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                        const Text('User', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                            if (value == 'logout') Navigator.pushNamed(context, '/login');
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'logout',
                              child: Row(children: [Icon(Icons.logout), SizedBox(width: 8), Text('Logout')]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: Row(
              children: [
                  // Sidebar - EXACT COPY from creator_dashboard_page.dart
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isSidebarCollapsed ? 90.0 : 250.0,
                  color: const Color(0xFF34495E),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                          const SizedBox(height: 16),
                          // Toggle button
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
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'Navigation',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: _isSidebarCollapsed ? 0 : 8),
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
                          // Navigation items
                          _buildNavItem('Dashboard', 'assets/images/Dahboard.png', false, context),
                          _buildNavItem('My Proposals', 'assets/images/My_Proposals.png', false, context),
                          _buildNavItem('Templates', 'assets/images/content_library.png', false, context),
                          _buildNavItem('Content Library', 'assets/images/content_library.png', false, context),
                          _buildNavItem('Client Management', 'assets/images/collaborations.png', false, context),
                          _buildNavItem('Approvals Status', 'assets/images/Time Allocation_Approval_Blue.png', false, context),
                          _buildNavItem('Analytics (My Pipeline)', 'assets/images/analytics.png', true, context),
                          const SizedBox(height: 20),
                          // Divider
                          if (!_isSidebarCollapsed)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              height: 1,
                              color: const Color(0xFF2C3E50),
                            ),
                          const SizedBox(height: 12),
                          // Logout button
                          _buildNavItem('Logout', 'assets/images/Logout_KhonoBuzz.png', false, context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                  // Content Area with Custom Scrollbar
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
                          // Header Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Analytics Dashboard',
                                      style: PremiumTheme.displayMedium.copyWith(fontSize: 28),
                                    ),
                                    const SizedBox(height: 8),
                                  Text(
                                      'Comprehensive business intelligence and performance metrics',
                                      style: PremiumTheme.bodyLarge.copyWith(color: PremiumTheme.textSecondary),
                                ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    _buildGlassDropdown(),
                                    const SizedBox(width: 12),
                                    _buildGlassButton('Export', Icons.download, _showExportDialog),
                                  ],
                              ),
                            ],
                          ),
                            const SizedBox(height: 32),

                          // Key Metrics Row
                          Row(
                            children: [
                                Expanded(child: _buildGlassMetricCard('Total Revenue', '\$2,847,392', '+12.5%', true, 'vs last month')),
                                const SizedBox(width: 20),
                                Expanded(child: _buildGlassMetricCard('Active Proposals', '47', '+8.2%', true, 'vs last month')),
                                const SizedBox(width: 20),
                                Expanded(child: _buildGlassMetricCard('Conversion Rate', '73.2%', '-2.1%', false, 'vs last month')),
                                const SizedBox(width: 20),
                                Expanded(child: _buildGlassMetricCard('Avg Deal Size', '\$60,583', '+5.7%', true, 'vs last month')),
                            ],
                          ),
                            const SizedBox(height: 32),

                            // Revenue Analytics Chart
                            _buildGlassChartCard('Revenue Analytics', _buildRevenueChart(), height: 350),
                            const SizedBox(height: 32),

                            // Second Row of Charts
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(flex: 2, child: _buildGlassChartCard('Proposal Status', _buildProposalStatusChart(), height: 320)),
                                const SizedBox(width: 20),
                                Expanded(child: _buildGlassChartCard('Win Rate', _buildWinRatePieChart(), height: 320)),
                            ],
                          ),
                            const SizedBox(height: 32),

                          // Performance Table
                            _buildGlassPerformanceTable(),
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

  // Nav item builder - EXACT COPY from creator_dashboard_page.dart
  Widget _buildNavItem(String label, String assetPath, bool isActive, BuildContext context) {
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              setState(() => _currentPage = label);
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
                  color: isActive ? const Color(0xFFE74C3C) : const Color(0xFFCBD5E1),
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
                child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
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
          setState(() => _currentPage = label);
            _navigateToPage(context, label);
          },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive ? Border.all(color: const Color(0xFF2980B9), width: 1) : null,
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
                    color: isActive ? const Color(0xFFE74C3C) : const Color(0xFFCBD5E1),
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
                  child: AssetService.buildImageWidget(assetPath, fit: BoxFit.contain),
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
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white),
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
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                items: ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'This Year'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
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

  Widget _buildGlassButton(String label, IconData icon, VoidCallback onPressed) {
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
          children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassMetricCard(String title, String value, String change, bool isPositive, String subtitle) {
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
            border: Border.all(color: PremiumTheme.glassWhiteBorder, width: 1.5),
          ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PremiumTheme.bodyMedium.copyWith(color: PremiumTheme.textSecondary)),
              const SizedBox(height: 12),
              Text(value, style: PremiumTheme.displayMedium.copyWith(fontSize: 32)),
              const SizedBox(height: 8),
              Row(
          children: [
            Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: isPositive ? PremiumTheme.success : PremiumTheme.error,
            ),
                  const SizedBox(width: 4),
            Text(
                    change,
              style: TextStyle(
                fontSize: 14,
                      color: isPositive ? PremiumTheme.success : PremiumTheme.error,
                      fontWeight: FontWeight.w600,
              ),
            ),
                  const SizedBox(width: 6),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassChartCard(String title, Widget chart, {double height = 300}) {
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
            border: Border.all(color: PremiumTheme.glassWhiteBorder, width: 1.5),
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

  Widget _buildRevenueChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10000,
          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF2D3748), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text('\$${(value / 1000).toInt()}K', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12));
              },
        ),
      ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                if (value.toInt() >= 0 && value.toInt() < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(months[value.toInt()], style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 5,
        minY: 0,
        maxY: 50000,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 25000),
              FlSpot(1, 32000),
              FlSpot(2, 28000),
              FlSpot(3, 40000),
              FlSpot(4, 38000),
              FlSpot(5, 47000),
            ],
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

  Widget _buildProposalStatusChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 20,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: const Color(0xFF2D3748),
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} proposals',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12));
              },
                        ),
                      ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                const statuses = ['Draft', 'Review', 'Approved', 'Won', 'Lost'];
                if (value.toInt() >= 0 && value.toInt() < statuses.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(statuses[value.toInt()], style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
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
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF2D3748), strokeWidth: 1),
                      ),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: const Color(0xFF8B5CF6), width: 32, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 15, color: const Color(0xFFF59E0B), width: 32, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 12, color: const Color(0xFF3B82F6), width: 32, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)))]),
          BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 18, color: const Color(0xFF10B981), width: 32, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)))]),
          BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 5, color: const Color(0xFFEF4444), width: 32, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)))]),
        ],
      ),
    );
  }

  Widget _buildWinRatePieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: [
          PieChartSectionData(
            color: const Color(0xFF10B981),
            value: 73.2,
            title: '73.2%',
            radius: 70,
            titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            color: const Color(0xFFEF4444),
            value: 26.8,
            title: '26.8%',
            radius: 70,
            titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
    );
  }

  Widget _buildGlassPerformanceTable() {
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
            border: Border.all(color: PremiumTheme.glassWhiteBorder, width: 1.5),
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
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2D3748), width: 2))),
                    children: [
                      _buildTableHeader('PROPOSAL'),
                      _buildTableHeader('VALUE'),
                      _buildTableHeader('STATUS'),
                      _buildTableHeader('DAYS'),
                      _buildTableHeader('WIN PROBABILITY'),
                    ],
                  ),
                  _buildTableRow('Enterprise Cloud Migration', '\$125,000', 'In Review', '8', '85%', const Color(0xFF3B82F6)),
                  _buildTableRow('Digital Transformation Initiative', '\$89,500', 'Approved', '15', '92%', const Color(0xFF10B981)),
                  _buildTableRow('Cybersecurity Assessment', '\$45,200', 'Draft', '3', '65%', const Color(0xFF8B5CF6)),
                  _buildTableRow('Data Analytics Platform', '\$156,800', 'Won', '22', '100%', const Color(0xFF10B981)),
                  _buildTableRow('Mobile App Development', '\$78,300', 'Lost', '30', '0%', const Color(0xFFEF4444)),
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
      child: Text(text, style: PremiumTheme.labelMedium.copyWith(color: PremiumTheme.textSecondary)),
    );
  }

  TableRow _buildTableRow(String proposal, String value, String status, String days, String probability, Color statusColor) {
    return TableRow(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2D3748), width: 1))),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(proposal, style: PremiumTheme.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(value, style: PremiumTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(days, style: PremiumTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: double.parse(probability.replaceAll('%', '')) / 100,
                  backgroundColor: const Color(0xFF2D3748),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(probability, style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
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
        // Templates functionality - redirect to content library for now
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Client Management':
        Navigator.pushReplacementNamed(context, '/collaboration');
        break;
      case 'Approvals Status':
        Navigator.pushReplacementNamed(context, '/approvals');
        break;
      case 'Analytics (My Pipeline)':
        // Already on analytics page
        break;
      case 'Logout':
        Navigator.pushReplacementNamed(context, '/login');
        break;
    }
  }
}
