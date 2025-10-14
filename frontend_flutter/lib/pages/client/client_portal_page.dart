import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

class ClientPortalPage extends StatefulWidget {
  final String? token;

  const ClientPortalPage({super.key, this.token});

  @override
  State<ClientPortalPage> createState() => _ClientPortalPageState();
}

class _ClientPortalPageState extends State<ClientPortalPage> {
  String currentView = 'dashboard';
  bool isLoading = true;
  bool isAuthenticated = false;
  String? clientEmail;
  String? proposalId;
  Map<String, dynamic>? proposalData;
  String? errorMessage;
  bool isSigningInProgress = false;

  // Signature controller
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

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
                    'Client Portal - Proposal & SOW Builder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      // Notification Bell
                      Stack(
                        children: [
                          const Icon(Icons.notifications, color: Colors.white, size: 24),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE74C3C),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 15),
                      // Client Info
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
                                'GT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'GlobalTech Inc.',
                            style: TextStyle(
                              color: Colors.white,
                              strokeWidth: 2,
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
                // Client Sidebar
                Container(
                  width: 280,
                  color: const Color(0xFF34495E),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildClientNavItem('📊', 'Dashboard', 'dashboard'),
                        _buildClientNavItem('📝', 'My Proposals', 'proposals'),
                        _buildClientNavItem('👁️', 'Review Proposal', 'review'),
                        _buildClientNavItem('📋', 'Signed Documents', 'signed'),
                        _buildClientNavItem('👥', 'Team Access', 'team'),
                        _buildClientNavItem('❓', 'Support', 'support'),
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
                          if (currentView == 'dashboard') _buildClientDashboard(),
                          if (currentView == 'proposals') _buildClientProposals(),
                          if (currentView == 'review') _buildClientReview(),
                          if (currentView == 'signed') _buildClientSigned(),
                          if (currentView == 'team') _buildClientTeam(),
                          if (currentView == 'support') _buildClientSupport(),
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
              border: Border(top: BorderSide(color: Color(0xFFDDD), style: BorderStyle.solid)),
            ),
            child: const Center(
              child: Text(
                'Client Portal - Khonology Proposal & SOW Builder | Secure Document Review and Signing',
                style: TextStyle(
                  color: Color(0xFF7F8C8D),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!isAuthenticated) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue,
                Colors.blue[800]!,
              ],
            ),
          ),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Access Denied',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage ?? 'Invalid access token',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

  Widget _buildClientDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Banner
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A6580), Color(0xFF2C3E50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome, GlobalTech Inc.!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You have 2 proposals awaiting your review and 3 signed documents in your archive.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () => setState(() => currentView = 'proposals'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Proposals Needing Attention'),
              ),
            ],
          ),
        ),
        
        // Dashboard Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 2.5,
          children: [
            _buildClientCard('Proposals for Review', '2', 'Pending'),
            _buildClientCard('Signed Documents', '3', 'Completed'),
            _buildClientCard('Avg. Response Time', '4.2', 'Days'),
            _buildClientCard('Active Projects', '2', 'Ongoing'),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Proposals Needing Attention
        _buildSection(
          '⏰ Proposals Needing Your Attention',
          _buildProposalList([
            {
              'name': 'Cloud Migration Project',
              'meta': 'Received: Oct 15, 2023 • Expires: Oct 29, 2023',
              'status': 'review',
            },
            {
              'name': 'Security Assessment',
              'meta': 'Received: Oct 18, 2023 • Expires: Nov 1, 2023',
              'status': 'review',
            },
          ]),
        ),
        
        const SizedBox(height: 20),
        
        // Help Section
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FC),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'Need Help?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildHelpItem('📖', 'How to review a proposal'),
              _buildHelpItem('🖊️', 'How to sign a document electronically'),
              _buildHelpItem('👥', 'How to add team members'),
              _buildHelpItem('❓', 'Contact support'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String view,
  }) {
    final isActive = currentView == view;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            setState(() {
              currentView = view;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (currentView) {
      case 'dashboard':
        return _buildDashboardView();
      case 'proposals':
        return _buildProposalsView();
      case 'signed':
        return _buildSignedDocumentsView();
      case 'support':
        return _buildSupportView();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Text(
            'Client Dashboard',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome, ${clientEmail ?? 'Client'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
          const SizedBox(height: 32),

          // Active Proposals Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.description,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Active Proposals',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProposalItem(
                    title: proposalData?['title'] ?? 'Business Proposal',
                    status: proposalData?['status'] ?? 'Pending Review',
                    date: 'Today',
                    onTap: () => setState(() => currentView = 'proposals'),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Proposal Content
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContentSection(
                'Executive Summary',
                'This proposal outlines the migration of your current infrastructure to a cloud-based solution, providing enhanced scalability, security, and cost efficiency. The project is estimated to take 12 weeks with a total investment of \$250,000.',
              ),
              _buildContentSection(
                'Scope of Work',
                '• Assessment of current infrastructure\n• Cloud architecture design\n• Data migration strategy\n• Security implementation\n• Testing and validation\n• Training and documentation',
              ),
              _buildContentSection(
                'Timeline',
                'The project will be completed in four phases over 12 weeks:\n• Phase 1: Planning (2 weeks)\n• Phase 2: Migration (6 weeks)\n• Phase 3: Testing (3 weeks)\n• Phase 4: Go-Live (1 week)',
              ),
              _buildContentSection(
                'Investment',
                'Total project cost: \$250,000\nPayment schedule:\n• 30% upon signing\n• 40% upon completion of migration phase\n• 30% upon project completion',
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Signature Area
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            border: Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sign Proposal',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 15),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter your title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCCC), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                ),
                child: const Center(
                  child: Text(
                    'Click to sign electronically',
                    style: TextStyle(color: Color(0xFF7F8C8D)),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign and Submit'),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Comments Section
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            border: Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('💬', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'Discussion',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildCommentItem(
                'Sarah Johnson (Khonology)',
                'Please let us know if you have any questions about the proposal. We\'re happy to schedule a call to discuss any details.',
                'Posted: Oct 15, 2023 at 10:30 AM',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSigned() {
    return _buildSection(
      '📋 Signed Documents',
      _buildProposalList([
        {
          'name': 'Managed Services Agreement',
          'meta': 'Signed: Sep 5, 2023 • Value: \$120,000',
          'status': 'signed',
        },
        {
          'name': 'Q1 Support Renewal',
          'meta': 'Signed: Mar 15, 2023 • Value: \$35,000',
          'status': 'signed',
        },
        {
          'name': 'Security Audit',
          'meta': 'Signed: Jan 10, 2023 • Value: \$75,000',
          'status': 'signed',
        },
      ]),
    );
  }

  Widget _buildClientTeam() {
    return _buildSection(
      '👥 Team Access',
      const Text('Team management features coming soon...'),
    );
  }

  Widget _buildClientSupport() {
    return _buildSection(
      '❓ Support',
      const Text('Support features coming soon...'),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCC), style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          content,
        ],
      ),
    );
  }

  Widget _buildProposalList(List<Map<String, String>> proposals) {
    return Column(
      children: proposals.map((proposal) => _buildProposalItem(proposal)).toList(),
    );
  }

  Widget _buildProposalItem(Map<String, String> proposal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal['name']!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  proposal['meta']!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (proposal['status'] == 'review') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB8DAFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Review Needed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF004085),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => setState(() => currentView = 'review'),
                  child: const Text('Review'),
                ),
              ] else if (proposal['status'] == 'signed') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC3E6CB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Signed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF155724),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Download'),
                ),
              ] else if (proposal['status'] == 'expired') ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEBA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Expired',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF856404),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('View'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProposalItem({
    required String title,
    required String status,
    required String date,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description,
            color: Colors.blue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: $status • $date',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_ios),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedItem({
    required String title,
    required String signedDate,
    required VoidCallback onDownload,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: Color(0xFF3498DB), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 5),
          Text(
            meta,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7F8C8D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }
}
