import 'package:flutter/material.dart';

class ClientPortalPage extends StatefulWidget {
  const ClientPortalPage({super.key});

  @override
  State<ClientPortalPage> createState() => _ClientPortalPageState();
}

class _ClientPortalPageState extends State<ClientPortalPage> {
  String currentView = 'dashboard';

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
                              fontSize: 16,
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
        ],
      ),
    );
  }

  Widget _buildClientNavItem(String icon, String label, String view) {
    final isActive = currentView == view;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => setState(() => currentView = view),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
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

  Widget _buildClientCard(String title, String value, String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3498DB),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientProposals() {
    return _buildSection(
      '📝 All Proposals',
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
        {
          'name': 'Managed Services Agreement',
          'meta': 'Signed: Sep 5, 2023 • Value: \$120,000',
          'status': 'signed',
        },
        {
          'name': 'Q2 Support Renewal',
          'meta': 'Expired: Aug 15, 2023',
          'status': 'expired',
        },
      ]),
    );
  }

  Widget _buildClientReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Proposal Detail Header
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cloud Migration Project',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Proposal ID: PRO-2023-010 • Received: Oct 15, 2023 • Expires: Oct 29, 2023',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Download PDF'),
                  ),
                ],
              ),
            ],
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
              _buildCommentItem(
                'Michael Chen (GlobalTech Inc.)',
                'Can we break the payment into four installments instead of three?',
                'Posted: Oct 16, 2023 at 2:15 PM',
              ),
              _buildCommentItem(
                'Sarah Johnson (Khonology)',
                'Yes, we can adjust the payment schedule. I\'ll update the proposal accordingly.',
                'Posted: Oct 16, 2023 at 3:40 PM',
              ),
              const SizedBox(height: 15),
              const TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a comment or question...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498DB),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Post Comment'),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildContentSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(String author, String text, String meta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
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
