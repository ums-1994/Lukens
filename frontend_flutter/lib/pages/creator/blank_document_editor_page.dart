import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'content_library_dialog.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/asset_service.dart';
import '../../api.dart';
import '../../theme/premium_theme.dart';
import '../../utils/html_content_parser.dart';

class BlankDocumentEditorPage extends StatefulWidget {
  final String? proposalId;
  final String? proposalTitle;
  final String? initialTitle;
  final Map<String, dynamic>? aiGeneratedSections;
  final bool readOnly; // For approver view-only mode

  const BlankDocumentEditorPage({
    super.key,
    this.proposalId,
    this.proposalTitle,
    this.initialTitle,
    this.aiGeneratedSections,
    this.readOnly = false, // Default to editable
  });

  @override
  State<BlankDocumentEditorPage> createState() =>
      _BlankDocumentEditorPageState();
}

class _BlankDocumentEditorPageState extends State<BlankDocumentEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _clientNameController;
  late TextEditingController _clientEmailController;
  bool _isSaving = false;
  DateTime? _lastSaved;
  List<_DocumentSection> _sections = [];
  int _hoveredSectionIndex = -1;
  int _selectedSectionIndex =
      0; // Track which section is selected for content insertion
  String _selectedCurrency = 'Rand (ZAR)';
  List<String> _uploadedImages = [];
  List<Map<String, dynamic>> _libraryImages = [];
  bool _isLoadingLibraryImages = false;
  bool _showCommentsPanel = false; // Toggle right-side comment panel visibility
  bool _isSettingsCollapsed = false;

  // Formatting state
  String _selectedTextStyle = 'Normal Text';
  String _selectedFont = 'Plus Jakarta Sans';
  String _selectedFontSize = '12px';
  String _selectedAlignment = 'left';
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;

  // Document settings
  String _pageSize = 'A4';
  String _pageMargin = '1.0 in';
  String _backgroundStyle = 'None';
  bool _showWatermark = false;
  String _numberFormat = '1,234.00';
  Color _brandPrimary = const Color(0xFF0F172A);

  // Sidebar state
  bool _isSidebarCollapsed = false;

  List<Map<String, dynamic>> _comments = [];
  late TextEditingController _commentController;
  final FocusNode _commentFocusNode = FocusNode();
  String _commentFilterStatus = 'all';
  String _highlightedText = '';
  int? _selectedSectionForComment;
  List<Map<String, dynamic>> _collaborators = [];
  bool _isCollaborating = false;

  // Auto-save and versioning
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  List<Map<String, dynamic>> _versionHistory = [];
  int _currentVersionNumber = 1;
  Timer? _mentionDebounce;
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _isSearchingMentions = false;
  int _mentionStartIndex = -1;
  String _mentionQuery = '';

  // Backend integration
  dynamic _savedProposalId; // Store the actual backend proposal ID (int or UUID)
  String? _authToken;
  String? _proposalStatus; // draft, Pending CEO Approval, Sent to Client, etc.

  @override
  void initState() {
    super.initState();

    print('📄 BlankDocumentEditorPage initState');
    print('   proposalId: ${widget.proposalId}');
    print('   proposalTitle: ${widget.proposalTitle}');
    print('   initialTitle: ${widget.initialTitle}');

    _titleController = TextEditingController(
      text: widget.initialTitle ?? widget.proposalTitle ?? 'Untitled Document',
    );
    _clientNameController = TextEditingController();
    _clientEmailController = TextEditingController();
    _commentController = TextEditingController();
    _commentController.addListener(_handleCommentTextChanged);
    _commentFocusNode.addListener(_handleCommentFocusChange);

    // Check if AI-generated sections are provided
    if (widget.aiGeneratedSections != null &&
        widget.aiGeneratedSections!.isNotEmpty) {
      // Populate sections from AI-generated content
      widget.aiGeneratedSections!.forEach((title, content) {
        final section = _DocumentSection(
          title: title,
          content: content as String,
        );
        _sections.add(section);

        // Add focus listeners
        section.contentFocus.addListener(() => setState(() {}));
        section.titleFocus.addListener(() => setState(() {}));

        // Add auto-save listeners
        section.controller.addListener(_onContentChanged);
        section.titleController.addListener(_onContentChanged);
      });

      _selectedSectionIndex = 0; // Select first section
    } else if (widget.proposalId == null) {
      // Only create initial section for new documents without AI content
      final initialSection = _DocumentSection(
        title: 'Untitled Section',
        content: '',
      );
      _sections.add(initialSection);

      // Add focus listeners for UI updates
      initialSection.contentFocus.addListener(() => setState(() {}));
      initialSection.titleFocus.addListener(() => setState(() {}));
    }

    // Setup auto-save listeners
    _setupAutoSaveListeners();

    // Only create initial version for new documents
    if (widget.proposalId == null) {
      _createVersion(widget.aiGeneratedSections != null
          ? 'AI-generated initial version'
          : 'Initial version');
    }

    // Get auth token and load existing data if editing
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      // Get token from AuthService (backend JWT auth)
      final token = AuthService.token;
      if (token != null && token.isNotEmpty) {
        _authToken = token;
        print('✅ Auth token initialized successfully from AuthService');
        print('Token length: ${token.length}');
      } else {
        print('⚠️ No token in AuthService - user may not be logged in');

        // Try to get from AppState as fallback
        if (mounted) {
          final appState = context.read<AppState>();
          if (appState.authToken != null) {
            _authToken = appState.authToken;
            print('✅ Auth token retrieved from AppState');
          } else {
            print('❌ No auth token found in AppState either');
          }
        }
      }

      // Load existing data if editing an existing proposal
      if (widget.proposalId != null) {
        final proposalId = int.tryParse(widget.proposalId!);
        if (proposalId != null) {
          _savedProposalId = proposalId;
          await _loadProposalFromDatabase(proposalId);
          await _loadVersionsFromDatabase(proposalId);
          await _loadCommentsFromDatabase(proposalId);
        }
      }

      // Load images from content library
      _loadLibraryImages();
    } catch (e) {
      print('❌ Error initializing auth: $e');
    }
  }

  Future<void> _loadLibraryImages() async {
    if (_isLoadingLibraryImages) return;

    setState(() => _isLoadingLibraryImages = true);

    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('⚠️ No token available for loading library images');
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/content?category=Images'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> content = data is Map && data.containsKey('content')
            ? data['content']
            : (data is List ? data : []);

        setState(() {
          _libraryImages = content
              .map((item) => {
                    'id': item['id'],
                    'label': item['label'] ?? 'Untitled',
                    'content': item['content'] ?? '',
                    'public_id': item['public_id'],
                  })
              .toList();
          _isLoadingLibraryImages = false;
        });

        print('✅ Loaded ${_libraryImages.length} images from library');
      } else {
        print('⚠️ Failed to load library images: ${response.statusCode}');
        setState(() => _isLoadingLibraryImages = false);
      }
    } catch (e) {
      print('❌ Error loading library images: $e');
      setState(() => _isLoadingLibraryImages = false);
    }
  }

  Future<void> _loadProposalFromDatabase(int proposalId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;

      print('🔄 Loading proposal content for ID $proposalId...');

      // Get all proposals and find the one we need
      final proposals = await ApiService.getProposals(token);
      final proposal = proposals.firstWhere(
        (p) => p['id'] == proposalId,
        orElse: () => <String, dynamic>{},
      );

      if (proposal.isEmpty) {
        print('⚠️ Proposal $proposalId not found');
        return;
      }

      // Parse the content JSON
      if (proposal['content'] != null) {
        try {
          final contentData = json.decode(proposal['content']);

          setState(() {
            // Set title
            _titleController.text = contentData['title'] ??
                proposal['title'] ??
                'Untitled Document';

            // Load proposal status
            _proposalStatus = proposal['status'] ?? 'draft';

            // Load client information
            _clientNameController.text = proposal['client_name'] ?? '';
            _clientEmailController.text = proposal['client_email'] ?? '';

            // Clear existing sections
            for (var section in _sections) {
              section.controller.dispose();
              section.titleController.dispose();
              section.contentFocus.dispose();
              section.titleFocus.dispose();
            }
            _sections.clear();

            // Load sections from content
            final List<dynamic> savedSections = contentData['sections'] ?? [];
            if (savedSections.isNotEmpty) {
              for (var sectionData in savedSections) {
                final newSection = _DocumentSection(
                  title: sectionData['title'] ?? 'Untitled Section',
                  content: sectionData['content'] ?? '',
                  backgroundColor: sectionData['backgroundColor'] != null
                      ? Color(sectionData['backgroundColor'] as int)
                      : Colors.white,
                  backgroundImageUrl:
                      sectionData['backgroundImageUrl'] as String?,
                  sectionType:
                      sectionData['sectionType'] as String? ?? 'content',
                  isCoverPage: sectionData['isCoverPage'] as bool? ?? false,
                  inlineImages: (sectionData['inlineImages'] as List<dynamic>?)
                      ?.map((img) =>
                          InlineImage.fromJson(img as Map<String, dynamic>))
                      .toList(),
                  tables: (sectionData['tables'] as List<dynamic>?)
                      ?.map((tableData) {
                        try {
                          return tableData is Map<String, dynamic>
                              ? DocumentTable.fromJson(tableData)
                              : DocumentTable.fromJson(
                                  Map<String, dynamic>.from(tableData as Map));
                        } catch (e) {
                          print('⚠️ Error loading table: $e');
                          return DocumentTable();
                        }
                      })
                      .toList() ?? [],
                );
                _sections.add(newSection);

                // Add listeners
                newSection.controller.addListener(_onContentChanged);
                newSection.titleController.addListener(_onContentChanged);

                // Add focus listeners for UI updates
                newSection.contentFocus.addListener(() => setState(() {}));
                newSection.titleFocus.addListener(() => setState(() {}));
              }
            } else {
              // If no sections, create a default one
              final defaultSection = _DocumentSection(
                title: 'Untitled Section',
                content: '',
              );
              _sections.add(defaultSection);
              defaultSection.controller.addListener(_onContentChanged);
              defaultSection.titleController.addListener(_onContentChanged);

              // Add focus listeners for UI updates
              defaultSection.contentFocus.addListener(() => setState(() {}));
              defaultSection.titleFocus.addListener(() => setState(() {}));
            }

            // Load metadata if available
            if (contentData['metadata'] != null) {
              final metadata = contentData['metadata'];
              _selectedCurrency = metadata['currency'] ?? _selectedCurrency;
            }
          });

          print('✅ Loaded proposal content with ${_sections.length} sections');
        } catch (e) {
          print('⚠️ Error parsing proposal content: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error loading proposal: $e');
    }
  }

  Future<void> _loadVersionsFromDatabase(int proposalId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;

      print('🔄 Loading versions for proposal $proposalId...');
      final versions = await ApiService.getVersions(
        token: token,
        proposalId: proposalId,
      );

      if (versions.isNotEmpty) {
        setState(() {
          _versionHistory.clear();
          for (var version in versions.reversed) {
            // Parse the content JSON back to title and sections
            try {
              final contentMap = json.decode(version['content']);
              _versionHistory.add({
                'version_number': version['version_number'],
                'timestamp': version['created_at'],
                'title': contentMap['title'] ?? '',
                'sections': contentMap['sections'] ?? [],
                'change_description': version['change_description'],
                'author': version['created_by_name'] ??
                    version['created_by_email'] ??
                    'User #${version['created_by']}',
              });
            } catch (e) {
              print('⚠️ Error parsing version content: $e');
            }
          }
          if (_versionHistory.isNotEmpty) {
            _currentVersionNumber = _versionHistory.last['version_number'] + 1;
          }
        });
        print('✅ Loaded ${versions.length} versions');
      }
    } catch (e) {
      print('⚠️ Error loading versions: $e');
    }
  }

  Future<void> _loadCommentsFromDatabase(int proposalId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ No auth token available for loading comments');
        return;
      }

      print('🔄 Loading comments for proposal $proposalId...');
      final response = await ApiService.getComments(
        token: token,
        proposalId: proposalId,
        status: _commentFilterStatus == 'all' ? null : _commentFilterStatus,
      );

      if (response == null) {
        print('⚠️ No response from comments API');
        return;
      }

      final comments = response['comments'] ?? [];
      final total = response['total'] ?? 0;
      // Note: openCount and resolvedCount are available but not used in this method

      print('📦 Received $total comments (${comments.length} root) from API');

      // Flatten threaded structure for display (convert to flat list with replies nested)
      List<Map<String, dynamic>> flatComments = [];
      
      void addCommentWithReplies(Map<String, dynamic> comment) {
        flatComments.add(comment);
        
        // Add replies if they exist
        final replies = comment['replies'] as List<dynamic>? ?? [];
        for (var reply in replies) {
          addCommentWithReplies(reply as Map<String, dynamic>);
        }
      }

      for (var comment in comments) {
        addCommentWithReplies(comment as Map<String, dynamic>);
      }

      // Always update state, even if empty (to clear old comments)
      setState(() {
        _comments.clear();
        for (var comment in flatComments) {
          _comments.add({
            'id': comment['id'],
            'parent_id': comment['parent_id'],
            'commenter_name': comment['author_name'] ??
                comment['author_username'] ??
                comment['author_email'] ??
                'User #${comment['created_by']}',
            'comment_text': comment['comment_text'],
            'section_index': comment['section_index'],
            'section_name': comment['section_name'],
            'block_type': comment['block_type'],
            'block_id': comment['block_id'],
            'highlighted_text': comment['highlighted_text'],
            'timestamp': comment['created_at'],
            'status': comment['status'] ?? 'open',
            'resolved_by': comment['resolved_by'],
            'resolved_at': comment['resolved_at'],
            'resolver_name': comment['resolver_name'],
            'replies': comment['replies'] ?? [],
          });
        }
      });
      print('✅ Loaded ${flatComments.length} comments (including replies)');

      if (mounted) {
        try {
          await context.read<AppState>().fetchNotifications();
        } catch (e) {
          print('⚠️ Error refreshing notifications: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error loading comments: $e');
    }
  }

  Future<void> _loadCollaborators() async {
    if (_savedProposalId == null) return;

    try {
      final token = await _getAuthToken();
      if (token == null) return;

      print('🔄 Loading collaborators for proposal $_savedProposalId...');
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/proposals/$_savedProposalId/collaborators'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> collaborators = jsonDecode(response.body);
        setState(() {
          _collaborators.clear();
          for (var collab in collaborators) {
            // Handle both 'email' and 'invited_email' fields (backend returns 'email' for both)
            final email = collab['invited_email'] ?? collab['email'] ?? '';
            if (email.isEmpty) {
              print('⚠️ Skipping collaborator without email: ${collab['id']}');
              continue;
            }
            
            // Handle timestamp fields: 'invited_at' for pending invitations, 'joined_at' for active collaborators
            final invitedAt = collab['invited_at'] ?? collab['joined_at'];
            final accessedAt = collab['accessed_at'] ?? collab['last_accessed_at'];
            
            _collaborators.add({
              'id': collab['id'],
              'email': email,
              'name': email.split('@')[0],
              'role': 'Full Access', // All collaborators have full access
              'status': collab['status'] ?? 'pending',
              'invited_at': invitedAt,
              'accessed_at': accessedAt,
            });
          }
          _isCollaborating = _collaborators.isNotEmpty;
        });
        print('✅ Loaded ${_collaborators.length} collaborators');
      } else {
        print('⚠️ Failed to load collaborators: ${response.statusCode} - ${response.body}');
        String errorMsg = 'Failed to load collaborators';
        if (response.statusCode == 401) {
          errorMsg = 'Authentication required to view collaborators';
        } else if (response.statusCode == 403) {
          errorMsg = 'Access denied to view collaborators';
        } else if (response.statusCode == 404) {
          errorMsg = 'Proposal not found';
        }
        print('❌ $errorMsg');
        
        // Clear collaborators on error to avoid stale data
        setState(() {
          _collaborators.clear();
          _isCollaborating = false;
        });
      }
    } catch (e) {
      print('⚠️ Error loading collaborators: $e');
      print('⚠️ Error details: ${e.toString()}');
      // Don't show error to user as this is called automatically
      // Errors will be visible in console logs
    }
  }

  Future<void> _removeCollaborator(int invitationId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;

      final response = await http.delete(
        Uri.parse('$baseUrl/api/collaborations/$invitationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _loadCollaborators();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collaborator removed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing collaborator: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _getAuthToken() async {
    // Try to get cached token first
    if (_authToken != null && _authToken!.isNotEmpty) {
      print('Using cached auth token');
      return _authToken;
    }

    // Try to get from AuthService
    final token = AuthService.token;
    if (token != null && token.isNotEmpty) {
      _authToken = token;
      print('✅ Got auth token from AuthService');
      return _authToken;
    }

    // Try to get from AppState as fallback
    if (mounted) {
      try {
        final appState = context.read<AppState>();
        if (appState.authToken != null && appState.authToken!.isNotEmpty) {
          _authToken = appState.authToken;
          print('✅ Got auth token from AppState');
          return _authToken;
        }
      } catch (e) {
        print('Error getting token from AppState: $e');
      }
    }

    print('❌ Cannot get auth token - user not logged in');
    return null;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _commentController.removeListener(_handleCommentTextChanged);
    _commentController.dispose();
    _commentFocusNode.removeListener(_handleCommentFocusChange);
    _commentFocusNode.dispose();
    _mentionDebounce?.cancel();
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
      final newSection = _DocumentSection(
        title: 'Untitled Section',
        content: '',
      );
      _sections.insert(afterIndex + 1, newSection);

      // Add listeners to new section
      newSection.controller.addListener(_onContentChanged);
      newSection.titleController.addListener(_onContentChanged);

      // Add focus listeners for UI updates
      newSection.contentFocus.addListener(() => setState(() {}));
      newSection.titleFocus.addListener(() => setState(() {}));
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

  void _duplicateSection(int index) {
    if (index < 0 || index >= _sections.length) return;
    final section = _sections[index];
    final duplicated = _DocumentSection(
      title: '${section.title} Copy',
      content: section.controller.text,
      backgroundColor: section.backgroundColor,
      backgroundImageUrl: section.backgroundImageUrl,
      sectionType: section.sectionType,
      isCoverPage: section.isCoverPage,
      inlineImages: section.inlineImages
          .map((img) => InlineImage(
                url: img.url,
                width: img.width,
                height: img.height,
                x: img.x,
                y: img.y,
              ))
          .toList(),
      tables: section.tables
          .map(
            (table) => DocumentTable(
              type: table.type,
              cells: table.cells
                  .map((row) => row.map((cell) => cell).toList())
                  .toList(),
              vatRate: table.vatRate,
            ),
          )
          .toList(),
    );

    setState(() {
      _sections.insert(index + 1, duplicated);
      _selectedSectionIndex = index + 1;
    });
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
    if (_sections.isEmpty || _selectedSectionIndex >= _sections.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a section first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
        final controller = currentSection.controller;
        
        // Parse content before setState to determine what we're inserting
        String textToInsert = content;
        List<DocumentTable> tablesToInsert = [];
        
        if (!isUrl) {
          // Check if content contains HTML (has HTML tags)
          final hasHtmlTags = RegExp(r'<[^>]+>').hasMatch(content);
          
          if (hasHtmlTags) {
            // Parse HTML content - strip comments, extract tables, strip tags
            final parsedContent = HtmlContentParser.parseContent(content);
            textToInsert = parsedContent.plainText;
            tablesToInsert = parsedContent.tables;
            
            // Remove table placeholders from text if any
            textToInsert = textToInsert.replaceAll(
              RegExp(r'\[TABLE_PLACEHOLDER_\d+\]'),
              '',
            );
          }
        } else {
          // If it's a URL (like a document), add it as a reference link
          textToInsert = '[📎 Document: $title]($content)';
        }
        
        setState(() {
          // Insert at cursor position if available, otherwise append
          final text = controller.text;
          final selection = controller.selection;
          
          if (selection.isValid && selection.start >= 0 && selection.start <= text.length) {
            // Insert at cursor position
            final before = text.substring(0, selection.start);
            final after = text.substring(selection.end);
            final separator = before.isNotEmpty && after.isNotEmpty ? '\n\n' : '';
            controller.text = '$before$separator$textToInsert$after';
            // Set cursor after inserted content
            final newPosition = selection.start + separator.length + textToInsert.length;
            controller.selection = TextSelection.collapsed(offset: newPosition);
          } else {
            // Append to end
            if (text.isEmpty) {
              controller.text = textToInsert;
            } else {
              controller.text = '$text\n\n$textToInsert';
            }
          }
          
          // Add tables to the section's tables list
          if (tablesToInsert.isNotEmpty) {
            currentSection.tables.addAll(tablesToInsert);
          }
        });

        final tablesCount = tablesToInsert.isNotEmpty ? ' (${tablesToInsert.length} table${tablesToInsert.length > 1 ? 's' : ''})' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Inserted "${isUrl ? 'Document: ' : ''}$title" into section$tablesCount'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  String _getCommenterName() {
    // Get user from AppState (same as dashboard)
    if (!mounted) return 'User';
    final app = context.read<AppState>();
    final user = app.currentUser;

    if (user == null) return 'User';

    // Try different possible field names for the user's name
    String? name = user['full_name'] ??
        user['first_name'] ??
        user['name'] ??
        user['username'];

    // If still no name, try to extract from email
    if (name == null || name.isEmpty) {
      final email = user['email'] as String?;
      if (email != null && email.isNotEmpty) {
        name = email.split('@')[0];
      }
    }

    return name ?? 'User';
  }

  String _getUserInitials() {
    // Get user from AppState (same as dashboard)
    if (!mounted) return 'U';
    final app = context.read<AppState>();
    final user = app.currentUser;

    if (user == null) return 'U';

    // Try to get full name first
    final fullName = user['full_name'] as String?;
    if (fullName != null && fullName.isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.length >= 2) {
        // First and last name initials
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      } else if (parts.length == 1) {
        // Just first letter if single name
        return parts.first[0].toUpperCase();
      }
    }

    // Try first name
    final firstName = user['first_name'] as String?;
    if (firstName != null && firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    }

    // Try username
    final username = user['username'] as String?;
    if (username != null && username.isNotEmpty) {
      return username[0].toUpperCase();
    }

    // Try email
    final email = user['email'] as String?;
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }

    return 'U';
  }

  void _handleCommentFocusChange() {
    if (!_commentFocusNode.hasFocus) {
      _clearMentionState();
    }
  }

  void _handleCommentTextChanged() {
    if (!_commentFocusNode.hasFocus) {
      _clearMentionState();
      return;
    }

    final selection = _commentController.selection;
    if (!selection.isValid) {
      _clearMentionState();
      return;
    }

    final caretIndex = selection.baseOffset;
    if (caretIndex < 0) {
      _clearMentionState();
      return;
    }

    final text = _commentController.text;
    if (caretIndex > text.length) {
      _clearMentionState();
      return;
    }

    final prefix = text.substring(0, caretIndex);
    final atIndex = prefix.lastIndexOf('@');
    if (atIndex == -1) {
      _clearMentionState();
      return;
    }

    if (atIndex > 0) {
      final charBefore = prefix[atIndex - 1];
      if (!RegExp(r'\s').hasMatch(charBefore)) {
        _clearMentionState();
        return;
      }
    }

    final query = prefix.substring(atIndex + 1);
    if (query.contains(
        RegExp('[\\s@#\$%^&*()+\\-=/\\\\{}\\[\\]|;:\'",<>?]'))) {
      _clearMentionState();
      return;
    }

    final suffix = text.substring(caretIndex);
    if (suffix.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_.]*').hasMatch(suffix[0])) {
      _clearMentionState();
      return;
    }

    if (!RegExp(r'^[A-Za-z0-9_.]*$').hasMatch(query)) {
      _clearMentionState();
      return;
    }

    if (_mentionStartIndex != atIndex || _mentionQuery != query) {
      setState(() {
        _mentionStartIndex = atIndex;
        _mentionQuery = query;
      });
    }

    _mentionDebounce?.cancel();

    _mentionDebounce = Timer(const Duration(milliseconds: 250), () {
      _loadMentionSuggestions(query);
    });
  }

  void _clearMentionState() {
    if (_mentionSuggestions.isEmpty &&
        _mentionStartIndex == -1 &&
        _mentionQuery.isEmpty &&
        !_isSearchingMentions) {
      return;
    }
    setState(() {
      _mentionSuggestions = [];
      _mentionStartIndex = -1;
      _mentionQuery = '';
      _isSearchingMentions = false;
    });
  }

  Future<void> _loadMentionSuggestions(String query) async {
    final currentQuery = query;
    final token = await _getAuthToken();
    if (token == null) {
      return;
    }

    setState(() {
      _isSearchingMentions = true;
    });

    try {
      final results = await ApiService.searchUsers(
        authToken: token,
        query: currentQuery,
        proposalId: _savedProposalId,
      );

      if (!mounted || _mentionQuery != currentQuery) {
        return;
      }

      final suggestions = results
          .map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            }
            if (item is Map) {
              return item.cast<String, dynamic>();
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .where((user) =>
              (user['username']?.toString().isNotEmpty ?? false) ||
              (user['email']?.toString().isNotEmpty ?? false))
          .toList();

      setState(() {
        _mentionSuggestions = suggestions;
        _isSearchingMentions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mentionSuggestions = [];
        _isSearchingMentions = false;
      });
      print('⚠️ Error loading mention suggestions: $e');
    }
  }

  void _insertMention(Map<String, dynamic> user) {
    if (_mentionStartIndex == -1) return;

    String mentionKey =
        (user['username']?.toString().trim() ?? '').replaceAll(' ', '');
    if (mentionKey.isEmpty) {
      final email = user['email']?.toString() ?? '';
      if (email.contains('@')) {
        mentionKey = email.split('@').first;
      }
    }

    mentionKey = mentionKey.replaceAll(RegExp(r'[^A-Za-z0-9_.]'), '');
    if (mentionKey.isEmpty) {
      return;
    }

    final text = _commentController.text;
    final selection = _commentController.selection;
    final caretIndex = selection.isValid ? selection.baseOffset : text.length;
    final start = _mentionStartIndex;
    final before = text.substring(0, start);
    final after = caretIndex <= text.length ? text.substring(caretIndex) : '';
    final mentionText = '@$mentionKey ';

    final newText = '$before$mentionText$after';
    _commentController.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: start + mentionText.length),
    );

    setState(() {
      _mentionSuggestions = [];
      _mentionStartIndex = -1;
      _mentionQuery = '';
      _isSearchingMentions = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mentioned @$mentionKey — they will be notified'),
        backgroundColor: const Color(0xFF00BCD4),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildMentionRichText(
    String text, {
    TextStyle? style,
  }) {
    if (text.isEmpty) {
      return Text(
        '',
        style: style ??
            const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF1A1A1A),
            ),
      );
    }

    final defaultStyle = style ??
        const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: Color(0xFF1A1A1A),
        );
    final mentionStyle = defaultStyle.copyWith(
      color: const Color(0xFF00BCD4),
      fontWeight: FontWeight.w600,
    );

    final spans = <TextSpan>[];
    final mentionRegex = RegExp(r'@([A-Za-z0-9_.]+)');
    int lastIndex = 0;

    for (final match in mentionRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: defaultStyle,
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: mentionStyle,
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: defaultStyle,
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: defaultStyle));
    }

    return RichText(
      text: TextSpan(children: spans, style: defaultStyle),
    );
  }

  Future<void> _addComment({int? parentId}) async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_savedProposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the proposal before adding comments'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final commentText = _commentController.text;
    final commenterName = _getCommenterName();
    final sectionName = _selectedSectionForComment != null &&
            _selectedSectionForComment! < _sections.length
        ? (_sections[_selectedSectionForComment!]
                .titleController
                .text
                .isNotEmpty
            ? _sections[_selectedSectionForComment!].titleController.text
            : 'Untitled Section')
        : null;

    // Clear form
    _commentController.clear();
    _clearMentionState();

    // Save comment to database
    try {
      final token = await _getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated. Please log in.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final savedComment = await ApiService.createComment(
        token: token,
        proposalId: _savedProposalId!,
        commentText: commentText,
        sectionIndex: _selectedSectionForComment,
        sectionName: sectionName,
        highlightedText: _highlightedText.isNotEmpty ? _highlightedText : null,
        parentId: parentId,
        blockType: null, // TODO: Add block type support
        blockId: null, // TODO: Add block ID support
      );

      if (savedComment != null) {
        // Reload comments from database to get updated structure
        await _loadCommentsFromDatabase(_savedProposalId!);
        
        // Clear form fields
        setState(() {
          _highlightedText = '';
          _selectedSectionForComment = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(parentId != null 
                ? 'Reply added'
                : 'Comment added by $commenterName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          try {
            await context.read<AppState>().fetchNotifications();
          } catch (e) {
            print('⚠️ Error refreshing notifications after comment: $e');
          }
        }
      } else {
        throw Exception('Failed to save comment');
      }
    } catch (e) {
      print('⚠️ Error saving comment to database: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving comment: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _resolveComment(int commentId) async {
    if (_savedProposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal must be saved to resolve comments'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final token = await _getAuthToken();
      if (token == null) return;

      final success = await ApiService.resolveComment(
        token: token,
        commentId: commentId,
      );

      if (success) {
        // Reload comments to get updated status
        await _loadCommentsFromDatabase(_savedProposalId!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment resolved'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to resolve comment');
      }
    } catch (e) {
      print('⚠️ Error resolving comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving comment: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _reopenComment(int commentId) async {
    if (_savedProposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal must be saved to reopen comments'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final token = await _getAuthToken();
      if (token == null) return;

      final success = await ApiService.reopenComment(
        token: token,
        commentId: commentId,
      );

      if (success) {
        // Reload comments to get updated status
        await _loadCommentsFromDatabase(_savedProposalId!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment reopened'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to reopen comment');
      }
    } catch (e) {
      print('⚠️ Error reopening comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reopening comment: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _archiveProposal() async {
    if (_savedProposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the proposal before archiving'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Confirm archive action
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Proposal'),
        content: const Text(
          'Are you sure you want to archive this proposal? '
          'It will become read-only and will be moved to the archived proposals view. '
          'You can restore it later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated. Please log in.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final result = await ApiService.archiveProposal(
        token: token,
        proposalId: _savedProposalId!,
      );

      if (result != null) {
        setState(() {
          _proposalStatus = 'archived';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proposal archived successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Refresh proposals in AppState
          try {
            await context.read<AppState>().fetchProposals();
          } catch (e) {
            print('⚠️ Error refreshing proposals: $e');
          }

          // Navigate back to proposals page after a delay
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/proposals');
          }
        }
      } else {
        throw Exception('Failed to archive proposal');
      }
    } catch (e) {
      print('⚠️ Error archiving proposal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving proposal: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _restoreProposal() async {
    if (_savedProposalId == null) return;

    // Confirm restore action
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Proposal'),
        content: const Text(
          'Are you sure you want to restore this proposal? '
          'It will become editable again and will be moved back to the active proposals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _getAuthToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not authenticated. Please log in.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final result = await ApiService.restoreProposal(
        token: token,
        proposalId: _savedProposalId!,
      );

      if (result != null) {
        setState(() {
          _proposalStatus = result['status'] ?? 'draft';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proposal restored successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Refresh proposals in AppState
          try {
            await context.read<AppState>().fetchProposals();
          } catch (e) {
            print('⚠️ Error refreshing proposals: $e');
          }
        }
      } else {
        throw Exception('Failed to restore proposal');
      }
    } catch (e) {
      print('⚠️ Error restoring proposal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring proposal: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showReplyDialog(Map<String, dynamic> parentComment) {
    final replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reply to Comment'),
          content: TextField(
            controller: replyController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Type your reply...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (replyController.text.trim().isNotEmpty) {
                  _commentController.text = replyController.text;
                  Navigator.pop(context);
                  await _addComment(parentId: parentComment['id']);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
              ),
              child: const Text('Reply'),
            ),
          ],
        );
      },
    );
  }

  void _deleteComment(int commentId) {
    setState(() {
      _comments.removeWhere((c) => c['id'] == commentId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment deleted'),
        backgroundColor: Color(0xFF1A3A52),
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredComments() {
    if (_commentFilterStatus == 'all') {
      return _comments;
    }
    return _comments.where((c) => c['status'] == _commentFilterStatus).toList();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final DateTime dt = DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Status helper methods
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending ceo approval':
        return const Color(0xFFF39C12); // Orange
      case 'sent to client':
        return const Color(0xFF3498DB); // Blue
      case 'approved':
        return const Color(0xFF2ECC71); // Green
      case 'rejected':
        return const Color(0xFFE74C3C); // Red
      default:
        return const Color(0xFF95A5A6); // Gray
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending ceo approval':
        return Icons.pending;
      case 'sent to client':
        return Icons.send;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending ceo approval':
        return 'Pending Approval';
      case 'sent to client':
        return 'Sent to Client';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Future<bool?> _showClientInfoDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Client Information Required'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide client information before sending for approval:',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _clientNameController,
                decoration: const InputDecoration(
                  labelText: 'Client Name *',
                  hintText: 'e.g., Acme Corporation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _clientEmailController,
                decoration: const InputDecoration(
                  labelText: 'Client Email *',
                  hintText: 'e.g., contact@acme.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              const Text(
                '* When approved, the proposal will be sent to this email',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic),
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
              // Validate inputs
              if (_clientNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter client name'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final email = _clientEmailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter client email'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Basic email validation
              if (!email.contains('@') || !email.contains('.')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email address'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendForApproval() async {
    // First save the document
    if (_hasUnsavedChanges) {
      await _saveToBackend();
    }

    if (_savedProposalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the document before sending for approval'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if client information is provided
    if (_clientNameController.text.trim().isEmpty ||
        _clientEmailController.text.trim().isEmpty) {
      // Show dialog to collect client information
      final clientInfoProvided = await _showClientInfoDialog();
      if (clientInfoProvided != true) return;

      // Save with client info
      await _saveToBackend();
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send for Approval'),
        content: const Text(
          'This will send your proposal to the CEO for approval. '
          'Once approved, it will be automatically sent to the client.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
            ),
            child: const Text('Send for Approval'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse(
            '${ApiService.baseUrl}/api/proposals/$_savedProposalId/send-for-approval'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _proposalStatus = data['status'];
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal sent for approval successfully!'),
              backgroundColor: Color(0xFF2ECC71),
            ),
          );
        }
      } else {
        throw Exception('Failed to send for approval');
      }
    } catch (e) {
      print('❌ Error sending for approval: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send for approval: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Auto-save and versioning methods
  void _setupAutoSaveListeners() {
    // Listen to title changes
    _titleController.addListener(_onContentChanged);

    // Listen to all section changes
    for (var section in _sections) {
      section.controller.addListener(_onContentChanged);
      section.titleController.addListener(_onContentChanged);
    }
  }

  void _onContentChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });

    // Cancel existing timer
    _autoSaveTimer?.cancel();

    // Start new timer (debounced auto-save after 3 seconds of inactivity)
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      if (_hasUnsavedChanges) {
        _autoSaveDocument();
      }
    });
  }

  String _serializeDocumentContent() {
    // Serialize sections into JSON format for backend storage
    final documentData = {
      'title': _titleController.text,
      'sections': _sections
          .map((section) => {
                'title': section.titleController.text,
                'content': section.controller.text,
                'backgroundColor': section.backgroundColor.value,
                'backgroundImageUrl': section.backgroundImageUrl,
                'sectionType': section.sectionType,
                'isCoverPage': section.isCoverPage,
                'inlineImages':
                    section.inlineImages.map((img) => img.toJson()).toList(),
                'tables': section.tables.map((table) => table.toJson()).toList(),
              })
          .toList(),
      'metadata': {
        'currency': _selectedCurrency,
        'version': _currentVersionNumber,
        'last_modified': DateTime.now().toIso8601String(),
      }
    };
    return json.encode(documentData);
  }

  Future<void> _autoSaveDocument() async {
    if (!_hasUnsavedChanges) return;

    setState(() => _isSaving = true);
    try {
      // Save to backend
      await _saveToBackend();

      // Create a new version
      _createVersion('Auto-saved');

      setState(() {
        _lastSaved = DateTime.now();
        _hasUnsavedChanges = false;
      });

      // Show subtle notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Auto-saved • Version $_currentVersionNumber'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 250,
          ),
        );
      }
    } catch (e) {
      final errorMessage = e.toString();
      print('Auto-save error: $errorMessage');

      if (mounted) {
        // Check if it's an authentication error
        if (errorMessage.contains('Not authenticated') ||
            errorMessage.contains('authentication') ||
            errorMessage.contains('Unauthorized')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Not authenticated. Please log in to save your document.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Login',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
          );
        } else {
          // Other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-save failed. Your work is saved locally.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveToBackend() async {
    // Get auth token (fresh or cached)
    final token = await _getAuthToken();

    if (token == null) {
      throw Exception(
          'Not authenticated - Please log in to save your document');
    }

    final title = _titleController.text.isEmpty
        ? 'Untitled Document'
        : _titleController.text;
    final content = _serializeDocumentContent();

    try {
      if (_savedProposalId == null) {
        // Create new proposal
        print('📝 Creating new proposal...');
        final result = await ApiService.createProposal(
          token: token,
          title: title,
          content: content,
          clientName: _clientNameController.text.trim().isEmpty
              ? null
              : _clientNameController.text.trim(),
          clientEmail: _clientEmailController.text.trim().isEmpty
              ? null
              : _clientEmailController.text.trim(),
          status: _proposalStatus ?? 'draft',
        );

        print('🔍 Create proposal result: $result');

        if (result != null && result['id'] != null) {
          final rawId = result['id'];
          final idAsString = rawId.toString();
          if (idAsString.isEmpty) {
            print('⚠️ Proposal creation returned empty ID value');
            throw Exception('Backend did not return a proposal ID');
          }
          setState(() {
            // Store the ID exactly as returned (works for both integers and UUIDs)
            _savedProposalId = idAsString;
          });
          print('✅ Proposal created with ID: $_savedProposalId');
          print(
              '💾 Proposal ID saved in state - future saves will UPDATE this proposal');
        } else {
          print('⚠️ Proposal creation returned null or no ID');
          print('🔍 Full result: $result');
          throw Exception('Failed to create proposal on the server');
        }
      } else {
        // Update existing proposal
        print('🔄 Updating existing proposal ID: $_savedProposalId...');
        final result = await ApiService.updateProposal(
          token: token,
          id: _savedProposalId!,
          title: title,
          content: content,
          clientName: _clientNameController.text.trim().isEmpty
              ? null
              : _clientNameController.text.trim(),
          clientEmail: _clientEmailController.text.trim().isEmpty
              ? null
              : _clientEmailController.text.trim(),
          status: _proposalStatus ?? 'draft',
        );
        print('✅ Proposal updated: $_savedProposalId');
        print('🔍 Update result: $result');
      }
    } catch (e) {
      print('❌ Error saving to backend: $e');
      rethrow;
    }
  }

  Future<void> _createVersion(String changeDescription) async {
    final version = {
      'version_number': _currentVersionNumber,
      'timestamp': DateTime.now().toIso8601String(),
      'title': _titleController.text,
      'sections': _sections
          .map((section) => {
                'title': section.titleController.text,
                'content': section.controller.text,
                'backgroundColor': section.backgroundColor.value,
                'backgroundImageUrl': section.backgroundImageUrl,
                'sectionType': section.sectionType,
                'isCoverPage': section.isCoverPage,
                'inlineImages':
                    section.inlineImages.map((img) => img.toJson()).toList(),
                'tables': section.tables.map((table) => table.toJson()).toList(),
              })
          .toList(),
      'change_description': changeDescription,
      'author': _getCommenterName(),
    };

    setState(() {
      _versionHistory.add(version);
      _currentVersionNumber++;
    });

    // Save version to database if proposal has been saved
    if (_savedProposalId != null) {
      try {
        final token = await _getAuthToken();
        if (token != null) {
          final content = _serializeDocumentContent();
          await ApiService.createVersion(
            token: token,
            proposalId: _savedProposalId!,
            versionNumber: _currentVersionNumber - 1,
            content: content,
            changeDescription: changeDescription,
          );
          print('✅ Version $_currentVersionNumber saved to database');
        }
      } catch (e) {
        print('⚠️ Error saving version to database: $e');
        // Continue silently - version is still in memory
      }
    }
  }

  Future<void> _restoreVersion(int versionNumber) async {
    final version = _versionHistory.firstWhere(
      (v) => v['version_number'] == versionNumber,
      orElse: () => {},
    );

    if (version.isEmpty) return;

    // Restore title
    _titleController.text = version['title'] ?? 'Untitled Template';

    // Clear existing sections
    for (var section in _sections) {
      section.controller.dispose();
      section.titleController.dispose();
      section.contentFocus.dispose();
      section.titleFocus.dispose();
    }
    _sections.clear();

    // Restore sections
    final List<dynamic> savedSections = version['sections'] ?? [];
    for (var sectionData in savedSections) {
      final newSection = _DocumentSection(
        title: sectionData['title'] ?? 'Untitled Section',
        content: sectionData['content'] ?? '',
        backgroundColor: sectionData['backgroundColor'] != null
            ? Color(sectionData['backgroundColor'] as int)
            : Colors.white,
        backgroundImageUrl: sectionData['backgroundImageUrl'] as String?,
        sectionType: sectionData['sectionType'] as String? ?? 'content',
        isCoverPage: sectionData['isCoverPage'] as bool? ?? false,
        inlineImages: (sectionData['inlineImages'] as List<dynamic>?)
            ?.map((img) => InlineImage.fromJson(img as Map<String, dynamic>))
            .toList(),
        tables: (sectionData['tables'] as List<dynamic>?)
            ?.map((tableData) {
              try {
                return tableData is Map<String, dynamic>
                    ? DocumentTable.fromJson(tableData)
                    : DocumentTable.fromJson(
                        Map<String, dynamic>.from(tableData as Map));
              } catch (e) {
                print('⚠️ Error loading table: $e');
                return DocumentTable();
              }
            })
            .toList() ?? [],
      );
      _sections.add(newSection);
    }

    // Setup listeners for new sections
    for (var section in _sections) {
      section.controller.addListener(_onContentChanged);
      section.titleController.addListener(_onContentChanged);

      // Add focus listeners for UI updates
      section.contentFocus.addListener(() => setState(() {}));
      section.titleFocus.addListener(() => setState(() {}));
    }

    setState(() {
      _selectedSectionIndex = 0;
      _hasUnsavedChanges = true;
    });

    // Create a new version for the restoration
    _createVersion('Restored from version $versionNumber');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored to version $versionNumber'),
          backgroundColor: const Color(0xFF00BCD4),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showVersionHistory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history,
                          color: Color(0xFF00BCD4), size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Version History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_versionHistory.length} version${_versionHistory.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // Version list
                Expanded(
                  child: _versionHistory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No version history yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _versionHistory.length,
                          reverse: true,
                          itemBuilder: (context, index) {
                            final version = _versionHistory[
                                _versionHistory.length - 1 - index];
                            final isCurrentVersion =
                                version['version_number'] ==
                                    _currentVersionNumber - 1;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isCurrentVersion
                                    ? const Color(0xFF00BCD4)
                                        .withValues(alpha: 0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCurrentVersion
                                      ? const Color(0xFF00BCD4)
                                      : Colors.grey[300]!,
                                  width: isCurrentVersion ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrentVersion
                                              ? const Color(0xFF00BCD4)
                                              : Colors.grey[600],
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'v${version['version_number']}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isCurrentVersion)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'CURRENT',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      Text(
                                        _formatTimestamp(version['timestamp']),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    version['change_description'] ??
                                        'No description',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'By ${version['author'] ?? 'Unknown'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    version['title'] ?? 'Untitled',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  if (!isCurrentVersion) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _restoreVersion(
                                              version['version_number']);
                                        },
                                        icon:
                                            const Icon(Icons.restore, size: 16),
                                        label: const Text('Restore'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF00BCD4),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(_clearMentionState);
  }

  // Get text alignment based on current selection
  TextAlign _getTextAlignment() {
    switch (_selectedAlignment) {
      case 'left':
        return TextAlign.left;
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  // Get font family name
  String _getFontFamily() {
    return _selectedFont;
  }

  // Get font size as double
  double _getFontSize() {
    final sizeStr = _selectedFontSize.replaceAll('px', '');
    return double.tryParse(sizeStr) ?? 13.0;
  }

  // Get content text style with all formatting applied
  TextStyle _getContentTextStyle() {
    double fontSize = _getFontSize();

    // Adjust font size based on text style
    if (_selectedTextStyle == 'Heading 1') {
      fontSize = 24.0;
    } else if (_selectedTextStyle == 'Heading 2') {
      fontSize = 20.0;
    } else if (_selectedTextStyle == 'Heading 3') {
      fontSize = 16.0;
    } else if (_selectedTextStyle == 'Title') {
      fontSize = 28.0;
    }

    return TextStyle(
      fontSize: fontSize,
      fontFamily: _getFontFamily(),
      fontWeight: _isBold ||
              _selectedTextStyle.contains('Heading') ||
              _selectedTextStyle == 'Title'
          ? FontWeight.w700
          : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration:
          _isUnderlined ? TextDecoration.underline : TextDecoration.none,
      color: const Color(0xFF1A1A1A),
      height: 1.8,
      letterSpacing: 0.2,
    );
  }

  // Get title text style
  TextStyle _getTitleTextStyle() {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      fontFamily: _getFontFamily(),
      color: const Color(0xFF1A1A1A),
      height: 1.4,
    );
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
      // Save to backend
      await _saveToBackend();

      // Create a new version for manual save
      _createVersion('Manual save');

      setState(() {
        _lastSaved = DateTime.now();
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _savedProposalId != null
                        ? 'Document saved successfully • Version $_currentVersionNumber'
                        : 'Document created and saved • Version $_currentVersionNumber',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      final errorMessage = e.toString();
      print('Manual save error: $errorMessage');

      if (mounted) {
        // Check if it's an authentication error
        if (errorMessage.contains('Not authenticated') ||
            errorMessage.contains('authentication') ||
            errorMessage.contains('Unauthorized')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Not authenticated. Please log in to save your document.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Login',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
          );
        } else {
          // Other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error saving document: ${errorMessage.length > 50 ? errorMessage.substring(0, 50) + "..." : errorMessage}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAndClose() async {
    setState(() => _isSaving = true);
    try {
      // Save to backend
      await _saveToBackend();

      // Create a new version
      _createVersion('Manual save');

      setState(() {
        _lastSaved = DateTime.now();
        _hasUnsavedChanges = false;
      });

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Document saved successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // Refresh proposals in AppState before navigating
        if (mounted) {
          final app = Provider.of<AppState>(context, listen: false);
          await app.fetchProposals();
          await app.fetchDashboard();
        }

        // Navigate back to proposals page after a brief delay
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/proposals');
        }
      }
    } catch (e) {
      final errorMessage = e.toString();
      print('Save and close error: $errorMessage');

      if (mounted) {
        // Check if it's an authentication error
        if (errorMessage.contains('Not authenticated') ||
            errorMessage.contains('authentication') ||
            errorMessage.contains('Unauthorized')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Not authenticated. Please log in to save your document.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Login',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ),
          );
        } else {
          // Other errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error saving document: ${errorMessage.length > 50 ? errorMessage.substring(0, 50) + "..." : errorMessage}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if proposal is archived - if so, make it read-only
    final isArchived = _proposalStatus?.toLowerCase() == 'archived';
    final isReadOnly = widget.readOnly || isArchived;
    
    // Show archive banner if archived
    if (isArchived && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.archive, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This proposal is archived and is read-only. Use "More Actions" to restore it.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      });
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(isReadOnly),
            if (!isReadOnly) _buildToolbar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isReadOnly) _buildLeftSidebar(),
                  Expanded(child: _buildDocumentCanvas(isReadOnly)),
                  if (!isReadOnly) _buildRightSidebar(),
                  if (_showCommentsPanel) _buildCommentsPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar() {
    final width = _isSidebarCollapsed ? 90.0 : 280.0;
    final blockItems = [
      {'icon': Icons.text_fields, 'label': 'Text', 'type': 'text'},
      {'icon': Icons.image_outlined, 'label': 'Image', 'type': 'image'},
      {'icon': Icons.videocam_outlined, 'label': 'Video', 'type': 'video'},
      {'icon': Icons.table_chart_outlined, 'label': 'Table', 'type': 'table'},
      {'icon': Icons.price_change_outlined, 'label': 'Pricing', 'type': 'pricing'},
      {'icon': Icons.segment, 'label': 'Section Header', 'type': 'section_header'},
      {'icon': Icons.horizontal_rule, 'label': 'Page Break', 'type': 'page_break'},
      {'icon': Icons.category_outlined, 'label': 'Shapes', 'type': 'shape'},
      {'icon': Icons.library_add_check_outlined, 'label': 'Library', 'type': 'library'},
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: width,
      margin: const EdgeInsets.only(left: 24, top: 16, bottom: 16),
      padding: EdgeInsets.all(_isSidebarCollapsed ? 8 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: _isSidebarCollapsed
          ? Column(
              children: [
                IconButton(
                  onPressed: _toggleSidebar,
                  icon: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  tooltip: 'Expand library',
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: blockItems
                        .map(
                          (block) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Tooltip(
                              message: block['label'] as String,
                              child: InkWell(
                                onTap: () =>
                                    _handleBlockSelected(block['type'] as String),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    block['icon'] as IconData,
                                    color: const Color(0xFF0EA5E9),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.extension, color: Color(0xFF0EA5E9)),
                    const SizedBox(width: 8),
                    const Text(
                      'Block Library',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _toggleSidebar,
                      icon: const Icon(Icons.chevron_left, color: Color(0xFF94A3B8)),
                      tooltip: 'Collapse library',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: blockItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final block = blockItems[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            _handleBlockSelected(block['type'] as String),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                block['icon'] as IconData,
                                size: 26,
                                color: const Color(0xFF0EA5E9),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                block['label'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Document Outline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      final isActive = index == _selectedSectionIndex;
                      String preview =
                          section.controller.text.replaceAll('\\n', ' ').trim();
                      if (preview.isEmpty) preview = 'Add content';
                      if (preview.length > 70) {
                        preview = '${preview.substring(0, 70)}...';
                      }
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSectionIndex = index),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFEEF6FF)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.drag_indicator,
                                      size: 16, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      section.titleController.text.isEmpty
                                          ? 'Untitled Section'
                                          : section.titleController.text,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF475569),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                preview,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
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

  void _toggleSidebar() {
    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
  }

  void _shareDocument() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share workflow coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildTopHeader(bool isReadOnly) {
    final minutesSinceSave = _lastSaved == null
        ? null
        : DateTime.now().difference(_lastSaved!).inMinutes;
    final autosaveLabel = _hasUnsavedChanges
        ? 'Saving...'
        : minutesSinceSave == null
            ? 'Autosave ready'
            : minutesSinceSave == 0
                ? 'Saved moments ago'
                : 'Saved ${minutesSinceSave}m ago';
    final currencies = [
      'Rand (ZAR)',
      'US Dollar (USD)',
      'Euro (EUR)',
      'British Pound (GBP)',
      'Indian Rupee (INR)',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _titleController,
                    enabled: !isReadOnly,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Proposal title',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _onContentChanged(),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasUnsavedChanges ? Icons.sync : Icons.check_circle,
                        size: 16,
                        color: _hasUnsavedChanges
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        autosaveLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                PopupMenuButton<int>(
                  tooltip: 'Version history',
                  enabled: _versionHistory.isNotEmpty,
                  itemBuilder: (context) {
                    if (_versionHistory.isEmpty) {
                      return [];
                    }
                    return _versionHistory.map((version) {
                      return PopupMenuItem<int>(
                        value: version['version_number'] as int? ?? 0,
                        child: Text(
                          "v${version['version_number']} • ${version['change_description'] ?? 'Manual save'}",
                        ),
                      );
                    }).toList();
                  },
                  onSelected: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Version v$value coming soon'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.history, size: 18, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Version history'),
                        SizedBox(width: 4),
                        Icon(Icons.expand_more, size: 18, color: Color(0xFF475569)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                PopupMenuButton<String>(
                  tooltip: 'Select currency',
                  itemBuilder: (context) => currencies
                      .map((currency) => PopupMenuItem<String>(
                            value: currency,
                            child: Text(currency),
                          ))
                      .toList(),
                  onSelected: (value) {
                    setState(() => _selectedCurrency = value);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.currency_exchange,
                            size: 18, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Text(_selectedCurrency),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more, size: 18, color: Color(0xFF475569)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _shareDocument,
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Share'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _showCommentsPanel = !_showCommentsPanel);
                },
                icon: const Icon(Icons.comment_outlined, size: 16),
                label: Text(_showCommentsPanel ? 'Hide comments' : 'Comments'),
              ),
              OutlinedButton.icon(
                onPressed: _showPreview,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview'),
              ),
              ElevatedButton.icon(
                onPressed: isReadOnly ? null : _sendForApproval,
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: const Text('Send for approval'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                onSelected: (value) {
                  switch (value) {
                    case 'duplicate':
                      _duplicateSection(_selectedSectionIndex);
                      break;
                    case 'page':
                      _insertSection(_selectedSectionIndex);
                      break;
                    case 'settings':
                      setState(() => _isSettingsCollapsed = !_isSettingsCollapsed);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'page', child: Text('Add new page')),
                  const PopupMenuItem(value: 'duplicate', child: Text('Duplicate block')),
                  PopupMenuItem(
                    value: 'settings',
                    child: Text(_isSettingsCollapsed
                        ? 'Expand document settings'
                        : 'Collapse document settings'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.more_horiz, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolbarGroup(
              'Text',
              [
                _buildSmallDropdown(_selectedTextStyle, [
                  'Normal Text',
                  'Heading 1',
                  'Heading 2',
                  'Heading 3',
                  'Title'
                ], (value) {
                  setState(() => _selectedTextStyle = value!);
                }),
                _buildSmallDropdown(_selectedFont, [
                  'Plus Jakarta Sans',
                  'Arial',
                  'Times New Roman',
                  'Georgia',
                  'Courier New'
                ], (value) {
                  setState(() => _selectedFont = value!);
                }),
                _buildSmallDropdown(_selectedFontSize, [
                  '10px',
                  '12px',
                  '14px',
                  '16px',
                  '18px',
                  '20px',
                  '24px',
                  '28px'
                ], (value) {
                  setState(() => _selectedFontSize = value!);
                }),
                _buildToolbarIconButton(
                  Icons.format_bold,
                  'Bold',
                  () => setState(() => _isBold = !_isBold),
                  isActive: _isBold,
                ),
                _buildToolbarIconButton(
                  Icons.format_italic,
                  'Italic',
                  () => setState(() => _isItalic = !_isItalic),
                  isActive: _isItalic,
                ),
                _buildToolbarIconButton(
                  Icons.format_underlined,
                  'Underline',
                  () => setState(() => _isUnderlined = !_isUnderlined),
                  isActive: _isUnderlined,
                ),
                _buildToolbarIconButton(
                  Icons.format_color_text,
                  'Text color',
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Text color picker coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                _buildToolbarIconButton(
                  Icons.highlight,
                  'Highlight',
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Highlight picker coming soon'),
                        duration: Duration(seconds: 2),
  Widget _buildDocumentCanvas(bool isReadOnly) {
    final hasContent = _sections.any(
        (section) => section.controller.text.trim().isNotEmpty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                child: Column(
                  children: [
                    if (!hasContent) _buildCanvasPlaceholder(),
                    ..._buildA4Pages(),
                    if (!isReadOnly) ...[
                      const SizedBox(height: 24),
                      _buildAddPageButton(),
                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarGroup(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarIconButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return Material(
      color: isActive ? const Color(0xFFE0F2FE) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isActive ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasPlaceholder() {
    return Container(
      width: 760,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: const [
          Icon(Icons.edit_note, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'Click anywhere to start building your proposal...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add text blocks, media, tables, pricing or import approved content from your library.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSidebar() {
    final width = _isSettingsCollapsed ? 56.0 : 320.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[200]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: _isSettingsCollapsed
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _isSettingsCollapsed = false),
                  icon: const Icon(Icons.tune, color: Color(0xFF64748B)),
                  tooltip: 'Expand settings',
                ),
                const SizedBox(height: 8),
                RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.grey[500],
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Document settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _isSettingsCollapsed = true),
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                        tooltip: 'Collapse settings',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSettingDropdown('Page size', _pageSize, [
                          'A4',
                          'Letter',
                          'Legal',
                        ], (value) => setState(() => _pageSize = value)),
                        _buildSettingDropdown('Margins', _pageMargin, [
                          '0.5 in',
                          '1.0 in',
                          '1.5 in',
                        ], (value) => setState(() => _pageMargin = value)),
                        _buildSettingDropdown('Background / cover', _backgroundStyle, [
                          'None',
                          'Gradient',
                          'Image overlay',
                        ], (value) => setState(() => _backgroundStyle = value)),
                        const SizedBox(height: 20),
                        const Text(
                          'Brand colors',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildColorPalette(),
                        const SizedBox(height: 20),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Watermark'),
                          subtitle:
                              const Text('Show company watermark on every page'),
                          value: _showWatermark,
                          onChanged: (value) => setState(() => _showWatermark = value),
                        ),
                        const SizedBox(height: 8),
                        _buildSettingDropdown('Number formatting', _numberFormat, [
                          '1,234.00',
                          '1.234,00',
                          '1234.00',
                        ], (value) => setState(() => _numberFormat = value)),
                        _buildSettingDropdown('Currency', _selectedCurrency, [
                          'Rand (ZAR)',
                          'US Dollar (USD)',
                          'Euro (EUR)',
                          'British Pound (GBP)',
                        ], (value) => setState(() => _selectedCurrency = value)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSettingDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: options
                .map((option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ))
                .toList(),
            onChanged: (newValue) {
              if (newValue != null) onChanged(newValue);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorPalette() {
    final colors = [
      const Color(0xFF0F172A),
      const Color(0xFF1D4ED8),
      const Color(0xFF0EA5E9),
      const Color(0xFFF97316),
      const Color(0xFF0F766E),
      const Color(0xFFDB2777),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((color) {
        final isSelected = color.value == _brandPrimary.value;
        return GestureDetector(
          onTap: () => setState(() => _brandPrimary = color),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF0EA5E9) : Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }


  void _insertContentIntoSection(String contentType, String content) {
    if (_sections.isEmpty) return;

    final section = _sections[_selectedSectionIndex];
    String newContent = section.controller.text;

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
      case 'section_header':
        newContent += '\n\n=== Section Header ===\n';
        break;
      case 'page_break':
        newContent += '\n\n--- Page Break ---\n';
        break;
    }

    setState(() {
      section.controller.text = newContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$contentType inserted into \"${section.title}\"'),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addPricingTable() {
    if (_sections.isEmpty) return;
    final section = _sections[_selectedSectionIndex];
    setState(() {
      section.tables.add(DocumentTable.priceTable());
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pricing table added to \"${section.title}\"'),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleBlockSelected(String type) {
    switch (type) {
      case 'text':
      case 'image':
      case 'video':
      case 'table':
      case 'shape':
      case 'signature':
      case 'section_header':
      case 'page_break':
        _insertContentIntoSection(type, '');
        break;
      case 'pricing':
        _addPricingTable();
        break;
      case 'library':
        _addFromLibrary();
        break;
    }
  }

  Widget _buildCommentsPanel() {
    // Get root comments (comments without parent_id)
    final rootComments = _comments.where((c) => c['parent_id'] == null).toList();
    final filteredRootComments = _commentFilterStatus == 'all'
        ? rootComments
        : rootComments.where((c) => c['status'] == _commentFilterStatus).toList();
    
    // Sort by newest first
    filteredRootComments.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.now();
      final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    final openCount = _comments.where((c) => c['status'] == 'open' && c['parent_id'] == null).length;
    final resolvedCount = _comments.where((c) => c['status'] == 'resolved' && c['parent_id'] == null).length;

    return Container(
      width: 400,
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A52),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Icon(Icons.comment, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // Comment count badges
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: openCount > 0 ? Colors.orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$openCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: openCount > 0 ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showCommentsPanel = false;
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          // Filter and controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _commentFilterStatus,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('All ($openCount open)')),
                      DropdownMenuItem(value: 'open', child: Text('Open ($openCount)')),
                      DropdownMenuItem(value: 'resolved', child: Text('Resolved ($resolvedCount)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _commentFilterStatus = value;
                        });
                        // Reload comments with new filter
                        if (_savedProposalId != null) {
                          _loadCommentsFromDatabase(_savedProposalId!);
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_savedProposalId != null) {
                      _loadCommentsFromDatabase(_savedProposalId!);
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh comments',
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: filteredRootComments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _comments.isEmpty ? 'No comments yet' : 'No ${_commentFilterStatus == 'all' ? '' : _commentFilterStatus} comments',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _comments.isEmpty 
                            ? 'Add comments to collaborate with your team'
                            : 'Change filter to see other comments',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredRootComments.length,
                    itemBuilder: (context, index) {
                      final comment = filteredRootComments[index];
                      return _buildCommentCard(comment);
                    },
                  ),
          ),
          
          // Add comment form
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
              color: Colors.grey[50],
            ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a comment... (use @ to mention)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    onChanged: (text) {
                      // Handle @mentions detection
                      _handleCommentTextChanged();
                    },
                  ),
                  // @mentions autocomplete dropdown
                  if (_isSearchingMentions && _mentionQuery.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text(
                          'Searching teammates...',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ] else if (_mentionSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _mentionSuggestions.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                        itemBuilder: (context, index) {
                          final user = _mentionSuggestions[index];
                          final name = user['full_name']?.toString() ??
                              user['first_name']?.toString() ??
                              user['email']?.toString() ??
                              'User';
                          final email = user['email']?.toString();
                          final username = user['username']?.toString();
                          return InkWell(
                            onTap: () => _insertMention(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF00BCD4),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '@',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (username != null || email != null)
                                          Text(
                                            [
                                              if (username != null && username.isNotEmpty) '@$username',
                                              if (email != null && email.isNotEmpty) email,
                                            ].join(' • '),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.alternate_email, size: 16, color: Color(0xFF00BCD4)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _commentController.clear();
                          _clearMentionState();
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await _addComment();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Post'),
                      ),
                    ],
                  ),
                ],
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final isResolved = comment['status'] == 'resolved';
    final hasHighlightedText = comment['highlighted_text'] != null &&
        comment['highlighted_text'].toString().isNotEmpty;
    final isReply = comment['parent_id'] != null;
    
    // Get replies for this comment
    final replies = _comments.where((c) => c['parent_id'] == comment['id']).toList();
    replies.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '') ?? DateTime.now();
      final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '') ?? DateTime.now();
      return aTime.compareTo(bTime); // Oldest first for replies
    });
    
    // Determine comment type
    String commentType = 'General';
    if (comment['block_type'] != null) {
      commentType = 'Block';
    } else if (comment['section_name'] != null || comment['section_index'] != null) {
      commentType = 'Section';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12, left: isReply ? 24 : 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isResolved ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isResolved
              ? Colors.grey[300]!
              : const Color(0xFF00BCD4).withOpacity(0.3),
          width: isReply ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment header
          Row(
            children: [
              CircleAvatar(
                radius: isReply ? 12 : 16,
                backgroundColor: const Color(0xFF00BCD4),
                child: Text(
                  comment['commenter_name']
                          ?.toString()
                          .substring(0, 1)
                          .toUpperCase() ??
                      'U',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isReply ? 10 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment['commenter_name'] ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: isReply ? 12 : 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        if (isReply) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTimestamp(comment['timestamp']),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge (only for root comments or if resolved)
              if (!isReply || isResolved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isResolved ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isResolved ? '✓' : 'OPEN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isResolved ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Comment type and location badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (commentType != 'General')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    commentType,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF00BCD4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (comment['section_name'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    comment['section_name'],
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),

          if (comment['section_name'] != null || commentType != 'General')
            const SizedBox(height: 8),

          // Highlighted text
          if (hasHighlightedText) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                comment['highlighted_text'],
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF1A1A1A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Comment text
          _buildMentionRichText(
            comment['comment_text'] ?? '',
            style: TextStyle(
              fontSize: isReply ? 12 : 13,
              color: const Color(0xFF1A1A1A),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 8),

          // Action buttons (only for root comments or if user is author)
          if (!isReply)
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showReplyDialog(comment),
                  icon: const Icon(Icons.reply, size: 14),
                  label: Text('Reply${replies.isNotEmpty ? ' (${replies.length})' : ''}'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00BCD4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (!isResolved)
                  TextButton.icon(
                    onPressed: () => _resolveComment(comment['id']),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Resolve'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _reopenComment(comment['id']),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reopen'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange[700],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),

          // Replies section
          if (replies.isNotEmpty && !isReply) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...replies.map((reply) => _buildCommentCard(reply)),
          ],
        ],
      ),
    );
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 900,
            height: 700,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A52),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Document Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Preview content - Multiple Pages
                Expanded(
                  child: Container(
                    color: const Color(0xFFF5F5F5),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            // Each section is a separate page
                            ..._sections.asMap().entries.map((entry) {
                              final index = entry.key;
                              final section = entry.value;
                              return Container(
                                width: 850,
                                margin: const EdgeInsets.only(bottom: 40),
                                padding: const EdgeInsets.all(60),
                                constraints: const BoxConstraints(
                                  minHeight: 800,
                                ),
                                decoration: BoxDecoration(
                                  color: section.backgroundImageUrl == null
                                      ? section.backgroundColor
                                      : Colors.white,
                                  image: section.backgroundImageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                              section.backgroundImageUrl!),
                                          fit: BoxFit.cover,
                                          opacity: 0.7,
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Section title
                                    Text(
                                      section.titleController.text.isEmpty
                                          ? 'Untitled Section'
                                          : section.titleController.text,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A3A52),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Section content
                                    Text(
                                      section.controller.text.isEmpty
                                          ? '(No content in this section)'
                                          : section.controller.text,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1A1A1A),
                                        height: 1.8,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    if (section.tables.isNotEmpty) ...[
                                      ...section.tables
                                          .map((table) =>
                                              _buildReadOnlyTable(table))
                                          .toList(),
                                      const SizedBox(height: 12),
                                    ],
                                    // Page indicator
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
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
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer with actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Export feature coming soon'),
                              backgroundColor: Color(0xFF00BCD4),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export PDF'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF00BCD4)),
                          foregroundColor: const Color(0xFF00BCD4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3A52),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Close Preview'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAIAssistantDialog() {
    final promptController = TextEditingController();
    String selectedAction =
        'generate'; // 'generate', 'improve', or 'full_proposal'
    String selectedSectionType = 'general';
    bool isGenerating = false;
    TextEditingController? generatedController;
    Map<String, TextEditingController>? generatedSectionControllers;
    String? generationMode; // 'section', 'full', 'improve'
    final BuildContext rootContext = context;

    void resetGeneratedState() {
      generatedController?.dispose();
      generatedController = null;
      if (generatedSectionControllers != null) {
        for (final controller in generatedSectionControllers!.values) {
          controller.dispose();
        }
        generatedSectionControllers = null;
      }
      generationMode = null;
    }

    void applyGeneratedResult(String mode,
        {String? content, Map<String, String>? sections}) {
      if (!mounted) return;
      String message = '';
      setState(() {
        if (mode == 'full' && sections != null) {
          for (var section in _sections) {
            section.controller.dispose();
            section.titleController.dispose();
            section.contentFocus.dispose();
            section.titleFocus.dispose();
          }
          _sections.clear();

          sections.forEach((title, body) {
            final newSection = _DocumentSection(
              title: title,
              content: body,
            );
            _sections.add(newSection);
            newSection.controller.addListener(_onContentChanged);
            newSection.titleController.addListener(_onContentChanged);
            newSection.contentFocus.addListener(() => setState(() {}));
            newSection.titleFocus.addListener(() => setState(() {}));
          });
          _selectedSectionIndex = 0;
          _hasUnsavedChanges = true;
          message =
              'AI drafted proposal inserted. Review and adjust before sending.';
        } else if (content != null) {
          if (_sections.isEmpty) {
            final newSection = _DocumentSection(
              title: 'Untitled Section',
              content: '',
            );
            _sections.add(newSection);
            newSection.controller.addListener(_onContentChanged);
            newSection.titleController.addListener(_onContentChanged);
            newSection.contentFocus.addListener(() => setState(() {}));
            newSection.titleFocus.addListener(() => setState(() {}));
            _selectedSectionIndex = 0;
          }

          final section = _sections[_selectedSectionIndex];
          if (mode == 'improve') {
            section.controller.text = content;
            message = 'AI improvements applied to the selected section.';
          } else {
            if (section.controller.text.trim().isEmpty) {
              section.controller.text = content;
            } else {
              section.controller.text += '\n\n$content';
            }
            message = 'AI drafted content inserted into the section.';
          }
          _hasUnsavedChanges = true;
        }
      });

      if (message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: SizedBox(
                width: 600,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9C27B0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFF9C27B0),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'AI Assistant',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Current section indicator
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2196F3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description,
                                color: Color(0xFF2196F3), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Writing to: Page ${_selectedSectionIndex + 1} - ${_sections[_selectedSectionIndex].titleController.text.isEmpty ? "Untitled Section" : _sections[_selectedSectionIndex].titleController.text}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action selector
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  resetGeneratedState();
                                  selectedAction = 'generate';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: selectedAction == 'generate'
                                      ? const Color(0xFF9C27B0)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedAction == 'generate'
                                        ? const Color(0xFF9C27B0)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.create,
                                      size: 22,
                                      color: selectedAction == 'generate'
                                          ? Colors.white
                                          : Colors.grey[700],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Section',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: selectedAction == 'generate'
                                            ? Colors.white
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  resetGeneratedState();
                                  selectedAction = 'full_proposal';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: selectedAction == 'full_proposal'
                                      ? const Color(0xFF9C27B0)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedAction == 'full_proposal'
                                        ? const Color(0xFF9C27B0)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.description,
                                      size: 22,
                                      color: selectedAction == 'full_proposal'
                                          ? Colors.white
                                          : Colors.grey[700],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Full Proposal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: selectedAction == 'full_proposal'
                                            ? Colors.white
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  resetGeneratedState();
                                  selectedAction = 'improve';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: selectedAction == 'improve'
                                      ? const Color(0xFF9C27B0)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selectedAction == 'improve'
                                        ? const Color(0xFF9C27B0)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.auto_fix_high,
                                      size: 22,
                                      color: selectedAction == 'improve'
                                          ? Colors.white
                                          : Colors.grey[700],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Improve',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: selectedAction == 'improve'
                                            ? Colors.white
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Section type selector (only for single section generation)
                      if (selectedAction == 'generate') ...[
                        Text(
                          'Section Type',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: selectedSectionType,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: [
                            'general',
                            'executive_summary',
                            'introduction',
                            'scope_deliverables',
                            'solution_overview',
                            'delivery_approach',
                            'timeline',
                            'budget',
                            'team',
                            'assumptions',
                            'risks',
                            'company_profile',
                            'conclusion',
                          ].map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(
                                type
                                    .split('_')
                                    .map((word) =>
                                        word[0].toUpperCase() +
                                        word.substring(1))
                                    .join(' '),
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSectionType = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Prompt input
                      Text(
                        selectedAction == 'generate'
                            ? 'What would you like to write?'
                            : selectedAction == 'full_proposal'
                                ? 'Describe your proposal requirements'
                                : 'Current section content will be improved',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: promptController,
                        maxLines: selectedAction == 'full_proposal' ? 6 : 4,
                        decoration: InputDecoration(
                          hintText: selectedAction == 'generate'
                              ? 'E.g., "Write an executive summary about implementing a new CRM system for a retail company"'
                              : selectedAction == 'full_proposal'
                                  ? 'E.g., "Create a proposal for implementing a cloud-based CRM system for a retail company with 50 employees, including data migration, training, and 6-month support"'
                                  : 'Optional: Add instructions for improvement',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),

                      if ((generationMode == 'section' ||
                              generationMode == 'improve') &&
                          generatedController != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          generationMode == 'improve'
                              ? 'Review AI Improvements'
                              : 'AI Draft Preview',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: generatedController,
                          maxLines: 12,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: generationMode == 'improve'
                                ? 'Review the improved draft and make any changes before applying.'
                                : 'Review the AI draft and make changes before inserting.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final edited =
                                  generatedController!.text.trim();
                              if (edited.isEmpty) {
                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Draft cannot be empty. Please provide some content.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              resetGeneratedState();
                              Navigator.of(rootContext).pop();
                              applyGeneratedResult(
                                generationMode == 'improve'
                                    ? 'improve'
                                    : 'section',
                                content: edited,
                              );
                            },
                            icon: Icon(
                              generationMode == 'improve'
                                  ? Icons.auto_fix_high
                                  : Icons.download_done,
                              size: 18,
                            ),
                            label: Text(
                              generationMode == 'improve'
                                  ? 'Apply Improvements'
                                  : 'Insert Draft',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],

                      if (generationMode == 'full' &&
                          generatedSectionControllers != null &&
                          generatedSectionControllers!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'AI Proposal Draft',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: ListView(
                            shrinkWrap: true,
                            children: generatedSectionControllers!.entries
                                .map((entry) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A3A52),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: entry.value,
                                      maxLines: 6,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        hintText:
                                            'Adjust the draft for this section.',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (generatedSectionControllers == null ||
                                  generatedSectionControllers!.isEmpty) {
                                ScaffoldMessenger.of(rootContext)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'No sections available to insert.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              final editedSections = <String, String>{};
                              generatedSectionControllers!.forEach(
                                  (title, controller) {
                                editedSections[title] =
                                    controller.text.trim();
                              });
                              resetGeneratedState();
                              Navigator.of(rootContext).pop();
                              applyGeneratedResult('full',
                                  sections: editedSections);
                            },
                            icon: const Icon(Icons.download_done, size: 18),
                            label: const Text('Insert Proposal Draft'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isGenerating
                                ? null
                                : () {
                                    resetGeneratedState();
                                    Navigator.pop(context);
                                  },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: isGenerating
                                ? null
                                : () async {
                                    if ((selectedAction == 'generate' ||
                                            selectedAction ==
                                                'full_proposal') &&
                                        promptController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(rootContext)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please describe what you want to write'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() {
                                      isGenerating = true;
                                      resetGeneratedState();
                                    });

                                    try {
                                      final token = await _getAuthToken();
                                      if (token == null) {
                                        throw Exception(
                                            'Not authenticated. Please log in.');
                                      }

                                      if (selectedAction == 'generate') {
                                        final result =
                                            await ApiService.generateAIContent(
                                          token: token,
                                          prompt: promptController.text,
                                          context: {
                                            'document_title':
                                                _titleController.text,
                                            'current_section':
                                                _selectedSectionIndex,
                                          },
                                          sectionType: selectedSectionType,
                                        );

                                        if (result != null &&
                                            result['content'] != null) {
                                          final generatedText =
                                              (result['content'] as String)
                                                  .trim();
                                          if (generatedText.isEmpty) {
                                            throw Exception(
                                                'AI returned an empty draft.');
                                          }
                                          setDialogState(() {
                                            generatedController?.dispose();
                                            generatedController =
                                                TextEditingController(
                                                    text: generatedText);
                                            if (generatedSectionControllers !=
                                                null) {
                                              for (final controller
                                                  in generatedSectionControllers!
                                                      .values) {
                                                controller.dispose();
                                              }
                                            }
                                            generatedSectionControllers = null;
                                            generationMode = 'section';
                                          });
                                          ScaffoldMessenger.of(rootContext)
                                                .showSnackBar(
                                              const SnackBar(
                                              content: Text(
                                                  'Draft ready. Review and edit below before inserting.'),
                                              backgroundColor:
                                                  Color(0xFF00BCD4),
                                            ),
                                          );
                                        } else {
                                          throw Exception(
                                              'Failed to generate content.');
                                        }
                                      } else if (selectedAction ==
                                          'full_proposal') {
                                        final result = await ApiService
                                            .generateFullProposal(
                                          token: token,
                                          prompt: promptController.text,
                                          context: {
                                            'document_title':
                                                _titleController.text,
                                          },
                                        );

                                        if (result != null &&
                                            result['sections'] is Map) {
                                          final Map<String, dynamic>
                                              generatedSections =
                                              Map<String, dynamic>.from(
                                              result['sections']
                                                      as Map<dynamic, dynamic>);
                                          if (generatedSections.isEmpty) {
                                            throw Exception(
                                                'AI did not return any sections.');
                                          }
                                          setDialogState(() {
                                            generatedController?.dispose();
                                            generatedController = null;
                                            if (generatedSectionControllers !=
                                                null) {
                                              for (final controller
                                                  in generatedSectionControllers!
                                                      .values) {
                                                controller.dispose();
                                              }
                                            }
                                            generatedSectionControllers = {};
                                            generatedSections
                                                .forEach((title, content) {
                                              generatedSectionControllers![
                                                  title] = TextEditingController(
                                                  text: (content ?? '')
                                                      .toString()
                                                      .trim());
                                            });
                                            generationMode = 'full';
                                          });
                                          ScaffoldMessenger.of(rootContext)
                                                .showSnackBar(
                                              SnackBar(
                                              content: Text(
                                                  'Draft proposal ready with ${generatedSections.length} sections. Review below.'),
                                              backgroundColor:
                                                  const Color(0xFF00BCD4),
                                            ),
                                          );
                                        } else {
                                          throw Exception(
                                              'Failed to generate full proposal.');
                                        }
                                      } else {
                                        if (_selectedSectionIndex >=
                                            _sections.length) {
                                          throw Exception(
                                              'No section selected to improve.');
                                        }

                                        final currentContent =
                                            _sections[_selectedSectionIndex]
                                                .controller
                                                .text;
                                        if (currentContent.trim().isEmpty) {
                                          throw Exception(
                                              'Current section is empty. Nothing to improve.');
                                        }

                                        final result =
                                            await ApiService.improveContent(
                                          token: token,
                                          content: currentContent,
                                          sectionType: selectedSectionType,
                                        );

                                        if (result != null &&
                                            result['improved_version'] !=
                                                null) {
                                          final improvedText =
                                              (result['improved_version']
                                                      as String)
                                                  .trim();
                                          if (improvedText.isEmpty) {
                                            throw Exception(
                                                'AI returned an empty improvement.');
                                          }

                                          setDialogState(() {
                                            generatedController?.dispose();
                                            generatedController =
                                                TextEditingController(
                                                    text: improvedText);
                                            if (generatedSectionControllers !=
                                                null) {
                                              for (final controller
                                                  in generatedSectionControllers!
                                                      .values) {
                                                controller.dispose();
                                              }
                                            }
                                            generatedSectionControllers = null;
                                            generationMode = 'improve';
                                          });

                                          if (result['summary'] != null) {
                                            ScaffoldMessenger.of(rootContext)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Improvements ready. Review below.',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(result['summary']
                                                        as String),
                                                  ],
                                                ),
                                                backgroundColor:
                                                    const Color(0xFF00BCD4),
                                                duration: const Duration(
                                                    seconds: 4),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(rootContext)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Improvements ready. Review and edit below before applying.'),
                                                backgroundColor:
                                                    Color(0xFF00BCD4),
                                              ),
                                            );
                                          }
                                        } else {
                                          throw Exception(
                                              'Failed to improve content.');
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(rootContext)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                      'Error: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setDialogState(() {
                                          isGenerating = false;
                                        });
                                      }
                                    }
                                  },
                            icon: isGenerating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome, size: 18),
                            label: Text(isGenerating
                                ? 'Generating...'
                                : (selectedAction == 'generate'
                                    ? 'Generate'
                                    : selectedAction == 'full_proposal'
                                        ? 'Generate Proposal'
                                        : 'Improve')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
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
      },
    );
  }

  void _showCollaborationDialog() {
    final emailController = TextEditingController();
    bool isInviting = false;
    // All collaborators get full access (edit, comment, suggest)
    String selectedPermission = 'edit';

    // Load existing collaborators
    _loadCollaborators();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: SizedBox(
                width: 600,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people,
                              color: Color(0xFF27AE60), size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            'Collaborate on Proposal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Invite others to collaborate on this proposal. They will receive an email with a secure link.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Add collaborator section
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                hintText: 'colleague@example.com',
                                prefixIcon: const Icon(Icons.email, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              enabled: !isInviting,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: isInviting
                                ? null
                                : () async {
                                    final email = emailController.text.trim();
                                    if (email.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please enter an email address'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    // Validate email format
                                    if (!RegExp(
                                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(email)) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please enter a valid email address'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    if (_savedProposalId == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Please save the proposal first'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() {
                                      isInviting = true;
                                    });

                                    try {
                                      final token = await _getAuthToken();
                                      if (token == null) {
                                        throw Exception(
                                            'Authentication required');
                                      }

                                      final response = await http.post(
                                        Uri.parse(
                                            '$baseUrl/api/proposals/$_savedProposalId/invite'),
                                        headers: {
                                          'Authorization': 'Bearer $token',
                                          'Content-Type': 'application/json',
                                        },
                                        body: jsonEncode({
                                          'email': email,
                                          'permission_level':
                                              selectedPermission,
                                        }),
                                      );

                                      if (response.statusCode == 201) {
                                        final result =
                                            jsonDecode(response.body);

                                        // Reload collaborators list
                                        await _loadCollaborators();

                                        setState(() {
                                          _isCollaborating = true;
                                        });

                                        emailController.clear();

                                        if (context.mounted) {
                                          final emailSent = result['email_sent'] == true;
                                          final emailError = result['email_error'];
                                          
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(emailSent
                                                  ? '✅ Invitation sent to $email'
                                                  : emailError != null
                                                      ? '⚠️ Invitation created but email failed: ${emailError.toString().substring(0, 50)}...'
                                                      : '⚠️ Invitation created but email failed to send. Check SMTP configuration.'),
                                              backgroundColor: emailSent
                                                  ? Colors.green
                                                  : Colors.orange,
                                              duration: Duration(seconds: emailSent ? 3 : 5),
                                            ),
                                          );
                                        }
                                      } else {
                                        String errorMessage = 'Failed to send invitation';
                                        try {
                                          final error = jsonDecode(response.body);
                                          errorMessage = error['detail'] ?? errorMessage;
                                        } catch (e) {
                                          errorMessage = 'Server error: ${response.statusCode}';
                                        }
                                        throw Exception(errorMessage);
                                      }
                                    } catch (e) {
                                      print('❌ Error inviting collaborator: $e');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error inviting collaborator: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 5),
                                          ),
                                        );
                                      }
                                    } finally {
                                      setDialogState(() {
                                        isInviting = false;
                                      });
                                    }
                                  },
                            icon: isInviting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send, size: 18),
                            label:
                                Text(isInviting ? 'Sending...' : 'Send Invite'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Collaborators list
                      if (_collaborators.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Current Collaborators (${_collaborators.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _collaborators.length,
                            itemBuilder: (context, index) {
                              final collaborator = _collaborators[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFF27AE60),
                                      child: Text(
                                        collaborator['name']
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            collaborator['name'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            collaborator['email'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        collaborator['role'],
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            collaborator['status'] == 'accepted'
                                                ? Colors.green[50]
                                                : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        collaborator['status'] == 'accepted'
                                            ? 'Active'
                                            : 'Pending',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: collaborator['status'] ==
                                                  'accepted'
                                              ? Colors.green[700]
                                              : Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      tooltip: 'Remove collaborator',
                                      onPressed: () async {
                                        final invitationId = collaborator['id'];
                                        if (invitationId != null) {
                                          Navigator.pop(context);
                                          await _removeCollaborator(
                                              invitationId);
                                          _showCollaborationDialog();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'No collaborators yet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Close button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
  Color backgroundColor;
  String? backgroundImageUrl;
  String sectionType; // 'cover', 'content', 'appendix', etc.
  bool isCoverPage;
  List<InlineImage> inlineImages; // Inline content images (not backgrounds)
  List<DocumentTable> tables; // Tables in this section

  _DocumentSection({
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

class InlineImage {
  String url;
  double width;
  double height;
  double x; // X position
  double y; // Y position

  InlineImage({
    required this.url,
    this.width = 300,
    this.height = 200,
    this.x = 0,
    this.y = 0,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'width': width,
        'height': height,
        'x': x,
        'y': y,
      };

  factory InlineImage.fromJson(Map<String, dynamic> json) => InlineImage(
        url: json['url'] as String,
        width: (json['width'] as num?)?.toDouble() ?? 300,
        height: (json['height'] as num?)?.toDouble() ?? 200,
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
      );
}

class DocumentTable {
  String type; // 'text' or 'price'
  List<List<String>> cells;
  double vatRate; // For price tables (default 15%)

  DocumentTable({
    this.type = 'text',
    List<List<String>>? cells,
    this.vatRate = 0.15,
  }) : cells = cells ??
            [
              ['Header 1', 'Header 2', 'Header 3'],
              ['Row 1 Col 1', 'Row 1 Col 2', 'Row 1 Col 3'],
              ['Row 2 Col 1', 'Row 2 Col 2', 'Row 2 Col 3'],
            ];

  factory DocumentTable.priceTable({double vatRate = 0.15}) {
    return DocumentTable(
      type: 'price',
      vatRate: vatRate,
      cells: [
        ['Item', 'Description', 'Quantity', 'Unit Price', 'Total'],
        ['', '', '1', '0.00', '0.00'],
        ['', '', '1', '0.00', '0.00'],
      ],
    );
  }

  void addRow() {
    final newRow = List.generate(cells[0].length, (_) => '');
    cells.add(newRow);
  }

  void addColumn() {
    for (var row in cells) {
      row.add('');
    }
  }

  void removeRow(int index) {
    if (cells.length > 2 && index > 0) {
      // Keep at least header + 1 row
      cells.removeAt(index);
    }
  }

  void removeColumn(int index) {
    if (cells[0].length > 2) {
      // Keep at least 2 columns
      for (var row in cells) {
        if (index < row.length) {
          row.removeAt(index);
        }
      }
    }
  }

  double getSubtotal() {
    if (type != 'price' || cells.length < 2) return 0.0;

    double subtotal = 0.0;
    for (var i = 1; i < cells.length; i++) {
      final row = cells[i];
      if (row.length >= 5) {
        final total = double.tryParse(row[4]) ?? 0.0;
        subtotal += total;
      }
    }
    return subtotal;
  }

  double getVAT() {
    return getSubtotal() * vatRate;
  }

  double getTotal() {
    return getSubtotal() + getVAT();
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'cells': cells,
        'vatRate': vatRate,
      };

  factory DocumentTable.fromJson(Map<String, dynamic> json) => DocumentTable(
        type: json['type'] as String? ?? 'text',
        cells: (json['cells'] as List<dynamic>?)
            ?.map((row) =>
                (row as List<dynamic>).map((cell) => cell.toString()).toList())
            .toList(),
        vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.15,
      );
}
