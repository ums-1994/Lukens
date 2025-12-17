import 'package:flutter/material.dart';

class ToolbarControls extends StatelessWidget {
  final String selectedAlignment;
  final ValueChanged<String> onAlignmentChanged;
  final VoidCallback onInsertBulletList;
  final VoidCallback onInsertNumberedList;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertFromLibrary;
  final VoidCallback onOpenAIAssistant;

  const ToolbarControls({
    super.key,
    required this.selectedAlignment,
    required this.onAlignmentChanged,
    required this.onInsertBulletList,
    required this.onInsertNumberedList,
    required this.onInsertTable,
    required this.onInsertFromLibrary,
    required this.onOpenAIAssistant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Alignment
          IconButton(
            icon: Icon(
              Icons.format_align_left,
              color:
                  selectedAlignment == 'left' ? const Color(0xFF00BCD4) : null,
            ),
            onPressed: () => onAlignmentChanged('left'),
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Left',
          ),
          IconButton(
            icon: Icon(
              Icons.format_align_center,
              color: selectedAlignment == 'center'
                  ? const Color(0xFF00BCD4)
                  : null,
            ),
            onPressed: () => onAlignmentChanged('center'),
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Center',
          ),
          IconButton(
            icon: Icon(
              Icons.format_align_right,
              color:
                  selectedAlignment == 'right' ? const Color(0xFF00BCD4) : null,
            ),
            onPressed: () => onAlignmentChanged('right'),
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Right',
          ),

          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),

          // Lists
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: onInsertBulletList,
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Bullet List',
          ),
          IconButton(
            icon: const Icon(Icons.format_list_numbered),
            onPressed: onInsertNumberedList,
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Numbered List',
          ),

          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),

          // Insert
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: onInsertTable,
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Insert Table',
          ),
          IconButton(
            icon: const Icon(Icons.library_add),
            onPressed: onInsertFromLibrary,
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Insert from Content Library',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: onOpenAIAssistant,
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'AI Assistant',
          ),
        ],
      ),
    );
  }
}
