import 'package:flutter/material.dart';
import '../models/document_section.dart';
import '../models/document_table.dart';
import '../models/inline_image.dart';
import 'image_widget.dart';

class SectionWidget extends StatelessWidget {
  final DocumentSection section;
  final bool isHovered;
  final bool isSelected;
  final bool readOnly;
  final bool canDelete;

  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;
  final VoidCallback onInsertBelow;
  final VoidCallback onInsertFromLibrary;
  final VoidCallback onShowAIAssistant;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  final TextStyle Function() getContentTextStyle;
  final TextAlign Function() getTextAlignment;

  final void Function(int oldIndex, int newIndex) onReorderTables;
  final Widget Function(int tableIndex, DocumentTable table)
      buildInteractiveTable;
  final void Function(int imageIndex) onRemoveInlineImage;

  const SectionWidget({
    super.key,
    required this.section,
    required this.isHovered,
    required this.isSelected,
    required this.readOnly,
    required this.canDelete,
    required this.onHoverChanged,
    required this.onTap,
    required this.onInsertBelow,
    required this.onInsertFromLibrary,
    required this.onShowAIAssistant,
    required this.onDuplicate,
    required this.onDelete,
    required this.getContentTextStyle,
    required this.getTextAlignment,
    required this.onReorderTables,
    required this.buildInteractiveTable,
    required this.onRemoveInlineImage,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFF00BCD4) : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? const Color(0xFF00BCD4).withValues(alpha: 0.03)
                : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isHovered)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          section.titleController.text.isEmpty
                              ? 'Section title'
                              : section.titleController.text,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Insert section below',
                          child: IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                                width: 28, height: 28),
                            onPressed: onInsertBelow,
                          ),
                        ),
                        Tooltip(
                          message: 'AI Assistant',
                          child: IconButton(
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                                width: 28, height: 28),
                            onPressed: onShowAIAssistant,
                          ),
                        ),
                        Tooltip(
                          message: 'Insert from content library',
                          child: IconButton(
                            icon: const Icon(Icons.library_add, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                                width: 28, height: 28),
                            onPressed: onInsertFromLibrary,
                          ),
                        ),
                        Tooltip(
                          message: 'Duplicate section',
                          child: IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                                width: 28, height: 28),
                            onPressed: onDuplicate,
                          ),
                        ),
                        Tooltip(
                          message: 'Delete section',
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                                width: 28, height: 28),
                            onPressed: canDelete ? onDelete : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              // Editable section title above content
              TextField(
                focusNode: section.titleFocus,
                controller: section.titleController,
                enabled: !readOnly,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Section title (e.g., Cover Letter)',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  isDense: true,
                ),
                onChanged: (value) {
                  section.title = value;
                },
              ),
              const SizedBox(height: 4),
              // Clean content area - text field for writing
              TextField(
                focusNode: section.contentFocus,
                controller: section.controller,
                maxLines: null,
                minLines: 15,
                enabled: !readOnly, // Disable editing in read-only mode
                style: getContentTextStyle(),
                textAlign: getTextAlignment(),
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: readOnly
                      ? '' // No hint in read-only mode
                      : 'Start writing your content here...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFBDC3C7),
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(8),
                ),
              ),
              // Display tables below text (with drag and drop)
              if (section.tables.isNotEmpty)
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: onReorderTables,
                  children: section.tables.asMap().entries.map((entry) {
                    final tableIndex = entry.key;
                    final table = entry.value;
                    return buildInteractiveTable(tableIndex, table);
                  }).toList(),
                )
              else
                const SizedBox.shrink(),
              // Display images below tables
              ...section.inlineImages.asMap().entries.map((entry) {
                final imageIndex = entry.key;
                final InlineImage image = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ImageWidget(
                    image: image,
                    onRemove: () => onRemoveInlineImage(imageIndex),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
