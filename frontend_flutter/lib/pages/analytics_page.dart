import 'package:flutter/material.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedPeriod = 'Last 30 Days';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: Column(
        children: [
          // Header
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Proposal & SOW Builder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
                          child: Text(
                            'U',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'User',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'logout') {
                            Navigator.pushReplacementNamed(context, '/login');
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

          // Main Content
          Expanded(
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 250,
                  color: const Color(0xFF34495E),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Title
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3E50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF34495E), width: 1),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: Color(0xFF3498DB),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Business Developer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildNavItem('📊', 'Dashboard', false, context),
                        _buildNavItem('📝', 'My Proposals', false, context),
                        _buildNavItem('📂', 'Templates', false, context),
                        _buildNavItem('🧩', 'Content Library', false, context),
                        _buildNavItem('👥', 'Collaboration', false, context),
                        _buildNavItem('📋', 'Approvals Status', false, context),
                        _buildNavItem(
                            '🔍', 'Analytics (My Pipeline)', true, context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Analytics & Pipeline',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Track your proposal performance and pipeline metrics',
                                    style: TextStyle(
                                      color: Color(0xFF718096),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedPeriod,
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
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Key Metrics Row
                          Row(
                            children: [
                              Expanded(
                                  child: _buildMetricCard('Total Proposals',
                                      '24', '+12%', const Color(0xFF3498DB))),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _buildMetricCard('Win Rate', '68%',
                                      '+5%', const Color(0xFF2ECC71))),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _buildMetricCard('Avg. Value', '\$45K',
                                      '+8%', const Color(0xFFE74C3C))),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _buildMetricCard(
                                      'Pipeline Value',
                                      '\$1.2M',
                                      '+15%',
                                      const Color(0xFFF39C12))),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Charts Row
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildChartCard(
                                    'Proposal Pipeline', _buildPipelineChart()),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 1,
                                child: _buildChartCard(
                                    'Win Rate by Type', _buildWinRateChart()),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Performance Table
                          _buildPerformanceTable(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            height: 50,
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: Color(0xFFDDD), style: BorderStyle.solid)),
            ),
            child: const Center(
              child: Text(
                'Khonology Proposal & SOW Builder | End-to-End Proposal Generation and Sign-Off',
                style: TextStyle(
                  color: Color(0xFF7F8C8D),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      String icon, String label, bool isActive, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(color: const Color(0xFF2980B9), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _navigateToPage(context, label);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(icon,
                    style: TextStyle(
                      fontSize: 18,
                      color: isActive ? Colors.white : const Color(0xFFBDC3C7),
                    )),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFFECF0F1),
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isActive)
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.white,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, String change, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              change,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2ECC71),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineChart() {
    return Container(
      height: 200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: Color(0xFFBDC3C7),
            ),
            SizedBox(height: 8),
            Text(
              'Pipeline Chart',
              style: TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
              ),
            ),
            Text(
              'Coming Soon',
              style: TextStyle(
                color: Color(0xFF95A5A6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinRateChart() {
    return Container(
      height: 200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart,
              size: 48,
              color: Color(0xFFBDC3C7),
            ),
            SizedBox(height: 8),
            Text(
              'Win Rate Chart',
              style: TextStyle(
                color: Color(0xFF718096),
                fontSize: 14,
              ),
            ),
            Text(
              'Coming Soon',
              style: TextStyle(
                color: Color(0xFF95A5A6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Proposals Performance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Proposal',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Value',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Days',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Win Rate',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildTableRow('Software Development Proposal', '\$75K', 'Won',
                    '12', '100%', const Color(0xFF2ECC71)),
                _buildTableRow('Cloud Migration SOW', '\$45K', 'Pending', '8',
                    '75%', const Color(0xFFF39C12)),
                _buildTableRow('Data Analytics Contract', '\$32K', 'Lost', '15',
                    '0%', const Color(0xFFE74C3C)),
                _buildTableRow('Maintenance Agreement', '\$18K', 'Won', '5',
                    '100%', const Color(0xFF2ECC71)),
                _buildTableRow('Consulting Services', '\$60K', 'In Review',
                    '10', '60%', const Color(0xFF3498DB)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String proposal, String value, String status,
      String days, String winRate, Color statusColor) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF8F9FA))),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            proposal,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            days,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            winRate,
            style: TextStyle(
              fontSize: 14,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
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
        Navigator.pushReplacementNamed(context, '/templates');
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content_library');
        break;
      case 'Collaboration':
        Navigator.pushReplacementNamed(context, '/collaboration');
        break;
      case 'Approvals Status':
        Navigator.pushReplacementNamed(context, '/approvals');
        break;
      case 'Analytics (My Pipeline)':
        // Already on analytics page
        break;
      default:
        Navigator.pushReplacementNamed(context, '/creator_dashboard');
    }
  }
}
