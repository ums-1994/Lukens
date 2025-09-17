import 'package:flutter/material.dart';

class ApproverAdminPage extends StatefulWidget {
  const ApproverAdminPage({super.key});

  @override
  State<ApproverAdminPage> createState() => _ApproverAdminPageState();
}

class _ApproverAdminPageState extends State<ApproverAdminPage> {
  bool isApproverView = true; // true for Approver, false for Admin

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
                      // Search Bar
                      Container(
                        width: 200,
                        height: 35,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFCCC), style: BorderStyle.solid),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 16, color: Color(0xFF7F8C8D)),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search proposals...',
                                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
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
                      // User Info
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
                                'JD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'John Doe',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Dashboard Tabs
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFECF0F1),
              border: Border(bottom: BorderSide(color: Color(0xFFDDD))),
            ),
            child: Row(
              children: [
                _buildTab('Approver Dashboard', true),
                _buildTab('Admin Dashboard', false),
              ],
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
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildNavItem('📊', 'Dashboard', true),
                      _buildNavItem('📝', 'Proposals', false),
                      _buildNavItem('📂', 'Templates', false),
                      _buildNavItem('🧩', 'Content Library', false),
                      _buildNavItem('👥', 'Team', false),
                      _buildNavItem('📋', 'Approvals', false),
                      _buildNavItem('🔍', 'Analytics', false),
                      _buildNavItem('⚙️', 'Settings', false),
                    ],
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
                          if (isApproverView) ..._buildApproverContent(),
                          if (!isApproverView) ..._buildAdminContent(),
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
                'Khonology Proposal & SOW Builder | Approver & Admin Dashboards',
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

  Widget _buildTab(String title, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isApproverView = isActive;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          border: isActive ? const Border(bottom: BorderSide(color: Color(0xFF3498DB), width: 3)) : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isActive ? const Color(0xFF2C3E50) : const Color(0xFF7F8C8D),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String icon, String label, bool isActive) {
    return Container(
      color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildApproverContent() {
    return [
      // My Approval Queue
      _buildSection(
        '📋 My Approval Queue',
        _buildApprovalQueue(),
      ),
      const SizedBox(height: 20),
      
      // My Approval Metrics
      _buildSection(
        '📈 My Approval Metrics',
        _buildApproverMetrics(),
      ),
      const SizedBox(height: 20),
      
      // Recently Approved
      _buildSection(
        '⏰ Recently Approved',
        _buildRecentlyApproved(),
      ),
    ];
  }

  List<Widget> _buildAdminContent() {
    return [
      // Proposal Pipeline Overview
      _buildSection(
        '📊 Proposal Pipeline Overview',
        _buildPipelineOverview(),
      ),
      const SizedBox(height: 20),
      
      // Performance Metrics
      _buildSection(
        '📈 Performance Metrics',
        _buildPerformanceMetrics(),
      ),
      const SizedBox(height: 20),
      
      // User Management
      _buildSection(
        '👥 User Management',
        _buildUserManagement(),
      ),
    ];
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCCC), style: BorderStyle.solid),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEE), style: BorderStyle.solid)),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            const SizedBox(height: 15),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalQueue() {
    final approvalItems = [
      {
        'name': 'GlobalTech Inc. - Cloud Migration',
        'meta': 'Submitted by: Sarah Johnson • Due: Today',
      },
      {
        'name': 'NewVentures - Security Assessment',
        'meta': 'Submitted by: Michael Chen • Due: Tomorrow',
      },
      {
        'name': 'Axis Corp - Managed Services',
        'meta': 'Submitted by: Emily Wong • Due: In 2 days',
      },
    ];

    return Column(
      children: approvalItems.map((item) => _buildApprovalItem(item['name'] as String, item['meta'] as String)).toList(),
    );
  }

  Widget _buildApprovalItem(String name, String meta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
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
          ),
          Row(
            children: [
              _buildButton('View Details', const Color(0xFF3498DB), true),
              const SizedBox(width: 10),
              _buildButton('Approve', const Color(0xFF3498DB), false),
              const SizedBox(width: 10),
              _buildButton('Reject', const Color(0xFFE74C3C), false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color color, bool isOutline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, style: BorderStyle.solid),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isOutline ? color : Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildApproverMetrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _buildMetricCard('Pending My Approval', '7', 'Proposals'),
        _buildMetricCard('Avg. Response Time', '1.5', 'Days'),
        _buildMetricCard('Approval Rate', '85%', 'This Month'),
        _buildMetricCard('Rejected Proposals', '3', 'This Month'),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyApproved() {
    final approvedItems = [
      {
        'name': 'DataCore - Implementation',
        'meta': 'Approved: Today, 10:30 AM',
        'status': 'Signed',
        'statusColor': const Color(0xFFC3E6CB),
        'textColor': const Color(0xFF155724),
      },
      {
        'name': 'WebSolutions - Support',
        'meta': 'Approved: Yesterday, 3:45 PM',
        'status': 'Waiting for Client',
        'statusColor': const Color(0xFFFFF3CD),
        'textColor': const Color(0xFF856404),
      },
    ];

    return Column(
      children: approvedItems.map((item) => _buildApprovedItem(
        item['name'] as String,
        item['meta'] as String,
        item['status'] as String,
        item['statusColor'] as Color,
        item['textColor'] as Color,
      )).toList(),
    );
  }

  Widget _buildApprovedItem(String name, String meta, String status, Color statusColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
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
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineOverview() {
    return Column(
      children: [
        // Filter Bar
        Row(
          children: [
            _buildFilterButton('This Week', true),
            const SizedBox(width: 10),
            _buildFilterButton('This Month', false),
            const SizedBox(width: 10),
            _buildFilterButton('This Quarter', false),
          ],
        ),
        const SizedBox(height: 15),
        
        // Kanban Board
        _buildKanbanBoard(),
      ],
    );
  }

  Widget _buildFilterButton(String text, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF3498DB) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFCCC), style: BorderStyle.solid),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? Colors.white : const Color(0xFF7F8C8D),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildKanbanBoard() {
    final columns = [
      {
        'title': 'Draft',
        'items': ['NewVentures - Security', 'MedCorp - Compliance', 'TechStart - RFP'],
      },
      {
        'title': 'In Review',
        'items': ['GlobalTech - Cloud', 'FinServe - Agreement'],
      },
      {
        'title': 'Client Review',
        'items': ['Axis Corp - Services', 'DataCore - Implementation'],
      },
      {
        'title': 'Signed',
        'items': ['WebSolutions - Support', 'SoftWorks - Maintenance'],
      },
    ];

    return Row(
      children: columns.map((column) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFDDD), style: BorderStyle.solid)),
                  ),
                  child: Text(
                    column['title'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                ...(column['items'] as List<String>).map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCCC), style: BorderStyle.solid),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12),
                  ),
                )).toList(),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildPerformanceMetrics() {
    final metrics = [
      {'value': '24', 'label': 'Total Proposals'},
      {'value': '18', 'label': 'Signed Proposals'},
      {'value': '75%', 'label': 'Success Rate'},
      {'value': '\$350K', 'label': 'Total Value'},
      {'value': '7.2', 'label': 'Avg. Days to Sign'},
      {'value': '12%', 'label': 'Above Target'},
    ];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      metric['value']!,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      metric['label']!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7F8C8D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 15),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCCC), style: BorderStyle.solid),
          ),
          child: const Center(
            child: Text(
              'Performance Trends Chart (Would display here)',
              style: TextStyle(
                color: Color(0xFF7F8C8D),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserManagement() {
    final users = [
      {
        'name': 'Sarah Johnson',
        'role': 'Consultant • 5 proposals',
        'initials': 'SJ',
      },
      {
        'name': 'Michael Chen',
        'role': 'Senior Consultant • 8 proposals',
        'initials': 'MC',
      },
      {
        'name': 'Emily Wong',
        'role': 'Delivery Lead • 12 proposals',
        'initials': 'EW',
      },
    ];

    return Column(
      children: [
        ...users.map((user) => _buildUserItem(
          user['name'] as String,
          user['role'] as String,
          user['initials'] as String,
        )).toList(),
        const SizedBox(height: 10),
        Container(
          height: 1,
          color: const Color(0xFFEEE),
        ),
        const SizedBox(height: 15),
        _buildButton('+ Invite User', const Color(0xFF3498DB), false),
      ],
    );
  }

  Widget _buildUserItem(String name, String role, String initials) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFDDD), style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: const BoxDecoration(
                  color: Color(0xFF3498DB),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    role,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildButton('Edit', const Color(0xFF3498DB), true),
        ],
      ),
    );
  }
}
