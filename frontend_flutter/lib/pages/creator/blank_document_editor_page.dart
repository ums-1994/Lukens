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
  String _selectedPanel = 'templates'; // templates, build, upload, signature
  int _selectedSectionIndex =
      0; // Track which section is selected for content insertion
  String _selectedCurrency = 'Rand (ZAR)';
  List<String> _uploadedImages = [];
  List<Map<String, dynamic>> _libraryImages = [];
  bool _isLoadingLibraryImages = false;
  String _signatureSearchQuery = '';
  String _uploadTabSelected = 'this_document'; // 'this_document' or 'library'
  bool _showSectionsSidebar = false; // Toggle sections sidebar visibility

  // Formatting state
  String _selectedTextStyle = 'Normal Text';
  String _selectedFont = 'Plus Jakarta Sans';
  String _selectedFontSize = '12px';
  String _selectedAlignment = 'left';
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;

  // Sidebar state
  bool _isSidebarCollapsed = false;
  String _currentPage = 'Editor';

  List<String> _signatures = [
    'Client Signature',
    'Authorized By',
    'Manager Approval'
  ];
  List<Map<String, dynamic>> _comments = [];
  late TextEditingController _commentController;
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

  // Backend integration
  int? _savedProposalId; // Store the actual backend proposal ID
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
        Uri.parse('http://localhost:8000/content?category=Images'),
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
                'author': version['created_by'],
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
      final comments = await ApiService.getComments(
        token: token,
        proposalId: proposalId,
      );

      print('📦 Received ${comments.length} comments from API');

      // Always update state, even if empty (to clear old comments)
      setState(() {
        _comments.clear();
        for (var comment in comments) {
          print(
              '📝 Comment: ${comment['created_by_name'] ?? comment['created_by_email']} - ${comment['comment_text']}');
          _comments.add({
            'id': comment['id'],
            'commenter_name': comment['created_by_name'] ??
                comment['created_by_email'] ??
                'User #${comment['created_by']}',
            'comment_text': comment['comment_text'],
            'section_index': comment['section_index'],
            'highlighted_text': comment['highlighted_text'],
            'timestamp': comment['created_at'],
            'status': comment['status'] ?? 'open',
          });
        }
      });
      print('✅ Loaded ${comments.length} comments');
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
            'http://localhost:8000/api/proposals/$_savedProposalId/collaborators'),
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
            _collaborators.add({
              'id': collab['id'],
              'email': collab['invited_email'],
              'name': collab['invited_email'].split('@')[0],
              'role': collab['permission_level'] == 'edit'
                  ? 'Can Edit'
                  : collab['permission_level'] == 'suggest'
                      ? 'Can Suggest'
                      : collab['permission_level'] == 'comment'
                          ? 'Can Comment'
                          : 'View Only',
              'status': collab['status'],
              'invited_at': collab['invited_at'],
              'accessed_at': collab['accessed_at'],
            });
          }
          _isCollaborating = _collaborators.isNotEmpty;
        });
        print('✅ Loaded ${collaborators.length} collaborators');
      }
    } catch (e) {
      print('⚠️ Error loading collaborators: $e');
    }
  }

  Future<void> _removeCollaborator(int invitationId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;

      final response = await http.delete(
        Uri.parse('http://localhost:8000/api/collaborations/$invitationId'),
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
    _commentController.dispose();
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

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final commentText = _commentController.text;
    final commenterName = _getCommenterName();
    _commentController.clear();

    final newComment = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'commenter_name': commenterName,
      'comment_text': commentText,
      'section_index': _selectedSectionForComment,
      'section_title': _selectedSectionForComment != null &&
              _selectedSectionForComment! < _sections.length
          ? (_sections[_selectedSectionForComment!]
                  .titleController
                  .text
                  .isNotEmpty
              ? _sections[_selectedSectionForComment!].titleController.text
              : 'Untitled Section')
          : null,
      'highlighted_text': _highlightedText.isNotEmpty ? _highlightedText : null,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'open',
    };

    setState(() {
      _comments.insert(0, newComment);
      _highlightedText = '';
      _selectedSectionForComment = null;
    });

    // Save comment to database if proposal has been saved
    if (_savedProposalId != null) {
      try {
        final token = await _getAuthToken();
        if (token != null) {
          final savedComment = await ApiService.createComment(
            token: token,
            proposalId: _savedProposalId!,
            commentText: commentText,
            createdBy: commenterName,
            sectionIndex: _selectedSectionForComment,
            highlightedText:
                _highlightedText.isNotEmpty ? _highlightedText : null,
          );

          if (savedComment != null) {
            // Update the local comment with database ID
            setState(() {
              final index =
                  _comments.indexWhere((c) => c['id'] == newComment['id']);
              if (index >= 0) {
                _comments[index]['id'] = savedComment['id'];
              }
            });
            print('✅ Comment saved to database');
          }
        }
      } catch (e) {
        print('⚠️ Error saving comment to database: $e');
        // Continue silently - comment is still in memory
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Comment added by $commenterName'),
        backgroundColor: const Color(0xFF1A3A52),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateCommentStatus(int commentId, String newStatus) {
    setState(() {
      final comment =
          _comments.firstWhere((c) => c['id'] == commentId, orElse: () => {});
      if (comment.isNotEmpty) {
        comment['status'] = newStatus;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Comment marked as $newStatus'),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
      ),
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
          setState(() {
            _savedProposalId = result['id'] is int
                ? result['id']
                : int.tryParse(result['id'].toString());
          });
          print('✅ Proposal created with ID: $_savedProposalId');
          print(
              '💾 Proposal ID saved in state - future saves will UPDATE this proposal');
        } else {
          print('⚠️ Proposal creation returned null or no ID');
          print('🔍 Full result: $result');
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
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // Left Sidebar (hide in read-only mode)
          if (!widget.readOnly) _buildLeftSidebar(),
          // Sections Sidebar (conditional, hide in read-only mode)
          if (!widget.readOnly && _showSectionsSidebar) _buildSectionsSidebar(),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top header
                _buildTopHeader(),
                // Formatting toolbar (hide in read-only mode)
                if (!widget.readOnly) _buildToolbar(),
                // Main document area
                Expanded(
                  child: Row(
                    children: [
                      // Center content
                      Expanded(
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 50,
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
                            ),
                            // Floating toolbar on right (hide in read-only mode)
                            if (!widget.readOnly)
                              Positioned(
                                right: 20,
                                top: 0,
                                bottom: 0,
                                child: _buildFloatingToolbar(),
                              ),
                          ],
                        ),
                      ),
                      // Right sidebar (hide in read-only mode)
                      if (!widget.readOnly) _buildRightSidebar(),
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
    return GestureDetector(
      onTap: () {
        if (_isSidebarCollapsed) {
          setState(() => _isSidebarCollapsed = false);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isSidebarCollapsed ? 90.0 : 250.0,
        color: const Color(0xFF34495E),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Toggle button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InkWell(
                  onTap: _toggleSidebar,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: _isSidebarCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!_isSidebarCollapsed)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Navigation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: _isSidebarCollapsed ? 0 : 8,
                          ),
                          child: Icon(
                            _isSidebarCollapsed
                                ? Icons.keyboard_arrow_right
                                : Icons.keyboard_arrow_left,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Navigation items
              _buildNavItem('Dashboard', 'assets/images/Dahboard.png',
                  _currentPage == 'Dashboard'),
              _buildNavItem('My Proposals', 'assets/images/My_Proposals.png',
                  _currentPage == 'My Proposals'),
              _buildNavItem('Templates', 'assets/images/content_library.png',
                  _currentPage == 'Templates'),
              _buildNavItem(
                  'Content Library',
                  'assets/images/content_library.png',
                  _currentPage == 'Content Library'),
              _buildNavItem('Collaboration', 'assets/images/collaborations.png',
                  _currentPage == 'Collaboration'),
              _buildNavItem(
                  'Approvals Status',
                  'assets/images/Time Allocation_Approval_Blue.png',
                  _currentPage == 'Approvals Status'),
              _buildNavItem(
                  'Analytics (My Pipeline)',
                  'assets/images/analytics.png',
                  _currentPage == 'Analytics (My Pipeline)'),
              const SizedBox(height: 20),
              // Divider
              if (!_isSidebarCollapsed)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 1,
                  color: const Color(0xFF2C3E50),
                ),
              const SizedBox(height: 12),
              // Logout button
              _buildNavItem(
                  'Logout', 'assets/images/Logout_KhonoBuzz.png', false),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSidebar() {
    setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
  }

  Widget _buildNavItem(String label, String assetPath, bool isActive) {
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              setState(() => _currentPage = label);
              _navigateToPage(label);
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFFCBD5E1),
                  width: isActive ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: AssetService.buildImageWidget(assetPath,
                    fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _currentPage = label);
          _navigateToPage(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF3498DB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: const Color(0xFF2980B9), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFFCBD5E1),
                    width: isActive ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: AssetService.buildImageWidget(assetPath,
                      fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFFECF0F1),
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isActive)
                const Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPage(String pageName) {
    switch (pageName) {
      case 'Dashboard':
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 'My Proposals':
        Navigator.pushReplacementNamed(context, '/proposals');
        break;
      case 'Templates':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Templates - Coming soon'),
            backgroundColor: Color(0xFF00BCD4),
          ),
        );
        break;
      case 'Content Library':
        Navigator.pushReplacementNamed(context, '/content-library');
        break;
      case 'Collaboration':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaboration - Coming soon'),
            backgroundColor: Color(0xFF00BCD4),
          ),
        );
        break;
      case 'Approvals Status':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approvals Status - Coming soon'),
            backgroundColor: Color(0xFF00BCD4),
          ),
        );
        break;
      case 'Analytics (My Pipeline)':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics - Coming soon'),
            backgroundColor: Color(0xFF00BCD4),
          ),
        );
        break;
      case 'Logout':
        Navigator.pushReplacementNamed(context, '/login');
        break;
    }
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
                final section = _sections[index];
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    section.title,
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
                                ),
                                const SizedBox(width: 8),
                                // Section type badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: section.isCoverPage
                                        ? const Color(0xFF00BCD4)
                                            .withValues(alpha: 0.1)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    section.sectionType == 'cover'
                                        ? 'Cover'
                                        : section.sectionType == 'appendix'
                                            ? 'Appendix'
                                            : section.sectionType ==
                                                    'references'
                                                ? 'Refs'
                                                : 'Page',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      color: section.isCoverPage
                                          ? const Color(0xFF00BCD4)
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
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
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit,
                            size: 16, color: Color(0xFF00BCD4)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            enabled: !widget
                                .readOnly, // Disable editing in read-only mode
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                            decoration: InputDecoration(
                              hintText: widget.readOnly
                                  ? '' // No hint in read-only mode
                                  : 'Click to edit document title...',
                              hintStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFFBDC3C7),
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
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // View Only badge (show in read-only mode)
                if (widget.readOnly) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF39C12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.visibility, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'View Only',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          // Save status with version info
          GestureDetector(
            onTap: _showVersionHistory,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isSaving
                    ? Colors.blue.withOpacity(0.1)
                    : (_hasUnsavedChanges
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _isSaving
                      ? Colors.blue
                      : (_hasUnsavedChanges ? Colors.orange : Colors.green),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSaving)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  else
                    Icon(
                      _hasUnsavedChanges ? Icons.pending : Icons.check_circle,
                      size: 14,
                      color: _hasUnsavedChanges ? Colors.orange : Colors.green,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    _isSaving
                        ? 'Saving...'
                        : (_hasUnsavedChanges
                            ? 'Unsaved changes'
                            : (_lastSaved == null ? 'Not Saved' : 'Saved')),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isSaving
                          ? Colors.blue[800]
                          : (_hasUnsavedChanges
                              ? Colors.orange[800]
                              : Colors.green[800]),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Version history button
          OutlinedButton.icon(
            onPressed: _showVersionHistory,
            icon: const Icon(Icons.history, size: 16),
            label: Text('v$_currentVersionNumber'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00BCD4)),
              foregroundColor: const Color(0xFF00BCD4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
          // Collaboration button
          OutlinedButton.icon(
            onPressed: () => _showCollaborationDialog(),
            icon: Icon(
              _isCollaborating ? Icons.people : Icons.person_add,
              size: 16,
            ),
            label: Text(_isCollaborating
                ? 'Collaborators (${_collaborators.length})'
                : 'Share'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _isCollaborating ? Colors.green : Colors.grey,
              ),
              foregroundColor: _isCollaborating ? Colors.green : Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Comments button
          OutlinedButton.icon(
            onPressed: () => _showCommentsPanel(),
            icon: const Icon(Icons.comment, size: 16),
            label: Text('Comments (${_comments.length})'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00BCD4)),
              foregroundColor: const Color(0xFF00BCD4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Status Badge
          if (_proposalStatus != null && _proposalStatus != 'draft')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(_proposalStatus!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getStatusIcon(_proposalStatus!),
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusLabel(_proposalStatus!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (_proposalStatus != null && _proposalStatus != 'draft')
            const SizedBox(width: 12),
          // Send for Approval button
          if (_proposalStatus == null || _proposalStatus == 'draft')
            ElevatedButton.icon(
              onPressed: _sendForApproval,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send for Approval'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          if (_proposalStatus == null || _proposalStatus == 'draft')
            const SizedBox(width: 12),
          // Action buttons
          OutlinedButton.icon(
            onPressed: _showPreview,
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
          // User initials
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                _getUserInitials(),
                style: const TextStyle(
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
          // Undo/Redo
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Undo - Feature coming soon'),
                  backgroundColor: Color(0xFF00BCD4),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Undo',
            iconSize: 18,
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Redo - Feature coming soon'),
                  backgroundColor: Color(0xFF00BCD4),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Redo',
            iconSize: 18,
            splashRadius: 20,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Style dropdown
          _buildSmallDropdown(_selectedTextStyle, [
            'Normal Text',
            'Heading 1',
            'Heading 2',
            'Heading 3',
            'Title'
          ], (value) {
            setState(() {
              _selectedTextStyle = value!;
            });
          }),
          const SizedBox(width: 8),
          // Font dropdown
          _buildSmallDropdown(_selectedFont, [
            'Plus Jakarta Sans',
            'Arial',
            'Times New Roman',
            'Georgia',
            'Courier New'
          ], (value) {
            setState(() {
              _selectedFont = value!;
            });
          }),
          const SizedBox(width: 8),
          // Font size dropdown
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
            setState(() {
              _selectedFontSize = value!;
            });
          }),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Text formatting
          IconButton(
            icon: Icon(Icons.format_bold,
                color: _isBold ? const Color(0xFF00BCD4) : null),
            onPressed: () {
              setState(() {
                _isBold = !_isBold;
              });
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Bold',
          ),
          IconButton(
            icon: Icon(Icons.format_italic,
                color: _isItalic ? const Color(0xFF00BCD4) : null),
            onPressed: () {
              setState(() {
                _isItalic = !_isItalic;
              });
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Italic',
          ),
          IconButton(
            icon: Icon(Icons.format_underlined,
                color: _isUnderlined ? const Color(0xFF00BCD4) : null),
            onPressed: () {
              setState(() {
                _isUnderlined = !_isUnderlined;
              });
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Underline',
          ),
          IconButton(
            icon: const Icon(Icons.format_color_text),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Text color picker - Feature coming soon'),
                  backgroundColor: Color(0xFF00BCD4),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Text Color',
          ),
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Insert link - Feature coming soon'),
                  backgroundColor: Color(0xFF00BCD4),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Link',
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Alignment
          IconButton(
            icon: Icon(Icons.format_align_left,
                color: _selectedAlignment == 'left'
                    ? const Color(0xFF00BCD4)
                    : null),
            onPressed: () {
              setState(() {
                _selectedAlignment = 'left';
              });
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Left',
          ),
          IconButton(
            icon: Icon(Icons.format_align_center,
                color: _selectedAlignment == 'center'
                    ? const Color(0xFF00BCD4)
                    : null),
            onPressed: () {
              setState(() {
                _selectedAlignment = 'center';
              });
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Center',
          ),
          IconButton(
            icon: Icon(Icons.format_align_right,
                color: _selectedAlignment == 'right'
                    ? const Color(0xFF00BCD4)
                    : null),
            onPressed: () {
              setState(() {
                _selectedAlignment = 'right';
              });
            },
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
            onPressed: () {
              if (_sections.isNotEmpty &&
                  _selectedSectionIndex < _sections.length) {
                setState(() {
                  final section = _sections[_selectedSectionIndex];
                  final currentText = section.controller.text;
                  section.controller.text =
                      currentText + '\n• Item 1\n• Item 2\n• Item 3';
                });
              }
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Bullet List',
          ),
          IconButton(
            icon: const Icon(Icons.format_list_numbered),
            onPressed: () {
              if (_sections.isNotEmpty &&
                  _selectedSectionIndex < _sections.length) {
                setState(() {
                  final section = _sections[_selectedSectionIndex];
                  final currentText = section.controller.text;
                  section.controller.text =
                      currentText + '\n1. Item 1\n2. Item 2\n3. Item 3';
                });
              }
            },
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Numbered List',
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Insert
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: () => _showTableTypeDialog(),
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Insert Table',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _showAIAssistantDialog,
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'AI Assistant',
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown(
      String label, List<String> items, Function(String?) onChanged) {
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
        onChanged: onChanged,
      ),
    );
  }

  List<Widget> _buildA4Pages() {
    // A4 dimensions: 210mm x 297mm (aspect ratio 0.707)
    // Using larger width of 900px for better visibility
    // Height: 1273px (A4 aspect ratio maintained)
    const double pageWidth = 900;
    const double pageHeight = 1273; // A4 aspect ratio

    return List.generate(
      _sections.length,
      (index) {
        final section = _sections[index];
        return Container(
          width: pageWidth,
          constraints: const BoxConstraints(
            minHeight: 600,
            maxHeight: pageHeight,
          ),
          margin: const EdgeInsets.only(bottom: 32),
          decoration: BoxDecoration(
            color: section.backgroundImageUrl == null
                ? section.backgroundColor
                : Colors.white,
            image: section.backgroundImageUrl != null
                ? DecorationImage(
                    image: NetworkImage(section.backgroundImageUrl!),
                    fit: BoxFit.cover,
                    opacity: 0.7, // Background image visibility
                  )
                : null,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: _buildSectionContent(index),
                ),
              ),
              // Page number indicator at bottom
              Positioned(
                bottom: 20,
                right: 60,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100]!.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
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
      },
    );
  }

  Widget _buildAddPageButton() {
    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              final newSection = _DocumentSection(
                title: 'Untitled Section',
                content: '',
              );
              setState(() {
                _sections.add(newSection);
                _selectedSectionIndex = _sections.length - 1;

                // Add listeners to new section
                newSection.controller.addListener(_onContentChanged);
                newSection.titleController.addListener(_onContentChanged);

                // Add focus listeners for UI updates
                newSection.contentFocus.addListener(() => setState(() {}));
                newSection.titleFocus.addListener(() => setState(() {}));
              });
            },
            customBorder: const CircleBorder(),
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
              // Clean content area - text field for writing
              TextField(
                focusNode: section.contentFocus,
                controller: section.controller,
                maxLines: null,
                minLines: 15,
                enabled: !widget.readOnly, // Disable editing in read-only mode
                style: _getContentTextStyle(),
                textAlign: _getTextAlignment(),
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: widget.readOnly
                      ? '' // No hint in read-only mode
                      : 'Start writing your content here...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFBDC3C7),
                  ),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(8),
                ),
              ),
              // Display tables below text
              ...section.tables.asMap().entries.map((entry) {
                final tableIndex = entry.key;
                final table = entry.value;
                return _buildInteractiveTable(index, tableIndex, table);
              }).toList(),
              // Display images below tables
              ...section.inlineImages.asMap().entries.map((entry) {
                final imageIndex = entry.key;
                final image = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    width: image.width,
                    height: image.height,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFF00BCD4), width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            image.url,
                            width: image.width,
                            height: image.height,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Delete button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _sections[index]
                                      .inlineImages
                                      .removeAt(imageIndex);
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // Build resizable inline image
  Widget _buildResizableImage(
      int sectionIndex, int imageIndex, InlineImage image) {
    return Positioned(
      left: image.x,
      top: image.y,
      child: GestureDetector(
        // Drag to move the image
        onPanUpdate: (details) {
          setState(() {
            image.x = (image.x + details.delta.dx).clamp(0.0, 700.0);
            image.y = (image.y + details.delta.dy).clamp(0.0, 1000.0);
          });
        },
        child: Container(
          width: image.width,
          height: image.height,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00BCD4), width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // The image itself
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  image.url,
                  width: image.width,
                  height: image.height,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('Failed to load image',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Move indicator (top-left)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.drag_indicator,
                      size: 16, color: Colors.white),
                ),
              ),
              // Delete button (top-right)
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _sections[sectionIndex]
                            .inlineImages
                            .removeAt(imageIndex);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Image removed'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
              // Resize handle (bottom-right corner)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      // Update width and height based on drag
                      image.width =
                          (image.width + details.delta.dx).clamp(100.0, 800.0);
                      image.height =
                          (image.height + details.delta.dy).clamp(100.0, 600.0);
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00BCD4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: const Icon(
                      Icons.zoom_out_map,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build interactive editable table
  Widget _buildInteractiveTable(
      int sectionIndex, int tableIndex, DocumentTable table) {
    // Get currency symbol
    String currencySymbol = '\$';
    switch (_selectedCurrency) {
      case 'ZAR':
        currencySymbol = 'R';
        break;
      case 'EUR':
        currencySymbol = '€';
        break;
      case 'GBP':
        currencySymbol = '£';
        break;
      default:
        currencySymbol = '\$';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header with controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${table.type == 'price' ? 'Price' : 'Text'} Table',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      onPressed: () => setState(() => table.addRow()),
                      tooltip: 'Add Row',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    // Disable add column for price tables (fixed structure)
                    IconButton(
                      icon: const Icon(Icons.view_column, size: 18),
                      onPressed: table.type == 'price'
                          ? null
                          : () => setState(() => table.addColumn()),
                      tooltip: table.type == 'price'
                          ? 'Price tables have fixed columns'
                          : 'Add Column',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _sections[sectionIndex].tables.removeAt(tableIndex);
                        });
                      },
                      tooltip: 'Delete Table',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Table content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
              border: TableBorder.all(color: Colors.grey[300]!),
              columns: List.generate(
                table.cells[0].length,
                (colIndex) => DataColumn(
                  label: Expanded(
                    child: Text(
                      table.cells[0][colIndex],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              rows: List.generate(
                table.cells.length - 1,
                (rowIndex) => DataRow(
                  cells: List.generate(
                    table.cells[rowIndex + 1].length,
                    (colIndex) => DataCell(
                      TextField(
                        controller: TextEditingController(
                          text: table.cells[rowIndex + 1][colIndex],
                        ),
                        onChanged: (value) {
                          setState(() {
                            table.cells[rowIndex + 1][colIndex] = value;
                            // Auto-calculate total for price tables
                            if (table.type == 'price' && colIndex == 2 ||
                                colIndex == 3) {
                              final qty = double.tryParse(
                                      table.cells[rowIndex + 1][2]) ??
                                  0;
                              final price = double.tryParse(
                                      table.cells[rowIndex + 1][3]) ??
                                  0;
                              table.cells[rowIndex + 1][4] =
                                  (qty * price).toStringAsFixed(2);
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(8),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Price table footer
          if (table.type == 'price') ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Subtotal: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          '$currencySymbol${table.getSubtotal().toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                          'VAT (${(table.vatRate * 100).toStringAsFixed(0)}%): ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          '$currencySymbol${table.getVAT().toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Total: ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                          '$currencySymbol${table.getTotal().toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Removed old buttons section - keeping only content
  Widget _buildSectionContentOld(int index) {
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
                  // Removed section title from here
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: section.contentFocus.hasFocus
                        ? const Color(0xFF00BCD4)
                        : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: TextField(
                  focusNode: section.contentFocus,
                  controller: section.controller,
                  enabled: true,
                  maxLines: null,
                  textAlign: _getTextAlignment(),
                  textAlignVertical: TextAlignVertical.top,
                  style: _getContentTextStyle(),
                  decoration: InputDecoration(
                    hintText:
                        'Click here to start typing or insert content from library...',
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
                _showCommentDialog();
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

      // Add listeners to new section
      newSection.controller.addListener(_onContentChanged);
      newSection.titleController.addListener(_onContentChanged);

      // Add focus listeners for UI updates
      newSection.contentFocus.addListener(() => setState(() {}));
      newSection.titleFocus.addListener(() => setState(() {}));
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

  void _addImageToSection(String imageUrl) async {
    if (_sections.isEmpty) return;

    final section = _sections[_selectedSectionIndex];

    // Ask user: Background or Inline Image?
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Image'),
        content: const Text('How would you like to use this image?'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.wallpaper),
            label: const Text('Set as Background'),
            onPressed: () => Navigator.pop(context, 'background'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.image),
            label: const Text('Insert as Image'),
            onPressed: () => Navigator.pop(context, 'inline'),
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );

    if (choice == null) return;

    setState(() {
      if (choice == 'background') {
        // Set as background image
        section.backgroundImageUrl = imageUrl;
        section.backgroundColor = Colors.white;
      } else if (choice == 'inline') {
        // Add as inline image
        section.inlineImages.add(InlineImage(url: imageUrl));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    choice == 'background'
                        ? 'Background image set!'
                        : 'Image inserted!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    choice == 'background'
                        ? 'Image set as background for "${section.title}"'
                        : 'You can resize the image by dragging the corner handle',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showTableTypeDialog() async {
    final tableType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Table'),
        content: const Text('What type of table would you like to insert?'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.table_chart),
            label: const Text('Text Table'),
            onPressed: () => Navigator.pop(context, 'text'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.attach_money),
            label: const Text('Price Table'),
            onPressed: () => Navigator.pop(context, 'price'),
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );

    if (tableType == null || _sections.isEmpty) return;

    setState(() {
      final section = _sections[_selectedSectionIndex];
      if (tableType == 'price') {
        section.tables.add(DocumentTable.priceTable());
      } else {
        section.tables.add(DocumentTable());
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${tableType == 'price' ? 'Price' : 'Text'} table inserted'),
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

  Widget _buildColorOption(Color color, String label) {
    if (_sections.isEmpty || _selectedSectionIndex >= _sections.length) {
      return const SizedBox.shrink();
    }
    final section = _sections[_selectedSectionIndex];
    final isSelected = section.backgroundColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          section.backgroundColor = color;
          section.backgroundImageUrl =
              null; // Clear image when color is selected
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Page ${_selectedSectionIndex + 1} background changed to $label'),
            backgroundColor: const Color(0xFF00BCD4),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: isSelected ? const Color(0xFF00BCD4) : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00BCD4).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Center(
                    child: Icon(
                      Icons.check,
                      color: Color(0xFF00BCD4),
                      size: 24,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? const Color(0xFF00BCD4) : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectBackgroundImageFromLibrary() async {
    if (_sections.isEmpty || _selectedSectionIndex >= _sections.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a page first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedModule = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ContentLibrarySelectionDialog(),
    );

    if (selectedModule != null) {
      final content = selectedModule['content'] ?? '';
      final title = selectedModule['title'] ?? 'Background';

      // Check if it's an image URL
      final isUrl =
          content.startsWith('http://') || content.startsWith('https://');

      if (isUrl) {
        setState(() {
          final section = _sections[_selectedSectionIndex];
          section.backgroundImageUrl = content;
          section.backgroundColor =
              Colors.white; // Reset color when image is selected
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Background image "$title" applied to Page ${_selectedSectionIndex + 1}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an image from the library'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
                  Row(
                    children: [
                      const Text(
                        'Page Style Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Page ${_selectedSectionIndex + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildColorOption(Colors.white, 'White'),
                      _buildColorOption(const Color(0xFFF5F5F5), 'Light Gray'),
                      _buildColorOption(const Color(0xFFFFF8DC), 'Cream'),
                      _buildColorOption(
                          const Color(0xFFFFF9E6), 'Light Yellow'),
                      _buildColorOption(const Color(0xFFE8F5E9), 'Light Green'),
                      _buildColorOption(const Color(0xFFE3F2FD), 'Light Blue'),
                      _buildColorOption(const Color(0xFFFCE4EC), 'Light Pink'),
                      _buildColorOption(
                          const Color(0xFFF3E5F5), 'Light Purple'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Background Image',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectBackgroundImageFromLibrary(),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6),
                          color: (_sections.isNotEmpty &&
                                  _selectedSectionIndex < _sections.length &&
                                  _sections[_selectedSectionIndex]
                                          .backgroundImageUrl !=
                                      null)
                              ? Colors.blue[50]
                              : Colors.grey[50],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (_sections.isNotEmpty &&
                                      _selectedSectionIndex <
                                          _sections.length &&
                                      _sections[_selectedSectionIndex]
                                              .backgroundImageUrl !=
                                          null)
                                  ? Icons.image
                                  : Icons.add_photo_alternate,
                              color: const Color(0xFF00BCD4),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                (_sections.isNotEmpty &&
                                        _selectedSectionIndex <
                                            _sections.length &&
                                        _sections[_selectedSectionIndex]
                                                .backgroundImageUrl !=
                                            null)
                                    ? 'Background image selected'
                                    : 'Select from Content Library',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (_sections.isNotEmpty &&
                                _selectedSectionIndex < _sections.length &&
                                _sections[_selectedSectionIndex]
                                        .backgroundImageUrl !=
                                    null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _sections[_selectedSectionIndex]
                                        .backgroundImageUrl = null;
                                  });
                                },
                                tooltip: 'Remove background',
                              ),
                          ],
                        ),
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
          // Drag & Drop Upload Area
          DragTarget<Object>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) {
              _handleFileDrop(details.data);
            },
            builder: (context, candidateData, rejectedData) {
              final isDragging = candidateData.isNotEmpty;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _addSampleImage();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDragging
                            ? const Color(0xFF00BCD4)
                            : Colors.grey[300]!,
                        width: isDragging ? 2 : 1,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isDragging
                          ? const Color(0xFF00BCD4).withValues(alpha: 0.05)
                          : Colors.grey[50],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isDragging
                              ? Icons.file_download
                              : Icons.cloud_upload_outlined,
                          size: 32,
                          color: isDragging
                              ? const Color(0xFF00BCD4)
                              : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isDragging
                              ? 'Drop images here'
                              : 'Click to upload from computer',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDragging
                                ? const Color(0xFF00BCD4)
                                : Colors.grey[600],
                          ),
                        ),
                        if (!isDragging)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Supports JPG, PNG, WebP, GIF',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
                  child: InkWell(
                    onTap: () {
                      _addImageToSection(_uploadedImages[index]);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey[50],
                      ),
                      child: Row(
                        children: [
                          // Actual image thumbnail
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                              image: _uploadedImages[index].isNotEmpty
                                  ? DecorationImage(
                                      image:
                                          NetworkImage(_uploadedImages[index]),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _uploadedImages[index].isEmpty
                                ? const Icon(Icons.image,
                                    color: Colors.grey, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Image ${index + 1}',
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
                          Icon(Icons.add_circle_outline,
                              size: 20, color: Colors.green[600]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ] else if (_uploadTabSelected == 'library') ...[
          // Library images
          if (_isLoadingLibraryImages)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_libraryImages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.image, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Images in Library',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loadLibraryImages,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                _libraryImages.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      _addImageToSection(_libraryImages[index]['content']);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey[50],
                      ),
                      child: Row(
                        children: [
                          // Image thumbnail
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                              image: _libraryImages[index]['content'] != null &&
                                      _libraryImages[index]['content']
                                          .toString()
                                          .isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          _libraryImages[index]['content']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _libraryImages[index]['content'] == null ||
                                    _libraryImages[index]['content']
                                        .toString()
                                        .isEmpty
                                ? const Icon(Icons.image,
                                    color: Colors.grey, size: 30)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _libraryImages[index]['label'] ?? 'Untitled',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Click to insert',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.add_circle_outline,
                              size: 20, color: Colors.green[600]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _addSampleImage() async {
    try {
      // Pick image file from computer
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Important for web
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled the picker
        return;
      }

      final file = result.files.first;

      // Show uploading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Uploading image...'),
            ],
          ),
          backgroundColor: Color(0xFF00BCD4),
          duration: Duration(seconds: 30),
        ),
      );

      // Upload to Cloudinary
      final appState = Provider.of<AppState>(context, listen: false);
      Map<String, dynamic>? uploadResult;

      if (file.bytes != null) {
        // For web, use bytes
        uploadResult = await appState.uploadImageToCloudinary(
          '', // Empty path for web
          fileBytes: file.bytes!,
          fileName: file.name,
        );
      } else {
        throw Exception('Could not read file data');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      if (uploadResult != null && uploadResult['url'] != null) {
        final imageUrl = uploadResult['url'] as String;
        setState(() {
          _uploadedImages.add(imageUrl);
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${file.name} uploaded successfully!'),
            backgroundColor: const Color(0xFF27AE60),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _handleFileDrop(Object data) {
    // Handle file drop - for now, we'll simulate adding an image
    // In a real implementation, you would process the dropped file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final imageUrl =
        'https://via.placeholder.com/300x200?text=Dropped+Image+$timestamp';

    setState(() {
      _uploadedImages.add(imageUrl);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image dropped successfully'),
        backgroundColor: Color(0xFF27AE60),
        duration: Duration(seconds: 2),
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

  void _showCommentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 500,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.comment,
                          color: Color(0xFF00BCD4), size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Add Comment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section selection
                  if (_sections.isNotEmpty) ...[
                    Text(
                      'Target Section',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSectionForComment ?? 0,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: _sections.asMap().entries.map((entry) {
                        return DropdownMenuItem<int>(
                          value: entry.key,
                          child: Text(
                            entry.value.titleController.text.isNotEmpty
                                ? entry.value.titleController.text
                                : 'Untitled Section',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSectionForComment = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Highlighted text display
                  if (_highlightedText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                const Color(0xFF00BCD4).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Highlighted Text:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _highlightedText.length > 100
                                ? '${_highlightedText.substring(0, 100)}...'
                                : _highlightedText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Comment input
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Comment',
                      hintText: 'Enter your comment here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _commentController.clear();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await _addComment();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                        ),
                        child: const Text('Add Comment'),
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

  void _showCommentsPanel() {
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
                      const Icon(Icons.comment,
                          color: Color(0xFF00BCD4), size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const Spacer(),
                      // Filter dropdown
                      DropdownButton<String>(
                        value: _commentFilterStatus,
                        items: ['all', 'open', 'resolved'].map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _commentFilterStatus = value!;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // Comments list
                Expanded(
                  child: _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.comment_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add comments to collaborate with your team',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _getFilteredComments().length,
                          itemBuilder: (context, index) {
                            final comment = _getFilteredComments()[index];
                            return _buildCommentCard(comment);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    final isResolved = comment['status'] == 'resolved';
    final hasHighlightedText = comment['highlighted_text'] != null &&
        comment['highlighted_text'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isResolved ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isResolved
              ? Colors.grey[300]!
              : const Color(0xFF00BCD4).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment header
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF00BCD4),
                child: Text(
                  comment['commenter_name']
                          ?.toString()
                          .substring(0, 1)
                          .toUpperCase() ??
                      'U',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['commenter_name'] ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      _formatTimestamp(comment['timestamp']),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isResolved ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isResolved ? 'RESOLVED' : 'OPEN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isResolved ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Section info
          if (comment['section_title'] != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Section: ${comment['section_title']}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF00BCD4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

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
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Comment text
          Text(
            comment['comment_text'] ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A1A),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              if (!isResolved)
                TextButton.icon(
                  onPressed: () =>
                      _updateCommentStatus(comment['id'], 'resolved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Resolve'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green[700],
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () => _updateCommentStatus(comment['id'], 'open'),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reopen'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                  ),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _deleteComment(comment['id']),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[700],
                ),
              ),
            ],
          ),
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

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isGenerating
                                ? null
                                : () => Navigator.pop(context),
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
                                        promptController.text.isEmpty) {
                                      ScaffoldMessenger.of(context)
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
                                    });

                                    try {
                                      final token = await _getAuthToken();
                                      if (token == null) {
                                        throw Exception(
                                            'Not authenticated. Please log in.');
                                      }

                                      if (selectedAction == 'generate') {
                                        // Generate new content
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
                                          if (mounted) {
                                            Navigator.pop(context);
                                          }

                                          // Insert into current section
                                          if (_selectedSectionIndex <
                                              _sections.length) {
                                            setState(() {
                                              final section = _sections[
                                                  _selectedSectionIndex];
                                              if (section
                                                  .controller.text.isEmpty) {
                                                section.controller.text =
                                                    result['content'];
                                              } else {
                                                section.controller.text +=
                                                    '\n\n${result['content']}';
                                              }
                                            });
                                          }

                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Row(
                                                  children: [
                                                    Icon(Icons.check_circle,
                                                        color: Colors.white),
                                                    SizedBox(width: 8),
                                                    Text(
                                                        'AI content generated successfully!'),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } else {
                                          throw Exception(
                                              'Failed to generate content');
                                        }
                                      } else if (selectedAction ==
                                          'full_proposal') {
                                        // Generate full multi-section proposal
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
                                            result['sections'] != null) {
                                          if (mounted) {
                                            Navigator.pop(context);
                                          }

                                          // Clear existing sections and create new ones
                                          final generatedSections =
                                              result['sections']
                                                  as Map<String, dynamic>;

                                          setState(() {
                                            // Dispose existing sections
                                            for (var section in _sections) {
                                              section.controller.dispose();
                                              section.titleController.dispose();
                                              section.contentFocus.dispose();
                                              section.titleFocus.dispose();
                                            }
                                            _sections.clear();

                                            // Create new sections from AI response
                                            generatedSections
                                                .forEach((title, content) {
                                              final newSection =
                                                  _DocumentSection(
                                                title: title,
                                                content: content as String,
                                              );
                                              _sections.add(newSection);

                                              // Add listeners
                                              newSection.controller.addListener(
                                                  _onContentChanged);
                                              newSection.titleController
                                                  .addListener(
                                                      _onContentChanged);
                                              newSection.contentFocus
                                                  .addListener(
                                                      () => setState(() {}));
                                              newSection.titleFocus.addListener(
                                                  () => setState(() {}));
                                            });

                                            _selectedSectionIndex = 0;
                                          });

                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.check_circle,
                                                        color: Colors.white),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                          'Full proposal generated with ${generatedSections.length} sections!'),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green,
                                                duration:
                                                    const Duration(seconds: 3),
                                              ),
                                            );
                                          }
                                        } else {
                                          throw Exception(
                                              'Failed to generate full proposal');
                                        }
                                      } else {
                                        // Improve existing content
                                        if (_selectedSectionIndex >=
                                            _sections.length) {
                                          throw Exception(
                                              'No section selected');
                                        }

                                        final currentContent =
                                            _sections[_selectedSectionIndex]
                                                .controller
                                                .text;
                                        if (currentContent.isEmpty) {
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
                                          if (mounted) {
                                            Navigator.pop(context);
                                          }

                                          // Replace with improved content
                                          setState(() {
                                            _sections[_selectedSectionIndex]
                                                    .controller
                                                    .text =
                                                result['improved_version'];
                                          });

                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Row(
                                                      children: [
                                                        Icon(Icons.check_circle,
                                                            color:
                                                                Colors.white),
                                                        SizedBox(width: 8),
                                                        Text(
                                                            'Content improved!'),
                                                      ],
                                                    ),
                                                    if (result['summary'] !=
                                                        null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 4),
                                                        child: Text(
                                                          result['summary'],
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green,
                                                duration:
                                                    const Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        } else {
                                          throw Exception(
                                              'Failed to improve content');
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.error,
                                                    color: Colors.white),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                      'Error: ${e.toString()}'),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Colors.red,
                                            duration:
                                                const Duration(seconds: 4),
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
    String selectedPermission = 'edit'; // Default to edit for collaborators

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
                          DropdownButton<String>(
                            value: selectedPermission,
                            items: const [
                              DropdownMenuItem(
                                value: 'edit',
                                child: Text('Can Edit'),
                              ),
                              DropdownMenuItem(
                                value: 'suggest',
                                child: Text('Can Suggest Changes'),
                              ),
                              DropdownMenuItem(
                                value: 'comment',
                                child: Text('Can Comment'),
                              ),
                              DropdownMenuItem(
                                value: 'view',
                                child: Text('View Only'),
                              ),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                selectedPermission = value ?? 'edit';
                              });
                            },
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
                                            'http://localhost:8000/api/proposals/$_savedProposalId/invite'),
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
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(result[
                                                          'email_sent'] ==
                                                      true
                                                  ? '✅ Invitation sent to $email'
                                                  : '⚠️ Invitation created but email failed to send'),
                                              backgroundColor:
                                                  result['email_sent'] == true
                                                      ? Colors.green
                                                      : Colors.orange,
                                            ),
                                          );
                                        }
                                      } else {
                                        final error = jsonDecode(response.body);
                                        throw Exception(error['detail'] ??
                                            'Failed to send invitation');
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
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
