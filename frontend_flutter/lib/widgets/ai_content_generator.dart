import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../services/api_service.dart';

class AIContentGenerator extends StatefulWidget {
  final bool open;
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onContentGenerated;

  const AIContentGenerator({
    Key? key,
    required this.open,
    required this.onClose,
    required this.onContentGenerated,
  }) : super(key: key);

  @override
  _AIContentGeneratorState createState() => _AIContentGeneratorState();
}

class _AIContentGeneratorState extends State<AIContentGenerator> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _selectedBlockType = '';
  String _generatedContent = '';
  bool _isGenerating = false;
  bool _isSaving = false;

  final List<Map<String, String>> _blockTypes = [
    {'value': 'company_profile', 'label': 'Company Profile'},
    {'value': 'capability', 'label': 'Capability'},
    {'value': 'delivery_approach', 'label': 'Delivery Approach'},
    {'value': 'case_study', 'label': 'Case Study'},
    {'value': 'team_bio', 'label': 'Team Bio'},
    {'value': 'methodology', 'label': 'Methodology'},
    {'value': 'assumptions', 'label': 'Assumptions'},
    {'value': 'risks', 'label': 'Risks'},
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _resetForm() {
    setState(() {
      _promptController.clear();
      _titleController.clear();
      _contentController.clear();
      _selectedBlockType = '';
      _generatedContent = '';
      _isGenerating = false;
      _isSaving = false;
    });
  }

  Future<void> _generateContent() async {
    if (_promptController.text.isEmpty || _selectedBlockType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide both a prompt and select a block type.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final app = context.read<AppState>();
      final token = app.authToken;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in.');
      }

      final String contextualPrompt = '''
You are a professional proposal writer for Khonology, a leading technology consulting firm.

Generate high-quality, professional content for a ${_selectedBlockType.replaceAll('_', ' ')} section based on the following requirements:

${_promptController.text}

Requirements:
- Write in a professional, confident tone
- Be specific and concrete with examples where appropriate
- Use industry-standard terminology
- Keep it concise but comprehensive (200-400 words)
- Focus on value proposition and business outcomes
- Make it ready to use in a client proposal

Generate the content now:''';

      final result = await ApiService.generateAIContent(
        token: token,
        prompt: contextualPrompt,
        sectionType: _selectedBlockType,
      );

      if (result != null && result['content'] != null) {
        setState(() {
          _generatedContent = result['content'];
          _contentController.text = result['content'];
          _isGenerating = false;
        });
      } else {
        throw Exception('Failed to generate content. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _autoTagContent(String content) async {
    try {
      final app = context.read<AppState>();
      final token = app.authToken;

      if (token == null || token.isEmpty) {
        return _getFallbackTags();
      }

      final tagPrompt = '''
Analyze the following content and suggest 5-8 relevant tags for categorization and search.
Tags should be:
- Single words or short phrases
- Industry-relevant
- Helpful for search and filtering
- Related to technologies, industries, services, or methodologies mentioned

Content:
$content

Return only a comma-separated list of tags.''';

      final result = await ApiService.generateAIContent(
        token: token,
        prompt: tagPrompt,
        sectionType: 'tagging',
      );

      if (result != null && result['content'] != null) {
        final String tagsString = result['content'];
        final List<String> tags = tagsString
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .take(8)
            .toList();
        return tags.isNotEmpty ? tags : _getFallbackTags();
      }
    } catch (e) {
      print('Error auto-tagging content: $e');
    }
    return _getFallbackTags();
  }

  List<String> _getFallbackTags() {
    final blockTypeLabel =
        _blockTypes.firstWhere((t) => t['value'] == _selectedBlockType,
            orElse: () => {'label': 'content'})['label']!;
    return [
      blockTypeLabel.toLowerCase(),
      'technology',
      'consulting',
      'khonology'
    ];
  }

  Future<void> _saveContent() async {
    if (_titleController.text.isEmpty ||
        _contentController.text.isEmpty ||
        _selectedBlockType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please ensure all fields are filled.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final app = context.read<AppState>();
      final List<String> tags = await _autoTagContent(_contentController.text);

      // Create the content block with tags
      final key = '${DateTime.now().millisecondsSinceEpoch}_${_selectedBlockType}';
      final success = await app.createContent(
        key: key,
        label: _titleController.text,
        content: _contentController.text,
        category: 'Sections',
      );

      if (success) {
        final Map<String, dynamic> contentData = {
          'title': _titleController.text,
          'label': _titleController.text,
          'block_type': _selectedBlockType,
          'content': _contentController.text,
          'tags': tags,
          'ai_generated': true,
          'generation_prompt': _promptController.text,
          'category': 'Sections',
        };

        widget.onContentGenerated(contentData);
        _resetForm();
        widget.onClose();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Content saved successfully to library!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to save content to library');
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return const SizedBox.shrink();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Content Generator',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Input Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Content Type Dropdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Content Type *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedBlockType.isEmpty
                                      ? null
                                      : _selectedBlockType,
                                  hint: const Text('Select content type'),
                                  isExpanded: true,
                                  items: _blockTypes.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type['value'],
                                      child: Text(type['label']!),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBlockType = value!;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Prompt Input
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Content Requirements *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _promptController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText:
                                    "E.g., 'Create a case study about a cloud migration project for a retail client that reduced infrastructure costs by 40% and improved uptime to 99.99%'",
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Describe what you need. Be specific about key points, achievements, or requirements.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Generate Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isGenerating ? null : _generateContent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isGenerating
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Generating...'),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 20),
                                      SizedBox(width: 8),
                                      Text('Generate Content'),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),

                    // Generated Content Section
                    if (_generatedContent.isNotEmpty) ...[
                      const Divider(height: 32),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: Colors.purple, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Generated Content',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Title Input
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Title *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  hintText: 'Give this content block a title',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Content Editor
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Content (editable)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 300,
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _contentController,
                                  maxLines: null,
                                  expands: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Info Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: Border.all(color: Colors.blue.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome,
                                    color: Colors.blue, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Content will be automatically tagged when saved',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _generatedContent = '';
                                    _contentController.clear();
                                    _titleController.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: Colors.grey.shade800,
                                ),
                                child: const Text('Regenerate'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _isSaving ? null : _saveContent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isSaving
                                    ? const Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Saving...'),
                                        ],
                                      )
                                    : const Text('Save to Library'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
