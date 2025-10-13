import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';

class ComposePage extends StatelessWidget {
  const ComposePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.currentProposal;
    if (p == null) {
      return const Center(
          child: Text("Select or create a proposal on the Dashboard."));
    }
    final sections = Map<String, dynamic>.from(p["sections"] ?? {});
    final ctrls = {
      for (final e in sections.entries)
        e.key: TextEditingController(text: e.value?.toString() ?? "")
    };
    // AI Assist inputs
    final providerCtrl = ValueNotifier<String>('ollama');
    final modelCtrl = TextEditingController(text: 'llama3.1');
    final scopeCtrl = TextEditingController();
    final constraintsCtrl = TextEditingController();
    final assumptionsCtrl = TextEditingController();
    final risksCtrl = TextEditingController();
    final isBusy = ValueNotifier<bool>(false);
    // AI Chat state
    final chatMessages = ValueNotifier<List<Map<String, String>>>([]);
    final chatCtrl = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${p["title"]} • ${p["client"]} • ${p["dtype"]}",
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // AI Chat Panel
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: Column(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<List<Map<String, String>>>(
                            valueListenable: chatMessages,
                            builder: (context, msgs, _) {
                              if (msgs.isEmpty) {
                                return const Center(
                                  child: Text('Start a conversation about your proposal…'),
                                );
                              }
                              return ListView.builder(
                                itemCount: msgs.length,
                                itemBuilder: (context, i) {
                                  final m = msgs[i];
                                  final isUser = m['role'] == 'user';
                                  return Align(
                                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isUser ? Colors.blue.shade600 : Colors.grey.shade800,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        m['content'] ?? '',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: chatCtrl,
                                minLines: 1,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Ask about this proposal…',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<bool>(
                              valueListenable: isBusy,
                              builder: (context, busy, _) {
                                return IconButton(
                                  icon: const Icon(Icons.send),
                                  color: Colors.blue,
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final q = chatCtrl.text.trim();
                                          if (q.isEmpty) return;
                                          chatCtrl.clear();
                                          chatMessages.value = [...chatMessages.value, {
                                            'role': 'user',
                                            'content': q,
                                          }];
                                          isBusy.value = true;
                                          try {
                                            final reply = await app.aiChat(
                                              provider: providerCtrl.value,
                                              model: modelCtrl.text.trim().isEmpty ? null : modelCtrl.text.trim(),
                                              messages: [
                                                // Optional system primer to ground to proposal context
                                                {
                                                  'role': 'system',
                                                  'content': 'You are an assistant for drafting proposals and SOWs. Be concise and practical.'
                                                },
                                                ...chatMessages.value,
                                              ],
                                            );
                                            chatMessages.value = [...chatMessages.value, {
                                              'role': 'assistant',
                                              'content': reply,
                                            }];
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Chat error: $e')),
                                            );
                                          } finally {
                                            isBusy.value = false;
                                          }
                                        },
                                );
                              },
                            )
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // AI Assist Panel
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Assist',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: providerCtrl,
                        builder: (context, prov, _) {
                          return DropdownButton<String>(
                            value: prov,
                            items: const [
                              DropdownMenuItem(value: 'ollama', child: Text('Ollama')),
                              DropdownMenuItem(value: 'gemini', child: Text('Gemini')),
                            ],
                            onChanged: (v) {
                              if (v != null) providerCtrl.value = v;
                              if (v == 'gemini') {
                                modelCtrl.text = 'gemini-1.5-flash';
                              } else {
                                modelCtrl.text = 'llama3.1';
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 240,
                        child: TextField(
                          controller: modelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: isBusy,
                        builder: (context, busy, _) {
                          return ElevatedButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    isBusy.value = true;
                                    try {
                                      final scope = scopeCtrl.text
                                          .split('\n')
                                          .where((e) => e.trim().isNotEmpty)
                                          .toList();
                                      final cons = constraintsCtrl.text
                                          .split('\n')
                                          .where((e) => e.trim().isNotEmpty)
                                          .toList();
                                      final assm = assumptionsCtrl.text
                                          .split('\n')
                                          .where((e) => e.trim().isNotEmpty)
                                          .toList();
                                      final risk = risksCtrl.text
                                          .split('\n')
                                          .where((e) => e.trim().isNotEmpty)
                                          .toList();

                                      final content = await app.aiGenerateSow(
                                        provider: providerCtrl.value,
                                        model: modelCtrl.text.trim().isEmpty
                                            ? null
                                            : modelCtrl.text.trim(),
                                        title: p['title'] ?? '',
                                        client: p['client'] ?? '',
                                        scopePoints: scope,
                                        constraints: cons,
                                        assumptions: assm,
                                        risks: risk,
                                      );

                                      // Insert into sections
                                      final updates = <String, String>{};
                                      if ((sections['Scope & Deliverables'] ?? '').toString().trim().isEmpty) {
                                        updates['Scope & Deliverables'] = content;
                                      }
                                      if ((sections['Executive Summary'] ?? '').toString().trim().isEmpty) {
                                        updates['Executive Summary'] = content;
                                      }
                                      if (updates.isEmpty) {
                                        // else append to Scope
                                        final prev = (sections['Scope & Deliverables'] ?? '').toString();
                                        updates['Scope & Deliverables'] =
                                            (prev.isEmpty ? '' : (prev + '\n\n')) + content;
                                      }
                                      await app.updateSections(updates);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('AI content inserted')),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('AI error: $e')),
                                      );
                                    } finally {
                                      isBusy.value = false;
                                    }
                                  },
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Generate SOW'),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _aiMultiline('Scope points (one per line)', scopeCtrl),
                  const SizedBox(height: 8),
                  _aiMultiline('Constraints (one per line)', constraintsCtrl),
                  const SizedBox(height: 8),
                  _aiMultiline('Assumptions (one per line)', assumptionsCtrl),
                  const SizedBox(height: 8),
                  _aiMultiline('Risks (one per line)', risksCtrl),
                ],
              ),
            ),
          ),
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
                        Text(k,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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

// Helper widget for AI Assist multi-line inputs
Widget _aiMultiline(String label, TextEditingController c) {
  return TextField(
    controller: c,
    maxLines: 3,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}
