import 'package:flutter/material.dart';
import 'content_library_dialog.dart';

class BlankDocumentEditorPage extends StatefulWidget {
  final String? proposalId;
  final String? proposalTitle;

  const BlankDocumentEditorPage({
    super.key,
    this.proposalId,
    this.proposalTitle,
  });

  @override
  State<BlankDocumentEditorPage> createState() =>
      _BlankDocumentEditorPageState();
}

class _BlankDocumentEditorPageState extends State<BlankDocumentEditorPage> {
  late TextEditingController _titleController;
  bool _isSaving = false;
  DateTime? _lastSaved;
  List<_DocumentSection> _sections = [];
  int _hoveredSectionIndex = -1;
  String _selectedPanel = 'templates'; // templates, build, upload, signature
  int _selectedSectionIndex =
      0; // Track which section is selected for content insertion
  String _selectedCurrency = 'Rand (ZAR)';
  List<String> _uploadedImages = [];
  String _signatureSearchQuery = '';
  String _uploadTabSelected = 'this_document'; // 'this_document' or 'library'
  bool _showSectionsSidebar = false; // Toggle sections sidebar visibility
  List<String> _signatures = [
    'Client Signature',
    'Authorized By',
    'Manager Approval'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.proposalTitle ?? 'Untitled Template',
    );
    // Create initial section
    _sections.add(_DocumentSection(
      title: 'Untitled Section',
      content: '',
    ));
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var section in _sections) {
      section.controller.dispose();
      section.titleController.dispose();
      section.contentFocus.dispose();
      section.titleFocus.dispose();
    }
    super.dispose();
  }

  void _insertSection(int afterIndex) {
    setState(() {
      _sections.insert(
        afterIndex + 1,
        _DocumentSection(
          title: 'Untitled Section',
          content: '',
        ),
      );
    });
  }

  void _deleteSection(int index) {
    if (_sections.length > 1) {
      setState(() {
        _sections[index].controller.dispose();
        _sections[index].titleController.dispose();
        _sections.removeAt(index);
      });
    }
  }

  void _createSnippet(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Snippet created from "${_sections[index].title}"'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInsertSectionMenu(int afterIndex, Offset globalOffset) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalOffset.dx,
        globalOffset.dy,
        globalOffset.dx + 1,
        globalOffset.dy + 1,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'blank',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_box_outlined, size: 18, color: Color(0xFF1A3A52)),
              SizedBox(width: 10),
              Text('Blank Section'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'library',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_add_outlined,
                  size: 18, color: Color(0xFF1A3A52)),
              SizedBox(width: 10),
              Text('Add from Library'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'blank') {
        _insertSection(afterIndex);
      } else if (value == 'library') {
        _addFromLibrary();
      }
    });
  }

  void _addFromLibrary() {
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ContentLibrarySelectionDialog(),
    ).then((selectedModule) {
      if (selectedModule != null && _selectedSectionIndex < _sections.length) {
        // Insert the selected library content into the current section
        final content = selectedModule['content'] ?? '';
        final title = selectedModule['title'] ?? 'Library Content';
        final isUrl =
            content.startsWith('http://') || content.startsWith('https://');

        final currentSection = _sections[_selectedSectionIndex];
        setState(() {
          // Add library content to the current section's content
          String textToInsert = content;
          if (isUrl) {
            // If it's a URL (like a document), add it as a reference link
            textToInsert = '[📎 Document: $title]($content)';
          }

          if (currentSection.controller.text.isEmpty) {
            currentSection.controller.text = textToInsert;
          } else {
            currentSection.controller.text += '\n\n$textToInsert';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Added "${isUrl ? 'Document: ' : ''}$title" to section'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  String _getCurrencySymbol() {
    final currencyMap = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'ZAR': 'R',
      'JPY': '¥',
      'CNY': '¥',
      'INR': '₹',
      'AUD': 'A\$',
      'CAD': 'C\$',
    };

    // Extract currency code from string like "Rand (ZAR)"
    final regex = RegExp(r'\(([A-Z]{3})\)');
    final match = regex.firstMatch(_selectedCurrency);
    if (match != null) {
      final code = match.group(1);
      return currencyMap[code] ?? '\$';
    }
    return '\$';
  }

  Future<void> _saveDocument() async {
    setState(() => _isSaving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _lastSaved = DateTime.now());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // Left Sidebar
          _buildLeftSidebar(),
          // Sections Sidebar (conditional)
          if (_showSectionsSidebar) _buildSectionsSidebar(),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top header
                _buildTopHeader(),
                // Formatting toolbar
                _buildToolbar(),
                // Main document area
                Expanded(
                  child: Row(
                    children: [
                      // Center content
                      Expanded(
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 40,
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
                            // Floating toolbar on right
                            Positioned(
                              right: 20,
                              top: 0,
                              bottom: 0,
                              child: _buildFloatingToolbar(),
                            ),
                          ],
                        ),
                      ),
                      // Right sidebar
                      _buildRightSidebar(),
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

  Widget _buildLeftSidebar() {
    return Container(
      width: 80,
      color: const Color(0xFF1A3A52),
      child: Column(
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const Divider(color: Color(0xFF2C3E50), height: 1),
          // Navigation icons
          Expanded(
            child: Column(
              children: [
                _buildNavIcon(Icons.home, 'Home'),
                _buildNavIcon(Icons.star, 'Favorites'),
                _buildNavIcon(Icons.folder, 'Documents'),
                _buildNavIcon(Icons.people, 'Team'),
                _buildNavIcon(Icons.trending_up, 'Analytics'),
                _buildNavIcon(Icons.settings, 'Settings'),
              ],
            ),
          ),
          // Bottom logout icon
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildNavIcon(Icons.logout, 'Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          icon,
          color: Colors.white54,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSectionsSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[200]!, width: 1)),
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
                  '${_sections.length} section${_sections.length != 1 ? 's' : ''}',
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
              itemCount: _sections.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                bool isSelected = _selectedSectionIndex == index;
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedSectionIndex = index;
                        });
                        _sections[index].contentFocus.requestFocus();
                      },
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
                            Text(
                              _sections[index].title,
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
                            const SizedBox(height: 4),
                            Text(
                              _sections[index].controller.text.isEmpty
                                  ? 'Empty section'
                                  : _sections[index]
                                      .controller
                                      .text
                                      .split('\n')
                                      .first
                                      .substring(
                                        0,
                                        (_sections[index]
                                                    .controller
                                                    .text
                                                    .split('\n')
                                                    .first
                                                    .length >
                                                40)
                                            ? 40
                                            : _sections[index]
                                                .controller
                                                .text
                                                .split('\n')
                                                .first
                                                .length,
                                      ),
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
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Untitled Template',
                      hintStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFBDC3C7),
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Template',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
          Text(
            _lastSaved == null ? 'Not Saved' : 'Saved',
            style: TextStyle(
              fontSize: 13,
              color: _lastSaved == null ? Colors.orange : Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 32),
          // Sections toggle button
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _showSectionsSidebar = !_showSectionsSidebar);
            },
            icon: const Icon(Icons.list, size: 16),
            label: const Text('Sections'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _showSectionsSidebar
                    ? const Color(0xFF00BCD4)
                    : Colors.grey,
              ),
              foregroundColor: _showSectionsSidebar
                  ? const Color(0xFF00BCD4)
                  : Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Action buttons
          TextButton(
            onPressed: () {},
            child: const Text(
              'Submit feedback',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveDocument,
            icon: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : const Icon(Icons.save, size: 16),
            label: const Text('Generate Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline),
            iconSize: 20,
            tooltip: 'Help',
          ),
          const SizedBox(width: 12),
          // User initials
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                'LS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          // Sections button
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.layers, size: 16),
            label: const Text('Sections'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Undo/Redo
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {},
            tooltip: 'Undo',
            iconSize: 18,
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () {},
            tooltip: 'Redo',
            iconSize: 18,
            splashRadius: 20,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Style dropdown
          _buildSmallDropdown(
              'Normal Text', ['Normal Text', 'Heading 1', 'Heading 2']),
          const SizedBox(width: 8),
          // Font dropdown
          _buildSmallDropdown('Plus Jakarta Sans',
              ['Plus Jakarta Sans', 'Arial', 'Times New Roman']),
          const SizedBox(width: 8),
          // Font size dropdown
          _buildSmallDropdown(
              '12px', ['10px', '12px', '14px', '16px', '18px', '20px']),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Text formatting
          IconButton(
            icon: const Icon(Icons.format_bold),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Bold',
          ),
          IconButton(
            icon: const Icon(Icons.format_italic),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Italic',
          ),
          IconButton(
            icon: const Icon(Icons.format_underlined),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Underline',
          ),
          IconButton(
            icon: const Icon(Icons.format_color_text),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Text Color',
          ),
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Link',
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Alignment
          IconButton(
            icon: const Icon(Icons.format_align_left),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Left',
          ),
          IconButton(
            icon: const Icon(Icons.format_align_center),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Center',
          ),
          IconButton(
            icon: const Icon(Icons.format_align_right),
            onPressed: () {},
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
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Bullet List',
          ),
          IconButton(
            icon: const Icon(Icons.format_list_numbered),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Numbered List',
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Insert
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Insert Link',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Insert Table',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'AI Assistant',
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown(String label, List<String> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<String>(
        value: label,
        underline: const SizedBox(),
        isDense: true,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
        onChanged: (_) {},
      ),
    );
  }

  List<Widget> _buildA4Pages() {
    // A4 dimensions: 210mm x 297mm (aspect ratio 0.707)
    // Using fixed width of 600px, height will be 600 / 0.707 ≈ 848px
    const double pageWidth = 600;
    const double pageHeight = 848; // A4 aspect ratio

    return List.generate(
      _sections.length,
      (index) => Container(
        width: pageWidth,
        constraints: const BoxConstraints(maxHeight: pageHeight),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _buildSectionContent(index),
          ),
        ),
      ),
    );
  }

  Widget _buildAddPageButton() {
    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _sections.add(_DocumentSection(
                  title: 'Untitled Section',
                  content: '',
                ));
                _selectedSectionIndex = _sections.length - 1;
              });
            },
            customBorder: CircleBorder(),
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

  Widget _buildSectionContent(int index) {
    final section = _sections[index];
    final isHovered = _hoveredSectionIndex == index;
    final isSelected = _selectedSectionIndex == index;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hoveredSectionIndex = index);
      },
      onExit: (_) {
        setState(() => _hoveredSectionIndex = -1);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () {
          setState(() => _selectedSectionIndex = index);
        },
        child: Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFF00BCD4) : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
            color: isSelected
                ? const Color(0xFF00BCD4).withValues(alpha: 0.03)
                : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        // Allow TextField to capture taps for focus
                        section.titleFocus.requestFocus();
                      },
                      child: TextField(
                        focusNode: section.titleFocus,
                        controller: section.titleController,
                        enabled: true,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Selection indicator
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Hover buttons
                  if (isHovered) ...[
                    // Insert Section button
                    Tooltip(
                      message: 'Insert Section',
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: GestureDetector(
                            onTapDown: (details) {
                              _showInsertSectionMenu(
                                index,
                                details.globalPosition,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.add,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Create Snippet button
                    Tooltip(
                      message: 'Create a Snippet',
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _createSnippet(index),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.save,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete Block button
                    Tooltip(
                      message: 'Delete Block',
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _sections.length > 1
                                ? () => _deleteSection(index)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: _sections.length > 1
                                    ? Colors.white
                                    : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // More options
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 16),
                              SizedBox(width: 8),
                              Text('Duplicate'),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C3E50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.more_vert,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // Content area
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Allow TextField to capture taps for focus
                  section.contentFocus.requestFocus();
                },
                child: TextField(
                  focusNode: section.contentFocus,
                  controller: section.controller,
                  enabled: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                    height: 1.8,
                    letterSpacing: 0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Start typing or insert content from library...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
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
    );
  }

  Widget _buildFloatingToolbar() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Library icon
            _buildFloatingToolbarButton(
              Icons.bookmark_outline,
              'Snippets',
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Snippets Library'),
                    backgroundColor: Color(0xFF00BCD4),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Add section button with menu
            _buildFloatingToolbarButton(
              Icons.add,
              'Add Section',
              () {
                _insertSectionFromFloatingMenu();
              },
            ),
            const SizedBox(height: 8),
            // Image icon
            _buildFloatingToolbarButton(
              Icons.image_outlined,
              'Insert Image',
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Insert Image feature coming soon'),
                    backgroundColor: Color(0xFF00BCD4),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Comment/Annotation icon
            _buildFloatingToolbarButton(
              Icons.edit_note,
              'Add Comment',
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Add Comment feature coming soon'),
                    backgroundColor: Color(0xFF00BCD4),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Code snippet icon
            _buildFloatingToolbarButton(
              Icons.code,
              'Code Snippet',
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code Snippet feature coming soon'),
                    backgroundColor: Color(0xFF00BCD4),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingToolbarButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF1A3A52),
            ),
          ),
        ),
      ),
    );
  }

  void _insertSectionFromFloatingMenu() {
    final newSection = _DocumentSection(
      title: 'Untitled Section',
      content: '',
    );
    setState(() {
      _sections.add(newSection);
      _selectedSectionIndex = _sections.length - 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New section added'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _insertContentIntoSection(String contentType, String content) {
    if (_sections.isEmpty) return;

    final section = _sections[_selectedSectionIndex];
    String newContent = section.controller.text;

    // Add content based on type
    switch (contentType) {
      case 'text':
        newContent += '\n[Text Block - Edit this text]';
        break;
      case 'image':
        newContent += '\n[Image placeholder - Image URL or file path]';
        break;
      case 'video':
        newContent += '\n[Video placeholder - Video URL]';
        break;
      case 'table':
        newContent +=
            '\n[Table]\n[Column 1] | [Column 2] | [Column 3]\n[Row 1] | [Data] | [Data]\n[Row 2] | [Data] | [Data]';
        break;
      case 'shape':
        newContent += '\n[Shape/Diagram placeholder]';
        break;
      case 'signature':
        newContent += '\n\nSignature: __________________ Date: __________\n';
        break;
    }

    setState(() {
      section.controller.text = newContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$contentType inserted into "${section.title}"'),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addImageToSection(String imageName) {
    if (_sections.isEmpty) return;

    final section = _sections[_selectedSectionIndex];
    String newContent = section.controller.text;
    newContent += '\n[Image: $imageName]';

    setState(() {
      section.controller.text = newContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image "$imageName" added to "${section.title}"'),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _insertSignatureIntoSection(String signatureName) {
    if (_sections.isEmpty) return;

    final section = _sections[_selectedSectionIndex];
    String newContent = section.controller.text;
    newContent +=
        '\n\nSignature ($signatureName): __________________ Date: __________\n';

    setState(() {
      section.controller.text = newContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Signature "$signatureName" added to "${section.title}"'),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildRightSidebar() {
    return Container(
      width: 300,
      color: Colors.white,
      child: Column(
        children: [
          // Panel tabs/icons at the top
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPanelTabIcon(Icons.tune, 'templates', 'Templates'),
                _buildPanelTabIcon(Icons.add_box_outlined, 'build', 'Build'),
                _buildPanelTabIcon(
                    Icons.cloud_upload_outlined, 'upload', 'Upload'),
                _buildPanelTabIcon(Icons.edit_note, 'signature', 'Signature'),
              ],
            ),
          ),
          // Panel content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildPanelContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelTabIcon(IconData icon, String panelName, String tooltip) {
    bool isActive = _selectedPanel == panelName;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPanel = panelName;
            });
          },
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? const Color(0xFF00BCD4) : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    switch (_selectedPanel) {
      case 'templates':
        return _buildTemplatesPanel();
      case 'build':
        return _buildBuildPanel();
      case 'upload':
        return _buildUploadPanel();
      case 'signature':
        return _buildSignaturePanel();
      default:
        return _buildTemplatesPanel();
    }
  }

  Widget _buildTemplatesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Template Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 20),
        // Template Style Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _showTemplateStyleDialog();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Template Style',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A3A52),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: const Color(0xFF1A3A52)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Adjust margins, orientation, background, etc.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Container(height: 1, color: Colors.grey[200]),
        const SizedBox(height: 24),
        // Currency Options
        const Text(
          'Currency Options',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Template Currency',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _showCurrencyDropdown();
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCurrency,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.expand_more, size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTemplateStyleDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Template Style Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Orientation',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Orientation changed to Portrait'),
                                backgroundColor: Color(0xFF27AE60),
                              ),
                            );
                          },
                          icon: const Icon(Icons.portrait),
                          label: const Text('Portrait'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BCD4),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Orientation changed to Landscape'),
                                backgroundColor: Color(0xFF27AE60),
                              ),
                            );
                          },
                          icon: const Icon(Icons.landscape),
                          label: const Text('Landscape'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Margins',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Enter margin size (in cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Background Color',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Template settings saved'),
                              backgroundColor: Color(0xFF27AE60),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCurrencyDropdown() {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 0, 0, 0),
      items: [
        'Rand (ZAR)',
        'US Dollar (USD)',
        'Euro (EUR)',
        'British Pound (GBP)',
        'Indian Rupee (INR)',
      ].map((currency) {
        return PopupMenuItem<String>(
          value: currency,
          child: Text(currency),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        setState(() {
          _selectedCurrency = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Currency changed to $value'),
            backgroundColor: const Color(0xFF27AE60),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Widget _buildBuildPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Build',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildBuildItem(Icons.text_fields, 'Text'),
            _buildBuildItem(Icons.image_outlined, 'Image'),
            _buildBuildItem(Icons.video_library_outlined, 'Video'),
            _buildBuildItem(Icons.table_chart_outlined, 'Table'),
            _buildBuildItem(Icons.dashboard_customize_outlined, 'Shape'),
          ],
        ),
      ],
    );
  }

  Widget _buildBuildItem(IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          String contentType = label.toLowerCase();
          if (contentType == 'shape') contentType = 'shape';
          _insertContentIntoSection(contentType, '');
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: const Color(0xFF1A3A52)),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPanel() {
    bool hasImages = _uploadedImages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Uploads',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        // Tabs
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _uploadTabSelected = 'this_document';
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          'This document',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _uploadTabSelected == 'this_document'
                                ? const Color(0xFF1A3A52)
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 2,
                          color: _uploadTabSelected == 'this_document'
                              ? const Color(0xFF1A3A52)
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _uploadTabSelected = 'library';
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          'Your library',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _uploadTabSelected == 'library'
                                ? const Color(0xFF1A3A52)
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 2,
                          color: _uploadTabSelected == 'library'
                              ? const Color(0xFF1A3A52)
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Show upload for "This document" tab or library for "Your library" tab
        if (_uploadTabSelected == 'this_document') ...[
          // Upload button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _addSampleImage();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.grey[300]!, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 32, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    Text(
                      'Click to upload images',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Images list or empty state
          if (!hasImages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'No images yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Images you upload will appear here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                _uploadedImages.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _uploadedImages[index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click to insert into document',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              onTap: () {
                                _addImageToSection(_uploadedImages[index]);
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.add, size: 16),
                                  SizedBox(width: 8),
                                  Text('Insert'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              onTap: () {
                                setState(() {
                                  _uploadedImages.removeAt(index);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Image deleted'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.delete, size: 16),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          child: Icon(Icons.more_vert,
                              size: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ] else ...[
          // Show library content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Content Library',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse and manage your content library',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening Content Library...'),
                          backgroundColor: Color(0xFF1A3A52),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.library_books),
                    label: const Text('Open Content Library'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _addSampleImage() {
    final newImageName = 'image_${DateTime.now().millisecond}.jpg';
    setState(() {
      _uploadedImages.add(newImageName);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image "$newImageName" uploaded'),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSignaturePanel() {
    List<String> filteredSignatures = _signatures
        .where((sig) =>
            sig.toLowerCase().contains(_signatureSearchQuery.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Signatures',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        // Search field
        TextField(
          onChanged: (value) {
            setState(() {
              _signatureSearchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Start typing',
            hintStyle: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
            ),
            prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
            prefixText: 'Signatures for   ',
            prefixStyle: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: Color(0xFF00BCD4),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Signature items list
        if (filteredSignatures.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No signatures found',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              filteredSignatures.length,
              (index) {
                final signature = filteredSignatures[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _insertSignatureIntoSection(signature);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0B2), // Light orange/peach
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit,
                              size: 24,
                              color: const Color(0xFFF57C00),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    signature,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Click to insert',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),
        // Add new signature button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _showAddSignatureDialog();
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey[50],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 18, color: Color(0xFF1A3A52)),
                  const SizedBox(width: 8),
                  Text(
                    'Add New Signature',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A3A52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddSignatureDialog() {
    TextEditingController signatureName = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Signature',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: signatureName,
                    decoration: InputDecoration(
                      labelText: 'Signature Name',
                      hintText: 'e.g., Company Director',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (signatureName.text.isNotEmpty) {
                            setState(() {
                              _signatures.add(signatureName.text);
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Signature "${signatureName.text}" added'),
                                backgroundColor: const Color(0xFF27AE60),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                        ),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DocumentSection {
  String title;
  String content;
  final TextEditingController controller;
  final TextEditingController titleController;
  final FocusNode contentFocus;
  final FocusNode titleFocus;

  _DocumentSection({
    required this.title,
    required this.content,
  })  : controller = TextEditingController(text: content),
        titleController = TextEditingController(text: title),
        contentFocus = FocusNode(),
        titleFocus = FocusNode();
}
