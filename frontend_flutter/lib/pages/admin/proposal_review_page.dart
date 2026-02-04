import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../theme/premium_theme.dart';
import '../../widgets/header.dart';
import 'package:intl/intl.dart';

class ProposalReviewPage extends StatefulWidget {
  final String proposalId;
  final String? proposalTitle;

  const ProposalReviewPage({
    super.key,
    required this.proposalId,
    this.proposalTitle,
  });

  @override
  State<ProposalReviewPage> createState() => _ProposalReviewPageState();
}

class _ProposalReviewPageState extends State<ProposalReviewPage> {
  Map<String, dynamic>? _proposal;
  List<Map<String, dynamic>> _versions = [];
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  bool _showVersions = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProposal();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProposal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = AuthService.token;
      if (token == null) {
        setState(() {
          _error = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      final proposalId = int.tryParse(widget.proposalId);
      if (proposalId == null) {
        setState(() {
          _error = 'Invalid proposal ID';
          _isLoading = false;
        });
        return;
      }

      // Try to get proposal from pending approvals first (for admins)
      Map<String, dynamic>? proposal;
      try {
        final pendingResponse = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/proposals/pending_approval'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (pendingResponse.statusCode == 200) {
          final pendingData = json.decode(pendingResponse.body);
          final pendingProposals = List<Map<String, dynamic>>.from(
            pendingData['proposals'] ?? [],
          );
          proposal = pendingProposals.firstWhere(
            (p) => p['id'] == proposalId,
            orElse: () => <String, dynamic>{},
          );
        }
      } catch (e) {
        print('Error fetching from pending approvals: $e');
      }

      // If not found in pending approvals, try to get directly by ID
      if (proposal == null || proposal.isEmpty) {
        try {
          // Try with /api prefix first
          var response = await http.get(
            Uri.parse('${ApiService.baseUrl}/api/proposals/$proposalId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          // If that fails, try without /api prefix
          if (response.statusCode != 200) {
            response = await http.get(
              Uri.parse('${ApiService.baseUrl}/proposals/$proposalId'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );
          }

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            proposal = Map<String, dynamic>.from(data);
          }
        } catch (e) {
          print('Error fetching proposal by ID: $e');
        }
      }

      // If still not found, try from all proposals (fallback)
      if (proposal == null || proposal.isEmpty) {
        final proposals = await ApiService.getProposals(token);
        proposal = proposals.firstWhere(
          (p) => p['id'] == proposalId,
          orElse: () => <String, dynamic>{},
        );
      }

      if (proposal == null || proposal.isEmpty) {
        setState(() {
          _error = 'Proposal not found';
          _isLoading = false;
        });
        return;
      }

      // Load versions
      await _loadVersions(proposalId, token);

      // Load comments
      await _loadComments(proposalId, token);

      setState(() {
        _proposal = proposal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading proposal: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVersions(int proposalId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/proposals/$proposalId/versions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Backend may return either a raw list of versions or an object
        // containing a `versions` field. Handle both for robustness.
        List<Map<String, dynamic>> versions = [];
        if (data is List) {
          versions = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['versions'] is List) {
          versions = List<Map<String, dynamic>>.from(data['versions']);
        }

        // Normalize field names so the UI can always use `description`.
        versions = versions.map((v) {
          final normalized = Map<String, dynamic>.from(v);
          if (normalized['description'] == null &&
              normalized['change_description'] != null) {
            normalized['description'] = normalized['change_description'];
          }
          return normalized;
        }).toList();

        setState(() {
          _versions = versions;
        });
      }
    } catch (e) {
      print('Error loading versions: $e');
    }
  }

  Future<void> _loadComments(int proposalId, String token) async {
    try {
      // Try multiple endpoints for comments
      var response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/proposals/$proposalId/comments'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // If that fails, try the document comments endpoint
      if (response.statusCode != 200) {
        response = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/comments/document/$proposalId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle different response formats
        List<Map<String, dynamic>> comments = [];
        if (data is List) {
          comments = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('comments')) {
          comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
        } else if (data is Map && data.containsKey('comment')) {
          comments = [Map<String, dynamic>.from(data)];
        }

        setState(() {
          _comments = comments.map((c) {
            // Normalize comment structure
            final authorName = c['author_name'] ??
                c['author_username'] ??
                c['author_email'] ??
                c['author'] ??
                c['created_by_name'] ??
                'Unknown';
            return {
              'id': c['id'],
              'comment': c['comment_text'] ?? c['comment'] ?? '',
              'author': authorName,
              'created_at': c['created_at'],
            };
          }).toList();
        });
      } else {
        print('Failed to load comments: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      final token = AuthService.token;
      if (token == null) return;

      final proposalId = int.tryParse(widget.proposalId);
      if (proposalId == null) return;

      // Try the document comments endpoint
      var response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/comments/document/$proposalId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'comment_text': _commentController.text.trim(),
        }),
      );

      // If that fails, try the proposals comments endpoint
      if (response.statusCode != 200 && response.statusCode != 201) {
        response = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/proposals/$proposalId/comments'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'comment': _commentController.text.trim(),
          }),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        await _loadComments(proposalId, token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _approveProposal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Proposal'),
        content: Text(
          'Are you sure you want to approve "${_proposal?['title'] ?? 'this proposal'}"? '
          'This will send it to the client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: PremiumTheme.teal,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = AuthService.token;
      if (token == null) return;

      final proposalId = int.tryParse(widget.proposalId);
      if (proposalId == null) return;

      String? clientEmail;
      final rawEmail = _proposal?['client_email'] ?? _proposal?['clientEmail'];
      if (rawEmail is String && rawEmail.trim().isNotEmpty) {
        clientEmail = rawEmail.trim();
      }

      Future<http.Response> sendApproval({String? overrideEmail}) {
        final body = <String, dynamic>{};
        final emailToUse = overrideEmail ?? clientEmail;
        if (emailToUse != null && emailToUse.isNotEmpty) {
          body['client_email'] = emailToUse;
        }
        return http.post(
          Uri.parse('${ApiService.baseUrl}/api/proposals/$proposalId/approve'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        );
      }

      http.Response response = await sendApproval();

      if (response.statusCode == 400) {
        try {
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.contains('application/json')) {
            final error = json.decode(response.body);
            if (error is Map &&
                error['error'] == 'missing_client_email' &&
                error['has_override_option'] == true) {
              final controller = TextEditingController(text: clientEmail ?? '');
              final override = await showDialog<String>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Client Email Required'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Client Email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PremiumTheme.teal,
                        ),
                        child: const Text('Continue'),
                      ),
                    ],
                  );
                },
              );

              if (override != null && override.isNotEmpty) {
                clientEmail = override;
                response = await sendApproval(overrideEmail: override);
              }
            }
          }
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal approved and sent to client!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        String errorMessage = 'Failed to approve proposal';
        try {
          final contentType = response.headers['content-type'] ?? '';
          if (contentType.contains('application/json')) {
            final error = json.decode(response.body);
            errorMessage = error['detail'] ?? errorMessage;
          } else {
            if (response.statusCode == 404) {
              errorMessage =
                  'Proposal approval endpoint not found (404). Please check server configuration.';
            } else {
              errorMessage = 'Server error (${response.statusCode})';
            }
          }
        } catch (_) {
          if (response.statusCode == 404) {
            errorMessage =
                'Endpoint not found (404). The approval route may not be registered correctly.';
          } else {
            errorMessage = 'Server returned error ${response.statusCode}';
          }
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectProposal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Proposal'),
        content: Text(
          'Are you sure you want to reject "${_proposal?['title'] ?? 'this proposal'}"? '
          'It will be returned to draft status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = AuthService.token;
      if (token == null) return;

      final proposalId = int.tryParse(widget.proposalId);
      if (proposalId == null) return;

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/proposals/$proposalId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Proposal rejected and returned to draft'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject proposal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openInEditor() {
    if (_proposal == null) return;

    final id = widget.proposalId;
    if (id.isEmpty) return;

    Navigator.pushNamed(
      context,
      '/compose',
      arguments: {
        'id': id,
        'title':
            _proposal!['title'] ?? widget.proposalTitle ?? 'Untitled Proposal',
        // Explicitly allow editing for approvers while they are reviewing
        'readOnly': false,
        // Enforce mandatory change descriptions for new versions
        'requireVersionDescription': true,
        // Use collaborator mode to hide the creator navigation/sidebar while
        // still allowing full editing from the admin review context.
        'isCollaborator': true,
      },
    );
  }

  String _formatContent(dynamic content) {
    if (content == null) return 'No content available';
    if (content is String) {
      try {
        final parsed = json.decode(content);
        if (parsed is Map && parsed.containsKey('sections')) {
          final sections = parsed['sections'] as List;
          return sections.map((s) {
            final title = s['title'] ?? 'Untitled Section';
            final sectionContent = s['content'] ?? '';
            return '$title\n\n$sectionContent';
          }).join('\n\n---\n\n');
        }
        return content;
      } catch (e) {
        return content;
      }
    }
    return content.toString();
  }

  // Decode the structured document JSON produced by the blank document editor.
  Map<String, dynamic>? _parseDocumentData() {
    final raw = _proposal?['content'];
    if (raw is! String || raw.trim().isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      print(
          '⚠️ Failed to parse proposal document content for admin preview: $e');
    }
    return null;
  }

  Alignment _alignmentForFooterPosition(String? position) {
    switch (position) {
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      case 'center':
      default:
        return Alignment.center;
    }
  }

  Widget _buildAdminHeader(
    Map<String, dynamic> metadata,
    String? documentTitle,
  ) {
    final headerLogoUrl = metadata['headerLogoUrl'] as String?;
    final headerLogoPosition =
        (metadata['headerLogoPosition'] as String?) ?? 'left';
    final headerBackgroundImageUrl =
        metadata['headerBackgroundImageUrl'] as String?;

    Widget? logoWidget;
    if (headerLogoUrl != null && headerLogoUrl.trim().isNotEmpty) {
      logoWidget = SizedBox(
        height: 32,
        child: Image.network(
          headerLogoUrl,
          fit: BoxFit.contain,
        ),
      );
    }

    final titleText = documentTitle?.trim();

    return DocumentHeader(
      title: titleText != null && titleText.isNotEmpty ? titleText : null,
      subtitle: null,
      leading: headerLogoPosition == 'left' ? logoWidget : null,
      center: headerLogoPosition == 'center' ? logoWidget : null,
      trailing: headerLogoPosition == 'right' ? logoWidget : null,
      backgroundImageUrl: headerBackgroundImageUrl,
      showDivider: false,
    );
  }

  Widget _buildAdminFooter({
    required Map<String, dynamic> metadata,
    required int pageNumber,
    required int totalPages,
  }) {
    final footerLogoUrl = metadata['footerLogoUrl'] as String?;
    final footerLogoPosition =
        (metadata['footerLogoPosition'] as String?) ?? 'left';
    final footerPageNumberPosition =
        (metadata['footerPageNumberPosition'] as String?) ?? 'center';
    final footerProposalIdPosition =
        (metadata['footerProposalIdPosition'] as String?) ?? 'right';

    // Safely derive the numeric proposal ID from the loaded proposal map.
    int? proposalId;
    final dynamic rawId = _proposal?['id'];
    if (rawId is int) {
      proposalId = rawId;
    } else if (rawId is String) {
      proposalId = int.tryParse(rawId);
    } else if (rawId != null) {
      proposalId = int.tryParse(rawId.toString());
    }

    Widget? logo;
    if (footerLogoUrl != null && footerLogoUrl.trim().isNotEmpty) {
      logo = Align(
        alignment: _alignmentForFooterPosition(footerLogoPosition),
        child: SizedBox(
          width: 80,
          height: 32,
          child: Image.network(
            footerLogoUrl,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    final pageChip = Align(
      alignment: _alignmentForFooterPosition(footerPageNumberPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100]!.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          'Page $pageNumber of $totalPages',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    Widget? proposalIdWidget;
    if (proposalId != null) {
      proposalIdWidget = Align(
        alignment: _alignmentForFooterPosition(footerProposalIdPosition),
        child: Text(
          'Proposal ID: $proposalId',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Stack(
        children: [
          if (logo != null) logo,
          pageChip,
          if (proposalIdWidget != null) proposalIdWidget,
        ],
      ),
    );
  }

  /// Build an A4-style preview of the proposal content using the same
  /// document structure as the creator's blank document editor.
  Widget _buildStructuredDocumentPreview() {
    final data = _parseDocumentData();
    if (data == null) {
      return Text(
        _formatContent(_proposal!['content']),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          height: 1.6,
        ),
      );
    }

    final sectionsRaw = data['sections'];
    if (sectionsRaw is! List || sectionsRaw.isEmpty) {
      return Text(
        _formatContent(_proposal!['content']),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          height: 1.6,
        ),
      );
    }

    final List<Map<String, dynamic>> sections = sectionsRaw
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();

    final metadata = (data['metadata'] is Map)
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : <String, dynamic>{};

    final String documentTitle =
        (data['title'] ?? _proposal?['title'] ?? 'Untitled Document')
            .toString();

    const double pageWidth = 900;
    const double pageHeight = 1273;

    return Center(
      child: Column(
        children: [
          ...sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;

            final sectionTitle =
                (section['title'] ?? 'Untitled Section').toString();
            final sectionContent = (section['content'] ?? '').toString();

            final int? bgColorValue = section['backgroundColor'] is int
                ? section['backgroundColor'] as int
                : int.tryParse(section['backgroundColor']?.toString() ?? '');
            final Color backgroundColor =
                bgColorValue != null ? Color(bgColorValue) : Colors.white;
            final String? backgroundImageUrl =
                section['backgroundImageUrl'] as String?;

            return Container(
              width: pageWidth,
              height: pageHeight,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color:
                    backgroundImageUrl == null ? backgroundColor : Colors.white,
                image: backgroundImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(backgroundImageUrl),
                        fit: BoxFit.cover,
                        opacity: 0.7,
                      )
                    : null,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildAdminHeader(metadata, documentTitle),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sectionTitle.isEmpty
                                  ? 'Untitled Section'
                                  : sectionTitle,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A3A52),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              sectionContent.isEmpty
                                  ? '(No content in this section)'
                                  : sectionContent,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1A1A1A),
                                height: 1.8,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildAdminFooter(
                    metadata: metadata,
                    pageNumber: index + 1,
                    totalPages: sections.length,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Review Proposal',
          style: PremiumTheme.titleMedium.copyWith(color: Colors.white),
        ),
        actions: [
          if (_proposal != null) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: _openInEditor,
              tooltip: 'Edit in Editor',
            ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () => setState(() => _showVersions = !_showVersions),
              tooltip: 'Versions',
            ),
            IconButton(
              icon: const Icon(Icons.comment, color: Colors.white),
              onPressed: () {
                // Scroll to comments section
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                } else {
                  // If scroll controller not attached yet, wait a bit
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (_scrollController.hasClients && mounted) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  });
                }
              },
              tooltip: 'Comments (${_comments.length})',
            ),
            ElevatedButton.icon(
              onPressed: _rejectProposal,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _approveProposal,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProposal,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _proposal == null
                  ? const Center(
                      child: Text('Proposal not found',
                          style: TextStyle(color: Colors.white)),
                    )
                  : Row(
                      children: [
                        // Main content area
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Proposal header
                                GlassContainer(
                                  borderRadius: 20,
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _proposal!['title'] ?? 'Untitled',
                                        style: PremiumTheme.titleLarge
                                            .copyWith(color: Colors.white),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _buildInfoChip(
                                            Icons.business,
                                            _proposal!['client_name'] ??
                                                'Unknown Client',
                                          ),
                                          const SizedBox(width: 12),
                                          if (_proposal!['budget'] != null)
                                            _buildInfoChip(
                                              Icons.attach_money,
                                              'R${_proposal!['budget']}',
                                            ),
                                          const SizedBox(width: 12),
                                          _buildInfoChip(
                                            Icons.calendar_today,
                                            _proposal!['updated_at'] != null
                                                ? DateFormat('dd MMM yyyy')
                                                    .format(DateTime.parse(
                                                        _proposal![
                                                            'updated_at']))
                                                : 'Unknown date',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Proposal content
                                GlassContainer(
                                  borderRadius: 20,
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Proposal Content',
                                        style: PremiumTheme.bodyLarge.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child:
                                            _buildStructuredDocumentPreview(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Versions section
                                if (_showVersions) ...[
                                  if (_versions.isEmpty)
                                    GlassContainer(
                                      borderRadius: 20,
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Versions',
                                            style:
                                                PremiumTheme.bodyLarge.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text(
                                              'No versions available yet',
                                              style: TextStyle(
                                                color: Colors.white54,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    GlassContainer(
                                      borderRadius: 20,
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Versions (${_versions.length})',
                                            style:
                                                PremiumTheme.bodyLarge.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ..._versions.map((version) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Version ${version['version_number']}',
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            if (version[
                                                                    'description'] !=
                                                                null)
                                                              Text(
                                                                version[
                                                                    'description'],
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      Text(
                                                        version['created_at'] !=
                                                                null
                                                            ? DateFormat(
                                                                    'dd MMM yyyy HH:mm')
                                                                .format(DateTime
                                                                    .parse(version[
                                                                        'created_at']))
                                                            : '',
                                                        style: TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                ],

                                // Comments section
                                GlassContainer(
                                  borderRadius: 20,
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Comments (${_comments.length})',
                                        style: PremiumTheme.bodyLarge.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Add comment
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _commentController,
                                                style: const TextStyle(
                                                    color: Colors.white),
                                                decoration:
                                                    const InputDecoration(
                                                  hintText: 'Add a comment...',
                                                  hintStyle: TextStyle(
                                                      color: Colors.white54),
                                                  border: InputBorder.none,
                                                ),
                                                maxLines: 3,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: _isSubmittingComment
                                                  ? null
                                                  : _submitComment,
                                              child: _isSubmittingComment
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Text('Post'),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Comments list
                                      if (_comments.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            'No comments yet',
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        )
                                      else
                                        ..._comments.map((comment) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          comment['author'] ??
                                                              'Unknown',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        if (comment[
                                                                'created_at'] !=
                                                            null)
                                                          Text(
                                                            DateFormat(
                                                                    'dd MMM yyyy HH:mm')
                                                                .format(DateTime
                                                                    .parse(comment[
                                                                        'created_at'])),
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      comment['comment'] ?? '',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PremiumTheme.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PremiumTheme.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: PremiumTheme.orange),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PremiumTheme.orange,
            ),
          ),
        ],
      ),
    );
  }
}
