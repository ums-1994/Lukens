import 'package:flutter/material.dart';
import '../../widgets/analytics_charts.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';
import '../../services/currency_service.dart';
import '../../widgets/currency_picker.dart';

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
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
            // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                      'Analytics Dashboard',
                                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                      'Comprehensive business intelligence and performance metrics',
                                    style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFB0B6BB),
                        fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                Row(
                  children: [
                    LiquidGlassCard(
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedPeriod,
                          dropdownColor: const Color(0xFF121212),
                          style: const TextStyle(color: Colors.white),
                                      items: [
                                        'Last 7 Days',
                                        'Last 30 Days',
                                        'Last 90 Days',
                                        'This Year'
                                      ].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                              child: Text(value, style: const TextStyle(color: Colors.white)),
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
                    const SizedBox(width: 12),
                    LiquidGlassCard(
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: const Row(
                        children: [
                          Icon(Icons.download, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Export',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                              ),
                            ],
                          ),
            const SizedBox(height: 32),

                          // Key Metrics Row
                          Row(
                            children: [
                              Expanded(
                  child: LiquidGlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Revenue',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CurrencyDisplay(
                          amount: 2847392,
                          largeAmount: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                          Row(
                            children: [
                            const Icon(Icons.trending_up, color: Color(0xFF14B3BB), size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              '+12.5%',
                              style: TextStyle(
                                color: Color(0xFF14B3BB),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              ' vs last month',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: LiquidGlassCard(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Proposals',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '47',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.trending_up, color: Color(0xFF14B3BB), size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              '+8.2%',
                style: TextStyle(
                                color: Color(0xFF14B3BB),
                  fontSize: 14,
                                fontWeight: FontWeight.w600,
                ),
              ),
                            const Text(
                              ' vs last month',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
            ),
          ),
        ],
                  ),
              ],
            ),
          ),
        ),
                const SizedBox(width: 20),
                Expanded(
                  child: LiquidGlassCard(
                    borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                        const Text(
                          'Conversion Rate',
                          style: TextStyle(
                            color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
                        const Text(
                          '73.2%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.trending_down, color: Color(0xFFE9293A), size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              '-2.1%',
              style: TextStyle(
                                color: Color(0xFFE9293A),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              ' vs last month',
                              style: TextStyle(
                                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: LiquidGlassCard(
                    borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                        const Text(
                          'Avg Deal Size',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CurrencyDisplay(
                          amount: 60583,
                          largeAmount: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
          children: [
                            const Icon(Icons.trending_up, color: Color(0xFF14B3BB), size: 16),
                            const SizedBox(width: 4),
                            const Text(
                              '+5.7%',
              style: TextStyle(
                                color: Color(0xFF14B3BB),
                fontSize: 14,
                                fontWeight: FontWeight.w600,
              ),
            ),
                            const Text(
                              ' vs last month',
              style: TextStyle(
                                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
                      ],
                    ),
              ),
            ),
          ],
        ),
            const SizedBox(height: 32),

            // Charts Section
            const AnalyticsCharts(),
            const SizedBox(height: 32),

            // Performance Table
            LiquidGlassCard(
              borderRadius: 16,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                    'Top Performing Proposals',
              style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
                  const SizedBox(height: 20),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(2),
                4: FlexColumnWidth(1),
              },
              children: [
                      TableRow(
                  decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                  ),
                        children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Proposal',
                        style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Client',
                              style: TextStyle(
                                color: Colors.white70,
                          fontWeight: FontWeight.w600,
                                fontSize: 14,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Value',
                        style: TextStyle(
                                color: Colors.white70,
                          fontWeight: FontWeight.w600,
                                fontSize: 14,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Status',
                        style: TextStyle(
                                color: Colors.white70,
                          fontWeight: FontWeight.w600,
                                fontSize: 14,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                              'Score',
                        style: TextStyle(
                                color: Colors.white70,
                          fontWeight: FontWeight.w600,
                                fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                      _buildTableRow('Enterprise Cloud Migration', 'TechCorp Inc.', '\$125,000', 'Signed', '98'),
                      _buildTableRow('Digital Marketing Campaign', 'RetailMax', '\$85,000', 'Approved', '95'),
                      _buildTableRow('Financial System Integration', 'BankFlow', '\$200,000', 'Pending', '92'),
                      _buildTableRow('Healthcare Platform', 'MediCare Plus', '\$150,000', 'Draft', '88'),
                      _buildTableRow('E-commerce Solution', 'ShopSmart', '\$75,000', 'Signed', '96'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Footer(),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String proposal, String client, String value, String status, String score) {
    Color statusColor;
    switch (status) {
      case 'Signed':
        statusColor = const Color(0xFF14B3BB);
        break;
      case 'Approved':
        statusColor = const Color(0xFFFFD700);
        break;
      case 'Pending':
        statusColor = const Color(0xFFE9293A);
        break;
      default:
        statusColor = const Color(0xFF6B7280);
    }

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            proposal,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            client,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            score,
            style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}