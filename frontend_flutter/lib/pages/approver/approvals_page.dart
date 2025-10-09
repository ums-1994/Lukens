import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  List<dynamic> pendingProposals = [];
  bool isLoading = true;

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
      backgroundColor: const Color(0xFFF5F7F9),
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
        title: const Text('Approve Proposal'),
        content: TextField(
          controller: commentsCtrl,
          decoration: const InputDecoration(
            labelText: 'Comments (optional)',
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
              final error = await app.approveProposal(proposalId,
                  comments: commentsCtrl.text);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Proposal approved!'),
                      backgroundColor: Colors.green),
                );
                _loadPendingApprovals();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71)),
            child: const Text('Approve'),
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
      return const Center(
          child: Text("Select a proposal to manage approvals."));
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
