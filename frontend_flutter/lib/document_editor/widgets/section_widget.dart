import 'package:flutter/material.dart';
import '../models/document_section.dart';
import '../models/document_table.dart';
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

  final void Function(int oldIndex, int newIndex) onReorderBlocks;
  final Widget Function(int tableIndex, DocumentTable table)
      buildInteractiveTable;
  final void Function(String imageId) onRemoveInlineImage;

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
    required this.onReorderBlocks,
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
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
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
              ReorderableListView(
                padding: EdgeInsets.zero,
                primary: false,
                buildDefaultDragHandles: false,
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                onReorder: onReorderBlocks,
                children: section.blockOrder.map((blockKey) {
                  if (blockKey == 'text') {
                    return KeyedSubtree(
                      key: const ValueKey('section-text-block'),
                      child: TextField(
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
                    );
                  }

                  if (blockKey.startsWith('table:')) {
                    final tableId = blockKey.substring('table:'.length);
                    final tableIndex =
                        section.tables.indexWhere((t) => t.id == tableId);
                    if (tableIndex == -1) {
                      return SizedBox.shrink(
                          key: ValueKey('missing-$blockKey'));
                    }
                    final table = section.tables[tableIndex];

                    return KeyedSubtree(
                      key: ValueKey('table-${table.id}'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReorderableDragStartListener(
                            index: section.blockOrder.indexOf(blockKey),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 20, right: 8),
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          Expanded(
                            child: buildInteractiveTable(tableIndex, table),
                          ),
                        ],
                      ),
                    );
                  }

                  if (blockKey.startsWith('image:')) {
                    final imageId = blockKey.substring('image:'.length);
                    final imageIndex = section.inlineImages
                        .indexWhere((img) => img.id == imageId);
                    if (imageIndex == -1) {
                      return SizedBox.shrink(
                          key: ValueKey('missing-$blockKey'));
                    }
                    final image = section.inlineImages[imageIndex];
                    return KeyedSubtree(
                      key: ValueKey('image-${image.id}'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReorderableDragStartListener(
                            index: section.blockOrder.indexOf(blockKey),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 12, right: 8),
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ImageWidget(
                              image: image,
                              onRemove: () => onRemoveInlineImage(imageId),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SizedBox.shrink(key: ValueKey('unknown-$blockKey'));
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
