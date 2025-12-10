import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
// External Dependencies (Keep all original imports)
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
// Core Service Imports
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/asset_service.dart';
import '../../api.dart';
import 'content_library_dialog.dart';
// Refactored Components
import 'mixins/signature_panel_mixin.dart';
import 'mixins/comments_panel_mixin.dart';
import 'widgets/document_toolbar.dart';
import 'widgets/document_sidebar.dart';
import 'widgets/document_area.dart';
// Placeholder Model Import (must be created)
import 'models/document_models.dart'; 


class BlankDocumentEditorPage extends StatefulWidget {
  final String? proposalId;
  final String? proposalTitle;
  final String? initialTitle;
  final Map<String, dynamic>? aiGeneratedSections;
  final bool readOnly; 

  const BlankDocumentEditorPage({
    super.key,
    this.proposalId,
    this.proposalTitle,
    this.initialTitle,
    this.aiGeneratedSections,
    this.readOnly = false,
  });

  @override
  State<BlankDocumentEditorPage> createState() =>
      _BlankDocumentEditorPageState();
}

class _BlankDocumentEditorPageState extends State<BlankDocumentEditorPage>
    with SignaturePanelMixin, CommentsPanelMixin { // Mixins are now imported
  
  // --- STATE VARIABLES (Kept in the main State class) ---
  String? _proposalId; // Internal, mutable proposal ID once we have a record.
  late TextEditingController _titleController;
  late TextEditingController _clientNameController;
  late TextEditingController _clientEmailController;
  
  bool _isSaving = false;
  DateTime? _lastSaved;
  Timer? _debounce;
  
  List<DocumentSection> _sections = []; // Assuming this model is in document_models.dart
  String? _selectedSidebarPanel; // e.g., 'outline', 'comments', 'signatures'
  bool _isGeneratingAI = false;
  bool _isImproving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? 'New Proposal');
    _clientNameController = TextEditingController();
    _clientEmailController = TextEditingController();
    _loadDocument();
    _setupAutoSave();
    // Initialize panel mixins (safe no-ops in current stubs).
    initSignaturePanel();
    initCommentsPanel();

    // Defer any context-dependent initialization to the first frame
    // so that Provider lookups are safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialiseFromProposal();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- CORE LOGIC (Kept in the main State class) ---

  // Very light document loading: start with no sections; real data is loaded
  // from the current proposal or AI-generated sections in `_initialiseFromProposal`.
  void _loadDocument() {
    _sections = [];
  }
  
  // Simple debounce-based auto-save: triggers a save shortly after typing
  // stops in the title field.
  void _setupAutoSave() {
    _titleController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), () {
        _saveDocument(auto: true);
      });
    });
  }

  /// Load initial data either from:
  ///  - AI-generated sections passed in via [widget.aiGeneratedSections], or
  ///  - the currently selected proposal in [AppState], or
  ///  - by matching [widget.proposalId] in the proposals list.
  Future<void> _initialiseFromProposal() async {
    final appState = context.read<AppState>();

    Map<String, dynamic>? proposal = appState.currentProposal;

    // Prefer explicit proposalId if provided
    if (widget.proposalId != null) {
      final id = int.tryParse(widget.proposalId!);
      if (id != null) {
        try {
          // Ensure proposals list is populated
          if (appState.proposals.isEmpty) {
            await appState.fetchProposals();
          }
          proposal = appState.proposals
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (p) => p['id'] == id,
                orElse: () => proposal ?? {},
              );
          if (proposal != null && proposal!.isNotEmpty) {
            appState.currentProposal = proposal;
            _proposalId = proposal!['id']?.toString();
          }
        } catch (_) {
          // Non-fatal: we'll just fall back to whatever is already loaded.
        }
      }
    }

    // If we still don't have a proposal and we're in an editable context,
    // create a new one immediately so that all subsequent saves and
    // content insertions are tied to a real backend record.
    if (proposal == null && !widget.readOnly) {
      try {
        final created = await appState.createProposal(
          _titleController.text.trim().isEmpty
              ? 'New Proposal'
              : _titleController.text.trim(),
          '', // client name can be filled in later
        );
        if (created != null) {
          proposal = created;
          appState.currentProposal = created;
          _proposalId = created['id']?.toString();
        }
      } catch (_) {
        // If creation fails, we still allow editing locally; saving will
        // surface an error to the user.
      }
    } else if (proposal != null && _proposalId == null) {
      _proposalId = proposal['id']?.toString();
    }

    // If AI sections were provided (from the New Proposal flow), use those
    // as the starting point regardless of what's on the server.
    Map<String, dynamic>? sectionsSource = widget.aiGeneratedSections;
    if (sectionsSource == null && proposal != null) {
      final rawSections = proposal['sections'];
      if (rawSections is Map<String, dynamic>) {
        sectionsSource = rawSections;
      } else if (rawSections is String && rawSections.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawSections);
          if (decoded is Map<String, dynamic>) {
            sectionsSource = decoded;
          }
        } catch (_) {
          // Ignore malformed JSON; we'll just start empty.
        }
      }
    }

    setState(() {
      if (proposal != null && proposal.isNotEmpty) {
        final title = proposal['title']?.toString();
        if (title != null && title.isNotEmpty) {
          _titleController.text = title;
        }
      }

      if (sectionsSource != null && sectionsSource!.isNotEmpty) {
        _sections = sectionsSource!.entries
            .map(
              (e) => DocumentSection(
                title: e.key,
                content: e.value?.toString() ?? '',
              ),
            )
            .toList();
      } else if (_sections.isEmpty) {
        // Start with a single blank section to make the UX less confusing.
        _sections = [
          DocumentSection(title: 'Section 1', content: ''),
        ];
      }
    });
  }

  // Placeholder for collaboration dialog
  // The original implementation is likely still valid, but is too large to include.
  // Move this logic to a separate service or utility file if it's still large.
  void _showCollaboratorsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Collaborators'),
        content: const Text('Collaboration management coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Add a blank section to the document.
  void _addEmptySection() {
    setState(() {
      final index = _sections.length + 1;
      _sections.add(
        DocumentSection(
          title: 'Section $index',
          content: '',
        ),
      );
    });
  }

  // Open the content library and insert the selected item as a new section.
  Future<void> _insertFromLibrary() async {
    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => const ContentLibrarySelectionDialog(),
    );

    if (!mounted || selected == null) return;

    final label = (selected['label'] ?? 'Untitled') as String;
    final content = (selected['content'] ?? '').toString();

    setState(() {
      _sections.add(
        DocumentSection(
          title: label,
          content: content,
        ),
      );
    });
  }

  // Insert content-library text into an existing section (used by section card).
  Future<void> _insertFromLibraryIntoSection(int index) async {
    if (index < 0 || index >= _sections.length) return;

    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => const ContentLibrarySelectionDialog(),
    );

    if (!mounted || selected == null) return;

    final content = (selected['content'] ?? '').toString();
    if (content.isEmpty) return;

    setState(() {
      final existing = _sections[index].content;
      final merged = (existing.isEmpty ? '' : '$existing\n\n') + content;
      _sections[index] = DocumentSection(
        title: _sections[index].title,
        content: merged,
      );
    });
  }

  void _deleteSection(int index) {
    if (index < 0 || index >= _sections.length) return;
    setState(() {
      _sections.removeAt(index);
    });
  }

  // Show dialog for AI generation - user describes what they want
  Future<void> _showGenerateAIDialog() async {
    final descriptionController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple),
            SizedBox(width: 8),
            Text('Generate with AI'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe the type of proposal you want to create. Be as specific as possible about the sections, content, and purpose.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'e.g., "A software development proposal for a mobile app with sections for project overview, timeline, budget, and team qualifications"',
                  border: OutlineInputBorder(),
                  labelText: 'Proposal Description',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (descriptionController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (result == true && descriptionController.text.trim().isNotEmpty) {
      await _generateWithAI(descriptionController.text.trim());
    }
  }

  // Generate proposal sections using AI
  Future<void> _generateWithAI(String description) async {
    if (_isGeneratingAI) return;

    setState(() {
      _isGeneratingAI = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating proposal sections with AI...'),
          ],
        ),
      ),
    );

    try {
      final token = AuthService.token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final result = await ApiService.generateFullProposal(
        token: token,
        prompt: description,
        context: {
          'document_title': _titleController.text.trim().isEmpty 
              ? 'New Proposal' 
              : _titleController.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result != null && result['sections'] != null) {
        final sections = result['sections'] as Map<String, dynamic>;
        
        setState(() {
          // Replace existing sections with AI-generated ones
          _sections = sections.entries
              .map(
                (e) => DocumentSection(
                  title: e.key,
                  content: e.value?.toString() ?? '',
                ),
              )
              .toList();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI generated ${sections.length} sections!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Failed to generate proposal sections');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating with AI: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAI = false;
        });
      }
    }
  }

  // Show confirmation dialog for improving content
  Future<void> _showImproveDialog() async {
    if (_sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some sections first before improving.'),
        ),
      );
      return;
    }

    // Check if there are any sections with content
    final sectionsWithContent = _sections.where((s) => s.content.trim().isNotEmpty).length;
    if (sectionsWithContent == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add content to sections before improving.'),
        ),
      );
      return;
    }

    final totalSections = _sections.length;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high, color: Colors.blue),
            SizedBox(width: 8),
            Text('Improve Content'),
          ],
        ),
        content: Text(
          'This will improve all $totalSections section(s) by:\n'
          '• Fixing typos and grammar errors\n'
          '• Improving wording and clarity\n'
          '• Enhancing professional tone\n'
          '• Ensuring consistency\n\n'
          'Your current sections will be saved automatically before improvement.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Improve All Sections'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _improveAllSections();
    }
  }

  // Improve all sections using AI
  Future<void> _improveAllSections() async {
    if (_isImproving || _sections.isEmpty) return;

    setState(() {
      _isImproving = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Saving sections first...'),
          ],
        ),
      ),
    );

    try {
      // First, ensure we have a proposal ID - create one if needed
      if (_proposalId == null || _proposalId!.isEmpty) {
        final appState = context.read<AppState>();
        try {
          final created = await appState.createProposal(
            _titleController.text.trim().isEmpty 
                ? 'New Proposal' 
                : _titleController.text.trim(),
            '', // client name can be filled in later
          );
          if (created != null) {
            _proposalId = created['id']?.toString();
            appState.currentProposal = created;
          }
        } catch (e) {
          print('Warning: Could not create proposal before improvement: $e');
        }
      }
      
      // Save the document to ensure all sections are persisted
      await _saveDocument(auto: true);
      
      if (!mounted) return;
      Navigator.pop(context); // Close "saving" dialog
      
      // Show "improving" dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('Improving ${_sections.length} section(s)...'),
            ],
          ),
        ),
      );

      final token = AuthService.token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final improvedSections = <DocumentSection>[];
      int successCount = 0;
      int failCount = 0;

      // Improve each section - read directly from _sections (current state)
      for (int i = 0; i < _sections.length; i++) {
        final section = _sections[i];
        
        // Skip empty sections
        if (section.content.trim().isEmpty) {
          improvedSections.add(section);
          continue;
        }

        try {
          final result = await ApiService.improveContent(
            token: token,
            content: section.content,
            sectionType: section.title.toLowerCase().replaceAll(' ', '_'),
          );

          if (result != null && result['improved_version'] != null) {
            improvedSections.add(
              DocumentSection(
                title: section.title,
                content: result['improved_version'] as String,
              ),
            );
            successCount++;
          } else {
            // If improvement fails, keep original
            improvedSections.add(section);
            failCount++;
          }
        } catch (e) {
          // If improvement fails for a section, keep original
          improvedSections.add(section);
          failCount++;
          print('Error improving section "${section.title}": $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      setState(() {
        _sections = improvedSections;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  failCount > 0
                      ? 'Improved $successCount section(s). $failCount section(s) could not be improved.'
                      : 'Successfully improved all $successCount section(s)!',
                ),
              ),
            ],
          ),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error improving content: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImproving = false;
        });
      }
    }
  }

  Future<void> _saveDocument({bool auto = false}) async {
    if (widget.readOnly) return;

    final appState = context.read<AppState>();

    // Determine the proposal ID: prefer internal _proposalId, then
    // fall back to widget.proposalId and currentProposal in AppState.
    String? proposalId = _proposalId ?? widget.proposalId;
    final current = appState.currentProposal;
    if ((proposalId == null || proposalId.isEmpty) && current != null) {
      final idVal = current['id'];
      if (idVal != null) {
        proposalId = idVal.toString();
        _proposalId = proposalId;
      }
    }

    if (proposalId == null || proposalId.isEmpty) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No proposal to save. Please create a proposal first.'),
          ),
        );
      }
      return;
    }

    final title = _titleController.text.trim();

    // Convert sections list into a map keyed by section title.
    final Map<String, String> sectionsPayload = {};
    for (final section in _sections) {
      final key = section.title.trim();
      if (key.isNotEmpty) {
        sectionsPayload[key] = section.content;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await appState.updateProposal(proposalId, {
        if (title.isNotEmpty) 'title': title,
        'sections': sectionsPayload,
      });

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _lastSaved = DateTime.now();
      });

      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposal saved')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving proposal: $e')),
        );
      }
    }
  }

  Future<void> _sendForSignature() async {
    final idString = widget.proposalId;
    final parsedId = idString != null ? int.tryParse(idString) : null;
    if (parsedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save this proposal first before sending for signature.'),
        ),
      );
      return;
    }

    final name = _clientNameController.text.trim();
    final email = _clientEmailController.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Client name and email are required for DocuSign.'),
        ),
      );
      return;
    }

    final appState = context.read<AppState>();
    try {
      final result = await appState.sendProposalForSignature(
        proposalId: parsedId,
        signerName: name,
        signerEmail: email,
        returnUrl:
            'http://localhost:8081/#/proposals/$parsedId?signed=true',
      );
      if (result != null && result['signing_url'] != null) {
        final url = result['signing_url'].toString();
        // You already use this in preview_page.dart; import if wired here later.
        // await launchUrlString(url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('DocuSign envelope created. Check console/logs for URL.'),
          ),
        );
        debugPrint('DocuSign signing URL: $url');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create DocuSign envelope.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending for signature: $e'),
        ),
      );
    }
  }

  // --- MISSING BUILD METHOD (Crucial Fix) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. TOOLBAR (Extracted to DocumentToolbar)
          DocumentToolbar(
            titleController: _titleController,
            isSaving: _isSaving,
            lastSaved: _lastSaved,
            onSave: () => _saveDocument(auto: false),
            onCollaboratorsTap: _showCollaboratorsDialog,
            onLibraryTap: _insertFromLibrary,
            onGenerateWithAI: widget.readOnly ? null : _showGenerateAIDialog,
            onImprove: widget.readOnly ? null : _showImproveDialog,
            readOnly: widget.readOnly,
          ),
          
          // 2. MAIN WORKSPACE (Flexible space for content)
          Expanded(
            child: Row(
              children: [
                // 2a. DOCUMENT AREA (Extracted to DocumentArea)
                Expanded(
                  child: DocumentArea(
                    sections: _sections,
                    readOnly: widget.readOnly,
                    onAddSection: _addEmptySection,
                    onTitleChanged: (index, value) {
                      setState(() {
                        _sections[index] =
                            DocumentSection(title: value, content: _sections[index].content);
                      });
                    },
                    onContentChanged: (index, value) {
                      setState(() {
                        _sections[index] =
                            DocumentSection(title: _sections[index].title, content: value);
                      });
                    },
                    onDeleteSection: _deleteSection,
                    onInsertFromLibrary: _insertFromLibraryIntoSection,
                  ),
                ),

                // 2b. SIDEBAR (Extracted to DocumentSidebar)
                DocumentSidebar(
                  selectedPanel: _selectedSidebarPanel,
                  onPanelSelected: (panel) {
                    setState(() {
                      _selectedSidebarPanel =
                          (panel == _selectedSidebarPanel) ? null : panel;
                    });
                  },
                  signaturePanelContent: buildSignaturePanel(
                    context,
                    onSendForSignature: _sendForSignature,
                  ),
                  commentsPanelContent: buildCommentsPanel(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}