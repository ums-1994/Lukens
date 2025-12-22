import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api.dart';
import '../services/auth_service.dart';
import '../theme/premium_theme.dart';
import '../widgets/footer.dart';
import '../widgets/custom_scrollbar.dart';
import 'package:provider/provider.dart';

class FinanceDashboardPage extends StatefulWidget {
  const FinanceDashboardPage({Key? key}) : super(key: key);

  @override
  State<FinanceDashboardPage> createState() => _FinanceDashboardPageState();
}

class _FinanceDashboardPageState extends State<FinanceDashboardPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingProposals = [];
  List<Map<String, dynamic>> _approvedProposals = [];
  List<Map<String, dynamic>> _rejectedProposals = [];
  bool _isLoading = true;
  String? _selectedProposalId;
  Map<String, dynamic>? _selectedProposal;
  final TextEditingController _commentController = TextEditingController();
  bool _approvedExpanded = true;
  bool _rejectedExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    
    try {
      final token = AuthService.token;
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/finance/proposals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final proposals = List<Map<String, dynamic>>.from(data['proposals'] ?? []);

        _pendingProposals = proposals.where((p) {
          final status = (p['status'] ?? '').toString().toLowerCase();
          return status == 'pending finance approval';
        }).toList();

        _approvedProposals = proposals.where((p) {
          final status = (p['status'] ?? '').toString().toLowerCase();
          return status == 'finance approved';
        }).toList();

        _rejectedProposals = proposals.where((p) {
          final status = (p['status'] ?? '').toString().toLowerCase();
          return status == 'finance rejected';
        }).toList();
      }
    } catch (e) {
      print('Error loading finance data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFinanceAction(String action) async {
    if (_selectedProposalId == null) return;

    try {
      final token = AuthService.token;
      if (token == null) return;

      final isApprove = action == 'approved';
      final path = isApprove
          ? '/api/finance/proposals/${_selectedProposalId}/approve'
          : '/api/finance/proposals/${_selectedProposalId}/reject';

      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'reason': _commentController.text,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proposal ${action} successfully'),
            backgroundColor: action == 'approved' ? Colors.green : Colors.orange,
          ),
        );
        await _loadFinanceData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating proposal status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;
    
    final userRole = 'Finance';
    final userName = app.currentUser?['full_name'] ?? 'Finance User';

    return Scaffold(
      body: Container(
        color: Colors.transparent,
        child: Column(
          children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Finance Dashboard',
                        style: PremiumTheme.titleLarge.copyWith(fontSize: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/User_Profile.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userRole,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(width: 10),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'logout') {
                              app.logout();
                              AuthService.logout();
                              Navigator.pushNamed(context, '/login');
                            }
                          },
                          itemBuilder: (BuildContext context) => const [
                            PopupMenuItem<String>(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout),
                                  SizedBox(width: 8),
                                  Text('Logout'),
                                ],
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

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: PremiumTheme.teal))
                  : SingleChildScrollView(
                      controller: ScrollController(),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review proposals pending financial approval.',
                              style: PremiumTheme.bodyMedium.copyWith(
                                color: PremiumTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _buildProposalTable(_pendingProposals, 'Pending Financial Review', Colors.orange),
                            const SizedBox(height: 24),
                            _buildProposalTable(_approvedProposals, 'Approved Proposals', Colors.green),
                            const SizedBox(height: 24),
                            _buildProposalTable(_rejectedProposals, 'Rejected Proposals', Colors.red),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProposalTable(List<Map<String, dynamic>> proposals, String title, Color color) {
    if (proposals.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                title.contains('Pending') ? Icons.hourglass_empty : 
                title.contains('Approved') ? Icons.check_circle : 
                Icons.cancel,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No ${title.toLowerCase()} yet.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          DataTable(
            columns: const [
              DataColumn(label: Text('Proposal Name')),
              DataColumn(label: Text('Client')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Action')),
            ],
            rows: proposals.map((proposal) {
              final proposalName = proposal['title'] ?? 'Untitled';
              final clientName = proposal['client_name'] ?? proposal['client'] ?? 'Unknown';
              final status = proposal['status'] ?? 'Unknown';

              return DataRow(
                cells: [
                  DataCell(Text(proposalName)),
                  DataCell(Text(clientName)),
                  DataCell(_buildStatusBadge(status)),
                  DataCell(
                    ElevatedButton(
                      onPressed: () => _showProposalDetails(proposal),
                      child: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending_finance':
        color = Colors.orange;
        text = 'Pending Finance';
        icon = Icons.hourglass_empty;
        break;
      case 'approved':
      case 'finance_approved':
        color = Colors.green;
        text = 'Finance Approved';
        icon = Icons.check_circle;
        break;
      case 'rejected':
      case 'finance_rejected':
        color = Colors.red;
        text = 'Finance Rejected';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showProposalDetails(Map<String, dynamic> proposal) {
    setState(() {
      _selectedProposal = proposal;
      _selectedProposalId = proposal['id']?.toString();
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    proposal['title'] ?? 'Proposal Details',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client: ${proposal['client_name'] ?? proposal['client'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          labelText: 'Finance Comment',
                          hintText: 'Add comments about approval/rejection...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleFinanceAction('approved'),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleFinanceAction('rejected'),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
