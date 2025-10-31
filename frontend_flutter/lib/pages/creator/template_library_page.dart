import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';
import 'template_builder.dart';

class TemplateLibraryPage extends StatefulWidget {
  const TemplateLibraryPage({Key? key}) : super(key: key);

  @override
  _TemplateLibraryPageState createState() => _TemplateLibraryPageState();
}

class _TemplateLibraryPageState extends State<TemplateLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  Template? _previewTemplate;
  bool _isLoading = true;

  List<Template> _templates = [];
  List<Template> _filteredTemplates = [];
  List<Template> _myTemplates = [];
  List<Template> _publicTemplates = [];

  final Map<String, StatusConfig> _statusConfig = {
    'draft': StatusConfig(
      color: Colors.grey.shade100,
      textColor: Colors.grey.shade800,
      icon: Icons.description,
      label: 'Draft',
    ),
    'pending_approval': StatusConfig(
      color: Colors.orange.shade100,
      textColor: Colors.orange.shade800,
      icon: Icons.schedule,
      label: 'Pending',
    ),
    'approved': StatusConfig(
      color: Colors.green.shade100,
      textColor: Colors.green.shade800,
      icon: Icons.check_circle,
      label: 'Approved',
    ),
    'rejected': StatusConfig(
      color: Colors.red.shade100,
      textColor: Colors.red.shade800,
      icon: Icons.close,
      label: 'Rejected',
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Mock API call - replace with your actual API
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock data
      final List<Template> mockTemplates = [
        Template(
          id: '1',
          name: 'Standard Proposal Template',
          description: 'Comprehensive proposal template for enterprise clients',
          templateType: 'proposal',
          approvalStatus: 'approved',
          isPublic: true,
          isApproved: true,
          version: 2,
          sections: [
            TemplateSection(title: 'Executive Summary', required: true),
            TemplateSection(title: 'Company Profile', required: true),
            TemplateSection(title: 'Scope & Deliverables', required: true),
          ],
          dynamicFields: [
            DynamicField(fieldKey: 'client_name', fieldName: 'Client Name'),
            DynamicField(fieldKey: 'project_scope', fieldName: 'Project Scope'),
          ],
          usageCount: 15,
          createdBy: 'admin@khonology.com',
          createdDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
        Template(
          id: '2',
          name: 'SOW Template',
          description: 'Detailed statement of work template',
          templateType: 'sow',
          approvalStatus: 'approved',
          isPublic: true,
          isApproved: true,
          version: 1,
          sections: [
            TemplateSection(title: 'Project Overview', required: true),
            TemplateSection(title: 'Deliverables', required: true),
            TemplateSection(title: 'Timeline', required: true),
          ],
          usageCount: 8,
          createdBy: 'admin@khonology.com',
          createdDate: DateTime.now().subtract(const Duration(days: 15)),
        ),
        Template(
          id: '3',
          name: 'My Custom Proposal',
          description: 'Custom proposal template for tech clients',
          templateType: 'proposal',
          approvalStatus: 'draft',
          isPublic: false,
          isApproved: false,
          version: 1,
          sections: [
            TemplateSection(title: 'Technical Approach', required: true),
          ],
          usageCount: 0,
          createdBy: 'current_user',
          createdDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

      setState(() {
        _templates = mockTemplates;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load templates: $e');
    }
  }

  void _applyFilters() {
    _filteredTemplates = _templates.where((template) {
      final matchesSearch = template.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          (template.description?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false);
      final matchesType = _typeFilter == 'all' || template.templateType == _typeFilter;
      final matchesStatus = _statusFilter == 'all' || template.approvalStatus == _statusFilter;
      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    // Separate my templates and public templates
    _myTemplates = _filteredTemplates.where((t) => t.createdBy == 'current_user').toList();
    _publicTemplates = _filteredTemplates.where((t) => t.isPublic && t.isApproved).toList();
  }

  Future<void> _cloneTemplate(Template template) async {
    try {
      // Mock API call - replace with your actual API
      await Future.delayed(const Duration(seconds: 1));
      
      final clonedTemplate = Template(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${template.name} (Copy)',
        description: template.description,
        templateType: template.templateType,
        approvalStatus: 'draft',
        isPublic: false,
        isApproved: false,
        version: 1,
        sections: template.sections,
        dynamicFields: template.dynamicFields,
        usageCount: 0,
        createdBy: 'current_user',
        createdDate: DateTime.now(),
        basedOnTemplateId: template.id,
      );

      setState(() {
        _templates.insert(0, clonedTemplate);
        _applyFilters();
      });

      _showSuccess('Template cloned successfully!');
    } catch (e) {
      _showError('Failed to clone template: $e');
    }
  }

  Future<void> _deleteTemplate(String templateId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text('Are you sure you want to delete this template? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Mock API call - replace with your actual API
        await Future.delayed(const Duration(seconds: 1));
        
        setState(() {
          _templates.removeWhere((t) => t.id == templateId);
          _applyFilters();
        });

        _showSuccess('Template deleted successfully!');
      } catch (e) {
        _showError('Failed to delete template: $e');
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Filters
                  _buildFilters(),
                  const SizedBox(height: 24),

                  // Public Templates
                  _buildPublicTemplates(),
                  const SizedBox(height: 24),

                  // My Templates
                  _buildMyTemplates(),

                  // Preview Dialog
                  if (_previewTemplate != null) _buildPreviewDialog(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to TemplateBuilder
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TemplateBuilder()),
          );
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.dashboard, size: 32, color: Colors.blue),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Template Library',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              'Create and manage proposal templates with dynamic fields',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Search
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search templates...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _applyFilters();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),

            // Type Filter
            Container(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: _typeFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Types')),
                  DropdownMenuItem(value: 'proposal', child: Text('Proposal')),
                  DropdownMenuItem(value: 'sow', child: Text('SOW')),
                  DropdownMenuItem(value: 'rfi', child: Text('RFI')),
                ],
                onChanged: (value) {
                  setState(() {
                    _typeFilter = value!;
                    _applyFilters();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),

            // Status Filter
            Container(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'pending_approval', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                ],
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value!;
                    _applyFilters();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicTemplates() {
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Approved Templates',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(_publicTemplates.length.toString()),
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _publicTemplates.isEmpty
                ? _buildEmptyState(
                    icon: Icons.star,
                    message: 'No approved templates yet',
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: _publicTemplates.length,
                    itemBuilder: (context, index) => _buildTemplateCard(_publicTemplates[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyTemplates() {
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'My Templates',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(_myTemplates.length.toString()),
                  backgroundColor: Colors.grey.shade200,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _myTemplates.isEmpty
                ? _buildEmptyState(
                    icon: Icons.dashboard,
                    message: 'You haven\'t created any templates yet',
                    showButton: true,
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TemplateBuilder()),
                      );
                    },
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: _myTemplates.length,
                    itemBuilder: (context, index) => _buildTemplateCard(_myTemplates[index], isMyTemplate: true),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(Template template, {bool isMyTemplate = false}) {
    final statusConfig = _statusConfig[template.approvalStatus]!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (template.description != null)
                        Text(
                          template.description!,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text(
                              template.templateType.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: Colors.grey.shade100,
                          ),
                          Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusConfig.icon, size: 12),
                                const SizedBox(width: 4),
                                Text(statusConfig.label, style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                            backgroundColor: statusConfig.color,
                          ),
                          if (template.isPublic)
                            Chip(
                              label: const Text(
                                'Public',
                                style: TextStyle(fontSize: 10, color: Colors.purple),
                              ),
                              backgroundColor: Colors.purple.shade100,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Stats
            Text(
              '${template.sections.length} sections • ${template.usageCount} uses',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _previewTemplate = template),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 8),
                if (isMyTemplate) ...[
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TemplateBuilder(templateId: template.id),
                        ),
                      );
                    },
                    child: const Icon(Icons.edit, size: 16),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => _cloneTemplate(template),
                    child: const Icon(Icons.copy, size: 16),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => _deleteTemplate(template.id),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Icon(Icons.delete, size: 16),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cloneTemplate(template),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Clone'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    bool showButton = false,
    VoidCallback? onButtonPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          if (showButton) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onButtonPressed,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Template'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewDialog() {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _previewTemplate!.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _previewTemplate = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _previewTemplate!.description ?? 'No description',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                label: Text(_previewTemplate!.templateType),
                                backgroundColor: Colors.grey.shade200,
                              ),
                              Chip(
                                label: Text('v${_previewTemplate!.version}'),
                                backgroundColor: Colors.blue.shade100,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sections
                    Text(
                      'Sections (${_previewTemplate!.sections.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: _previewTemplate!.sections.map((section) => Card(
                        child: ListTile(
                          title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                          trailing: section.required 
                              ? const Chip(label: Text('Required', style: TextStyle(fontSize: 12)))
                              : null,
                          subtitle: section.defaultContent != null
                              ? Text(
                                  section.defaultContent!,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                        ),
                      )).toList(),
                    ),

                    // Dynamic Fields
                    if (_previewTemplate!.dynamicFields.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Dynamic Fields',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2,
                        ),
                        itemCount: _previewTemplate!.dynamicFields.length,
                        itemBuilder: (context, index) {
                          final field = _previewTemplate!.dynamicFields[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: Border.all(color: Colors.blue.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '{{${field.fieldKey}}}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  field.fieldName,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          );
                        },
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

// Data Models
class Template {
  final String id;
  final String name;
  final String? description;
  final String templateType;
  final String approvalStatus;
  final bool isPublic;
  final bool isApproved;
  final int version;
  final List<TemplateSection> sections;
  final List<DynamicField> dynamicFields;
  final int usageCount;
  final String createdBy;
  final DateTime createdDate;
  final String? basedOnTemplateId;

  Template({
    required this.id,
    required this.name,
    this.description,
    required this.templateType,
    required this.approvalStatus,
    required this.isPublic,
    required this.isApproved,
    required this.version,
    required this.sections,
    this.dynamicFields = const [],
    required this.usageCount,
    required this.createdBy,
    required this.createdDate,
    this.basedOnTemplateId,
  });
}

class TemplateSection {
  final String title;
  final bool required;
  final String? defaultContent;

  TemplateSection({
    required this.title,
    this.required = false,
    this.defaultContent,
  });
}

class DynamicField {
  final String fieldKey;
  final String fieldName;

  DynamicField({
    required this.fieldKey,
    required this.fieldName,
  });
}

class StatusConfig {
  final Color color;
  final Color textColor;
  final IconData icon;
  final String label;

  StatusConfig({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.label,
  });
}
