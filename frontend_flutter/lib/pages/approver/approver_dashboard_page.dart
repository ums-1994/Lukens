import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
// Direct page imports for navigation without named routes
import 'reviewer_proposals_page.dart';
import 'comments_feedback_page.dart';
import 'approval_history_page.dart';
import 'governance_checks_page.dart';

class ApproverDashboardPage extends StatefulWidget {
  const ApproverDashboardPage({super.key});

  @override
  State<ApproverDashboardPage> createState() => _ApproverDashboardPageState();
}

class _ApproverDashboardPageState extends State<ApproverDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = context.read<AppState>();
      a.fetchReviewerApprovals();
      a.fetchAdminMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
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
                    'Proposal & SOW Builder - Approver Dashboard',
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
                        child: Padding(
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
                            'John Doe - Approver',
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
          
          // Main Content
          Expanded(
            child: Row(
              children: [
                // Sidebar
                Container(
                  width: 250,
                  color: const Color(0xFF34495E),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Title
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Text(
                            'Reviewer / Approver',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildApproverNavItem('📊', 'Dashboard', true),
                        _buildApproverNavItem('📋', 'Proposals for Review', false),
                        _buildApproverNavItem('💬', 'Comments & Feedback', false),
                        _buildApproverNavItem('✅', 'Approval History', false),
                        _buildApproverNavItem('🔍', 'Governance Checks', false),
                        const SizedBox(height: 20), // Add bottom padding
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
                          // My Approval Queue
                          _buildSection(
                            '📋 My Approval Queue',
                            _buildApprovalQueue(context, app),
                          ),
                          const SizedBox(height: 20),
                          
                          // My Approval Metrics
                          _buildSection(
                            '📈 My Approval Metrics',
                            _buildApproverMetrics(app),
                          ),
                          const SizedBox(height: 20),
                          // Reviewer Performance (per reviewer approved/rejected counts)
                          _buildSection(
                            '🏅 Reviewer Performance',
                            _buildReviewerPerformance(app),
                          ),
                          const SizedBox(height: 20),
                          
                          // Recently Approved
                          _buildSection(
                            '⏰ Recently Approved',
                            _buildRecentlyApproved(),
                          ),
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
                'Khonology Proposal & SOW Builder | Approver Dashboard',
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

  Widget _buildApproverNavItem(String icon, String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF5DADE2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          // Use direct routes to avoid any named route/context issues
          if (label == 'Proposals for Review') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReviewerProposalsPage()),
            );
          } else if (label == 'Comments & Feedback') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CommentsFeedbackPage()),
            );
          } else if (label == 'Approval History') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ApprovalHistoryPage()),
            );
          } else if (label == 'Governance Checks') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GovernanceChecksPage()),
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : const Color(0xFF7F8C8D),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: TextStyle(
                      fontSize: 14,
                      color: isActive ? const Color(0xFF34495E) : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isActive ? const Color(0xFF2C3E50) : Colors.white,
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    // Badge for open comments (optional)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildApprovalQueue(BuildContext context, AppState app) {
    final items = app.reviewerApprovals;
    if (items.isEmpty) {
      return const Text('No proposals pending your review', style: TextStyle(color: Color(0xFF7F8C8D)));
    }
    return Column(
      children: items.map((p) {
        final name = (p['title'] ?? 'Untitled').toString();
        final meta = 'Client: ${(p['client'] ?? 'N/A')} • Status: ${(p['status'] ?? '')}';
        final id = (p['id'] ?? '').toString();
        return _buildApprovalItem(context, app, id, name, meta);
      }).toList(),
    );
  }

  Widget _buildApprovalItem(BuildContext context, AppState app, String id, String name, String meta) {
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
              GestureDetector(
                onTap: () async {
                  await app.reviewerApprove(id, reviewerId: 'reviewer-1');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
                },
                child: _buildButton('Approve', const Color(0xFF3498DB), false),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  await app.reviewerReject(id, reviewerId: 'reviewer-1');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected')));
                },
                child: _buildButton('Reject', const Color(0xFFE74C3C), false),
              ),
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

  // -------- Metrics --------
  Widget _buildApproverMetrics(AppState app) {
    final m = app.adminMetrics;
    final pending = (m['pending'] ?? 0).toString();
    final avgSec = (m['avg_response_time_seconds'] ?? 0).toString();
    final totalReviewed = (m['total_reviewed'] ?? 0).toString();
    final openComments = (m['open_comments'] ?? 0).toString();
    final flagged = (m['flagged_count'] ?? 0).toString();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildMetricCard('Pending My Approval', pending, 'Proposals'),
        _buildMetricCard('Avg. Response Time', avgSec, 'Seconds'),
        _buildMetricCard('Total Reviewed', totalReviewed, 'Proposals'),
        _buildMetricCard('Open Comments', openComments, 'Unresolved'),
        _buildMetricCard('Flagged Proposals', flagged, 'Need Review'),
      ],
    );
  }

  Widget _buildReviewerPerformance(AppState app) {
    final stats = Map<String, dynamic>.from(app.adminMetrics['reviewer_stats'] ?? {});
    if (stats.isEmpty) {
      return const Text('No reviewer activity yet', style: TextStyle(color: Color(0xFF7F8C8D)));
    }
    final rows = stats.entries.map((e) {
      final rid = e.key;
      final m = Map<String, dynamic>.from(e.value as Map);
      final approved = (m['approved'] ?? 0).toString();
      final rejected = (m['rejected'] ?? 0).toString();
      return DataRow(cells: [
        DataCell(Text(rid)),
        DataCell(Text(approved)),
        DataCell(Text(rejected)),
      ]);
    }).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(columns: const [
        DataColumn(label: Text('Reviewer')),
        DataColumn(label: Text('Approved')),
        DataColumn(label: Text('Rejected')),
      ], rows: rows),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle) {
    return Container(
      width: 260,
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
}
