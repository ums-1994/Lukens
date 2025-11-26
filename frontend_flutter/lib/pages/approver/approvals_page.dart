import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/proposal_selector.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  List<dynamic> pendingProposals = [];
  bool isLoading = true;
  bool _showingAnalysis = false;

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    final app = context.read<AppState>();
    final userRole = app.currentUser?['role'] ?? '';

    if (userRole == 'CEO') {
      final proposals = await app.getPendingApprovals();
      setState(() {
        pendingProposals = proposals;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final userRole = app.currentUser?['role'] ?? '';

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userRole == 'CEO') {
      return _buildCEOApprovalView();
    } else {
      return _buildLegacyApprovalView();
    }
  }

  Widget _buildCEOApprovalView() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Pending CEO Approvals'),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
      ),
      body: pendingProposals.isEmpty
          ? const Center(
              child: Text(
                'No proposals pending approval',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: pendingProposals.length,
              itemBuilder: (context, index) {
                final proposal = pendingProposals[index];
                return _buildProposalCard(proposal);
              },
            ),
    );
  }

  Widget _buildProposalCard(Map<String, dynamic> proposal) {
    final app = context.read<AppState>();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              proposal['title'] ?? 'Untitled',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Client: ${proposal['client'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'Status: ${proposal['status']}',
              style: const TextStyle(color: Color(0xFF3498DB)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text('Reject'),
                  onPressed: () => _showRejectDialog(proposal['id']),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _showApproveDialog(proposal['id']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showApproveDialog(String proposalId) {
    final commentsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & Send to Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will approve the proposal and send it to the client via email.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
          controller: commentsCtrl,
          decoration: const InputDecoration(
            labelText: 'Comments (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  content: SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              );
              
              final app = context.read<AppState>();
              final error = await app.approveProposal(proposalId,
                  comments: commentsCtrl.text);
              
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop(); // Close loading
                
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                        content: Text('✅ Proposal approved and email sent to client!'),
                      backgroundColor: Colors.green),
                );
                  // Reload pending approvals and refresh data
                _loadPendingApprovals();
                  await app.fetchProposals();
                  await app.fetchDashboard();
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71)),
            child: const Text('Approve & Send to Client'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String proposalId) {
    final commentsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Proposal'),
        content: TextField(
          controller: commentsCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final app = context.read<AppState>();
              final error = await app.rejectProposal(proposalId,
                  comments: commentsCtrl.text);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Proposal rejected'),
                      backgroundColor: Colors.orange),
                );
                _loadPendingApprovals();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyApprovalView() {
    final app = context.watch<AppState>();
    final p = app.currentProposal;
    if (p == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ProposalSelector(
            title: 'Select a proposal to manage approvals',
            description:
                'Choose a draft or sent proposal to unlock governance and risk checks.',
            onSelect: _handleProposalSelected,
            onRunRiskGate: _runRiskGate,
          ),
        ),
      );
    }
    final status = p["status"];
    final approvals =
        Map<String, dynamic>.from(p["approval"]["approvals"] ?? {});
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Status: $status",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, children: [
            _stageChip(context, "Delivery", approvals["Delivery"] != null),
            _stageChip(context, "Legal", approvals["Legal"] != null),
            _stageChip(context, "Exec", approvals["Exec"] != null),
          ]),
          const Spacer(),
          if (status == "Released" || status == "Sent to Client") SignPanel(),
        ],
      ),
    );
  }

  void _handleProposalSelected(Map<String, dynamic> proposal) {
    final app = context.read<AppState>();
    app.selectProposal(Map<String, dynamic>.from(proposal));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${proposal['title'] ?? 'proposal'}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _runRiskGate(Map<String, dynamic> proposal) async {
    if (_showingAnalysis) return;
    final appState = context.read<AppState>();
    String? token = AuthService.token ?? appState.authToken;
    final proposalId = _parseProposalId(proposal['id']);

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No auth token available. Please log in again.'),
        ),
      );
      return;
    }
    if (proposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal ID missing')),
      );
      return;
    }

    setState(() => _showingAnalysis = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    Map<String, dynamic>? result;
    try {
      result = await ApiService.analyzeRisks(
        token: token,
        proposalId: proposalId,
      );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _showingAnalysis = false);
      }
    }

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risk analysis failed')),
      );
      return;
    }

    _showRiskResult(result, proposal);
  }

  int? _parseProposalId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _showRiskResult(
      Map<String, dynamic> payload, Map<String, dynamic> proposal) {
    final score = payload['risk_score'] ?? 0;
    final level = (payload['overall_risk_level'] ?? 'unknown').toString();
    final canRelease = payload['can_release'] == true;
    final issues = List<Map<String, dynamic>>.from(
        payload['issues'] is List ? payload['issues'] : []);
    final summary = payload['summary'] ??
        payload['ai_summary']?['summary'] ??
        payload['precheck_summary']?['summary'] ??
        'Review completed.';
    final requiredActions = List<String>.from(
        payload['required_actions'] is List ? payload['required_actions'] : []);
    
    // Check proposal status
    final proposalStatus = (proposal['status'] ?? 'draft').toString().toLowerCase();
    final isDraft = proposalStatus == 'draft' || proposalStatus.isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Risk Gate • ${proposal['title'] ?? 'Proposal'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      backgroundColor: Colors.white12,
                      label: Text(
                        'Risk score: $score/100',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      backgroundColor: canRelease
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      label: Text(
                        canRelease ? 'Can release' : 'Blocked',
                        style: TextStyle(
                          color: canRelease ? Colors.greenAccent : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      backgroundColor: Colors.white12,
                      label: Text(
                        'Level: ${level.toUpperCase()}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  summary,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                if (issues.isNotEmpty) ...[
                  const Text(
                    'Detected signals',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...issues.map((issue) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.bolt,
                          color: _severityColor(
                              (issue['severity'] ?? 'low').toString()),
                        ),
                        title: Text(
                          issue['description'] ?? 'Issue detected',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: issue['recommendation'] != null
                            ? Text(
                                issue['recommendation'],
                                style: const TextStyle(color: Colors.white70),
                              )
                            : null,
                      )),
                ],
                if (requiredActions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Required actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...requiredActions.map(
                    (action) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline,
                          color: Colors.white70),
                      title: Text(
                        action,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Show proposal status warning if not draft
                if (!isDraft) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current status: ${proposal['status'] ?? 'Unknown'}\nOnly proposals in "draft" status can be sent for approval.',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (canRelease && isDraft)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send, size: 20),
                        label: const Text('Review & Send to CEO for Approval'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _sendToCEOForApproval(proposal);
                        },
                      )
                    else if (canRelease && !isDraft)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.info_outline, size: 20),
                        label: const Text('Proposal Not in Draft'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please use a proposal in "draft" status. Create a new proposal to send for approval.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        },
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 20),
                        label: const Text('Review Proposal'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to proposal editor or show message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please fix the issues before approving.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendToCEOForApproval(Map<String, dynamic> proposal) async {
    final proposalId = _parseProposalId(proposal['id']);
    if (proposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid proposal ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final app = context.read<AppState>();
      final error = await app.sendForApproval(proposalId.toString());
      
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading
        
        if (error != null) {
          // Show detailed error message with helpful suggestion
          final errorMsg = error.contains('already') || error.contains('Cannot send')
              ? '⚠️ This proposal cannot be sent for approval.\n\nReason: ${error.contains("Current status") ? error.split("Current status:")[1].split(".")[0].trim() : "Proposal is not in draft status"}\n\n💡 Solution: Create a new draft proposal or use a proposal that is still in "draft" status.'
              : error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Create New',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushNamed(context, '/proposals');
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal sent to CEO for approval!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          // Reload data to reflect status change
          await app.fetchProposals();
          await app.updateDashboardCountsWithPending();
          await app.fetchDashboard();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveAndSendToClient(
      Map<String, dynamic> proposal) async {
    final proposalId = _parseProposalId(proposal['id']);
    if (proposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid proposal ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & Send to Client'),
        content: Text(
            'Are you sure you want to approve "${proposal['title'] ?? 'this proposal'}" and send it to the client?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
            ),
            child: const Text('Approve & Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final app = context.read<AppState>();
      final error = await app.approveProposal(proposalId.toString());
      
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading
        
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proposal approved and sent to client!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          // Reload pending approvals
          _loadPendingApprovals();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.redAccent;
      case 'high':
        return Colors.deepOrangeAccent;
      case 'medium':
        return Colors.amberAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }

  Widget _stageChip(BuildContext context, String stage, bool approved) {
    final app = context.read<AppState>();
    return InputChip(
      label: Text("$stage ${approved ? "✓" : ""}"),
      onPressed: approved
          ? null
          : () async {
              await app.approveStage(stage);
            },
    );
  }
}

class SignPanel extends StatefulWidget {
  @override
  State<SignPanel> createState() => _SignPanelState();
}

class _SignPanelState extends State<SignPanel> {
  final ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(labelText: "Signer Name (Client)")),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.draw_outlined),
          label: const Text("Client Sign-Off"),
          onPressed: () async {
            final err = await app.signOff(ctrl.text);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err ?? "Signed successfully"),
              duration: const Duration(seconds: 3),
            ));
          },
        ),
      ],
    );
  }
}
