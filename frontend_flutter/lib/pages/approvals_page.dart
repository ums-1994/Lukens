import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.currentProposal;
    if (p == null) {
      return const Center(child: Text("Select a proposal to manage approvals."));
    }
    final status = p["status"];
    final approvals = Map<String, dynamic>.from(p["approval"]["approvals"] ?? {});
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Status: $status", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, children: [
            _stageChip(context, "Delivery", approvals["Delivery"] != null),
            _stageChip(context, "Legal", approvals["Legal"] != null),
            _stageChip(context, "Exec", approvals["Exec"] != null),
          ]),
          const Spacer(),
          if (status == "Released") SignPanel(),
        ],
      ),
    );
  }

  Widget _stageChip(BuildContext context, String stage, bool approved) {
    final app = context.read<AppState>();
    return InputChip(
      label: Text("$stage ${approved ? "✓" : ""}"),
      onPressed: approved ? null : () async {
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
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Signer Name (Client)")),
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
