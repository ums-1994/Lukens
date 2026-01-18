import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web/web.dart' as web;
import '../../api.dart';
import '../../config/api_config.dart';

class ClientProposalViewer extends StatefulWidget {
  final int proposalId;
  final String accessToken;

  const ClientProposalViewer({
    super.key,
    required this.proposalId,
    required this.accessToken,
  });

  @override
  State<ClientProposalViewer> createState() => _ClientProposalViewerState();
}

class _ClientProposalViewerState extends State<ClientProposalViewer> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _proposalData;
  Map<String, dynamic>? _signatureData;
  String? _signingUrl;
  String? _signatureStatus;
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _activityLog = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  String? _currentSessionId;
  // Section-by-section viewing state for analytics
  List<Map<String, dynamic>> _sections = [];
  int _currentSectionIndex = 0;
  DateTime? _sectionViewStart;

  int _selectedTab = 0; // 0: Content, 1: Comments

  @override
  void initState() {
    super.initState();
    _checkIfReturnedFromSigning();
    _loadProposal();
    _startSession();
    _logEvent('open');
  }

  List<Map<String, dynamic>> _parseSectionsFromContent(dynamic content) {
    try {
      if (content == null) return [];

      dynamic decoded = content;
      if (decoded is String) {
        if (decoded.trim().isEmpty) return [];
        decoded = jsonDecode(decoded);
      }

      if (decoded is Map<String, dynamic>) {
        if (decoded['sections'] is List) {
          final list = decoded['sections'] as List;
          return list
              .where((item) => item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }

        return decoded.entries
            .map((entry) => <String, dynamic>{
                  'title': entry.key,
                  'content': entry.value?.toString() ?? '',
                })
            .toList();
      }

      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded as Map);
        return _parseSectionsFromContent(map);
      }

      if (decoded is List) {
        return decoded
            .where((item) => item is Map)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      return [
        {
          'title': 'Content',
          'content': decoded.toString(),
        },
      ];
    } catch (e) {
      print('Error parsing sections from content: $e');
      return [];
    }
  }

  void _logCurrentSectionView() {
    if (_sections.isEmpty || _sectionViewStart == null) return;

    final now = DateTime.now();
    final index = _currentSectionIndex.clamp(0, _sections.length - 1);
    final section = _sections[index];
    final sectionTitle =
        (section['title']?.toString().trim().isNotEmpty ?? false)
            ? section['title'].toString().trim()
            : 'Section ${index + 1}';

    final durationSeconds = now.difference(_sectionViewStart!).inSeconds;
    final safeDuration = durationSeconds <= 0 ? 1 : durationSeconds;

    _logEvent('view_section', metadata: {
      'section': sectionTitle,
      'duration': safeDuration,
    });
  }

  void _onSectionChanged(int newIndex) {
    if (_sections.isEmpty) return;
    if (newIndex < 0 || newIndex >= _sections.length) return;

    final now = DateTime.now();

    // Log time spent on previous section before switching
    if (_sectionViewStart != null && newIndex != _currentSectionIndex) {
      final prevIndex = _currentSectionIndex.clamp(0, _sections.length - 1);
      final previousSection = _sections[prevIndex];
      final prevTitle =
          (previousSection['title']?.toString().trim().isNotEmpty ?? false)
              ? previousSection['title'].toString().trim()
              : 'Section ${prevIndex + 1}';

      final durationSeconds = now.difference(_sectionViewStart!).inSeconds;
      final safeDuration = durationSeconds <= 0 ? 1 : durationSeconds;

      _logEvent('view_section', metadata: {
        'section': prevTitle,
        'duration': safeDuration,
      });
    }

    setState(() {
      _currentSectionIndex = newIndex;
      _sectionViewStart = now;
    });
  }

  void _checkIfReturnedFromSigning() {
    // Check if we're returning from DocuSign signing
    if (kIsWeb) {
      final currentUrl = web.window.location.href;
      final uri = Uri.parse(currentUrl);

      // Check for signed=true in query params or hash
      final signedParam = uri.queryParameters['signed'];
      final hash = uri.fragment;
      final hasSignedInHash = hash.contains('signed=true');

      if (signedParam == 'true' || hasSignedInHash) {
        print('✅ Detected return from DocuSign signing');
        // Reload proposal after a short delay to ensure backend has updated
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _loadProposal();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _logCurrentSectionView();
    _endSession();
    _logEvent('close');
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/client/session/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.accessToken,
          'proposal_id': widget.proposalId,
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _currentSessionId = data['session_id'];
        });
      }
    } catch (e) {
      print('Error starting session: $e');
    }
  }

  Future<void> _endSession() async {
    if (_currentSessionId != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.backendBaseUrl}/api/client/session/end'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'session_id': _currentSessionId,
          }),
        );
      } catch (e) {
        print('Error ending session: $e');
      }
    }
  }

  Future<void> _logEvent(String eventType,
      {Map<String, dynamic>? metadata}) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/client/activity'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.accessToken,
          'proposal_id': widget.proposalId,
          'event_type': eventType,
          'metadata': metadata ?? {},
        }),
      );
    } catch (e) {
      print('Error logging event: $e');
    }
  }

  Future<void> _loadProposal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.backendBaseUrl}/api/client/proposals/${widget.proposalId}?token=${widget.accessToken}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📄 Proposal data received: ${data['proposal']?['title']}');
        final content = data['proposal']?['content'];
        print('📄 Content type: ${content?.runtimeType}');
        if (content != null) {
          final contentStr = content.toString();
          final preview = contentStr.length > 100
              ? contentStr.substring(0, 100)
              : contentStr;
          print('📄 Content value: $preview');
        } else {
          print('📄 Content is null or empty');
        }
        final parsedSections = _parseSectionsFromContent(content);

        setState(() {
          _proposalData = data['proposal'];
          _signatureData = data['signature'] != null
              ? Map<String, dynamic>.from(data['signature'])
              : null;
          _signingUrl = _signatureData?['signing_url']?.toString();
          _signatureStatus = _signatureData?['status']?.toString();

          // Debug logging for signature data
          print('📝 Signature data: ${_signatureData?.toString()}');
          print('📝 Signing URL: $_signingUrl');
          print('📝 Signature Status: $_signatureStatus');

          _comments = (data['comments'] as List?)
                  ?.map((c) => Map<String, dynamic>.from(c))
                  .toList() ??
              [];
          _activityLog = (data['activity'] as List?)
                  ?.map((a) => Map<String, dynamic>.from(a))
                  .toList() ??
              [];
          _sections = parsedSections;
          _currentSectionIndex = 0;
          _sectionViewStart = _sections.isNotEmpty ? DateTime.now() : null;
          _isLoading = false;
        });
      } else {
        final errorBody = response.body;
        print('❌ Error loading proposal: ${response.statusCode}');
        print('❌ Error body: $errorBody');
        try {
          final error = jsonDecode(errorBody);
          setState(() {
            _error = error['detail'] ?? 'Failed to load proposal';
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _error =
                'Failed to load proposal (${response.statusCode}): $errorBody';
            _isLoading = false;
          });
        }
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
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/client/proposals/${widget.proposalId}/comment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': widget.accessToken,
          'comment_text': _commentController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        _logEvent('comment', metadata: {
          'comment_length': _commentController.text.trim().length
        });
        _commentController.clear();
        await _loadProposal();

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

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => RejectDialog(
        proposalId: widget.proposalId,
        accessToken: widget.accessToken,
        onSuccess: () {
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Go back to dashboard
        },
      ),
    );
  }

  void _showApproveDialog() {
    showDialog(
      context: context,
      builder: (context) => ApproveDialog(
        proposalId: widget.proposalId,
        accessToken: widget.accessToken,
        onSuccess: () {
          Navigator.pop(context); // Close dialog
          _loadProposal(); // Reload to show updated status
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F9),
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
        backgroundColor: const Color(0xFFF5F7F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C3E50),
          title: const Text('Error'),
        ),
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

    final proposal = _proposalData!;
    final status = proposal['status'] as String? ?? 'Unknown';
    final signatureStatus = (_signatureStatus ?? '').toLowerCase();
    final isSigned = signatureStatus.contains('completed');
    final isDeclined = signatureStatus.contains('declined');
    // Show action bar if not signed and not declined, or if signature status is unknown
    final canTakeAction = !isSigned && !isDeclined;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: Column(
        children: [
          // Header
          _buildHeader(proposal, status),

          // Action Buttons - Always show if proposal is not signed
          if (canTakeAction) _buildActionBar(),

          // Content
          Expanded(
            child: _selectedTab == 0
                ? _buildProposalContent(proposal)
                : _buildCommentsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> proposal, String status) {
    return Container(
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal['title'] ?? 'Untitled Proposal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Proposal #${proposal['id']} • ${_formatDate(proposal['updated_at'])}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge(status),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () {
              _logEvent('download');
              // TODO: Download as PDF
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF download coming soon')),
              );
            },
            tooltip: 'Download PDF',
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    final signatureStatus = (_signatureStatus ?? '').toLowerCase();
    final isSigned = signatureStatus.contains('completed');
    final isDeclined = signatureStatus.contains('declined');
    final hasSigningUrl = _signingUrl != null && _signingUrl!.isNotEmpty;

    // Debug logging
    print(
        '🔍 Action Bar - isSigned: $isSigned, isDeclined: $isDeclined, hasSigningUrl: $hasSigningUrl');
    print(
        '🔍 Action Bar - signatureStatus: $_signatureStatus, signingUrl: $_signingUrl');
    final statusColor = isSigned
        ? Colors.green
        : isDeclined
            ? Colors.red
            : Colors.blue;
    final statusIcon = isSigned
        ? Icons.verified
        : isDeclined
            ? Icons.cancel
            : Icons.info_outline;
    final message = isSigned
        ? 'This proposal has been signed. Thank you for completing the process.'
        : isDeclined
            ? 'You previously declined this proposal. Contact your Khonology partner for assistance.'
            : hasSigningUrl
                ? 'Please review the proposal and sign using the secure DocuSign link.'
                : 'This proposal is ready for review.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isSigned)
            OutlinedButton.icon(
              onPressed: _showRejectDialog,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          if (!isSigned && hasSigningUrl) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                print('🔐 ========== SIGN PROPOSAL BUTTON CLICKED ==========');
                print(
                    '🔐 Current URL before click: ${web.window.location.href}');
                print(
                    '🔐 Signing URL: ${_signingUrl?.substring(0, _signingUrl!.length > 80 ? 80 : _signingUrl!.length)}...');

                if (_signingUrl == null || _signingUrl!.isEmpty) {
                  print('⚠️ No signing URL available');
                  _openSigningModal();
                  return;
                }

                // Open DocuSign in the same tab (redirect mode - works on HTTP)
                print('🔐 Opening DocuSign in same tab (redirect mode)...');
                final url = _signingUrl!;

                try {
                  print(
                      '🔐 Navigating to DocuSign URL: ${url.substring(0, url.length > 100 ? 100 : url.length)}...');

                  // Use replace() to navigate to external URL (bypasses Flutter routing)
                  // This prevents Flutter from intercepting the external DocuSign URL
                  web.window.location.replace(url);
                  print(
                      '✅ Navigation initiated to DocuSign using location.replace()');

                  // Note: We don't show a SnackBar here because the page will navigate immediately
                  // The navigation happens synchronously, so any mounted check would be unreliable
                } catch (e, stackTrace) {
                  print('❌ Error opening DocuSign: $e');
                  print('❌ Stack trace: $stackTrace');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening DocuSign: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 10),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.draw, size: 18),
              label: const Text('Sign Proposal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ] else if (!isSigned && !hasSigningUrl) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showApproveDialog,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _loadProposal,
              child: const Text('Refresh'),
            )
          ]
        ],
      ),
    );
  }

  Future<void> _openSigningModal() async {
    print('🔐 Opening signing modal...');
    print('🔐 Current signing URL: $_signingUrl');
    _logEvent('sign', metadata: {'action': 'signing_modal_opened'});

    // If no signing URL, try to get/create one
    if (_signingUrl == null || _signingUrl!.isEmpty) {
      print('⚠️ No signing URL, creating one...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creating signing link...'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      try {
        final response = await http.post(
          Uri.parse(
              '${ApiConfig.backendBaseUrl}/api/client/proposals/${widget.proposalId}/get_signing_url'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'token': widget.accessToken,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final signingUrl = data['signing_url']?.toString();
          if (signingUrl != null && signingUrl.isNotEmpty) {
            setState(() {
              _signingUrl = signingUrl;
            });
            // Continue to open modal with the new URL
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Failed to create signing link. Please try again later.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } else {
          final error = jsonDecode(response.body);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(error['detail'] ?? 'Failed to create signing link'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
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
        return;
      }
    }

    if (!kIsWeb) {
      await launchUrlString(_signingUrl!, mode: LaunchMode.externalApplication);
      return;
    }

    // Use redirect mode - navigate to DocuSign in the same tab (works on HTTP)
    final urlToOpen = _signingUrl!;
    print(
        '🔐 Opening DocuSign URL (redirect mode): ${urlToOpen.substring(0, urlToOpen.length > 100 ? 100 : urlToOpen.length)}...');

    try {
      if (kIsWeb) {
        // Navigate to DocuSign in the same tab (redirect mode)
        // Use replace() to navigate to external URL (bypasses Flutter routing)
        print('🔐 Navigating to DocuSign in same tab...');
        web.window.location.replace(urlToOpen);
        print('✅ Navigation initiated to DocuSign using location.replace()');
      } else {
        // For mobile, use external launcher
        await launchUrlString(
          urlToOpen,
          mode: LaunchMode.externalApplication,
        );
        print('✅ Opened DocuSign via launcher');
      }
    } catch (e) {
      print('❌ Error opening DocuSign: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening DocuSign: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab(0, 'Proposal Content', Icons.description),
          _buildTab(1, 'Comments (${_comments.length})', Icons.comment),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    isSelected ? const Color(0xFF3498DB) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF3498DB) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? const Color(0xFF3498DB) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProposalContent(Map<String, dynamic> proposal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            // Title
            Text(
              proposal['title'] ?? 'Untitled',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Shared by ${proposal['owner_name'] ?? 'Unknown'}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const Divider(height: 40),

            // Content
            _buildContentSections(proposal['content']),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSections(dynamic content) {
    if (_sections.isNotEmpty) {
      final total = _sections.length;
      final index = _currentSectionIndex.clamp(0, total - 1);
      final currentSection = _sections[index];
      final sectionTitle =
          (currentSection['title']?.toString().trim().isNotEmpty ?? false)
              ? currentSection['title'].toString().trim()
              : 'Section ${index + 1}';
      final sectionContent = currentSection['content']?.toString() ??
          currentSection['text']?.toString() ??
          '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sections',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              Text(
                'Section ${index + 1} of $total',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(total, (i) {
                final section = _sections[i];
                final title =
                    (section['title']?.toString().trim().isNotEmpty ?? false)
                        ? section['title'].toString().trim()
                        : 'Section ${i + 1}';
                final isSelected = i == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _onSectionChanged(i);
                      }
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            sectionContent,
            style: const TextStyle(
              fontSize: 15,
              height: 1.8,
              color: Color(0xFF34495E),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed:
                    index > 0 ? () => _onSectionChanged(index - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous section'),
              ),
              TextButton.icon(
                onPressed: index < total - 1
                    ? () => _onSectionChanged(index + 1)
                    : null,
                label: const Text('Next section'),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
    }

    if (content == null || content.toString().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No content available',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'The proposal content has not been added yet.',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Try to parse as JSON
    try {
      if (content is String) {
        if (content.trim().isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No content available',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          );
        }
        final decoded = jsonDecode(content);
        return _buildContentSections(decoded);
      } else if (content is Map || content is List) {
        return _buildContentSections(_parseSectionsFromContent(content));
      } else {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            content.toString(),
            style: const TextStyle(fontSize: 15, height: 1.8),
          ),
        );
      }
    } catch (e) {
      print('Error parsing content: $e');
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error parsing content',
              style: TextStyle(fontSize: 16, color: Colors.red[600]),
            ),
            const SizedBox(height: 8),
            SelectableText(
              content.toString(),
              style: const TextStyle(fontSize: 15, height: 1.8),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActivityTimeline() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            const Text(
              'Activity Timeline',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 24),
            if (_activityLog.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.timeline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No activity yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._activityLog
                  .map((activity) => _buildActivityItem(activity))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.circle,
              size: 12,
              color: Color(0xFF3498DB),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['action'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity['description'] ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(activity['timestamp']),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            const Text(
              'Discussion & Comments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 24),

            // Add comment
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment or question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                    enabled: !_isSubmittingComment,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmittingComment ? null : _submitComment,
                  icon: _isSubmittingComment
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                  ),
                ),
              ],
            ),

            const Divider(height: 40),

            // Comments list
            if (_comments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No comments yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to add a comment',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._comments
                  .map((comment) => _buildCommentItem(comment))
                  .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final commenterName = comment['created_by_name']?.toString() ??
        comment['created_by_email']?.toString() ??
        'User';
    final commentText = comment['comment_text']?.toString() ?? '';
    final timestamp = comment['created_at']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
                radius: 18,
                backgroundColor: const Color(0xFF3498DB),
                child: Text(
                  commenterName.isNotEmpty
                      ? commenterName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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
                      commenterName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatDate(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            commentText,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    final statusLower = status.toLowerCase();
    if (statusLower.contains('pending') ||
        statusLower.contains('sent to client')) {
      color = Colors.orange;
      icon = Icons.pending;
    } else if (statusLower.contains('approved') ||
        statusLower.contains('signed')) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (statusLower.contains('declined') ||
        statusLower.contains('rejected')) {
      color = Colors.red;
      icon = Icons.cancel;
    } else {
      color = Colors.blue;
      icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';

      return '${dt.day} ${_getMonth(dt.month)} ${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }

  String _getMonth(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }
}

// Reject Dialog
class RejectDialog extends StatefulWidget {
  final int proposalId;
  final String accessToken;
  final VoidCallback onSuccess;

  const RejectDialog({
    super.key,
    required this.proposalId,
    required this.accessToken,
    required this.onSuccess,
  });

  @override
  State<RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<RejectDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for rejection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/client/proposals/${widget.proposalId}/reject'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': widget.accessToken,
          'reason': _reasonController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proposal rejected'),
              backgroundColor: Colors.orange,
            ),
          );
          widget.onSuccess();
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to reject');
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
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cancel, color: Colors.red, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Reject Proposal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Please provide a reason for rejecting this proposal. This will help the team understand your concerns.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for Rejection *',
                hintText: 'Explain why you are rejecting this proposal...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cancel),
                  label: const Text('Reject Proposal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}

// Approve Dialog
class ApproveDialog extends StatefulWidget {
  final int proposalId;
  final String accessToken;
  final VoidCallback onSuccess;

  const ApproveDialog({
    super.key,
    required this.proposalId,
    required this.accessToken,
    required this.onSuccess,
  });

  @override
  State<ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<ApproveDialog> {
  final TextEditingController _signerNameController = TextEditingController();
  final TextEditingController _signerTitleController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_signerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide your name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/client/proposals/${widget.proposalId}/approve'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': widget.accessToken,
          'signer_name': _signerNameController.text.trim(),
          'signer_title': _signerTitleController.text.trim(),
          'comments': _commentsController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final signingUrl = data['signing_url']?.toString();

        if (mounted) {
          Navigator.pop(context); // Close approve dialog

          if (signingUrl != null && signingUrl.isNotEmpty) {
            // Open DocuSign signing modal
            _openDocuSignSigning(signingUrl);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Proposal approved, but signing URL not available'),
                backgroundColor: Colors.orange,
              ),
            );
            widget.onSuccess();
          }
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to approve');
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
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openDocuSignSigning(String signingUrl) async {
    // Open DocuSign in the same tab
    print(
        '🔐 ApproveDialog: Opening DocuSign URL in same tab: ${signingUrl.substring(0, signingUrl.length > 100 ? 100 : signingUrl.length)}...');

    try {
      // Navigate to DocuSign in the same tab (redirect mode - works on HTTP)
      print('🔐 ApproveDialog: Navigating to DocuSign (redirect mode)...');
      // Use replace() to navigate to external URL (bypasses Flutter routing)
      web.window.location.replace(signingUrl);
      print(
          '✅ Navigation initiated to DocuSign from ApproveDialog using location.replace()');

      // Reload proposal after a delay to check for signature completion
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          print(
              '🔄 ApproveDialog: Reloading proposal to check signature status...');
          widget.onSuccess(); // Reload to check if signed
        }
      });
    } catch (e) {
      print('❌ ApproveDialog: Error opening DocuSign: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening DocuSign: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Approve Proposal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Please provide your information to approve this proposal.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _signerNameController,
              decoration: InputDecoration(
                labelText: 'Your Name *',
                hintText: 'Enter your full name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _signerTitleController,
              decoration: InputDecoration(
                labelText: 'Your Title (Optional)',
                hintText: 'e.g., CEO, Director, Manager',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentsController,
              decoration: InputDecoration(
                labelText: 'Comments (Optional)',
                hintText: 'Any additional comments...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle),
                  label: const Text('Approve Proposal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _signerNameController.dispose();
    _signerTitleController.dispose();
    _commentsController.dispose();
    super.dispose();
  }
}
