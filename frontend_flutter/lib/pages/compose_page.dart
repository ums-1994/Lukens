import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';

class ComposePage extends StatelessWidget {
  const ComposePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.currentProposal;
    if (p == null) {
      return const Center(child: Text("Select or create a proposal on the Dashboard."));
    }
    final sections = Map<String, dynamic>.from(p["sections"] ?? {});
    final ctrls = { for (final e in sections.entries) e.key : TextEditingController(text: e.value?.toString() ?? "") };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${p["title"]} • ${p["client"]} • ${p["dtype"]}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: sections.keys.map((k) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: ctrls[k],
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: "Enter content...",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () async {
                              await app.updateSections({k: ctrls[k]!.text});
                            },
                            child: const Text("Save Section"),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
