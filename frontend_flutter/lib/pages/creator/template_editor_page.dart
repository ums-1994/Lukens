import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';

class TemplateEditorPage extends StatefulWidget {
  final String? templateId;
  final Map<String, dynamic>? existingTemplate;

  const TemplateEditorPage({
    super.key,
    this.templateId,
    this.existingTemplate,
  });

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _priceController;
  String _selectedFontFamily = 'Plus Jakarta Sans';
  double _selectedFontSize = 12.0;
  FontWeight _selectedFontWeight = FontWeight.normal;
  TextAlign _textAlign = TextAlign.left;
  Color _textColor = const Color(0xFF2C3E50);
  String _templateCurrency = 'US Dollar (USD)';
  bool _isSaved = true;
  String _sectionTitle = 'Untitled Section';

  List<String> fontFamilies = [
    'Arial',
    'Verdana',
    'Georgia',
    'Times New Roman',
    'Plus Jakarta Sans',
    'Courier New',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingTemplate != null) {
      _titleController =
          TextEditingController(text: widget.existingTemplate!['title']);
      _contentController =
          TextEditingController(text: widget.existingTemplate!['content']);
      _priceController = TextEditingController(
          text: widget.existingTemplate!['price'] ?? '0.00');
    } else {
      _titleController = TextEditingController(text: 'Untitled Template');
      _contentController = TextEditingController();
      _priceController = TextEditingController(text: '0.00');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _updateContent() {
    setState(() {
      _isSaved = false;
    });
  }

  Future<void> _saveTemplate(AppState app) async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template title')),
      );
      return;
    }

    try {
      final templateKey = _titleController.text
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');

      await app.createContent(
        templateKey,
        _titleController.text,
        _contentController.text,
        category: 'Templates',
      );

      if (mounted) {
        setState(() {
          _isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, app, _) => Scaffold(
        backgroundColor: const Color(0xFFF5F7F9),
        body: Column(
          children: [
            // Header - Redesigned to match screenshot
            Container(
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Title, price, and badge
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 250,
                                    child: TextField(
                                      controller: _titleController,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Untitled Template',
                                        hintStyle: TextStyle(
                                          color: Color(0xFFA0AEC0),
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (_) => _updateContent(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00BCD4),
                                      borderRadius: BorderRadius.circular(4),
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
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text(
                                    '\$',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: TextField(
                                      controller: _priceController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1E293B),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: '0.00',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (_) => _updateContent(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _isSaved
                                          ? Colors.green[50]
                                          : Colors.orange[50],
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _isSaved
                                            ? Colors.green[300]!
                                            : Colors.orange[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      _isSaved ? 'Saved' : 'Not Saved',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _isSaved
                                            ? Colors.green[700]
                                            : Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Right side: Buttons
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Feedback submitted'),
                              ),
                            );
                          },
                          child: const Text(
                            'Submit feedback',
                            style: TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Preview coming soon'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('Preview'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Generate Document coming soon'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('Generate Document'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Help requested'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.help_outline),
                          tooltip: 'Help',
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'LS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Formatting Toolbar
            Container(
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notes, size: 20),
                      tooltip: 'Sections',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.undo, size: 20),
                      tooltip: 'Undo',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.redo, size: 20),
                      tooltip: 'Redo',
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: 'Normal Text',
                        underline: const SizedBox(),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'Normal Text',
                            child: Text('Normal Text',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        onChanged: (value) {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedFontFamily,
                        underline: const SizedBox(),
                        isDense: true,
                        items: fontFamilies.map((font) {
                          return DropdownMenuItem(
                            value: font,
                            child: Text(font,
                                style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFontFamily = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<double>(
                        value: _selectedFontSize,
                        underline: const SizedBox(),
                        isDense: true,
                        items: [12.0, 14.0, 16.0, 18.0, 20.0].map((size) {
                          return DropdownMenuItem(
                            value: size,
                            child: Text('${size.toInt()}px',
                                style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFontSize = value ?? 12.0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_bold, size: 18),
                      tooltip: 'Bold',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_italic, size: 18),
                      tooltip: 'Italic',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_underlined, size: 18),
                      tooltip: 'Underline',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_color_text, size: 18),
                      tooltip: 'Text Color',
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_align_left, size: 18),
                      tooltip: 'Align Left',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_align_center, size: 18),
                      tooltip: 'Align Center',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_align_right, size: 18),
                      tooltip: 'Align Right',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_list_bulleted, size: 18),
                      tooltip: 'Bullet List',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.format_list_numbered, size: 18),
                      tooltip: 'Numbered List',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.link, size: 18),
                      tooltip: 'Insert Link',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.brush, size: 18),
                      tooltip: 'Text Formatting',
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      tooltip: 'AI',
                    ),
                  ],
                ),
              ),
            ),
            // Main Content Area
            Expanded(
              child: Row(
                children: [
                  // Editor
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF9FAFB),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Title
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _sectionTitle,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Icons.add, size: 20),
                                        tooltip: 'Add',
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20),
                                        tooltip: 'Delete',
                                      ),
                                      IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Icons.more_vert,
                                            size: 20),
                                        tooltip: 'More',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Text Editor
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: TextField(
                                controller: _contentController,
                                maxLines: 15,
                                style: TextStyle(
                                  fontSize: _selectedFontSize,
                                  fontFamily: _selectedFontFamily,
                                  color: _textColor,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Write text here...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFA0AEC0),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(20),
                                ),
                                onChanged: (_) => _updateContent(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Right Sidebar - Settings
                  Container(
                    width: 280,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Template Settings',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const Divider(),
                          // Template Style Button
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Color(0xFFD1D5DB)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {},
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Template Style',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Adjust margins, orientation, background, etc.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          // Currency Options
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Currency Options',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Template Currency',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Color(0xFFD1D5DB)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _templateCurrency,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    items: [
                                      'US Dollar (USD)',
                                      'Euro (EUR)',
                                      'British Pound (GBP)',
                                      'Canadian Dollar (CAD)',
                                    ].map((currency) {
                                      return DropdownMenuItem(
                                        value: currency,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(currency,
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _templateCurrency = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Save Button
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _saveTemplate(app),
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('Save Template'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
