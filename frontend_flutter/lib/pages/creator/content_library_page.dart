import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';

class ContentLibraryPage extends StatefulWidget {
  const ContentLibraryPage({super.key});

  @override
  State<ContentLibraryPage> createState() => _ContentLibraryPageState();
}

class _ContentLibraryPageState extends State<ContentLibraryPage> {
  final keyCtrl = TextEditingController();
  final labelCtrl = TextEditingController();
  final contentCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Content Library",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: keyCtrl,
                        decoration:
                            const InputDecoration(labelText: "Key (unique)"))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: labelCtrl,
                        decoration: const InputDecoration(labelText: "Label"))),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: () async {
                      // create new block
                      try {
                        await app.createContent(keyCtrl.text.trim(),
                            labelCtrl.text.trim(), contentCtrl.text.trim());
                        keyCtrl.clear();
                        labelCtrl.clear();
                        contentCtrl.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Content created")));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("Failed to create content: $e")));
                      }
                    },
                    child: const Text("Create")),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
                controller: contentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Content")),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: app.contentBlocks.length,
                itemBuilder: (ctx, i) {
                  final b = app.contentBlocks[i];
                  return ListTile(
                    title: Text(b["label"] ?? b["key"]),
                    subtitle: Text((b["content"] ?? "").toString(),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          icon: const Icon(Icons.add_box_outlined),
                          onPressed: () async {
                            if (app.currentProposal == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("Select a proposal first")));
                              return;
                            }
                            await app.addContentToProposal(b["id"]);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Added to proposal")));
                          }),
                      IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            try {
                              await app.deleteContent(b["id"]);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Deleted")));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Delete failed: $e")));
                            }
                          }),
                    ]),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
