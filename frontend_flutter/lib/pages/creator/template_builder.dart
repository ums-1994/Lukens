import 'package:flutter/material.dart';

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
    name: '',
    description: '',
    templateType: 'proposal',
    sections: [],
    dynamicFields: [],
    isPublic: false,
    tags: '',
  );

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
        await Future.delayed(const Duration(seconds: 1));

        final mockTemplate = TemplateData(
          name: 'Standard Consulting Proposal',
          description: 'Comprehensive proposal template for enterprise clients',
          templateType: 'proposal',
          sections: [
            TemplateSection(
              key: 'section_1',
              title: 'Executive Summary',
              required: true,
              defaultContent: 'This proposal outlines our approach to delivering exceptional value...',
              order: 0,
            ),
            TemplateSection(
              key: 'section_2',
              title: 'Company Profile',
              required: true,
              defaultContent: 'Our company brings extensive expertise in...',
              order: 1,
            ),
          ],
          dynamicFields: _defaultDynamicFields,
          isPublic: false,
          tags: 'consulting, technology, enterprise',
        );

        setState(() {
          _templateData = mockTemplate;
          _nameController.text = mockTemplate.name;
          _descriptionController.text = mockTemplate.description;
          _tagsController.text = mockTemplate.tags;
        });
      } else {
        setState(() {
          _templateData = _templateData.copyWith(dynamicFields: _defaultDynamicFields);
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
      await Future.delayed(const Duration(seconds: 2));

      _templateData = _templateData.copyWith(
        name: _nameController.text,
        description: _descriptionController.text,
        tags: _tagsController.text,
      );

      if (submitForApproval) {
        _showSuccess('Template submitted for approval!');
      } else {
        _showSuccess('Template saved successfully!');
      }

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pop(context);
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
            if (widget.templateId != null)
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
  final String name;
  final String description;
  final String templateType;
  final List<TemplateSection> sections;
  final List<DynamicField> dynamicFields;
  final bool isPublic;
  final String tags;

  TemplateData({
    required this.name,
    required this.description,
    required this.templateType,
    required this.sections,
    required this.dynamicFields,
    required this.isPublic,
    required this.tags,
  });

  TemplateData copyWith({
    String? name,
    String? description,
    String? templateType,
    List<TemplateSection>? sections,
    List<DynamicField>? dynamicFields,
    bool? isPublic,
    String? tags,
  }) {
    return TemplateData(
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

  TemplateSection copyWithField(String field, dynamic value) {
    switch (field) {
      case 'title':
        return TemplateSection(
          key: key,
          title: value,
          required: required,
          defaultContent: defaultContent,
          order: order,
        );
      case 'required':
        return TemplateSection(
          key: key,
          title: title,
          required: value,
          defaultContent: defaultContent,
          order: order,
        );
      case 'defaultContent':
        return TemplateSection(
          key: key,
          title: title,
          required: required,
          defaultContent: value,
          order: order,
        );
      case 'order':
        return TemplateSection(
          key: key,
          title: title,
          required: required,
          defaultContent: defaultContent,
          order: value,
        );
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
}
