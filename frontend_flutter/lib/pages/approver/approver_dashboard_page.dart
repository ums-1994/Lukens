import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../widgets/role_switcher.dart';
import '../../widgets/custom_scrollbar.dart';
import '../../theme/premium_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ApproverDashboardPage extends StatefulWidget {
  const ApproverDashboardPage({super.key});

  @override
  State<ApproverDashboardPage> createState() => _ApproverDashboardPageState();
}

class _ApproverDashboardPageState extends State<ApproverDashboardPage> {
  List<Map<String, dynamic>> _pendingProposals = [];
  List<Map<String, dynamic>> _recentlyApproved = [];
  bool _isLoading = true;
  int _pendingCount = 0;
  int _approvedCount = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Wait for next frame to ensure auth is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    print('🔄 Approver Dashboard: Loading data...');
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Force restore from localStorage
      print('🔄 Restoring session from storage...');
      AuthService.restoreSessionFromStorage();

      var token = AuthService.token;
      print('🔑 After restore - Token available: ${token != null}');
      print('🔑 After restore - User: ${AuthService.currentUser?['email']}');
      print('🔑 After restore - isLoggedIn: ${AuthService.isLoggedIn}');

      if (token == null) {
        print(
            '⚠️ Token still null after restore, checking localStorage directly...');
        // Check localStorage directly
        try {
          final data = html.window.localStorage['lukens_auth_session'];
          print('📦 localStorage data exists: ${data != null}');
          if (data != null) {
            print('📦 localStorage content: ${data.substring(0, 50)}...');
          }
        } catch (e) {
          print('❌ Error accessing localStorage: $e');
        }

        // Wait and retry
        await Future.delayed(const Duration(milliseconds: 500));
        token = AuthService.token;
      }

      if (token != null) {
        final preview = token.length > 20 ? token.substring(0, 20) : token;
        print('🔑 Token value: $preview...');
      }

      if (token == null) {
        print('❌ No token available after restoration attempts');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  '⚠️ Session expired. Please switch back to Creator mode.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _loadData(),
              ),
            ),
          );
        }
        return;
      }

      print('📡 Fetching proposals from API...');
      print('🌐 API URL: ${ApiService.baseUrl}/api/proposals');

      final proposals = await ApiService.getProposals(token).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ Timeout! API call took too long');
          throw Exception('Request timed out');
        },
      );

      print('✅ API Response received!');
      print('✅ Number of proposals: ${proposals.length}');
      print('✅ Proposals type: ${proposals.runtimeType}');

      if (proposals.isEmpty) {
        print('⚠️ WARNING: No proposals returned from API!');
      }

      // Debug: Print all proposal statuses
      print('\n📋 All Proposals:');
      for (var i = 0; i < proposals.length; i++) {
        final p = proposals[i];
        print('  [$i] Title: "${p['title']}"');
        print('      Status: "${p['status']}"');
        print('      ID: ${p['id']}');
        print('      User: ${p['user_id']}');
      }
      print('');

      // Filter for pending approval
      _pendingProposals = proposals
          .where((p) {
            final status = p['status'] as String?;
            print(
                '🔍 Checking proposal "${p['title']}" with status: [$status]');
            // Check exact match first, then case-insensitive
            return status == 'Pending CEO Approval' ||
                status?.toLowerCase() == 'pending ceo approval';
          })
          .map((p) => p as Map<String, dynamic>)
          .toList();

      print('⏳ Pending approvals found: ${_pendingProposals.length}');

      // Filter for recently approved/sent
      _recentlyApproved = proposals
          .where((p) {
            final status = (p['status'] as String?)?.toLowerCase() ?? '';
            return status == 'sent to client' || status == 'approved';
          })
          .take(5)
          .map((p) => p as Map<String, dynamic>)
          .toList();

      print('✅ Recently approved found: ${_recentlyApproved.length}');

      if (mounted) {
        setState(() {
          _pendingCount = _pendingProposals.length;
          _approvedCount = _recentlyApproved.length;
          _isLoading = false;
        });
        print('✅ State updated! Loading complete.');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading approver data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveProposal(int proposalId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Proposal'),
        content: Text(
            'Approve "$title"?\n\nThis will automatically send the proposal to the client.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
            ),
            child: const Text('Approve & Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = AuthService.token;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/proposals/$proposalId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal approved and sent to client!'),
              backgroundColor: Color(0xFF2ECC71),
            ),
          );
          _loadData(); // Refresh list
        }
      } else {
        throw Exception('Failed to approve proposal');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectProposal(int proposalId, String title) async {
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Proposal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject "$title"?'),
            const SizedBox(height: 12),
            const Text(
                'This will return the proposal to draft for the creator to make changes.'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Feedback (optional)',
                hintText: 'e.g., Please update the pricing section',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = AuthService.token;
      if (token == null) throw Exception('Not authenticated');

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/proposals/$proposalId/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'comments': commentController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proposal rejected and returned to creator'),
              backgroundColor: Color(0xFFF39C12),
            ),
          );
          _loadData(); // Refresh list
        }
      } else {
        throw Exception('Failed to reject proposal');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            // Header
            Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CEO Approval Dashboard',
                    style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
                  ),
                  Row(
                    children: [
                      // Role Switcher
                      const CompactRoleSwitcher(),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadData,
                        tooltip: 'Refresh',
                      ),
                      const SizedBox(width: 15),
                      // Notification Bell
                      Stack(
                        children: [
                          const Icon(Icons.notifications,
                              color: Colors.white, size: 24),
                          if (_pendingCount > 0)
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
                            child: Center(
                              child: Text(
                                (AuthService.currentUser?['email'] as String?)
                                        ?.substring(0, 2)
                                        .toUpperCase() ??
                                    'AP',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${AuthService.currentUser?['email'] ?? 'Approver'} - CEO',
                            style: const TextStyle(color: Colors.white),
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
            child: CustomScrollbar(
              controller: _scrollController,
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                  controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(right: 24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // My Approval Queue
                      _buildSection(
                        '📋 My Approval Queue ($_pendingCount pending)',
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _buildApprovalQueue(),
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
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ),

            // Footer
            Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  top: BorderSide(
                    color: PremiumTheme.glassWhiteBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  'Khonology Proposal & SOW Builder | Approver Dashboard',
                  style: PremiumTheme.bodyMedium.copyWith(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return GlassContainer(
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: PremiumTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildApprovalQueue() {
    if (_pendingProposals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 48, color: Color(0xFF2ECC71)),
              SizedBox(height: 12),
              Text(
                'No proposals pending approval',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF7F8C8D),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _pendingProposals.map((proposal) {
        final submittedBy = proposal['user_id'] ?? 'Unknown';
        final createdAt = proposal['created_at'] != null
            ? DateTime.parse(proposal['created_at'])
            : DateTime.now();
        final daysAgo = DateTime.now().difference(createdAt).inDays;

        return _buildApprovalItem(
          proposal['id'],
          proposal['title'] ?? 'Untitled',
          proposal['client_name'] ?? 'No client',
          'Submitted by: $submittedBy • ${daysAgo == 0 ? "Today" : "$daysAgo days ago"}',
        );
      }).toList(),
    );
  }

  Widget _buildApprovalItem(int id, String name, String client, String meta) {
    return InkWell(
      onTap: () {
        print('📄 Opening proposal for viewing:');
        print('   ID: $id');
        print('   Title: $name');
        print('   Arguments: ${{
          'proposalId': id.toString(),
          'proposalTitle': name,
          'readOnly': true
        }}');

        // Navigate to view the proposal
        Navigator.pushNamed(
          context,
          '/blank-document',
          arguments: {
            'proposalId': id.toString(),
            'proposalTitle': name,
            'readOnly': true, // View-only mode for approver
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PremiumTheme.orange.withOpacity(0.15),
              PremiumTheme.orange.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PremiumTheme.orange.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pending,
                          size: 16, color: Color(0xFFF39C12)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: PremiumTheme.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: PremiumTheme.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: Color(0xFF7F8C8D)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🏢 $client',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 4),
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
                _buildButton(
                  'Approve',
                  const Color(0xFF2ECC71),
                  false,
                  () => _approveProposal(id, name),
                ),
                const SizedBox(width: 10),
                _buildButton(
                  'Reject',
                  const Color(0xFFE74C3C),
                  true,
                  () => _rejectProposal(id, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
      String text, Color color, bool isOutline, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isOutline ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isOutline ? color : Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
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
        _buildMetricCard(
            'Pending My Approval', _pendingCount.toString(), 'Proposals'),
        _buildMetricCard(
            'Recently Approved', _approvedCount.toString(), 'This Month'),
        _buildMetricCard('Approval Rate', '85%', 'This Month'),
        _buildMetricCard('Avg. Response Time', '1.5', 'Days'),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle) {
    final gradients = {
      'Pending My Approval': PremiumTheme.orangeGradient,
      'Recently Approved': PremiumTheme.tealGradient,
      'Approval Rate': PremiumTheme.blueGradient,
      'Avg. Response Time': PremiumTheme.purpleGradient,
    };
    
    return PremiumStatCard(
      title: title,
      value: value,
      subtitle: subtitle,
      gradient: gradients[title] ?? PremiumTheme.blueGradient,
    );
  }

  Widget _buildRecentlyApproved() {
    if (_recentlyApproved.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No recently approved proposals',
            style: TextStyle(color: Color(0xFF7F8C8D)),
          ),
        ),
      );
    }

    return Column(
      children: _recentlyApproved.map((proposal) {
        final updatedAt = proposal['updated_at'] != null
            ? DateTime.parse(proposal['updated_at'])
            : DateTime.now();

        return _buildApprovedItem(
          proposal['title'] ?? 'Untitled',
          'Approved: ${_formatDate(updatedAt)}',
          proposal['status'] == 'Sent to Client'
              ? 'Sent to Client'
              : 'Approved',
          const Color(0xFFC3E6CB),
          const Color(0xFF155724),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildApprovedItem(String name, String meta, String status,
      Color statusColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumTheme.glassWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PremiumTheme.glassWhiteBorder,
          width: 1,
        ),
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
