import 'package:flutter/material.dart';
import '../../../widgets/custom_scrollbar.dart';
import '../models/document_models.dart';

class DocumentArea extends StatefulWidget {
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
  State<DocumentArea> createState() => _DocumentAreaState();
}

class _DocumentAreaState extends State<DocumentArea> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) {
      if (widget.readOnly) {
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
              onPressed: widget.onAddSection,
              icon: const Icon(Icons.add),
              label: const Text('Add Section'),
            ),
          ],
        ),
      );
    }

    return CustomScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(32),
        itemCount: widget.sections.length + (widget.readOnly ? 0 : 1), // Add one extra item for the "Add Section" button
        itemBuilder: (context, index) {
          // Show "Add Section" button at the top (index 0)
          if (!widget.readOnly && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                onPressed: widget.onAddSection,
                icon: const Icon(Icons.add),
                label: const Text('Add New Section'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            );
          }
          
          // Adjust index for sections (subtract 1 if button is shown)
          final sectionIndex = widget.readOnly ? index : index - 1;
          
          // Safety check to prevent index out of bounds
          if (sectionIndex < 0 || sectionIndex >= widget.sections.length) {
            return const SizedBox.shrink();
          }
          
          final section = widget.sections[sectionIndex];
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
                    enabled: !widget.readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Section title',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        widget.onTitleChanged?.call(sectionIndex, value.trim()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: section.content,
                    enabled: !widget.readOnly,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) =>
                        widget.onContentChanged?.call(sectionIndex, value),
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.onInsertFromLibrary != null)
                          TextButton.icon(
                            onPressed: () => widget.onInsertFromLibrary!(sectionIndex),
                            icon: const Icon(Icons.library_books_outlined),
                            label: const Text('Insert from Library'),
                          ),
                        const SizedBox(width: 8),
                        if (widget.onDeleteSection != null)
                          TextButton.icon(
                            onPressed: () {
                              // Show confirmation dialog before deleting
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Section'),
                                  content: Text(
                                    'Are you sure you want to delete "${section.title}"? This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onDeleteSection!(sectionIndex);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
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
      ),
    );
  }
}

