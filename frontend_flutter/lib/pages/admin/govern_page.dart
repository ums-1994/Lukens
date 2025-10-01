import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';

class GovernPage extends StatelessWidget {
  const GovernPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.currentProposal;
    if (p == null) {
      return const Center(
          child: Text("Select a proposal to see readiness checks."));
    }
    final issues = List<String>.from(p["readiness_issues"] ?? []);
    final score = p["readiness_score"]?.toString() ?? "0";
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Readiness Score: $score%",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (issues.isEmpty)
            const Chip(label: Text("All mandatory sections complete")),
          if (issues.isNotEmpty) ...[
            const Text("Issues:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...issues
                .map((e) => ListTile(
                    leading: const Icon(Icons.error_outline), title: Text(e)))
                .toList(),
          ],
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.outgoing_mail),
              label: const Text("Submit for Internal Review"),
              onPressed: () async {
                final err = await app.submitForReview();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(err == null
                        ? "Submitted for review"
                        : "Blocked:\n$err"),
                    duration: const Duration(seconds: 3),
                  ));
                }
              },
            ),
          )
        ],
      ),
    );
  }
}
