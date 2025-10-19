import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';

class ApproverDashboardPage extends StatefulWidget {
  const ApproverDashboardPage({super.key});

  @override
  State<ApproverDashboardPage> createState() => _ApproverDashboardPageState();
}

class _ApproverDashboardPageState extends State<ApproverDashboardPage> {

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Approver Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            
            // Approval Queue
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
                        'My Approval Queue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/approvals'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildApprovalItem('GlobalTech Inc. - Cloud Migration', 'Sarah Johnson', 'Today', Icons.cloud),
                  _buildApprovalItem('NewVentures - Security Assessment', 'Michael Chen', 'Tomorrow', Icons.security),
                  _buildApprovalItem('Axis Corp - Managed Services', 'Emily Wong', 'In 2 days', Icons.business),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Approval Metrics
            LiquidGlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Approval Metrics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('Pending', '12', const Color(0xFFFF9800))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Approved Today', '8', const Color(0xFF4CAF50))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMetricCard('Avg. Time', '2.3h', const Color(0xFF2196F3))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Recently Approved
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
                        'Recently Approved',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/approvals'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildApprovedItem('WebSolutions - Support Contract', 'Approved', '2 hours ago', Icons.check_circle),
                  _buildApprovedItem('SoftWorks - Maintenance', 'Approved', '4 hours ago', Icons.check_circle),
                  _buildApprovedItem('DataCore - Implementation', 'Approved', '6 hours ago', Icons.check_circle),
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
        ),
      ),
    );
  }

  Widget _buildApprovalItem(String title, String submitter, String due, IconData icon) {
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
                  'Submitted by: $submitter • Due: $due',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildActionButton('View Details', const Color(0xFF2196F3), true),
              const SizedBox(width: 8),
              _buildActionButton('Approve', const Color(0xFF4CAF50), false),
              const SizedBox(width: 8),
              _buildActionButton('Reject', const Color(0xFFF44336), false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedItem(String title, String status, String time, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
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
                  '$status • $time',
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

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, bool isOutline) {
    return GestureDetector(
      onTap: () {
        switch (text) {
          case 'View Details':
            Navigator.pushNamed(context, '/preview');
            break;
          case 'Approve':
            Navigator.pushNamed(context, '/approvals');
            break;
          case 'Reject':
            Navigator.pushNamed(context, '/approvals');
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isOutline ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isOutline ? color : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}