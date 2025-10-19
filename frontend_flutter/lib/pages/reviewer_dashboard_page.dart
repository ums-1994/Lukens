import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/footer.dart';

class ReviewerDashboardPage extends StatefulWidget {
  const ReviewerDashboardPage({super.key});

  @override
  State<ReviewerDashboardPage> createState() => _ReviewerDashboardPageState();
}

class _ReviewerDashboardPageState extends State<ReviewerDashboardPage> {
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
        child: _buildReviewerDashboard({}),
      ),
    );
  }

  Widget _buildReviewerDashboard(Map<String, dynamic> counts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviewer Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 32),
        
        // Review Metrics Row
        Row(
          children: [
            Expanded(child: _buildReviewCard(
              'PENDING REVIEWS',
              '18',
              '+5.2%',
              Icons.pending_actions,
              const Color(0xFFFF9800),
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildReviewCard(
              'COMPLETED TODAY',
              '12',
              '+8.1%',
              Icons.check_circle,
              const Color(0xFF4CAF50),
            )),
            const SizedBox(width: 16),
            Expanded(child: _buildReviewCard(
              'AVERAGE TIME',
              '2.3h',
              '-0.5h',
              Icons.timer,
              const Color(0xFF2196F3),
            )),
          ],
        ),
        const SizedBox(height: 24),
        
        // Review Queue
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
                    'Review Queue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/review_queue'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildReviewItem('ABC Corp - Service Agreement', 'High Priority', '2 hours ago', Icons.priority_high),
              _buildReviewItem('XYZ Ltd - Contract Renewal', 'Medium Priority', '4 hours ago', Icons.schedule),
              _buildReviewItem('DEF Inc - Proposal Review', 'Low Priority', '6 hours ago', Icons.low_priority),
              _buildReviewItem('GHI Corp - Legal Document', 'High Priority', '8 hours ago', Icons.priority_high),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Quality Metrics
        LiquidGlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quality Metrics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildQualityMetric('Accuracy', '94%', const Color(0xFF4CAF50))),
                  Expanded(child: _buildQualityMetric('Speed', '87%', const Color(0xFF2196F3))),
                  Expanded(child: _buildQualityMetric('Consistency', '91%', const Color(0xFF9C27B0))),
                ],
              ),
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

  Widget _buildReviewCard(String title, String value, String change, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/review_queue'),
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

  Widget _buildReviewItem(String title, String priority, String time, IconData icon) {
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
                Row(
                  children: [
                    Text(
                      priority,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const Text(' • ', style: TextStyle(color: Colors.white60)),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityMetric(String metric, String value, Color color) {
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
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
