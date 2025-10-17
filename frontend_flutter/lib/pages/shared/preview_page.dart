import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';

class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.currentProposal;
    if (p == null) {
      return const Center(child: Text("Select a proposal to preview."));
    }
    final sections = Map<String, dynamic>.from(p["sections"] ?? {});
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(p["title"],
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("${p["dtype"]} for ${p["client"]}"),
          const Divider(),
          // Export PDF & Request e-sign buttons handled here
          const SizedBox(height: 8),
          ...sections.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(e.value?.toString() ?? ""),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
