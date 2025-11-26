import 'package:flutter/material.dart';

/// Standalone mixin that manages a simple in‑memory list of comments and
/// builds the comments panel UI.
mixin CommentsPanelMixin<T extends StatefulWidget> on State<T> {
  final TextEditingController _commentController = TextEditingController();
  final List<_Comment> _comments = <_Comment>[];

  void initCommentsPanel() {
    // No-op for now – placeholder for future initialization.
  }

  void disposeCommentsPanel() {
    _commentController.dispose();
  }

  Widget buildCommentsPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add a comment...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () {
              final text = _commentController.text.trim();
              if (text.isEmpty) return;
              setState(() {
                _comments.insert(
                  0,
                  _Comment(
                    text: text,
                    createdAt: DateTime.now(),
                  ),
                );
                _commentController.clear();
              });
            },
            icon: const Icon(Icons.add_comment, size: 16),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _comments.isEmpty
              ? const Center(
                  child: Text(
                    'No comments yet.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final c = _comments[index];
                    return ListTile(
                      dense: true,
                      title: Text(c.text),
                      subtitle: Text(
                        _formatTimestamp(c.createdAt),
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Comment {
  final String text;
  final DateTime createdAt;

  _Comment({
    required this.text,
    required this.createdAt,
  });
}



