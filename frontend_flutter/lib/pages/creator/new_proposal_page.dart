import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api.dart';
import '../../services/api_service.dart';
import 'blank_document_editor_page.dart';

class NewProposalPage extends StatefulWidget {
  const NewProposalPage({super.key});

  @override
  State<NewProposalPage> createState() => _NewProposalPageState();
}

class _NewProposalPageState extends State<NewProposalPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  String _selectedProposalType = 'Business Proposal';

  @override
  void dispose() {
    _titleController.dispose();
    _clientController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final app = context.read<AppState>();
      await app.createProposal(
        _titleController.text.trim(),
        _clientController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposal created')),
      );

      // After creating, go to proposals list
      Navigator.pushReplacementNamed(context, '/proposals');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating proposal: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateWithAI() async {
    if (!_formKey.currentState!.validate()) return;

    // Show AI generation dialog
    await _showAIGenerationDialog();
  }

  Future<void> _showAIGenerationDialog() async {
    final TextEditingController keywordsController = TextEditingController();
    final TextEditingController goalsController = TextEditingController();

    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF9C27B0)),
                  const SizedBox(width: 8),
                  const Text('Generate with AI'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                color: Colors.purple[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'AI will generate a complete proposal with 12 sections based on your inputs',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Proposal Info Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Proposal Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow('Title', _titleController.text),
                            _buildInfoRow('Client', _clientController.text),
                            if (_contentController.text.isNotEmpty)
                              _buildInfoRow(
                                  'Description',
                                  _contentController.text.substring(0, 50) +
                                      '...'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Proposal Type
                      const Text(
                        'Proposal Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedProposalType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Business Proposal',
                              child: Text('Business Proposal')),
                          DropdownMenuItem(
                              value: 'Statement of Work (SOW)',
                              child: Text('Statement of Work (SOW)')),
                          DropdownMenuItem(
                              value: 'RFI Response',
                              child: Text('RFI Response')),
                          DropdownMenuItem(
                              value: 'RFP Response',
                              child: Text('RFP Response')),
                          DropdownMenuItem(
                              value: 'Technical Proposal',
                              child: Text('Technical Proposal')),
                          DropdownMenuItem(
                              value: 'Consulting Proposal',
                              child: Text('Consulting Proposal')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            _selectedProposalType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Keywords
                      const Text(
                        'Keywords / Tags',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: keywordsController,
                        decoration: InputDecoration(
                          hintText: 'e.g., CRM, Cloud, Integration, Mobile App',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Goals
                      const Text(
                        'Project Goals / Objectives',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: goalsController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Describe the main objectives, expected outcomes, and success criteria...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context, true);

                    // Start AI generation
                    await _generateProposalWithAI(
                      keywords: keywordsController.text,
                      goals: goalsController.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generate Proposal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateProposalWithAI({
    required String keywords,
    required String goals,
  }) async {
    setState(() => _isLoading = true);

    try {
      // Get token
      final app = context.read<AppState>();
      final token = app.authToken ?? '';

      if (token.isEmpty) {
        throw Exception('Authentication token not found');
      }

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Generating your proposal with AI...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take 10-15 seconds',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );

      // Build AI prompt
      final prompt = '''
Create a comprehensive ${_selectedProposalType} for:

Client: ${_clientController.text}
Project: ${_titleController.text}
${_contentController.text.isNotEmpty ? 'Description: ${_contentController.text}\n' : ''}
${keywords.isNotEmpty ? 'Keywords: $keywords\n' : ''}
${goals.isNotEmpty ? 'Goals: $goals\n' : ''}

Generate a detailed, professional proposal with all necessary sections.
''';

      // Call AI service
      final result = await ApiService.generateFullProposal(
        token: token,
        prompt: prompt,
        context: {
          'document_title': _titleController.text,
          'client_name': _clientController.text,
          'proposal_type': _selectedProposalType,
          'keywords': keywords,
          'goals': goals,
        },
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (result != null && result['sections'] != null) {
        // Create proposal first
        await app.createProposal(
          _titleController.text.trim(),
          _clientController.text.trim(),
        );

        if (!mounted) return;

        // Navigate to blank document editor with AI-generated content
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BlankDocumentEditorPage(
              initialTitle: _titleController.text,
              aiGeneratedSections: result['sections'] as Map<String, dynamic>,
            ),
          ),
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text('AI generated ${result['section_count']} sections!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Failed to generate proposal');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Proposal'),
        backgroundColor: const Color(0xFF2C3E50),
      ),
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Opportunity / Proposal Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _clientController,
                  decoration: const InputDecoration(
                    labelText: 'Client Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Brief Description / Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 6,
                ),
                const SizedBox(height: 20),
                // Two-button layout
                Row(
                  children: [
                    // Regular Create Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.description, size: 18),
                        label: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Create Blank'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // AI Generate Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateWithAI,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Generate with AI'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.purple[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use AI to generate a complete proposal with all sections automatically',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
