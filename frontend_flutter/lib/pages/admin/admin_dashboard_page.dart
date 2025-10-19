import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {

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
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            
            // System Overview
            Row(
              children: [
                Expanded(child: _buildSystemCard('Total Users', '156', const Color(0xFF2196F3))),
                const SizedBox(width: 16),
                Expanded(child: _buildSystemCard('Active Sessions', '23', const Color(0xFF4CAF50))),
                const SizedBox(width: 16),
                Expanded(child: _buildSystemCard('System Load', '67%', const Color(0xFFFF9800))),
              ],
            ),
            const SizedBox(height: 24),
            
            // User Management
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
                        'User Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/user_management'),
                        child: const Text('Manage Users'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildUserItem('John Doe', 'CEO', 'Active', Icons.person),
                  _buildUserItem('Sarah Johnson', 'Financial Manager', 'Active', Icons.person),
                  _buildUserItem('Mike Chen', 'Reviewer', 'Pending', Icons.person),
                  _buildUserItem('Emily Wong', 'Client', 'Active', Icons.person),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // System Settings
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
                        'System Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/system_settings'),
                        child: const Text('Configure'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildSettingItem('Database', 'Connected', Icons.storage)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSettingItem('Email Service', 'Active', Icons.email)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSettingItem('Backup', 'Scheduled', Icons.backup)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Analytics
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
                        'System Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/analytics'),
                        child: const Text('View Reports'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildAnalyticsCard('Proposals Created', '247', '+12%')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildAnalyticsCard('Users Active', '89', '+5%')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildAnalyticsCard('System Uptime', '99.9%', '+0.1%')),
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
        ),
      ),
    );
  }

  Widget _buildSystemCard(String label, String value, Color color) {
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
                Icon(Icons.monitor, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Live',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
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
    );
  }

  Widget _buildUserItem(String name, String role, String status, IconData icon) {
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
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$role • $status',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Active' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: status == 'Active' ? Colors.green : Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String name, String status, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String label, String value, String change) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
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
          const SizedBox(height: 4),
          Text(
            change,
            style: TextStyle(
              color: change.startsWith('+') ? Colors.green : Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}