import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/footer.dart';

class FinancialManagerDashboardPage extends StatefulWidget {
  const FinancialManagerDashboardPage({super.key});

  @override
  State<FinancialManagerDashboardPage> createState() => _FinancialManagerDashboardPageState();
}

class _FinancialManagerDashboardPageState extends State<FinancialManagerDashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildFinancialManagerDashboard({}),
      ),
    );
  }

  Widget _buildFinancialManagerDashboard(Map<String, dynamic> counts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Manager Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 32),
        
        // Financial Metrics Row
        Row(
          children: [
            Expanded(child: _buildFinancialCard(
              'MONTHLY REVENUE',
              'R 847,392',
              '+8.2%',
              Icons.attach_money,
              const Color(0xFF4CAF50),
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildFinancialCard(
              'PENDING INVOICES',
              '23',
              '+12.1%',
              Icons.receipt_long,
              const Color(0xFFFF9800),
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildFinancialCard(
              'OVERDUE PAYMENTS',
              '7',
              '-2.3%',
              Icons.warning,
              const Color(0xFFF44336),
            )),
          ],
        ),
        const SizedBox(height: 24),
        
        // Pipeline Overview
        LiquidGlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pipeline Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildPipelineStage('Prospects', '15', const Color(0xFF2196F3))),
                  Expanded(child: _buildPipelineStage('Negotiations', '8', const Color(0xFFFF9800))),
                  Expanded(child: _buildPipelineStage('Contracts', '12', const Color(0xFF4CAF50))),
                  Expanded(child: _buildPipelineStage('Closed', '5', const Color(0xFF9C27B0))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Recent Activities
        LiquidGlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activities',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/proposals'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildActivityItem('New proposal from ABC Corp', '2 hours ago', Icons.description),
              _buildActivityItem('Invoice #1234 approved', '4 hours ago', Icons.check_circle),
              _buildActivityItem('Payment received from XYZ Ltd', '6 hours ago', Icons.payment),
              _buildActivityItem('Contract renewal due', '1 day ago', Icons.schedule),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Role Testing Section - MOVED TO BOTTOM OUTSIDE MAIN CARDS
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Role Testing (Debug)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      AuthService.setTestRole('CEO');
                      Navigator.pushReplacementNamed(context, '/creator_dashboard');
                    },
                    child: const Text('Set CEO'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AuthService.setTestRole('Financial Manager');
                      Navigator.pushReplacementNamed(context, '/creator_dashboard');
                    },
                    child: const Text('Set Financial Manager'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AuthService.setTestRole('Reviewer');
                      Navigator.pushReplacementNamed(context, '/creator_dashboard');
                    },
                    child: const Text('Set Reviewer'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AuthService.setTestRole('Client');
                      Navigator.pushReplacementNamed(context, '/creator_dashboard');
                    },
                    child: const Text('Set Client'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AuthService.setTestRole('Approver');
                      Navigator.pushReplacementNamed(context, '/creator_dashboard');
                    },
                    child: const Text('Set Approver'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AuthService.setTestRole('Admin');
                      Navigator.pushReplacementNamed(context, '/creator_dashboard');
                    },
                    child: const Text('Set Admin'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Current Role: ${AuthService.currentUser?['role'] ?? 'None'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Footer(),
      ],
    );
  }

  Widget _buildFinancialCard(String title, String value, String change, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/analytics'),
      child: LiquidGlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Text(
                  change,
                  style: TextStyle(
                    color: change.startsWith('+') ? Colors.green : Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineStage(String stage, String count, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
