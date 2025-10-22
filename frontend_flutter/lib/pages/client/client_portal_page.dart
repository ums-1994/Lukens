import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/footer.dart';

class ClientPortalPage extends StatefulWidget {
  const ClientPortalPage({super.key});

  @override
  State<ClientPortalPage> createState() => _ClientPortalPageState();
}

class _ClientPortalPageState extends State<ClientPortalPage> {
  String currentView = 'dashboard';

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
              'Client Portal',
                style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                  color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            
            // Client Status Overview
            Row(
          children: [
                Expanded(child: _buildStatusCard('Active Proposals', '3', const Color(0xFF2196F3))),
                const SizedBox(width: 16),
                Expanded(child: _buildStatusCard('Signed Contracts', '7', const Color(0xFF4CAF50))),
                const SizedBox(width: 16),
                Expanded(child: _buildStatusCard('Pending Review', '2', const Color(0xFFFF9800))),
              ],
            ),
            const SizedBox(height: 24),
            
            // My Proposals
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
                        'My Proposals',
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
                  _buildProposalItem('Website Development Proposal', 'Under Review', '2 days ago', Icons.web),
                  _buildProposalItem('Mobile App Contract', 'Draft', '1 week ago', Icons.phone_android),
                  _buildProposalItem('Consulting Services', 'Approved', '2 weeks ago', Icons.business),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Signed Documents
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
                        'Signed Documents',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/signed_documents'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDocumentItem('Service Agreement v2.1', 'Signed', '3 days ago', Icons.description),
                  _buildDocumentItem('NDA Contract', 'Signed', '1 week ago', Icons.security),
                  _buildDocumentItem('Payment Terms', 'Signed', '2 weeks ago', Icons.payment),
            ],
          ),
        ),
            const SizedBox(height: 24),
            
            // Quick Actions
            LiquidGlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildActionButton('Send Message', Icons.message, () => Navigator.pushNamed(context, '/messages'))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildActionButton('Request Support', Icons.support_agent, () => Navigator.pushNamed(context, '/support'))),
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

  Widget _buildStatusCard(String title, String value, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/proposals'),
      child: LiquidGlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
                Icon(Icons.description, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
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

  Widget _buildProposalItem(String title, String status, String time, IconData icon) {
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

  Widget _buildDocumentItem(String title, String status, String time, IconData icon) {
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
                  '$status • $time',
            style: const TextStyle(
                    color: Colors.green,
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

  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: Column(
        children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
