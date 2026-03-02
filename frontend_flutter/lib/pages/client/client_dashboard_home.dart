import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'dart:async';
import 'package:url_launcher/url_launcher_string.dart';
import 'client_proposal_viewer.dart';
import '../../api.dart';
import '../../theme/premium_theme.dart';

class ClientDashboardHome extends StatefulWidget {
  final String? initialToken;

  const ClientDashboardHome({super.key, this.initialToken});

  @override
  State<ClientDashboardHome> createState() => _ClientDashboardHomeState();
}

class _ClientDashboardHomeState extends State<ClientDashboardHome> {
  bool _isLoading = true;
  String? _error;
  String? _accessToken;
  String? _clientEmail;
  List<Map<String, dynamic>> _proposals = [];
  Map<String, dynamic>? _selectedDocument;
  int _selectedNavIndex = 0;
  Map<String, int> _statusCounts = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'viewed': 0,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractTokenAndLoad();
    });
  }

  List<Map<String, dynamic>> _filteredDocuments() {
    final idx = _selectedNavIndex;
    final docs = List<Map<String, dynamic>>.from(_proposals);
    if (idx == 0) {
      return docs;
    }

    bool isSow(Map<String, dynamic> p) {
      final t = (p['template_type'] ?? p['templateType'] ?? p['template_key'] ?? '')
          .toString()
          .toLowerCase();
      return t.contains('sow');
    }

    if (idx == 1) {
      return docs.where((p) => !isSow(p)).toList();
    }
    if (idx == 2) {
      return docs.where(isSow).toList();
    }
    return docs;
  }

  String _documentLabel(Map<String, dynamic> doc) {
    final t = (doc['template_type'] ?? doc['templateType'] ?? doc['template_key'] ?? '')
        .toString()
        .toLowerCase();
    if (t.contains('sow')) return 'SOW';
    return 'Proposal';
  }

  Future<void> _downloadPdfForDocument(Map<String, dynamic> doc) async {
    final rawId = doc['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null || _accessToken == null || _accessToken!.isEmpty) return;

    final url =
        '$baseUrl/api/client/proposals/$id/export/pdf?token=${Uri.encodeComponent(_accessToken!)}&download=1';
    web.window.open(url, '_blank');
  }

  Future<void> _openSigningUrl(Map<String, dynamic> doc) async {
    final signingUrl = doc['signing_url']?.toString() ?? '';
    if (signingUrl.trim().isEmpty) return;
    await launchUrlString(signingUrl, mode: LaunchMode.externalApplication);
  }

  Future<void> _showFallbackSignModal(Map<String, dynamic> doc) async {
    if (_accessToken == null || _accessToken!.isEmpty) return;
    final rawId = doc['id'];
    final proposalId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (proposalId == null) return;

    final nameController = TextEditingController();
    bool consent = false;
    bool submitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final signerName = nameController.text.trim();
              if (signerName.isEmpty) {
                setModalState(() => error = 'Please enter your name.');
                return;
              }
              if (!consent) {
                setModalState(() => error = 'Please confirm you agree to sign.');
                return;
              }

              setModalState(() {
                submitting = true;
                error = null;
              });

              try {
                final resp = await http.post(
                  Uri.parse('$baseUrl/api/client/proposals/$proposalId/sign_token'),
                  headers: const {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'token': _accessToken,
                    'signer_name': signerName,
                  }),
                );

                if (resp.statusCode >= 200 && resp.statusCode < 300) {
                  if (mounted) Navigator.of(context).pop();
                  await _loadClientProposals();
                  return;
                }

                String detail = 'Unable to sign (HTTP ${resp.statusCode})';
                try {
                  final decoded = jsonDecode(resp.body);
                  if (decoded is Map && decoded['detail'] != null) {
                    detail = decoded['detail'].toString();
                  }
                } catch (_) {}
                setModalState(() => error = detail);
              } catch (e) {
                setModalState(() => error = e.toString());
              } finally {
                setModalState(() => submitting = false);
              }
            }

            return AlertDialog(
              title: const Text('Confirm Signature'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['title']?.toString() ?? 'Document',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !submitting,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: consent,
                          onChanged: submitting
                              ? null
                              : (v) => setModalState(() => consent = v ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'I confirm that I agree to sign this document electronically.',
                          ),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm Signature'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSidebar() {
    Widget navItem(int index, IconData icon, String label) {
      final selected = _selectedNavIndex == index;
      return InkWell(
        onTap: () {
          setState(() {
            _selectedNavIndex = index;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withValues(alpha: 0.96),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Icon(Icons.grid_view_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Client Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          navItem(0, Icons.dashboard_outlined, 'Dashboard'),
          navItem(1, Icons.description_outlined, 'Proposals'),
          navItem(2, Icons.assignment_outlined, 'SOWs'),
          navItem(3, Icons.receipt_long_outlined, 'Invoices'),
          navItem(4, Icons.mail_outline, 'Messages'),
          navItem(5, Icons.folder_outlined, 'Documents'),
          navItem(6, Icons.person_outline, 'Profile'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Text(
              _clientEmail ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220).withValues(alpha: 0.55),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Client Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back, ${_clientEmail ?? 'Client'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.mail_outline, color: Colors.white70),
            tooltip: 'Messages',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.white70),
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: _loadClientProposals,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTiles() {
    final docs = _filteredDocuments();
    final activeCount = docs.where((d) {
      final s = (d['status'] ?? '').toString().toLowerCase();
      return s.contains('sent') || s.contains('released') || s.contains('review');
    }).length;
    final signedCount = docs.where((d) {
      final s = (d['status'] ?? '').toString().toLowerCase();
      return s.contains('signed');
    }).length;
    final pendingCount = docs.where((d) {
      final s = (d['status'] ?? '').toString().toLowerCase();
      return s.contains('pending');
    }).length;

    Widget tile(String label, String value, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white70, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 860;
        final children = [
          tile('Active Proposals', activeCount.toString(), Icons.description_outlined),
          tile('Signed SOWs', signedCount.toString(), Icons.verified_outlined),
          tile('Pending Approvals', pendingCount.toString(), Icons.pending_actions_outlined),
        ];
        if (narrow) {
          return Column(
            children: [
              children[0],
              const SizedBox(height: 12),
              children[1],
              const SizedBox(height: 12),
              children[2],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 12),
            Expanded(child: children[1]),
            const SizedBox(width: 12),
            Expanded(child: children[2]),
          ],
        );
      },
    );
  }

  Widget _buildRecentDocuments() {
    final docs = _filteredDocuments();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Documents',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${docs.length}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Text(
              'No documents available for this link.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length > 6 ? 6 : docs.length,
              separatorBuilder: (_, __) => Divider(
                height: 14,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final selected = _selectedDocument?['id']?.toString() == doc['id']?.toString();
                final status = (doc['status'] ?? '').toString();
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDocument = doc;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: selected ? Colors.lightBlueAccent : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_documentLabel(doc)} #${doc['id']} - ${doc['title'] ?? 'Untitled'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.isEmpty ? '—' : status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openProposal(doc),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRightPanel() {
    final doc = _selectedDocument;
    final title = doc?['title']?.toString() ?? 'Select a document';
    final status = doc?['status']?.toString() ?? '';
    final hasSigning = (doc?['signing_url']?.toString() ?? '').trim().isNotEmpty;

    Widget panelCard({required String title, required Widget child}) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
    }

    return Column(
      children: [
        panelCard(
          title: 'Sign Document',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                status.isEmpty ? '' : status,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                height: 88,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Signature',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: doc == null
                          ? null
                          : () {
                              if (hasSigning) {
                                _openSigningUrl(doc);
                              } else {
                                _showFallbackSignModal(doc);
                              }
                            },
                      child: const Text('Sign Now'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: doc == null ? null : () => _openProposalComments(doc),
                      child: const Text('Request Changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        panelCard(
          title: 'Project Chat',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open a document to view and post comments.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: doc == null ? null : () => _openProposalComments(doc),
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: const Text('Open Comments'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        panelCard(
          title: 'Documents & Downloads',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: doc == null ? null : () => _downloadPdfForDocument(doc),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoon(String title) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hourglass_top, color: Colors.white70),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Coming soon. This section is part of the client portal experience but is not enabled in this build.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLeftContent() {
    if (_selectedNavIndex == 0 || _selectedNavIndex == 1 || _selectedNavIndex == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryTiles(),
          const SizedBox(height: 16),
          _buildRecentDocuments(),
        ],
      );
    }

    final titles = {
      3: 'Invoices',
      4: 'Messages',
      5: 'Documents',
      6: 'Profile',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryTiles(),
        const SizedBox(height: 16),
        _buildComingSoon(titles[_selectedNavIndex] ?? 'Coming Soon'),
      ],
    );
  }

  void _extractTokenAndLoad() {
    String? token = widget.initialToken;

    try {
      final currentUrl = web.window.location.href;
      final uri = Uri.parse(currentUrl);

      if (token == null || token.isEmpty) {
        // Try multiple ways to extract token
        token = uri.queryParameters['token'];
      }

      if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
        final fragment = uri.fragment;
        if (fragment.contains('token=')) {
          final queryStart = fragment.indexOf('?');
          if (queryStart != -1) {
            final queryString = fragment.substring(queryStart + 1);
            final params = Uri.splitQueryString(queryString);
            token = params['token'];
          }
        }
      }

      if (token == null || token.isEmpty) {
        final hash = web.window.location.hash;
        if (hash.contains('token=')) {
          final tokenMatch = RegExp(r'token=([^&]+)').firstMatch(hash);
          if (tokenMatch != null) {
            token = tokenMatch.group(1);
          }
        }
      }
    } catch (e) {
      print('âŒ Error parsing URL: $e');
    }

    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No access token provided';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _accessToken = token;
    });

    _loadClientProposals();
  }

  Future<void> _loadClientProposals() async {
    if (_accessToken == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/client/proposals?token=$_accessToken'),
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw Exception('Unexpected response format');
        }
        final data = Map<String, dynamic>.from(decoded);
        final proposalsRaw = data['proposals'];
        if (proposalsRaw is! List) {
          throw Exception('Invalid token response (missing proposals)');
        }
        setState(() {
          _clientEmail = data['client_email'];
          _proposals = proposalsRaw
              .map((p) => Map<String, dynamic>.from(p))
              .toList();

          if (_selectedDocument != null) {
            final selId = _selectedDocument?['id']?.toString();
            final updated = _proposals
                .where((p) => p['id']?.toString() == selId)
                .cast<Map<String, dynamic>>()
                .toList();
            if (updated.isNotEmpty) {
              _selectedDocument = updated.first;
            }
          }

          // Calculate status counts
          _statusCounts = {
            'pending': 0,
            'approved': 0,
            'rejected': 0,
            'viewed': 0,
          };

          for (var proposal in _proposals) {
            final status = (proposal['status'] as String? ?? '').toLowerCase();
            if (status.contains('pending') ||
                status.contains('sent to client')) {
              _statusCounts['pending'] = (_statusCounts['pending'] ?? 0) + 1;
            } else if (status.contains('approved') ||
                status.contains('signed')) {
              _statusCounts['approved'] = (_statusCounts['approved'] ?? 0) + 1;
            } else if (status.contains('declined') ||
                status.contains('rejected')) {
              _statusCounts['rejected'] = (_statusCounts['rejected'] ?? 0) + 1;
            } else if (status.contains('viewed')) {
              _statusCounts['viewed'] = (_statusCounts['viewed'] ?? 0) + 1;
            }
          }

          _isLoading = false;
        });
      } else {
        Map<String, dynamic>? error;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            error = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
        setState(() {
          _error = error?['detail'] ??
              'Failed to load proposals (HTTP ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e is TimeoutException
            ? 'This link timed out. Please retry or ask the sender to resend it.'
            : 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _openProposal(Map<String, dynamic> proposal) {
    final rawId = proposal['id'];
    final proposalId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (proposalId == null || _accessToken == null || _accessToken!.isEmpty) {
      print(
          '[ClientDashboardHome] Cannot open proposal: invalid id=$rawId tokenPresent=${_accessToken != null && _accessToken!.isNotEmpty}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open proposal (missing proposal id).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    print('[ClientDashboardHome] Opening proposal in app: id=$proposalId');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientProposalViewer(
          proposalId: proposalId,
          accessToken: _accessToken!,
        ),
      ),
    ).then((_) {
      _loadClientProposals();
    });
  }

  void _openProposalComments(Map<String, dynamic> proposal) {
    final rawId = proposal['id'];
    final proposalId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (proposalId == null || _accessToken == null || _accessToken!.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientProposalViewer(
          proposalId: proposalId,
          accessToken: _accessToken!,
          initialTab: 1,
        ),
      ),
    ).then((_) {
      _loadClientProposals();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your proposals...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
                onPressed: () => _loadClientProposals(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Global BG.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.35),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 980;
                              final leftContent = _buildMainLeftContent();

                              if (narrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    leftContent,
                                    const SizedBox(height: 16),
                                    if (_selectedNavIndex == 0 ||
                                        _selectedNavIndex == 1 ||
                                        _selectedNavIndex == 2)
                                      _buildRightPanel(),
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: leftContent),
                                  const SizedBox(width: 16),
                                  if (_selectedNavIndex == 0 ||
                                      _selectedNavIndex == 1 ||
                                      _selectedNavIndex == 2)
                                    SizedBox(
                                      width: 380,
                                      child: _buildRightPanel(),
                                    ),
                                ],
                              );
                            },
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
          const Icon(Icons.dashboard, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Client Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back, ${_clientEmail ?? 'Client'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadClientProposals,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending Review',
            _statusCounts['pending'].toString(),
            Icons.pending_actions,
            PremiumTheme.orangeGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Approved',
            _statusCounts['approved'].toString(),
            Icons.check_circle,
            PremiumTheme.tealGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Rejected',
            _statusCounts['rejected'].toString(),
            Icons.cancel,
            PremiumTheme.redGradient,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Proposals',
            _proposals.length.toString(),
            Icons.description,
            PremiumTheme.blueGradient,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Gradient gradient) {
    String subtitle;
    switch (title) {
      case 'Pending Review':
        subtitle = 'For your review';
        break;
      case 'Approved':
        subtitle = 'Signed / approved';
        break;
      case 'Rejected':
        subtitle = 'Declined proposals';
        break;
      case 'Total Proposals':
        subtitle = 'All proposals sent to you';
        break;
      default:
        subtitle = '';
    }

    return PremiumStatCard(
      title: title,
      value: value,
      subtitle: subtitle.isEmpty ? null : subtitle,
      icon: icon,
      gradient: gradient,
    );
  }

  Widget _buildProposalsSection() {
    return GlassContainer(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Your Proposals',
                  style: PremiumTheme.titleMedium,
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    '${_proposals.length} ${_proposals.length == 1 ? 'proposal' : 'proposals'}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Table
          if (_proposals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No proposals yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF111827),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Proposal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Last Updated',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Action',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                rows: _proposals.map((proposal) {
                  return DataRow(cells: [
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              proposal['title'] ?? 'Untitled',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${proposal['id']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                        _buildStatusBadge(proposal['status'] ?? 'Unknown')),
                    DataCell(
                      Text(
                        _formatDate(proposal['updated_at']),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () => _openProposal(proposal),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3498DB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
