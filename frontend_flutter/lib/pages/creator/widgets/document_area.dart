import 'package:flutter/material.dart';

import '../models/document_models.dart';

class DocumentArea extends StatelessWidget {
  final List<DocumentSection> sections;
  final bool readOnly;
  final void Function(int index, String title)? onTitleChanged;
  final void Function(int index, String content)? onContentChanged;
  final void Function(int index)? onDeleteSection;
  final void Function(int index)? onInsertFromLibrary;
  final VoidCallback? onAddSection;

  const DocumentArea({
    super.key,
    required this.sections,
    required this.readOnly,
    this.onTitleChanged,
    this.onContentChanged,
    this.onDeleteSection,
    this.onInsertFromLibrary,
    this.onAddSection,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      if (readOnly) {
        return const Center(
          child: Text(
            'No content yet.\nStart by adding sections to your document.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'No content yet.\nStart by adding sections to your document.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddSection,
              icon: const Icon(Icons.add),
              label: const Text('Add Section'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 24),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: section.title,
                  enabled: !readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Section title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      onTitleChanged?.call(index, value.trim()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: section.content,
                  enabled: !readOnly,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (value) =>
                      onContentChanged?.call(index, value),
                ),
                if (!readOnly) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onInsertFromLibrary != null)
                        TextButton.icon(
                          onPressed: () => onInsertFromLibrary!(index),
                          icon: const Icon(Icons.library_books_outlined),
                          label: const Text('Insert from Library'),
                        ),
                      const SizedBox(width: 8),
                      if (onDeleteSection != null)
                        TextButton.icon(
                          onPressed: () => onDeleteSection!(index),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete Section'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

