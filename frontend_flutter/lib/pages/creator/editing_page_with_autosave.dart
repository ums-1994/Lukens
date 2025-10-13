import 'package:flutter/material.dart';
import '../../services/auto_draft_service.dart';
import '../../widgets/auto_save_indicator.dart';

class EditingPageWithAutosave extends StatefulWidget {
  final String proposalId;
  final String proposalTitle;
  final Map<String, dynamic> initialSections;

  const EditingPageWithAutosave({
    super.key,
    required this.proposalId,
    required this.proposalTitle,
    required this.initialSections,
  });

  @override
  State<EditingPageWithAutosave> createState() =>
      _EditingPageWithAutosaveState();
}

class _EditingPageWithAutosaveState extends State<EditingPageWithAutosave> {
  final AutoDraftService _autoDraftService = AutoDraftService();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _sections = {};

  @override
  void initState() {
    super.initState();
    _initializeSections();
    _startAutoDraft();
  }

  void _initializeSections() {
    _sections.clear();
    _sections.addAll(widget.initialSections);

    // Create controllers for each section
    for (final entry in _sections.entries) {
      _controllers[entry.key] =
          TextEditingController(text: entry.value.toString());
    }
  }

  void _startAutoDraft() {
    _autoDraftService.startAutoDraft(widget.proposalId, _sections);
  }

  void _onSectionChanged(String key, String value) {
    setState(() {
      _sections[key] = value;
    });

    // Mark as changed for autosave
    _autoDraftService.markChanged(_sections);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: Text(widget.proposalTitle),
        backgroundColor: const Color(0xFF2C3E50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Auto-save indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AutoSaveIndicator(autoDraftService: _autoDraftService),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFE8F4FD),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your changes are automatically saved every 30 seconds or when you stop typing.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _buildSectionWidgets(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionWidgets() {
    final widgets = <Widget>[];

    for (final entry in _sections.entries) {
      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatSectionTitle(entry.key),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controllers[entry.key],
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText:
                        'Enter ${_formatSectionTitle(entry.key).toLowerCase()}...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (value) => _onSectionChanged(entry.key, value),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  String _formatSectionTitle(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  void dispose() {
    _autoDraftService.stopAutoDraft();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
