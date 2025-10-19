import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/bg_video.dart';
import '../widgets/footer.dart';

class CEODashboardPage extends StatefulWidget {
  const CEODashboardPage({super.key});

  @override
  State<CEODashboardPage> createState() => _CEODashboardPageState();
}

class _CEODashboardPageState extends State<CEODashboardPage> {
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
        child: _buildCEODashboard({}),
      ),
    );
  }

  Widget _buildCEODashboard(Map<String, dynamic> counts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CEO Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 32),

        // Premium Metrics Grid
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildPremiumMetricCard(
                    'DRAFT PROPOSALS',
                    counts['Draft']?.toString() ?? '0',
                    '90.0%',
                    const LinearGradient(
                      colors: [Color(0xFFE9293A), Color(0xFFFFD700)],
                    ),
                    Icons.edit_document,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumMetricCard(
                    'PENDING APPROVAL',
                    counts['Pending']?.toString() ?? '0',
                    '15.2%',
                    const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    Icons.pending_actions,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumMetricCard(
                    'SENT TO CLIENT',
                    counts['Sent']?.toString() ?? '0',
                    '8.7%',
                    const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF14B3BB)],
                    ),
                    Icons.send,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Center - Global Analytics
            Expanded(
              flex: 3,
              child: _buildGlobalAnalyticsCard(),
            ),
            const SizedBox(width: 16),

            // Right Column - Data Cards
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildPremiumMetricCard(
                    'SIGNED PROPOSALS',
                    counts['Signed']?.toString() ?? '0',
                    '2.5%',
                    const LinearGradient(
                      colors: [Color(0xFF14B3BB), Color(0xFF00D4FF)],
                    ),
                    Icons.check_circle,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumMetricCard(
                    'TOTAL REVENUE',
                    'R 2,847,392',
                    '08.9%',
                    const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    Icons.attach_money,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumMetricCard(
                    'LIQUIDATED',
                    counts['Liquidated']?.toString() ?? '0',
                    '0%',
                    const LinearGradient(
                      colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)],
                    ),
                    Icons.water_drop,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
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

  Widget _buildPremiumMetricCard(String label, String value, String percentage, LinearGradient gradient, IconData icon) {
    return GestureDetector(
      onTap: () {
        switch (label) {
          case 'TOTAL REVENUE':
            Navigator.pushNamed(context, '/analytics');
            break;
          case 'ACTIVE CLIENTS':
            Navigator.pushNamed(context, '/user_management');
            break;
          case 'PENDING APPROVAL':
            Navigator.pushNamed(context, '/approvals');
            break;
        }
      },
      child: LiquidGlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: Colors.white, size: 32),
                  Text(
                    percentage,
                    style: const TextStyle(
                      color: Colors.white70,
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
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalAnalyticsCard() {
    return Container(
      height: 400,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/analytics'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9293A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE9293A)),
                  ),
                  child: const Text(
                    'GLOBAL ANALYTICS',
                    style: TextStyle(
                      color: Color(0xFFE9293A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/analytics'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B3BB).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF14B3BB)),
                  ),
                  child: const Text(
                    'LIVE DATA',
                    style: TextStyle(
                      color: Color(0xFF14B3BB),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: const BgVideo(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/user_management'),
                child: _buildAnalyticsMetric('Clients', '156', const Color(0xFF14B3BB)),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/analytics'),
                child: _buildAnalyticsMetric('Countries', '23', const Color(0xFF00D4FF)),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/analytics'),
                child: _buildAnalyticsMetric('Growth', '+23%', const Color(0xFFE9293A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
