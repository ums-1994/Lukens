import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api.dart';

class TemplateBuilder extends StatefulWidget {
  final String? templateId;

  const TemplateBuilder({Key? key, this.templateId}) : super(key: key);

  @override
  State<TemplateBuilder> createState() => _TemplateBuilderState();
}

class _TemplateBuilderState extends State<TemplateBuilder> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  TemplateData _templateData = TemplateData(
    id: null,
    templateKey: null,
    status: 'draft',
    isApproved: false,
    name: '',
    description: '',
    templateType: 'proposal',
    sections: [],
    dynamicFields: [],
    isPublic: false,
    tags: '',
  );

  bool get _isEditing => widget.templateId != null;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmitting = false;

  final List<DynamicField> _defaultDynamicFields = [
    DynamicField(fieldName: 'Client Name', fieldKey: 'client_name', source: 'proposal', description: 'Client company name'),
    DynamicField(fieldName: 'Client Contact', fieldKey: 'client_contact', source: 'proposal', description: 'Contact person name'),
    DynamicField(fieldName: 'Client Email', fieldKey: 'client_email', source: 'proposal', description: 'Client email address'),
    DynamicField(fieldName: 'Engagement Value', fieldKey: 'engagement_value', source: 'proposal', description: 'Project value'),
    DynamicField(fieldName: 'Target Date', fieldKey: 'target_completion_date', source: 'proposal', description: 'Completion date'),
    DynamicField(fieldName: 'Your Name', fieldKey: 'user_name', source: 'user', description: 'Current user\'s full name'),
    DynamicField(fieldName: 'Your Email', fieldKey: 'user_email', source: 'user', description: 'Current user\'s email'),
    DynamicField(fieldName: 'Current Date', fieldKey: 'current_date', source: 'custom', description: 'Today\'s date'),
    DynamicField(fieldName: 'Company Name', fieldKey: 'company_name', source: 'custom', description: 'Your company name'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplateData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplateData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.templateId != null) {
        final app = context.read<AppState>();
        final response = await app.fetchTemplateById(widget.templateId!);
        if (response != null) {
          final templateJson = Map<String, dynamic>.from(response);
          var loadedTemplate = TemplateData.fromJson(templateJson);
          if (loadedTemplate.dynamicFields.isEmpty) {
            loadedTemplate = loadedTemplate.copyWith(
              dynamicFields: List<DynamicField>.from(_defaultDynamicFields),
            );
          }
          setState(() {
            _templateData = loadedTemplate;
            _nameController.text = loadedTemplate.name;
            _descriptionController.text = loadedTemplate.description;
            _tagsController.text = loadedTemplate.tags;
          });
        } else {
          _showError('Unable to load template data');
        }
      } else {
        setState(() {
          _templateData = _templateData.copyWith(
              dynamicFields: List<DynamicField>.from(_defaultDynamicFields));
        });
      }
    } catch (e) {
      _showError('Failed to load template: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addSection() {
    setState(() {
      _templateData = _templateData.copyWith(
        sections: [
          ..._templateData.sections,
          TemplateSection(
            key: 'section_${DateTime.now().millisecondsSinceEpoch}',
            title: 'New Section',
            required: false,
            defaultContent: '',
            order: _templateData.sections.length,
          ),
        ],
      );
    });
  }

  void _updateSection(int index, String field, dynamic value) {
    setState(() {
      final newSections = List<TemplateSection>.from(_templateData.sections);
      newSections[index] = newSections[index].copyWithField(field, value);
      _templateData = _templateData.copyWith(sections: newSections);
    });
  }

  void _deleteSection(int index) {
    setState(() {
      _templateData = _templateData.copyWith(
        sections: List<TemplateSection>.from(_templateData.sections)..removeAt(index),
      );
    });
  }

  void _reorderSections(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final sections = List<TemplateSection>.from(_templateData.sections);
      final TemplateSection item = sections.removeAt(oldIndex);
      sections.insert(newIndex, item);

      final updatedSections = sections.asMap().entries.map((entry) {
        return entry.value.copyWith(order: entry.key);
      }).toList();

      _templateData = _templateData.copyWith(sections: updatedSections);
    });
  }

  Future<void> _saveTemplate(bool submitForApproval) async {
    if (_nameController.text.isEmpty) {
      _showError('Please provide a template name');
      return;
    }

    setState(() {
      if (submitForApproval) {
        _isSubmitting = true;
      } else {
        _isSaving = true;
      }
    });

    try {
      final payload = _buildTemplatePayload(submitForApproval);
      final app = context.read<AppState>();
      Map<String, dynamic>? result;

      if (_isEditing) {
        result = await app.updateTemplate(widget.templateId!, payload);
      } else {
        result = await app.createTemplate(payload);
      }

      if (result == null) {
        throw Exception('No response from server');
      }

      if (submitForApproval) {
        _showSuccess('Template submitted for approval!');
      } else {
        _showSuccess('Template saved successfully!');
      }

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      _showError('Failed to save template: $e');
    } finally {
      setState(() {
        _isSaving = false;
        _isSubmitting = false;
      });
    }
  }

  Map<String, dynamic> _buildTemplatePayload(bool submitForApproval) {
    final sectionsPayload =
        _templateData.sections.asMap().entries.map((entry) {
      final section = entry.value;
      final key = _resolveSectionKey(section.key, section.title, entry.key);
      return {
        'key': key,
        'title': section.title,
        'required': section.required,
        'content': section.defaultContent ?? '',
        'order': entry.key,
      };
    }).toList();

    final dynamicFieldsPayload =
        _templateData.dynamicFields.map((field) => field.toJson()).toList();

    final status = submitForApproval ? 'pending_approval' : 'draft';

    return {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'template_type': _templateData.templateType,
      'is_public': _templateData.isPublic,
      'status': status,
      'tags': _tagsController.text.trim(),
      'sections': sectionsPayload,
      'dynamic_fields': dynamicFieldsPayload,
      if (_templateData.templateKey != null &&
          _templateData.templateKey!.isNotEmpty)
        'template_key': _templateData.templateKey,
    };
  }

  void _insertDynamicField(int sectionIndex, String fieldKey) {
    final currentContent = _templateData.sections[sectionIndex].defaultContent ?? '';
    final newContent = '$currentContent\n\n{{$fieldKey}}';
    _updateSection(sectionIndex, 'defaultContent', newContent);
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

  String _resolveSectionKey(String? key, String title, int order) {
    if (key != null && key.isNotEmpty) {
      return key;
    }
    final slug = _slugify(title);
    if (slug.isEmpty) {
      return 'section_$order';
    }
    return '${slug}_$order';
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildTemplateInfoCard(),
                    const SizedBox(height: 16),
                    _buildDynamicFieldsCard(),
                    const SizedBox(height: 16),
                    _buildSectionsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.templateId != null ? 'Edit Template' : 'Create Template',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                'Design reusable templates with dynamic fields',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _saveTemplate(false),
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save Draft'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () => _saveTemplate(true),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Submit for Approval'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTemplateInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Template Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Template Name *'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'e.g., Standard Consulting Proposal',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Template Type *'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _templateData.templateType,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'proposal', child: Text('Proposal')),
                          DropdownMenuItem(value: 'sow', child: Text('Statement of Work')),
                          DropdownMenuItem(value: 'rfi', child: Text('RFI Response')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _templateData = _templateData.copyWith(templateType: value!);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Describe when to use this template...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tags'),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., consulting, enterprise, proposal',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Make this template public'),
              subtitle: const Text('Public templates are available to all users in the organization'),
              value: _templateData.isPublic,
              onChanged: (value) {
                setState(() {
                  _templateData = _templateData.copyWith(isPublic: value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicFieldsCard() {
    return Card(
      elevation: 4,
      child: ExpansionTile(
        title: const Text('Dynamic Fields Reference'),
        subtitle: const Text('Click to view available dynamic fields'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _defaultDynamicFields.map((field) {
              return Chip(
                label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(field.fieldName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Key: ${field.fieldKey}', style: const TextStyle(fontSize: 11)),
                    Text('Source: ${field.source}', style: const TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  final customField = DynamicField(
                    fieldName: 'Custom Field',
                    fieldKey: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    source: 'custom',
                    description: 'Custom dynamic field',
                  );
                  _templateData = _templateData.copyWith(
                    dynamicFields: [..._templateData.dynamicFields, customField],
                  );
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Field'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Template Sections',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Chip(label: Text('${_templateData.sections.length} sections')),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addSection,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Section'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _templateData.sections.isEmpty
                ? _buildEmptySections()
                : ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _templateData.sections.length,
                    onReorder: _reorderSections,
                    itemBuilder: (context, index) {
                      final section = _templateData.sections[index];
                      return Card(
                        key: ValueKey(section.key),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(text: section.title),
                                      decoration: const InputDecoration(
                                        labelText: 'Section Title',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) => _updateSection(index, 'title', value),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    children: [
                                      Switch(
                                        value: section.required,
                                        onChanged: (value) => _updateSection(index, 'required', value),
                                      ),
                                      const Text('Required'),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteSection(index),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: TextEditingController(text: section.defaultContent ?? ''),
                                decoration: const InputDecoration(
                                  labelText: 'Default Content',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                                maxLines: 6,
                                onChanged: (value) => _updateSection(index, 'defaultContent', value),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: PopupMenuButton<String>(
                                  onSelected: (value) => _insertDynamicField(index, value),
                                  itemBuilder: (context) {
                                    return _templateData.dynamicFields.map((field) {
                                      return PopupMenuItem(
                                        value: field.fieldKey,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(field.fieldName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text('Key: ${field.fieldKey}'),
                                            Text('Source: ${field.source}'),
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  },
                                  child: const Text('Insert Dynamic Field'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySections() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.description, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No sections yet. Add your first section to get started.',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class TemplateData {
  final String? id;
  final String? templateKey;
  final String status;
  final bool isApproved;
  final String name;
  final String description;
  final String templateType;
  final List<TemplateSection> sections;
  final List<DynamicField> dynamicFields;
  final bool isPublic;
  final String tags;

  TemplateData({
    required this.id,
    required this.templateKey,
    required this.status,
    required this.isApproved,
    required this.name,
    required this.description,
    required this.templateType,
    required this.sections,
    required this.dynamicFields,
    required this.isPublic,
    required this.tags,
  });

  factory TemplateData.fromJson(Map<String, dynamic> json) {
    final sections = (json['sections'] as List?)
            ?.asMap()
            .entries
            .map((entry) => TemplateSection.fromJson(
                  Map<String, dynamic>.from(entry.value as Map),
                  fallbackOrder: entry.key,
                ))
            .toList() ??
        [];
    final dynamicFields = (json['dynamic_fields'] as List?)
            ?.map((field) =>
                DynamicField.fromJson(Map<String, dynamic>.from(field as Map)))
            .toList() ??
        [];

    return TemplateData(
      id: json['id']?.toString(),
      templateKey: json['template_key']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      isApproved: json['is_approved'] ?? false,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      templateType: json['template_type'] ?? 'proposal',
      sections: sections,
      dynamicFields: dynamicFields,
      isPublic: json['is_public'] ?? false,
      tags: json['tags']?.toString() ?? '',
    );
  }

  TemplateData copyWith({
    String? id,
    String? templateKey,
    String? status,
    bool? isApproved,
    String? name,
    String? description,
    String? templateType,
    List<TemplateSection>? sections,
    List<DynamicField>? dynamicFields,
    bool? isPublic,
    String? tags,
  }) {
    return TemplateData(
      id: id ?? this.id,
      templateKey: templateKey ?? this.templateKey,
      status: status ?? this.status,
      isApproved: isApproved ?? this.isApproved,
      name: name ?? this.name,
      description: description ?? this.description,
      templateType: templateType ?? this.templateType,
      sections: sections ?? this.sections,
      dynamicFields: dynamicFields ?? this.dynamicFields,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
    );
  }
}

class TemplateSection {
  final String key;
  final String title;
  final bool required;
  final String? defaultContent;
  final int order;

  TemplateSection({
    required this.key,
    required this.title,
    required this.required,
    this.defaultContent,
    required this.order,
  });

  factory TemplateSection.fromJson(Map<String, dynamic> json,
      {int fallbackOrder = 0}) {
    return TemplateSection(
      key: json['key']?.toString() ??
          'section_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Untitled Section',
      required: json['required'] ?? false,
      defaultContent: json['content'] ?? json['body'],
      order: json['order'] ?? fallbackOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'required': required,
      'content': defaultContent ?? '',
      'order': order,
    };
  }

  TemplateSection copyWithField(String field, dynamic value) {
    switch (field) {
      case 'title':
        return copyWith(title: value);
      case 'required':
        return copyWith(required: value);
      case 'defaultContent':
        return copyWith(defaultContent: value);
      case 'order':
        return copyWith(order: value);
      default:
        return this;
    }
  }

  TemplateSection copyWith({
    String? key,
    String? title,
    bool? required,
    String? defaultContent,
    int? order,
  }) {
    return TemplateSection(
      key: key ?? this.key,
      title: title ?? this.title,
      required: required ?? this.required,
      defaultContent: defaultContent ?? this.defaultContent,
      order: order ?? this.order,
    );
  }
}

class DynamicField {
  final String fieldName;
  final String fieldKey;
  final String source;
  final String description;

  DynamicField({
    required this.fieldName,
    required this.fieldKey,
    required this.source,
    required this.description,
  });

  factory DynamicField.fromJson(Map<String, dynamic> json) {
    return DynamicField(
      fieldName: json['field_name'] ?? '',
      fieldKey: json['field_key'] ?? '',
      source: json['source'] ?? 'proposal',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      'field_key': fieldKey,
      'source': source,
      'description': description,
    };
  }

  DynamicField copyWith({
    String? fieldName,
    String? fieldKey,
    String? source,
    String? description,
  }) {
    return DynamicField(
      fieldName: fieldName ?? this.fieldName,
      fieldKey: fieldKey ?? this.fieldKey,
      source: source ?? this.source,
      description: description ?? this.description,
    );
  }
}
