# Blank Document Editor Widget

## 1. Where the widgets are (file paths)

| Widget / Class | File path (relative to repo root) | What it does |
|----------------|-----------------------------------|--------------|
| `BlankDocumentEditorPage` | `frontend_flutter/lib/pages/creator/blank_document_editor_page.dart` | Main editor page that renders A4 pages, header, toolbar, and sidebars |
| `DocumentSection` | `frontend_flutter/lib/document_editor/models/document_section.dart` | Data model for one page/section (title, content, background, tables, images) |
| `SectionWidget` | `frontend_flutter/lib/document_editor/widgets/section_widget.dart` | UI for a single editable section (title, content, hover toolbar, tables, images) |
| `SectionsSidebar` | `frontend_flutter/lib/document_editor/widgets/sections_sidebar.dart` | Left sidebar listing all sections with navigation |
| `Footer` | `frontend_flutter/lib/widgets/footer.dart` | Global footer widget (copyright, branding) |

---

## 2. Where the “blank document widget” lives

The “blank document” experience in your app is composed of a few key pieces:

- **Page widget (full editor)**  
  `frontend_flutter/lib/pages/creator/blank_document_editor_page.dart`  
  Class: `BlankDocumentEditorPage` (+ its private state class)

- **Section model (one page/section of the document)**  
  `frontend_flutter/lib/document_editor/models/document_section.dart`  
  Class: `DocumentSection`

- **Section UI widget (the editable block/page)**  
  `frontend_flutter/lib/document_editor/widgets/section_widget.dart`  
  Class: `SectionWidget`

- **Sections sidebar (list of all pages/sections)**  
  `frontend_flutter/lib/document_editor/widgets/sections_sidebar.dart`  
  Class: `SectionsSidebar`

- **Footer widget (global footer)**  
  `frontend_flutter/lib/widgets/footer.dart`  
  Class: `Footer`

If you share those files/classes, the other team will have what they need to enhance the blank document editor.

---

## 3. Core code for the blank document widget

### 3.1 Section model (`DocumentSection`)

```dart
import 'package:flutter/material.dart';

import 'inline_image.dart';
import 'document_table.dart';

class DocumentSection {
  String title;
  String content;
  final TextEditingController controller;
  final TextEditingController titleController;
  final FocusNode contentFocus;
  final FocusNode titleFocus;
  Color backgroundColor;
  String? backgroundImageUrl;
  String sectionType; // 'cover', 'content', 'appendix', etc.
  bool isCoverPage;
  List<InlineImage> inlineImages; // Inline content images (not backgrounds)
  List<DocumentTable> tables; // Tables in this section

  DocumentSection({
    required this.title,
    required this.content,
    this.backgroundColor = Colors.white,
    this.backgroundImageUrl,
    this.sectionType = 'content',
    this.isCoverPage = false,
    List<InlineImage>? inlineImages,
    List<DocumentTable>? tables,
  })  : controller = TextEditingController(text: content),
        titleController = TextEditingController(text: title),
        contentFocus = FocusNode(),
        titleFocus = FocusNode(),
        inlineImages = inlineImages ?? [],
        tables = tables ?? [];
}
```

---

### 3.2 Section UI (`SectionWidget`)

This is the main “blank document section” widget: title, body text, tables, inline images, and action toolbar.

```dart
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
```

---

### 3.3 Sections sidebar (`SectionsSidebar`)

```dart
import 'package:flutter/material.dart';
import '../models/document_section.dart';

/// Sidebar listing all sections in the current document.
///
/// This widget is stateless; selection changes and focus handling are
/// delegated back to the parent via [onSectionTap].
class SectionsSidebar extends StatelessWidget {
  const SectionsSidebar({
    super.key,
    required this.sections,
    required this.selectedSectionIndex,
    required this.onSectionTap,
  });

  final List<DocumentSection> sections;
  final int selectedSectionIndex;
  final ValueChanged<int> onSectionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sections',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sections.length} section${sections.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: sections.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                final section = sections[index];
                final bool isSelected = selectedSectionIndex == index;

                final String fullText = section.controller.text;
                final String snippet;
                if (fullText.isEmpty) {
                  snippet = 'Empty section';
                } else {
                  final firstLine = fullText.split('\n').first;
                  snippet = firstLine.length > 40
                      ? firstLine.substring(0, 40)
                      : firstLine;
                }

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSectionTap(index),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00BCD4).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFF00BCD4),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    section.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF00BCD4)
                                          : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Section type badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: section.isCoverPage
                                        ? const Color(0xFF00BCD4)
                                            .withValues(alpha: 0.1)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    section.sectionType == 'cover'
                                        ? 'Cover'
                                        : section.sectionType == 'appendix'
                                            ? 'Appendix'
                                            : section.sectionType ==
                                                    'references'
                                                ? 'Refs'
                                                : 'Page',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: section.isCoverPage
                                          ? const Color(0xFF00BCD4)
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              snippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### 2.4 How the page renders “blank document” A4 sections

These are the key methods from `BlankDocumentEditorPageState` that drive the blank document UI.

```dart
// In _BlankDocumentEditorPageState

@override
Widget build(BuildContext context) {
  // Check if proposal is archived - if so, make it read-only
  final isArchived = _proposalStatus?.toLowerCase() == 'archived';
  final isReadOnly = widget.readOnly || isArchived;

  // In collaborator mode, hide navigation sidebar but allow editing
  final isCollaboratorMode = widget.isCollaborator;

  return Scaffold(
    backgroundColor: const Color(0xFFF5F5F5),
    body: Row(
      children: [
        // Left Sidebar (hide in read-only mode AND collaborator mode)
        if (!isReadOnly && !isCollaboratorMode) _buildLeftSidebar(),
        // Sections Sidebar (conditional)
        if (!isReadOnly && !isCollaboratorMode && _showSectionsSidebar)
          _buildSectionsSidebar(),
        // Main content
        Expanded(
          child: _currentPage == 'Governance & Risk'
              ? _buildGovernanceRiskView()
              : Column(
                  children: [
                    // Top header
                    _buildTopHeader(),
                    // Formatting toolbar
                    if (!isReadOnly) _buildToolbar(),
                    // Main document area
                    Expanded(
                      child: Row(
                        children: [
                          // Center content
                          Expanded(
                            child: Stack(
                              children: [
                                SingleChildScrollView(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 40,
                                        vertical: 50,
                                      ),
                                      child: Column(
                                        children: [
                                          // Generate A4 pages
                                          ..._buildA4Pages(),
                                          // Plus button to add new page
                                          const SizedBox(height: 24),
                                          _buildAddPageButton(),
                                          const SizedBox(height: 40),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Right sidebars, comments, etc...
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}

/// Build each A4-size page from the _sections list.
List<Widget> _buildA4Pages() {
  const double pageWidth = 900;
  const double pageHeight = 1273; // A4 aspect ratio

  return List.generate(
    _sections.length,
    (index) {
      final section = _sections[index];
      return Container(
        width: pageWidth,
        constraints: const BoxConstraints(
          minHeight: 600,
          maxHeight: pageHeight,
        ),
        margin: const EdgeInsets.only(bottom: 32),
        decoration: BoxDecoration(
          color: section.backgroundImageUrl == null
              ? section.backgroundColor
              : Colors.white,
          image: section.backgroundImageUrl != null
              ? DecorationImage(
                  image: NetworkImage(section.backgroundImageUrl!),
                  fit: BoxFit.cover,
                  opacity: 0.7,
                )
              : null,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(60),
                child: _buildSectionContent(index),
              ),
            ),
            // Page number indicator
            Positioned(
              bottom: 20,
              right: 60,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100]!.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  'Page ${index + 1} of ${_sections.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Floating "+" button below the pages to add a new blank page.
Widget _buildAddPageButton() {
  return Center(
    child: Column(
      children: [
        InkWell(
          onTap: () {
            final newSection = DocumentSection(
              title: 'Untitled Section',
              content: '',
            );
            setState(() {
              _sections.add(newSection);
              _selectedSectionIndex = _sections.length - 1;

              // Attach listeners for autosave & UI updates
              newSection.controller.addListener(_onContentChanged);
              newSection.titleController.addListener(_onContentChanged);
              newSection.contentFocus.addListener(() => setState(() {}));
              newSection.titleFocus.addListener(() => setState(() {}));
            });
          },
          customBorder: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00BCD4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Add New Page',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    ),
  );
}

/// Wire one DocumentSection into the SectionWidget.
Widget _buildSectionContent(int index) {
  final section = _sections[index];
  final isHovered = _hoveredSectionIndex == index;
  final isSelected = _selectedSectionIndex == index;

  return SectionWidget(
    section: section,
    isHovered: isHovered,
    isSelected: isSelected,
    readOnly: widget.readOnly,
    canDelete: _sections.length > 1,
    onHoverChanged: (hovered) {
      setState(() {
        _hoveredSectionIndex = hovered ? index : -1;
      });
    },
    onTap: () {
      setState(() => _selectedSectionIndex = index);
    },
    onInsertBelow: () => _insertSection(index),
    onInsertFromLibrary: () {
      setState(() {
        _selectedSectionIndex = index;
      });
      _addFromLibrary();
    },
    onShowAIAssistant: () {
      setState(() {
        _selectedSectionIndex = index;
      });
      _showAIAssistantDialog();
    },
    onDuplicate: () => _duplicateSection(index),
    onDelete: () => _deleteSection(index),
    getContentTextStyle: _getContentTextStyle,
    getTextAlignment: _getTextAlignment,
    onReorderTables: (int oldIndex, int newIndex) {
      setState(() {
        if (newIndex > oldIndex) newIndex -= 1;
        final table = section.tables.removeAt(oldIndex);
        section.tables.insert(newIndex, table);
      });
    },
    buildInteractiveTable: (int tableIndex, DocumentTable table) =>
        _buildInteractiveTable(
      index,
      tableIndex,
      table,
      key: ValueKey('table_${index}_$tableIndex'),
    ),
    onRemoveInlineImage: (imageIndex) {
      setState(() {
        _sections[index].inlineImages.removeAt(imageIndex);
      });
    },
  );
}
```

---

### 3.5 Header widget (`_buildTopHeader`)

The header is part of the blank editor page. It shows the document title, price, and save status.

```dart
Widget _buildTopHeader() {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Row(
      children: [
        // Title and badge
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit,
                          size: 16, color: Color(0xFF00BCD4)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          enabled: !widget
                              .readOnly, // Disable editing in read-only mode
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                          decoration: InputDecoration(
                            hintText: widget.readOnly
                                ? '' // No hint in read-only mode
                                : 'Click to edit document title...',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFBDC3C7),
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // View Only badge (show in read-only mode)
              if (widget.readOnly) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF39C12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.visibility, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'View Only',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Price
        Row(
          children: [
            Text(
              '${_getCurrencySymbol()} ',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  // Price value input - ready for future use
                  setState(() {});
                },
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                      color: Color(0xFF00BCD4),
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Save status with version info
        GestureDetector(
          onTap: _showVersionHistory,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isSaving
                  ? Colors.blue.withOpacity(0.1)
                  : (_hasUnsavedChanges
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isSaving
                    ? Colors.blue
                    : (_hasUnsavedChanges ? Colors.orange : Colors.green),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status icon + text added here in full code
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

### 3.6 Footer widget (`Footer`)

The `Footer` widget renders a global site footer that can be reused on landing or editor pages.

**Location:**

```text
frontend_flutter/lib/widgets/footer.dart
```

**Code:**

```dart
class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        border: Border(top: BorderSide(color: Color(0x22333B53))),
      ),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD1D5DB),
                  fontSize: 12,
                ),
            children: const [
              TextSpan(text: '© 2025 made with '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  Icons.favorite,
                  size: 14,
                  color: Color(0xFFE11D48),
                ),
              ),
              TextSpan(
                text: '  by the Khonology Team. Digitizing Africa.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Usage:**

- Place `const Footer()` at the bottom of a page’s `Column` or inside a `Scaffold` body/footer area.
- It is purely presentational and does not manage any state.

---

## 4. How it all works (for documentation)

### 4.1 Data model

- **`DocumentSection`**
  - **Fields**:
    - **`title` / `titleController`**: text and controller for the page/section title.
    - **`content` / `controller`**: main body content and controller.
    - **FocusNodes**: `titleFocus`, `contentFocus` for focus‑driven UI.
    - **Layout**: `backgroundColor`, `backgroundImageUrl`, `sectionType`, `isCoverPage`.
    - **Rich content**: `inlineImages` (list of `InlineImage`), `tables` (list of `DocumentTable`).
  - **Lifecycle**: controllers and focus nodes are created in the constructor; the editor page is responsible for disposing them when sections are removed or the page is destroyed.

### 4.2 UI structure

- **`BlankDocumentEditorPage`**
  - Top‑level `Scaffold` with:
    - Optional left navigation sidebar.
    - Optional sections sidebar (`SectionsSidebar`).
    - Center area with:
      - Header (`_buildTopHeader`).
      - Formatting toolbar (`_buildToolbar`).
      - Scrollable stack of A4 “pages” built by `_buildA4Pages()`.
      - Floating “Add New Page” button (`_buildAddPageButton()`).
    - Right side: risk/governance panel and comments/collaboration panels (not shown above).

- **A4 pages (`_buildA4Pages`)**
  - For each `DocumentSection` in `_sections`, build a fixed‑width A4‑style card:
    - Background color or image from `DocumentSection`.
    - Inner padding (60px) with `_buildSectionContent(index)` → `SectionWidget`.
    - Page number indicator at bottom right.

- **Section widget (`SectionWidget`)**
  - Hover toolbar:
    - **Insert below**: triggers `_insertSection(index)` in the page.
    - **AI assistant**: opens AI dialog for that section.
    - **Insert from content library**: opens content library insertion.
    - **Duplicate**: clones the section.
    - **Delete**: removes section (if allowed).
  - Title `TextField` bound to `section.titleController`.
  - Content `TextField` bound to `section.controller`:
    - Styling and alignment driven by callbacks from the page (`_getContentTextStyle`, `_getTextAlignment`).
  - Tables and inline images are rendered below the text.

- **Sections sidebar (`SectionsSidebar`)**
  - Receives the same `_sections` list and the index of the currently selected section.
  - Shows:
    - Section title.
    - Type badge (Cover / Appendix / Refs / Page).
    - First line snippet or “Empty section”.
  - Clicking a row calls `onSectionTap(index)` so the parent can update `_selectedSectionIndex`.

### 4.3 Behaviour & interactions

- **Creating a new blank document**
  - In `initState`, if there’s no existing proposal and no AI‑generated content:
    - Create one `DocumentSection(title: 'Untitled Section', content: '')`.
    - Attach listeners for autosave and UI updates.

- **Adding a new blank page**
  - Clicking the round “Add New Page” button:
    - Instantiates another `DocumentSection(title: 'Untitled Section', content: '')`.
    - Appends it to `_sections`.
    - Attaches listeners for autosave and focus.

- **Loading / saving**
  - When opening an existing proposal, `_loadProposalFromDatabase`:
    - Parses JSON, builds `DocumentSection` instances from saved data.
  - Autosave/versioning logic listens to controllers and writes back JSON including sections.

- **Formatting**
  - Text style and alignment are controlled centrally in the page by `_getContentTextStyle` and `_getTextAlignment`, based on UI state such as `_selectedTextStyle`, `_selectedFont`, `_selectedAlignment`.

---

## 5. How to extend / enhance it

Here are concrete extension points you can mention in the documentation:

- **Add new section actions**
  - **Where**: `SectionWidget` action toolbar + `_buildSectionContent`.
  - **How**:
    - Add a new `VoidCallback` prop to `SectionWidget`.
    - Wire it from `_buildSectionContent` to whatever new behaviour you want (e.g. “Insert pricing table”, “Generate summary with AI”).

- **Add new formatting options**
  - **Where**: `_selectedTextStyle`, `_selectedFont`, `_selectedFontSize`, `_selectedAlignment` and their toolbar; `_getContentTextStyle`, `_getTextAlignment`.
  - **How**:
    - Extend the toolbar to set new style state.
    - Update `_getContentTextStyle` to apply new fonts/sizes/styles.
    - `SectionWidget` will automatically pick up new styles via its callbacks.

- **Change page size / layout**
  - **Where**: `_buildA4Pages`.
  - **How**:
    - Adjust `pageWidth`, `pageHeight`, margins and `Padding` to change the layout (e.g. smaller preview, different aspect ratio).

- **Add new visual metadata on pages**
  - **Where**: `DocumentSection` (add fields) + `_buildA4Pages` / `SectionWidget`.
  - **How**:
    - Add new fields to `DocumentSection` (e.g. `watermarkText`, `headerText`).
    - Render them either in the A4 container (e.g. header/footer) or inside `SectionWidget`.

---

## 6. Summary

- **Code to share**:  
  - `BlankDocumentEditorPage` (especially `build`, `_buildA4Pages`, `_buildSectionContent`, `_buildAddPageButton`).  
  - `DocumentSection`, `SectionWidget`, `SectionsSidebar`, `Footer`.

- **Conceptual model**:  
  - The blank document is a list of `DocumentSection` models, each rendered as an A4‑style page using `SectionWidget`, with sidebars and tools around it.

If you tell me how “deep” the other team wants the code (just UI, or including autosave/governance/comments), I can trim this down to a smaller self‑contained example or expand it to include the full page class.
