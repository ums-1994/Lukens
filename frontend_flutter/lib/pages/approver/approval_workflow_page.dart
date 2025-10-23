import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class ApprovalWorkflowPage extends StatefulWidget {
  const ApprovalWorkflowPage({Key? key}) : super(key: key);

  @override
  State<ApprovalWorkflowPage> createState() => _ApprovalWorkflowPageState();
}

class _ApprovalWorkflowPageState extends State<ApprovalWorkflowPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingApprovals = [];
  List<dynamic> _approvalHistory = [];
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final currentUser = AuthService.currentUser;
      final userId = currentUser?['username'] ?? 'admin';

      // Load pending approvals, history, and analytics in parallel
      final results = await Future.wait([
        ApiService.getPendingApprovals(token, userId),
        ApiService.getProposalApprovalRequests(token, 'all'), // Get all for history
        ApiService.getApprovalAnalytics(token),
      ]);

      setState(() {
        _pendingApprovals = results[0] as List<dynamic>;
        _approvalHistory = results[1] as List<dynamic>;
        _analytics = results[2] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Approval Workflow',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: 'Pending',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'History',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Analytics',
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingApprovalsTab(),
                    _buildHistoryTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsTab() {
    if (_pendingApprovals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            Text(
              'No Pending Approvals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'All caught up! No approval requests waiting for your review.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingApprovals.length,
        itemBuilder: (context, index) {
          final approval = _pendingApprovals[index];
          return _buildApprovalCard(approval, isPending: true);
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_approvalHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No Approval History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Approval history will appear here once you start reviewing proposals.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _approvalHistory.length,
        itemBuilder: (context, index) {
          final approval = _approvalHistory[index];
          return _buildApprovalCard(approval, isPending: false);
        },
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_analytics == null) {
      return const Center(
        child: Text('No analytics data available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsCard(
            title: 'Overview',
            children: [
              _buildStatItem(
                'Total Requests',
                _analytics!['total_requests']?.toString() ?? '0',
                Icons.assignment,
                Colors.blue,
              ),
              _buildStatItem(
                'Pending',
                _analytics!['pending_requests']?.toString() ?? '0',
                Icons.pending,
                Colors.orange,
              ),
              _buildStatItem(
                'Approved',
                _analytics!['approved_requests']?.toString() ?? '0',
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatItem(
                'Rejected',
                _analytics!['rejected_requests']?.toString() ?? '0',
                Icons.cancel,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnalyticsCard(
            title: 'Performance',
            children: [
              _buildStatItem(
                'Approval Rate',
                '${((_analytics!['approval_rate'] ?? 0) * 100).toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.green,
              ),
              _buildStatItem(
                'Avg. Time',
                '${_analytics!['average_approval_time_hours']?.toString() ?? '0'}h',
                Icons.access_time,
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> approval, {required bool isPending}) {
    final status = approval['status'] ?? 'pending';
    final stage = approval['stage'] ?? 'Unknown';
    final priority = approval['priority'] ?? 'medium';
    final comments = approval['comments'] ?? '';
    final dueDate = approval['due_date'];
    final requestedAt = approval['requested_at'] ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    Color priorityColor;
    switch (priority) {
      case 'urgent':
        priorityColor = Colors.red;
        break;
      case 'high':
        priorityColor = Colors.orange;
        break;
      case 'medium':
        priorityColor = Colors.blue;
        break;
      case 'low':
        priorityColor = Colors.grey;
        break;
      default:
        priorityColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stage: $stage',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (comments.isNotEmpty) ...[
              Text(
                'Comments: $comments',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Requested: ${_formatDate(requestedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (dueDate != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(dueDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            if (isPending && status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _takeAction(approval['id'], 'approve'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _takeAction(approval['id'], 'reject'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _sendReminder(approval['id']),
                    icon: const Icon(Icons.notifications_active),
                    tooltip: 'Send Reminder',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Future<void> _takeAction(String requestId, String action) async {
    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${action.capitalize()} Approval Request'),
          content: Text('Are you sure you want to $action this approval request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: action == 'approve' ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(action.capitalize()),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await ApiService.takeApprovalAction(
        token: token,
        requestId: requestId,
        action: action,
        actionTakenBy: AuthService.currentUser?['username'] ?? 'unknown',
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approval request ${action}d successfully'),
            backgroundColor: action == 'approve' ? Colors.green : Colors.red,
          ),
        );
        _loadData(); // Refresh data
      } else {
        throw Exception('Failed to $action approval request');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendReminder(String requestId) async {
    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final result = await ApiService.sendApprovalReminder(
        token: token,
        requestId: requestId,
      );

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to send reminder');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
