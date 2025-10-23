import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'content_library_dialog.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../api.dart';

class BlankDocumentEditorPage extends StatefulWidget {
  final String? proposalId;
  final String? proposalTitle;

  const BlankDocumentEditorPage({
    super.key,
    this.proposalId,
    this.proposalTitle,
  });

  @override
  State<BlankDocumentEditorPage> createState() =>
      _BlankDocumentEditorPageState();
}

class _BlankDocumentEditorPageState extends State<BlankDocumentEditorPage> {
  late TextEditingController _titleController;
  bool _isSaving = false;
  DateTime? _lastSaved;
  List<_DocumentSection> _sections = [];
  int _hoveredSectionIndex = -1;
  String _selectedPanel = 'templates'; // templates, build, upload, signature
  int _selectedSectionIndex =
      0; // Track which section is selected for content insertion
  String _selectedCurrency = 'Rand (ZAR)';
  List<String> _uploadedImages = [];
  String _signatureSearchQuery = '';
  String _uploadTabSelected = 'this_document'; // 'this_document' or 'library'
  bool _showSectionsSidebar = false; // Toggle sections sidebar visibility
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.proposalTitle ?? 'Untitled Document',
    );
    _commentController = TextEditingController();
    // Create initial section
    _sections.add(_DocumentSection(
      title: 'Untitled Section',
      content: '',
    ));

    // Setup auto-save listeners
    _setupAutoSaveListeners();

    // Create initial version
    _createVersion('Initial version');

    // Get auth token
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
          await _loadVersionsFromDatabase(proposalId);
          await _loadCommentsFromDatabase(proposalId);
        }
      }
    } catch (e) {
      print('❌ Error initializing auth: $e');
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
      if (token == null) return;

      print('🔄 Loading comments for proposal $proposalId...');
      final comments = await ApiService.getComments(
        token: token,
        proposalId: proposalId,
      );

      if (comments.isNotEmpty) {
        setState(() {
          _comments.clear();
          for (var comment in comments) {
            _comments.add({
              'id': comment['id'],
              'commenter_name': comment['created_by'],
              'comment_text': comment['comment_text'],
              'section_index': comment['section_index'],
              'highlighted_text': comment['highlighted_text'],
              'timestamp': comment['created_at'],
              'status': comment['status'] ?? 'open',
            });
          }
        });
        print('✅ Loaded ${comments.length} comments');
      }
    } catch (e) {
      print('⚠️ Error loading comments: $e');
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
        print('Creating new proposal...');
        final result = await ApiService.createProposal(
          token: token,
          title: title,
          content: content,
          status: 'draft',
        );

        if (result != null && result['id'] != null) {
          setState(() {
            _savedProposalId = result['id'] is int
                ? result['id']
                : int.tryParse(result['id'].toString());
          });
          print('✅ Proposal created with ID: $_savedProposalId');
        } else {
          print('⚠️ Proposal creation returned null or no ID');
        }
      } else {
        // Update existing proposal
        print('Updating proposal ID: $_savedProposalId...');
        await ApiService.updateProposal(
          token: token,
          id: _savedProposalId!,
          title: title,
          content: content,
          status: 'draft',
        );
        print('✅ Proposal updated: $_savedProposalId');
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
      );
      _sections.add(newSection);
    }

    // Setup listeners for new sections
    for (var section in _sections) {
      section.controller.addListener(_onContentChanged);
      section.titleController.addListener(_onContentChanged);
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
                                    ? const Color(0xFF00BCD4).withOpacity(0.1)
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
          // Left Sidebar
          _buildLeftSidebar(),
          // Sections Sidebar (conditional)
          if (_showSectionsSidebar) _buildSectionsSidebar(),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Top header
                _buildTopHeader(),
                // Formatting toolbar
                _buildToolbar(),
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
                            // Floating toolbar on right
                            Positioned(
                              right: 20,
                              top: 0,
                              bottom: 0,
                              child: _buildFloatingToolbar(),
                            ),
                          ],
                        ),
                      ),
                      // Right sidebar
                      _buildRightSidebar(),
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
    return Container(
      width: 80,
      color: const Color(0xFF1A3A52),
      child: Column(
        children: [
          // Logo area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.description,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const Divider(color: Color(0xFF2C3E50), height: 1),
          // Navigation icons
          Expanded(
            child: Column(
              children: [
                _buildNavIcon(Icons.home, 'Home'),
                _buildNavIcon(Icons.star, 'Favorites'),
                _buildNavIcon(Icons.folder, 'Documents'),
                _buildNavIcon(Icons.people, 'Team'),
                _buildNavIcon(Icons.trending_up, 'Analytics'),
                _buildNavIcon(Icons.settings, 'Settings'),
              ],
            ),
          ),
          // Bottom logout icon
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _buildNavIcon(Icons.logout, 'Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          icon,
          color: Colors.white54,
          size: 24,
        ),
      ),
    );
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
                            Text(
                              _sections[index].title,
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
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Untitled Template',
                      hintStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFBDC3C7),
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4),
                    borderRadius: BorderRadius.circular(20),
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
                color: _hasUnsavedChanges
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _hasUnsavedChanges ? Colors.orange : Colors.green,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasUnsavedChanges ? Icons.pending : Icons.check_circle,
                    size: 14,
                    color: _hasUnsavedChanges ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hasUnsavedChanges
                        ? 'Unsaved changes'
                        : (_lastSaved == null ? 'Not Saved' : 'Saved'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _hasUnsavedChanges
                          ? Colors.orange[800]
                          : Colors.green[800],
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
          // Action buttons
          OutlinedButton.icon(
            onPressed: () {},
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
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveDocument,
            icon: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : const Icon(Icons.save, size: 16),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Save & Close button
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAndClose,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save & Close'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
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
            onPressed: () {},
            tooltip: 'Undo',
            iconSize: 18,
            splashRadius: 20,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () {},
            tooltip: 'Redo',
            iconSize: 18,
            splashRadius: 20,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Style dropdown
          _buildSmallDropdown(
              'Normal Text', ['Normal Text', 'Heading 1', 'Heading 2']),
          const SizedBox(width: 8),
          // Font dropdown
          _buildSmallDropdown('Plus Jakarta Sans',
              ['Plus Jakarta Sans', 'Arial', 'Times New Roman']),
          const SizedBox(width: 8),
          // Font size dropdown
          _buildSmallDropdown(
              '12px', ['10px', '12px', '14px', '16px', '18px', '20px']),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Text formatting
          IconButton(
            icon: const Icon(Icons.format_bold),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Bold',
          ),
          IconButton(
            icon: const Icon(Icons.format_italic),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Italic',
          ),
          IconButton(
            icon: const Icon(Icons.format_underlined),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Underline',
          ),
          IconButton(
            icon: const Icon(Icons.format_color_text),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Text Color',
          ),
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Link',
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Alignment
          IconButton(
            icon: const Icon(Icons.format_align_left),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Left',
          ),
          IconButton(
            icon: const Icon(Icons.format_align_center),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Align Center',
          ),
          IconButton(
            icon: const Icon(Icons.format_align_right),
            onPressed: () {},
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
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Bullet List',
          ),
          IconButton(
            icon: const Icon(Icons.format_list_numbered),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Numbered List',
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // Insert
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Insert Link',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'Insert Table',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {},
            iconSize: 18,
            splashRadius: 20,
            tooltip: 'AI Assistant',
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown(String label, List<String> items) {
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
        onChanged: (_) {},
      ),
    );
  }

  List<Widget> _buildA4Pages() {
    // A4 dimensions: 210mm x 297mm (aspect ratio 0.707)
    // Using fixed width of 794px (approx 210mm at 96 DPI)
    // Height: 1123px (approx 297mm at 96 DPI)
    const double pageWidth = 794;
    const double pageHeight = 1123; // A4 aspect ratio

    return List.generate(
      _sections.length,
      (index) => Container(
        width: pageWidth,
        constraints: const BoxConstraints(maxHeight: pageHeight),
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: _buildSectionContent(index),
          ),
        ),
      ),
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
              });
            },
            customBorder: CircleBorder(),
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
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        // Allow TextField to capture taps for focus
                        section.titleFocus.requestFocus();
                      },
                      child: TextField(
                        focusNode: section.titleFocus,
                        controller: section.titleController,
                        enabled: true,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Selection indicator
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // Allow TextField to capture taps for focus
                  section.contentFocus.requestFocus();
                },
                child: TextField(
                  focusNode: section.contentFocus,
                  controller: section.controller,
                  enabled: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                    height: 1.8,
                    letterSpacing: 0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Start typing or insert content from library...',
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

  void _addImageToSection(String imageName) {
    if (_sections.isEmpty) return;

    final section = _sections[_selectedSectionIndex];
    String newContent = section.controller.text;
    newContent += '\n[Image: $imageName]';

    setState(() {
      section.controller.text = newContent;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image "$imageName" added to "${section.title}"'),
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
                  const Text(
                    'Template Style Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
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
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
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
          // Upload button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _addSampleImage();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.grey[300]!, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 32, color: Colors.grey[600]),
                    const SizedBox(height: 8),
                    Text(
                      'Click to upload images',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[200]!),
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _uploadedImages[index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Click to insert into document',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              onTap: () {
                                _addImageToSection(_uploadedImages[index]);
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.add, size: 16),
                                  SizedBox(width: 8),
                                  Text('Insert'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              onTap: () {
                                setState(() {
                                  _uploadedImages.removeAt(index);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Image deleted'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.delete, size: 16),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          child: Icon(Icons.more_vert,
                              size: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ] else ...[
          // Show library content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Content Library',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse and manage your content library',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening Content Library...'),
                          backgroundColor: Color(0xFF1A3A52),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.library_books),
                    label: const Text('Open Content Library'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _addSampleImage() {
    final newImageName = 'image_${DateTime.now().millisecond}.jpg';
    setState(() {
      _uploadedImages.add(newImageName);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image "$newImageName" uploaded'),
        backgroundColor: const Color(0xFF27AE60),
        duration: const Duration(seconds: 2),
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
                            color: const Color(0xFF00BCD4).withOpacity(0.3)),
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

  void _showCollaborationDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
                      const SizedBox(width: 20),

                      Text(
                        'Invite others to collaborate on this proposal. They will be able to view, comment, and edit.',
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (emailController.text.isNotEmpty) {
                                setDialogState(() {
                                  _collaborators.add({
                                    'email': emailController.text,
                                    'name': emailController.text.split('@')[0],
                                    'role': 'Editor',
                                    'added_at':
                                        DateTime.now().toIso8601String(),
                                  });
                                  _isCollaborating = true;
                                });
                                setState(() {});
                                emailController.clear();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Invitation sent to ${emailController.text}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Invite'),
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
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        setDialogState(() {
                                          _collaborators.removeAt(index);
                                          if (_collaborators.isEmpty) {
                                            _isCollaborating = false;
                                          }
                                        });
                                        setState(() {});

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${collaborator['name']} removed from collaborators',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
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

  _DocumentSection({
    required this.title,
    required this.content,
  })  : controller = TextEditingController(text: content),
        titleController = TextEditingController(text: title),
        contentFocus = FocusNode(),
        titleFocus = FocusNode();
}
