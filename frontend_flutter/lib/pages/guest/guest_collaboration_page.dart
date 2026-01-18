import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'dart:async';
import '../../api.dart';
import '../../config/api_config.dart';

class GuestCollaborationPage extends StatefulWidget {
  const GuestCollaborationPage({super.key});

  @override
  State<GuestCollaborationPage> createState() => _GuestCollaborationPageState();
}

class _GuestCollaborationPageState extends State<GuestCollaborationPage> {
  bool _isLoading = true;
  String? _error;
  String? _accessToken;
  Map<String, dynamic>? _proposalData;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  // Mention/autocomplete state
  Timer? _mentionDebounce;
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _showSuggestions = false;
  int _mentionStartIndex = -1; // index in text where current @ started
  String _mentionQuery = '';
  List<Map<String, dynamic>> _taggedUsers = []; // Track users that were tagged

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractTokenAndLoad();
    });
    _commentController.addListener(_onCommentChanged);
  }

  void _onCommentChanged() {
    final text = _commentController.text;
    final selection = _commentController.selection;
    final caret = selection.baseOffset;

    if (caret < 0) {
      _hideSuggestions();
      return;
    }

    // Find last '@' before the caret that is not preceded by a non-whitespace (i.e., start or whitespace)
    final textBefore = text.substring(0, caret);
    final atIndex = textBefore.lastIndexOf('@');

    if (atIndex == -1) {
      _hideSuggestions();
      return;
    }

    // Ensure '@' is start of word (start or preceded by whitespace/newline)
    if (atIndex > 0) {
      final charBefore = textBefore[atIndex - 1];
      if (charBefore != ' ' && charBefore != '\n' && charBefore != '\t') {
        _hideSuggestions();
        return;
      }
    }

    final query = textBefore.substring(atIndex + 1);
    // If query contains whitespace or punctuation, not a mention
    if (query.contains(RegExp(r"\s|[.,:;!?]"))) {
      _hideSuggestions();
      return;
    }

    // Allow empty query so typing just '@' shows default suggestions (owner + invited collaborators).
    // We'll still search with an empty string which the backend handles by returning the owner/invited list
    // when a valid collab token and proposal_id are present.

    _mentionStartIndex = atIndex;
    _mentionQuery = query;
    _searchUsersDebounced(query);
  }

  void _hideSuggestions() {
    if (_showSuggestions) {
      setState(() {
        _showSuggestions = false;
        _userSuggestions = [];
      });
    }
  }

  void _searchUsersDebounced(String q) {
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 250), () {
      _searchUsers(q);
    });
  }

  Future<void> _searchUsers(String q) async {
    // Allow empty query so backend can return default suggestions when appropriate.

    try {
      // Include proposal_id and collaboration token when available so guests can search
      final params = {
        'q': q,
        if (_proposalData != null && _proposalData!['proposal'] != null)
          'proposal_id': _proposalData!['proposal']['id']?.toString(),
        if (_accessToken != null) 'collab_token': _accessToken!,
      }..removeWhere((k, v) => v == null);

      final uri = Uri.parse('${ApiConfig.backendBaseUrl}/users/search?${Uri(queryParameters: params).query}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        final results =
            data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        setState(() {
          _userSuggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      } else {
        setState(() {
          _userSuggestions = [];
          _showSuggestions = false;
        });
      }
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _userSuggestions = [];
        _showSuggestions = false;
      });
    }
  }

  void _insertMentionAtCursor(Map<String, dynamic> user) {
    final username = user['username'] ??
        user['email'] ??
        user['name'] ??
        user['id']?.toString() ??
        'user';
    final text = _commentController.text;
    final selection = _commentController.selection;
    final caret =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final start = (_mentionStartIndex != -1 && _mentionStartIndex <= caret)
        ? _mentionStartIndex
        : caret;

    final before = text.substring(0, start);
    final after = text.substring(caret);
    final insertText = '@$username ';
    final newText = before + insertText + after;

    setState(() {
      // Add user to tagged list if not already present
      if (!_taggedUsers.any((tagged) => tagged['id'] == user['id'])) {
        _taggedUsers.add(user);
      }
      _commentController.text = newText;
      final newPos = (before + insertText).length;
      _commentController.selection =
          TextSelection.fromPosition(TextPosition(offset: newPos));
      _showSuggestions = false;
      _userSuggestions = [];
      _mentionStartIndex = -1;
      _mentionQuery = '';
    });
  }

  List<InlineSpan> _buildCommentTextSpans(String text) {
    final spans = <InlineSpan>[];
    final mentionRegex = RegExp(r'@([A-Za-z0-9_.]+)');
    int lastEnd = 0;
    for (final m in mentionRegex.allMatches(text)) {
      if (m.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
      }
      final uname = m.group(0) ?? '';
      // WidgetSpan with Tooltip and clickable mention
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () {
            // Placeholder: open profile or show message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Open profile for ${m.group(1)}')),
            );
          },
          child: Tooltip(
            message: 'Mentioned — will be notified',
            child: Text(
              uname,
              style: const TextStyle(
                color: Color(0xFF3498DB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ));
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return spans;
  }

  void _extractTokenAndLoad() {
    // Get token from URL query parameters
    // For Flutter web with hash routing, need to parse window.location.href
    String? token;

    try {
      // Get the full URL from the browser
      final currentUrl = web.window.location.href;
      print('🔍 Full URL: $currentUrl');
      print('🔍 Hash: ${web.window.location.hash}');
      print('🔍 Search: ${web.window.location.search}');

      // Parse the URL
      final uri = Uri.parse(currentUrl);
      print('🔍 URI Fragment: ${uri.fragment}');
      print('🔍 URI Query: ${uri.query}');

      // Try 1: Direct query parameters (before #)
      token = uri.queryParameters['token'];
      print('📍 Try 1 - Token from URI query params: $token');

      // Try 2: From window.location.search
      if (token == null || token.isEmpty) {
        final search = web.window.location.search;
        if (search.isNotEmpty) {
          final searchUri = Uri.parse('${ApiConfig.frontendBaseUrl}/dummy$search');
          token = searchUri.queryParameters['token'];
          print('📍 Try 2 - Token from location.search: $token');
        }
      }

      // Try 3: Parse from fragment (after #)
      if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
        final fragment = uri.fragment;
        print('📍 Try 3 - Parsing fragment: $fragment');

        // Fragment might be like: /collaborate?token=xyz
        if (fragment.contains('token=')) {
          final queryStart = fragment.indexOf('?');
          if (queryStart != -1) {
            final queryString = fragment.substring(queryStart + 1);
            print('📍 Query string from fragment: $queryString');

            // Parse query string manually
            final params = Uri.splitQueryString(queryString);
            token = params['token'];
            print('📍 Token from fragment: $token');
          }
        }
      }

      // Try 4: Direct from window.location.hash
      if (token == null || token.isEmpty) {
        final hash = web.window.location.hash;
        if (hash.contains('token=')) {
          final tokenMatch = RegExp(r'token=([^&]+)').firstMatch(hash);
          if (tokenMatch != null) {
            token = tokenMatch.group(1);
            print('📍 Try 4 - Token from regex: $token');
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error parsing URL: $e');
      print('❌ Stack trace: $stackTrace');
    }

    if (token == null || token.isEmpty) {
      setState(() {
        _error =
            'No access token provided. Check browser console (F12) for debug info.';
        _isLoading = false;
      });
      return;
    }

    print('✅ Token extracted successfully: ${token.substring(0, 20)}...');
    setState(() {
      _accessToken = token;
    });

    _loadProposal();
  }

  Future<void> _loadProposal() async {
    if (_accessToken == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/collaborate?token=$_accessToken'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _proposalData = data;
          _comments = (data['comments'] as List?)
                  ?.map((c) => Map<String, dynamic>.from(c))
                  .toList() ??
              [];
          _isLoading = false;
        });
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _error = error['detail'] ?? 'Failed to load proposal';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final text = _commentController.text.trim();

      // Get tagged user IDs from our tracked list
      final taggedUserIds = _taggedUsers
          .where((u) => text.contains(
              '@${u['username'] ?? u['email'] ?? u['name'] ?? u['id']}'))
          .map((u) => u['id']?.toString() ?? u['email'])
          .where((id) => id != null)
          .toList();

      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/collaborate/comment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': _accessToken,
          'comment_text': text,
          'tagged_users': taggedUserIds,
        }),
      );

      if (response.statusCode == 201) {
        _commentController.clear();
        _taggedUsers.clear(); // Clear tagged users list after successful post
        await _loadProposal(); // Reload to get updated comments

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to add comment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmittingComment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading proposal...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadProposal(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final proposal = _proposalData?['proposal'];
    final canComment = _proposalData?['can_comment'] == true;
    final permissionLevel = _proposalData?['permission_level'] ?? 'view';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF2C3E50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.description, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal?['title'] ?? 'Untitled Proposal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            permissionLevel == 'comment'
                                ? Icons.comment
                                : Icons.visibility,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            permissionLevel == 'comment'
                                ? 'You can view and comment'
                                : 'View only access',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _proposalData?['invited_email'] ?? 'Guest',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Row(
              children: [
                // Proposal Content (Left Side)
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Proposal Content',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Shared by ${proposal?['owner_name'] ?? proposal?['owner_email'] ?? 'Unknown'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),

                          // Proposal content
                          _buildProposalContent(proposal?['content']),
                        ],
                      ),
                    ),
                  ),
                ),

                // Comments Sidebar (Right Side)
                Container(
                  width: 350,
                  margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                  child: Column(
                    children: [
                      // Comments section
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.comment,
                                      size: 20, color: Color(0xFF3498DB)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Comments (${_comments.length})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Comments list
                              Expanded(
                                child: _comments.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.chat_bubble_outline,
                                                size: 48,
                                                color: Colors.grey[300]),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No comments yet',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: _comments.length,
                                        itemBuilder: (context, index) {
                                          final comment = _comments[index];
                                          return _buildCommentItem(comment);
                                        },
                                      ),
                              ),

                              // Add comment section
                              if (canComment) ...[
                                const Divider(height: 24),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _commentController,
                                            decoration: InputDecoration(
                                              hintText: 'Add a comment...',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                            ),
                                            maxLines: 2,
                                            enabled: !_isSubmittingComment,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: _isSubmittingComment
                                              ? null
                                              : _submitComment,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF27AE60),
                                            padding: const EdgeInsets.all(14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: _isSubmittingComment
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors.white),
                                                  ),
                                                )
                                              : const Icon(Icons.send,
                                                  size: 20),
                                        ),
                                      ],
                                    ),

                                    // Suggestions dropdown
                                    if (_showSuggestions) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        constraints: const BoxConstraints(
                                            maxHeight: 160),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: _userSuggestions.length,
                                          itemBuilder: (context, i) {
                                            final u = _userSuggestions[i];
                                            final uname = u['username'] ??
                                                u['email'] ??
                                                u['name'] ??
                                                u['id']?.toString() ??
                                                'user';
                                            final display = u['display_name'] ??
                                                u['name'] ??
                                                uname;
                                            return ListTile(
                                              dense: true,
                                              title: Text(uname),
                                              subtitle:
                                                  Text(display.toString()),
                                              onTap: () {
                                                _insertMentionAtCursor(u);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ] else ...[
                                const Divider(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.orange[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: Colors.orange[700], size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'You have view-only access',
                                          style: TextStyle(
                                            color: Colors.orange[900],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildProposalContent(dynamic content) {
    if (content == null) {
      return const Text('No content available');
    }

    // Handle JSON content (sections format)
    if (content is String) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          return _buildSectionsView(decoded);
        }
      } catch (e) {
        // Not JSON, treat as plain text
      }

      // Plain text content
      return SelectableText(
        content,
        style: const TextStyle(fontSize: 14, height: 1.6),
      );
    }

    if (content is Map) {
      return _buildSectionsView(content);
    }

    return const Text('Invalid content format');
  }

  Widget _buildSectionsView(Map<dynamic, dynamic> sections) {
    if (sections.isEmpty) {
      return const Text('No sections available');
    }

    final sectionWidgets = <Widget>[];

    sections.forEach((key, value) {
      sectionWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              value?.toString() ?? '',
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sectionWidgets,
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    // Use created_by_name if available, fall back to created_by_email, then 'Unknown'
    final commenterName = comment['created_by_name']?.toString() ??
        comment['created_by_email']?.toString() ??
        'User #${comment['created_by']?.toString() ?? 'Unknown'}';
    final commentText = comment['comment_text']?.toString() ?? '';
    final timestamp = comment['created_at']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF3498DB),
                child: Text(
                  commenterName.isNotEmpty
                      ? commenterName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  commenterName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: Colors.black),
              children: _buildCommentTextSpans(commentText),
            ),
          ),
          if (timestamp.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timestamp;
    }
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }
}
