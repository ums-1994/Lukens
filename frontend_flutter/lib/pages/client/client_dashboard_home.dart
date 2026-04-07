import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:web/web.dart' as web;
import 'dart:async';
import 'package:url_launcher/url_launcher_string.dart';
import 'client_proposal_viewer.dart';
import '../../api.dart';
import '../../theme/premium_theme.dart';

class ClientDashboardHome extends StatefulWidget {
  final String? initialToken;
  final int? initialNavIndex;
  final bool showSummary;

  const ClientDashboardHome({
    super.key,
    this.initialToken,
    this.initialNavIndex,
    this.showSummary = true,
  });

  @override
  State<ClientDashboardHome> createState() => _ClientDashboardHomeState();
}

class _ClientDashboardHomeState extends State<ClientDashboardHome> {
  bool _isLoading = true;
  String? _error;
  String? _accessToken;
  String? _clientEmail;
  String? _deviceId;
  String? _clientSessionToken;
  List<Map<String, dynamic>> _proposals = [];
  Map<String, dynamic>? _selectedDocument;
  int _selectedNavIndex = 0;
  bool _overviewLoading = false;
  String? _overviewError;
  Map<String, dynamic>? _overview;
  String _dashboardDocFilter = 'all';
  Map<String, int> _statusCounts = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'viewed': 0,
  };

  bool _isSow(Map<String, dynamic> p) {
    final t =
        (p['template_type'] ?? p['templateType'] ?? p['template_key'] ?? '')
            .toString()
            .toLowerCase();
    return t.contains('sow');
  }

  Widget _filterChip(String label, String value) {
    final selected = _dashboardDocFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _dashboardDocFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? PremiumTheme.primaryRed.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected
                  ? PremiumTheme.primaryRed.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  bool _isProposalRequiringAction(Map<String, dynamic> p) {
    if (_isSow(p)) return false;
    final s = (p['status'] ?? '').toString().toLowerCase();
    return s.contains('sent') ||
        s.contains('released') ||
        s.contains('review') ||
        s.contains('pending') ||
        s.contains('signature');
  }

  bool _isSignedDocument(Map<String, dynamic> p) {
    if (_isSow(p)) return false;
    final statusLower = (p['status'] ?? '').toString().toLowerCase().trim();
    return statusLower.contains('client signed') ||
        statusLower.contains('signed');
  }

  bool _isAwaitingSignature(Map<String, dynamic> p) {
    if (_isSow(p)) return false;
    if (_isSignedDocument(p)) return false;

    final statusLower = (p['status'] ?? '').toString().toLowerCase().trim();

    return statusLower.contains('sent for signature') ||
        statusLower.contains('sent to client') ||
        statusLower.contains('released') ||
        statusLower.contains('in review') ||
        statusLower.contains('review') ||
        statusLower.contains('sent');
  }

  int _proposalsRequiringActionCount() {
    return _proposals.where(_isProposalRequiringAction).length;
  }

  String _normalizeStatus(String rawStatus) {
    final lower = rawStatus.toLowerCase().trim();
    if (lower.isEmpty) return 'Unknown';
    if (lower.contains('signed') || lower.contains('approved')) return 'Signed';
    if (lower.contains('declined') || lower.contains('rejected')) {
      return 'Declined';
    }
    if (lower.contains('sent for signature')) return 'Sent for Signature';
    if (lower.contains('sent to client') || lower.contains('released')) {
      return 'Released';
    }
    if (lower.contains('review')) return 'In Review';
    if (lower.contains('pending')) return 'Pending';
    if (lower.contains('draft')) return 'Draft';

    return rawStatus.trim();
  }

  String _groupStatusForCounts(String rawStatus) {
    final normalized = _normalizeStatus(rawStatus).toLowerCase();
    if (normalized.contains('pending') ||
        normalized.contains('released') ||
        normalized.contains('sent for signature') ||
        normalized.contains('in review')) {
      return 'pending';
    }
    if (normalized.contains('signed')) return 'approved';
    if (normalized.contains('declined')) return 'rejected';
    if (normalized.contains('viewed')) return 'viewed';
    return 'pending';
  }

  @override
  void initState() {
    super.initState();
    _selectedNavIndex = widget.initialNavIndex ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractTokenAndLoad();
    });
  }

  bool get _isOverviewDashboard => widget.showSummary && _selectedNavIndex == 0;

  void _navigateClient(String route) {
    final token = _accessToken;
    final suffix = (token != null && token.isNotEmpty)
        ? '?token=${Uri.encodeComponent(token)}'
        : '';
    Navigator.pushReplacementNamed(context, '$route$suffix');
  }

  String _sanitizeToken(String token) {
    var t = token.trim();
    try {
      t = Uri.decodeComponent(t);
    } catch (_) {}
    while (t.startsWith('"') || t.startsWith("'")) {
      t = t.substring(1);
    }
    while (t.endsWith('"') || t.endsWith("'")) {
      t = t.substring(0, t.length - 1);
    }
    return t.trim();
  }

  String _getOrCreateDeviceId() {
    if (!kIsWeb) {
      return 'flutter-device';
    }
    try {
      final existing = web.window.localStorage['lukens_client_device_id'];
      final clean = existing?.trim();
      if (clean != null && clean.isNotEmpty) return clean;
      final id =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${(100000 + (DateTime.now().microsecondsSinceEpoch % 900000))}';
      web.window.localStorage['lukens_client_device_id'] = id;
      return id;
    } catch (_) {
      return 'dev_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  void _loadCachedClientSession() {
    if (!kIsWeb) return;
    try {
      final token = web.window.localStorage['lukens_client_session_token'];
      final clean = token?.trim();
      if (clean != null && clean.isNotEmpty) {
        _clientSessionToken = clean;
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _filteredDocuments() {
    final idx = _selectedNavIndex;
    final docs = List<Map<String, dynamic>>.from(_proposals);
    if (idx == 0) {
      if (_dashboardDocFilter == 'all') return docs;
      return docs.where((d) {
        final status = (d['status'] ?? '').toString().toLowerCase();
        switch (_dashboardDocFilter) {
          case 'released':
            return status.contains('sent to client') ||
                status.contains('released');
          case 'signed':
            return status.contains('signed');
          case 'changes_requested':
            return status.contains('change') || status.contains('request');
          default:
            return true;
        }
      }).toList();
    }
    if (idx == 1) {
      return docs.where(_isAwaitingSignature).toList();
    }
    if (idx == 2) {
      return docs.where(_isSignedDocument).toList();
    }
    return docs;
  }

  String _documentLabel(Map<String, dynamic> doc) {
    final t = (doc['template_type'] ??
            doc['templateType'] ??
            doc['template_key'] ??
            '')
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
    final proposalId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
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
                setModalState(
                    () => error = 'Please confirm you agree to sign.');
                return;
              }

              setModalState(() {
                submitting = true;
                error = null;
              });

              try {
                final resp = await http.post(
                  Uri.parse(
                      '$baseUrl/api/client/proposals/$proposalId/sign_token'),
                  headers: {
                    'Content-Type': 'application/json',
                    if (_deviceId != null && _deviceId!.isNotEmpty)
                      'X-Client-Device-Id': _deviceId!,
                    if (_clientSessionToken != null &&
                        _clientSessionToken!.isNotEmpty)
                      'X-Client-Session-Token': _clientSessionToken!,
                  },
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
                              : (v) =>
                                  setModalState(() => consent = v ?? false),
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
                  onPressed:
                      submitting ? null : () => Navigator.of(context).pop(),
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
    Widget navItem(int index, IconData icon, String label,
        {VoidCallback? afterTap}) {
      final selected = _selectedNavIndex == index;
      final badgeCount =
          label == 'Proposals' ? _proposalsRequiringActionCount() : 0;
      return InkWell(
        onTap: () {
          if (index == 0) {
            if (!widget.showSummary) {
              _navigateClient('/client/dashboard');
            }
            return;
          }
          if (index == 1) {
            if (widget.showSummary) {
              _navigateClient('/client/proposals');
            }
            return;
          }
          setState(() {
            _selectedNavIndex = index;
          });
          afterTap?.call();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.white70, size: 20),
              Icon(icon,
                  color: selected ? Colors.white : Colors.white70, size: 20),
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
              if (badgeCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: PremiumTheme.primaryRed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
          navItem(2, Icons.folder_outlined, 'Documents'),
          navItem(3, Icons.person_outline, 'Profile'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Text(
              _clientEmail ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF2A2A2A),
      child: SafeArea(
        child: Builder(
          builder: (context) {
            return Container(
              color: const Color(0xFF2A2A2A),
              child: SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 8, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Client Portal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white70),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerNavItem(
                      context, 0, Icons.dashboard_outlined, 'Dashboard'),
                  _buildDrawerNavItem(
                      context, 1, Icons.description_outlined, 'Proposals'),
                  _buildDrawerNavItem(
                      context, 2, Icons.folder_outlined, 'Documents'),
                  _buildDrawerNavItem(
                      context, 3, Icons.person_outline, 'Profile'),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Text(
                      _clientEmail ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12),
                    ),
                  ),
                ],
              )),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDrawerNavItem(
      BuildContext context, int index, IconData icon, String label,
      {VoidCallback? onTap, double itemHeight = 37.77, double? itemWidth}) {
    final selected = _selectedNavIndex == index;
    final badgeCount =
        label == 'Proposals' ? _proposalsRequiringActionCount() : 0;
    return InkWell(
      onTap: () {
        if (index == 0) {
          Navigator.of(context).pop();
          if (!widget.showSummary) {
            _navigateClient('/client/dashboard');
          }
          return;
        }
        if (index == 1) {
          Navigator.of(context).pop();
          if (widget.showSummary) {
            _navigateClient('/client/proposals');
          }
          return;
        }
        setState(() {
          _selectedNavIndex = index;
        });
        onTap?.call();
        Navigator.of(context).pop();
      },
      child: Container(
        width: itemWidth,
        height: itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          border: selected
              ? Border(
                  left: BorderSide(color: PremiumTheme.primaryRed, width: 3),
                )
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF1F2937), size: 14),
            ),
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
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PremiumTheme.primaryRed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader({required bool useDrawer}) {
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
          if (useDrawer)
            IconButton(
              onPressed: () {
                final scaffold = Scaffold.maybeOf(context);
                scaffold?.openDrawer();
              },
              icon: const Icon(Icons.menu, color: Colors.white70),
              tooltip: 'Menu',
            ),
          if (useDrawer) const SizedBox(width: 6),
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
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.white70),
            tooltip: 'Notifications',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTiles() {
    final allDocs = List<Map<String, dynamic>>.from(_proposals);
    final activeCount = allDocs.where((d) {
      final s = (d['status'] ?? '').toString().toLowerCase();
      if (s.contains('signed')) return false;
      return s.contains('sent') ||
          s.contains('released') ||
          s.contains('review');
    }).length;
    final signedSowCount = allDocs.where((d) {
      if (!_isSow(d)) return false;
      final s = (d['status'] ?? '').toString().toLowerCase();
      return s.contains('signed');
    }).length;
    final pendingApprovalsCount = _statusCounts['pending'] ?? 0;

    const tileDescription =
        'Additional description information can be included if required.';

    const tileWidth = 306.62;
    const tileHeight = 102.64;

    Widget tile({
      required String label,
      required String value,
      required IconData icon,
    }) {
      return Container(
        width: tileWidth,
        height: tileHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(5.32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 3.55),
              blurRadius: 3.55,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tileDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          height: 1.25,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: PremiumTheme.primaryRed, size: 22),
            ),
          ],
        ),
      );
    }

    final children = [
      tile(
        label: 'Active Proposals',
        value: activeCount.toString(),
        icon: Icons.adjust,
      ),
      tile(
        label: "Signed SOW'S",
        value: signedSowCount.toString(),
        icon: Icons.check,
      ),
      tile(
        label: 'Pending Approvals',
        value: pendingApprovalsCount.toString(),
        icon: Icons.remove_red_eye_outlined,
      ),
    ];

    // Figma: three blocks side-by-side, 306.62 × 102.64 each; scroll horizontally if needed.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          children[0],
          const SizedBox(width: 12),
          children[1],
          const SizedBox(width: 12),
          children[2],
        ],
      ),
    );
  }

  Widget _buildRecentDocuments() {
    final docs = _filteredDocuments();
    final isDocumentsTab = _selectedNavIndex == 2;
    final isProposalsTab = _selectedNavIndex == 1;
    final listTitle = isDocumentsTab
        ? 'Signed Documents'
        : isProposalsTab
            ? 'Awaiting Signature'
            : 'Recent Documents';
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 466.59,
        height: 308.28,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(5.32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 3.55),
                blurRadius: 3.55,
                spreadRadius: 0,
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  listTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_selectedNavIndex == 0)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dashboardDocFilter = 'all';
                    });
                  },
                  child: const Text('View All'),
                ),
              Text(
                '${docs.length}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedNavIndex == 0)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip('View All', 'all'),
                _filterChip('Released', 'released'),
                _filterChip('Signed', 'signed'),
                _filterChip('Changes Requested', 'changes_requested'),
              ],
            ),
          if (_selectedNavIndex == 0) const SizedBox(height: 12),
          if (docs.isEmpty)
            Text(
              isDocumentsTab
                  ? 'No signed documents available yet.'
                  : isProposalsTab
                      ? 'No proposals are currently awaiting signature.'
                      : 'No documents available for this link.',
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
                final selected = _selectedDocument?['id']?.toString() ==
                    doc['id']?.toString();
                final status = (doc['status'] ?? '').toString();

                Widget _statusChip(String rawStatus) {
                  final normalizedLabel = _normalizeStatus(rawStatus);
                  final lower = normalizedLabel.toLowerCase().trim();
                  Color bg = Colors.white.withValues(alpha: 0.10);
                  Color fg = Colors.white.withValues(alpha: 0.80);
                  String label = normalizedLabel.isEmpty
                      ? (rawStatus.isEmpty ? 'Unknown' : rawStatus)
                      : normalizedLabel;

                  if (lower.contains('signed')) {
                    bg = const Color(0xFF27AE60).withValues(alpha: 0.18);
                    fg = const Color(0xFF2ECC71);
                  } else if (lower.contains('pending') ||
                      lower.contains('released') ||
                      lower.contains('sent for signature') ||
                      lower.contains('in review')) {
                    bg = const Color(0xFFF39C12).withValues(alpha: 0.20);
                    fg = const Color(0xFFF1C40F);
                  } else if (lower.contains('rejected') ||
                      lower.contains('declined')) {
                    bg = const Color(0xFFE74C3C).withValues(alpha: 0.18);
                    fg = const Color(0xFFE74C3C);
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDocument = doc;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color:
                            selected ? Colors.lightBlueAccent : Colors.white70,
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
                            _statusChip(status),
                          ],
                        ),
                      ),
                      if (isDocumentsTab)
                        TextButton(
                          onPressed: () => _downloadPdfForDocument(doc),
                          child: const Text('Download'),
                        )
                      else if (isProposalsTab)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedDocument = doc;
                            });
                            _openSigningUrl(doc);
                          },
                          child: const Text('View'),
                        )
                      else
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
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    final doc = _selectedDocument;
    final title = doc?['title']?.toString() ?? 'Select a document';
    final status = doc?['status']?.toString() ?? '';
    final hasSigning =
        (doc?['signing_url']?.toString() ?? '').trim().isNotEmpty;
    final statusLower = status.toLowerCase().trim();
    final isSignedStatus =
        statusLower.contains('client signed') || statusLower.contains('signed');

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
        if (doc != null) ...[
          panelCard(
            title: 'View Document',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  status.isEmpty ? '' : status,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12),
                ),
                if (isSignedStatus) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: Color(0xFF2ECC71)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This document has been signed. No further action is required.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSignedStatus
                            ? null
                            : () {
                                if (hasSigning) {
                                  _openSigningUrl(doc);
                                } else {
                                  _showFallbackSignModal(doc);
                                }
                              },
                        child: const Text('View'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSignedStatus
                            ? null
                            : () => _openProposalComments(doc),
                        child: const Text('Request Changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        panelCard(
          title: 'Project Chat',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open a document to view and post comments.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed:
                      doc == null ? null : () => _openProposalComments(doc),
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
                      onPressed: doc == null
                          ? null
                          : () => _downloadPdfForDocument(doc),
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
    if (_isOverviewDashboard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSummaryTiles(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackLowerCards = constraints.maxWidth < 980;
              if (stackLowerCards) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRecentDocuments(),
                    const SizedBox(height: 14),
                    _buildRightPanel(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRecentDocuments(),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRightPanel()),
                ],
              );
            },
          ),
        ],
      );
    }

    if (!widget.showSummary && _selectedNavIndex == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proposals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Review and sign documents awaiting your signature',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          _buildRecentDocuments(),
        ],
      );
    }

    if (_selectedNavIndex == 0 ||
        _selectedNavIndex == 1 ||
        _selectedNavIndex == 2) {
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
      3: 'Profile',
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

    token = _sanitizeToken(token);
    if (token.isEmpty) {
      setState(() {
        _error = 'No access token provided';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _accessToken = token;
    });

    _deviceId = _getOrCreateDeviceId();
    _loadCachedClientSession();

    _loadClientProposals();
  }

  Future<void> _loadClientProposals() async {
    if (_accessToken == null) return;

    final token = _sanitizeToken(_accessToken!);
    if (token.isEmpty) {
      setState(() {
        _error = 'No access token provided';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/api/client/proposals')
          .replace(queryParameters: {'token': token});
      final response = await http.get(
        uri,
        headers: {
          if (_deviceId != null) 'X-Client-Device-Id': _deviceId!,
          if (_clientSessionToken != null)
            'X-Client-Session-Token': _clientSessionToken!,
        },
      ).timeout(
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
        if (!mounted) return;
        setState(() {
          _clientEmail = data['client_email'];
          _proposals =
              proposalsRaw.map((p) => Map<String, dynamic>.from(p)).toList();

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
            final status = (proposal['status'] as String? ?? '');
            final key = _groupStatusForCounts(status);
            _statusCounts[key] = (_statusCounts[key] ?? 0) + 1;
          }

          _isLoading = false;
        });

        if (_isOverviewDashboard) {
          await _loadDashboardOverview();
        }
      } else if (response.statusCode == 428) {
        Map<String, dynamic>? decoded;
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            decoded = Map<String, dynamic>.from(body);
          }
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _error = decoded?['detail']?.toString() ??
              'Unable to open client dashboard.';
          _isLoading = false;
        });
      } else if (response.statusCode == 423) {
        Map<String, dynamic>? decoded;
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            decoded = Map<String, dynamic>.from(body);
          }
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _error = decoded?['detail']?.toString() ??
              'Access locked due to too many failed attempts.';
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
        if (!mounted) return;
        setState(() {
          _error = error?['detail'] ??
              'Failed to load proposals (HTTP ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is TimeoutException
            ? 'This link timed out. Please retry or ask the sender to resend it.'
            : 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardOverview() async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _overviewLoading = true;
      _overviewError = null;
    });

    try {
      final clean = _sanitizeToken(token);
      final uri = Uri.parse('$baseUrl/api/client/dashboard/overview')
          .replace(queryParameters: {'token': clean});

      final resp = await http.get(
        uri,
        headers: {
          if (_deviceId != null) 'X-Client-Device-Id': _deviceId!,
          if (_clientSessionToken != null)
            'X-Client-Session-Token': _clientSessionToken!,
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      Map<String, dynamic>? decoded;
      try {
        final body = jsonDecode(resp.body);
        if (body is Map) decoded = Map<String, dynamic>.from(body);
      } catch (_) {}

      if (resp.statusCode != 200) {
        final msg = decoded?['detail']?.toString() ??
            'Failed to load dashboard (HTTP ${resp.statusCode})';
        if (!mounted) return;
        setState(() {
          _overviewError = msg;
          _overviewLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _overview = decoded;
        _overviewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _overviewError = e is TimeoutException
            ? 'Dashboard request timed out. Please retry.'
            : 'Error: $e';
        _overviewLoading = false;
      });
    }
  }

  int _kpi(String key) {
    final kpis = _overview?['kpis'];
    if (kpis is Map && kpis[key] != null) {
      return int.tryParse(kpis[key].toString()) ?? 0;
    }
    return 0;
  }

  int _pipe(String key) {
    final pipe = _overview?['pipeline'];
    if (pipe is Map && pipe[key] != null) {
      return int.tryParse(pipe[key].toString()) ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> _activity() {
    final a = _overview?['activity'];
    if (a is List) {
      return a.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _trend() {
    final analytics = _overview?['analytics'];
    if (analytics is Map) {
      final t = analytics['trend'];
      if (t is List) {
        return t.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  Map<String, int> _conversionBreakdown() {
    final analytics = _overview?['analytics'];
    if (analytics is Map) {
      final b = analytics['conversion_breakdown'];
      if (b is Map) {
        return {
          'signed': int.tryParse(b['signed']?.toString() ?? '0') ?? 0,
          'rejected': int.tryParse(b['rejected']?.toString() ?? '0') ?? 0,
          'requested_changes':
              int.tryParse(b['requested_changes']?.toString() ?? '0') ?? 0,
        };
      }
    }
    return {'signed': 0, 'rejected': 0, 'requested_changes': 0};
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '${weeks} weeks ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _activityIcon(String eventType) {
    final e = eventType.toLowerCase().trim();
    if (e.contains('view') || e.contains('open'))
      return Icons.visibility_outlined;
    if (e.contains('sign')) return Icons.check_circle_outline;
    if (e.contains('download')) return Icons.download_outlined;
    if (e.contains('comment') || e.contains('change')) {
      return Icons.mode_comment_outlined;
    }
    return Icons.bolt_outlined;
  }

  String _activityLabel(Map<String, dynamic> a) {
    final proposalId = a['proposal_id']?.toString();
    final event = (a['event_type'] ?? '').toString();
    final ev = event.toLowerCase().trim();
    String verb;
    if (ev.contains('view') || ev.contains('open')) {
      verb = 'viewed';
    } else if (ev.contains('sign')) {
      verb = 'signed';
    } else if (ev.contains('download')) {
      verb = 'downloaded';
    } else if (ev.contains('comment')) {
      verb = 'commented';
    } else if (ev.contains('change')) {
      verb = 'requested changes';
    } else {
      verb = event.isEmpty ? 'updated' : event;
    }
    if (proposalId == null || proposalId.isEmpty) return 'Proposal $verb';
    return 'Proposal #$proposalId $verb';
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildKpiCards() {
    final cards = [
      (
        'Active Proposals',
        _kpi('active_proposals').toString(),
        Icons.play_circle_outline,
        PremiumTheme.blueGradient,
        '/client/proposals'
      ),
      (
        'Signed Proposals',
        _kpi('signed_proposals').toString(),
        Icons.check_circle_outline,
        PremiumTheme.tealGradient,
        '/client/proposals'
      ),
      (
        'Requested for Change',
        _kpi('requested_changes').toString(),
        Icons.edit_note,
        PremiumTheme.orangeGradient,
        '/client/proposals'
      ),
      (
        'Rejected Proposals',
        _kpi('rejected_proposals').toString(),
        Icons.cancel_outlined,
        PremiumTheme.redGradient,
        '/client/proposals'
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 980;
        final children = cards
            .map(
              (c) => SizedBox(
                width:
                    narrow ? double.infinity : (constraints.maxWidth - 48) / 4,
                height: 109,
                child: PremiumStatCard(
                  title: c.$1,
                  value: c.$2,
                  subtitle: null,
                  icon: c.$3,
                  gradient: c.$4,
                  onTap: () => _navigateClient(c.$5),
                ),
              ),
            )
            .toList();

        if (narrow) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ]
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ]
          ],
        );
      },
    );
  }

  Widget _buildPipelineOverview() {
    final active = _pipe('active');
    final changes = _pipe('requested_changes');
    final signed = _pipe('signed');
    final rejected = _pipe('rejected');
    final total = _pipe('total');
    final denom = total <= 0 ? 1 : total;

    Widget segment({
      required int count,
      required Color color,
      required String label,
    }) {
      final flex =
          (count <= 0) ? 0 : (count * 1000 / denom).round().clamp(1, 1000);
      if (count <= 0) {
        return const SizedBox.shrink();
      }
      return Expanded(
        flex: flex,
        child: Container(
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    Widget pill(String label, int count, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$label: $count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return _sectionCard(
      title: 'Pipeline Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              segment(count: active, color: PremiumTheme.info, label: 'Active'),
              const SizedBox(width: 6),
              segment(
                  count: changes,
                  color: PremiumTheme.warning,
                  label: 'Changes'),
              const SizedBox(width: 6),
              segment(
                  count: signed, color: PremiumTheme.success, label: 'Signed'),
              const SizedBox(width: 6),
              segment(
                  count: rejected,
                  color: PremiumTheme.error,
                  label: 'Rejected'),
              if (active + changes + signed + rejected == 0)
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              pill('Active', active, PremiumTheme.info),
              pill('Requested Changes', changes, PremiumTheme.warning),
              pill('Signed', signed, PremiumTheme.success),
              pill('Rejected', rejected, PremiumTheme.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final items = _activity();
    return _sectionCard(
      title: 'Recent Activity',
      child: Column(
        children: [
          if (items.isEmpty)
            Text(
              _overviewLoading
                  ? 'Loading activity...'
                  : 'No recent activity yet.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
            )
          else
            for (int i = 0; i < items.length; i++) ...[
              Builder(
                builder: (context) {
                  final a = items[i];
                  DateTime? created;
                  try {
                    final raw = a['created_at']?.toString();
                    if (raw != null && raw.isNotEmpty) {
                      created = DateTime.parse(raw);
                    }
                  } catch (_) {}

                  final eventType = (a['event_type'] ?? '').toString();
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: Icon(
                            _activityIcon(eventType),
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _activityLabel(a),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                created == null
                                    ? ''
                                    : _timeAgo(created.toLocal()),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.60),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (i != items.length - 1)
                Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
            ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return _sectionCard(
      title: 'Quick Actions',
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateClient('/client/proposals'),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('View Proposals'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateClient('/client/documents'),
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text('Download Documents'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    final points = _trend();
    if (points.isEmpty) {
      return _sectionCard(
        title: 'Proposals Trend',
        child: Text(
          _overviewLoading ? 'Loading trend...' : 'No trend data yet.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
        ),
      );
    }

    final created = <FlSpot>[];
    final signed = <FlSpot>[];
    final rejected = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      created.add(FlSpot(i.toDouble(), (p['created'] ?? 0).toDouble()));
      signed.add(FlSpot(i.toDouble(), (p['signed'] ?? 0).toDouble()));
      rejected.add(FlSpot(i.toDouble(), (p['rejected'] ?? 0).toDouble()));
    }

    String bottomTitle(double value) {
      final idx = value.round();
      if (idx < 0 || idx >= points.length) return '';
      final raw = points[idx]['period']?.toString();
      if (raw == null || raw.isEmpty) return '';
      try {
        final dt = DateTime.parse(raw);
        return '${dt.day}/${dt.month}';
      } catch (_) {
        return '';
      }
    }

    return _sectionCard(
      title: 'Proposals Trend',
      child: SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 1,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (points.length / 4).ceilToDouble().clamp(1, 999),
                  getTitlesWidget: (v, meta) => Text(
                    bottomTitle(v),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: created,
                isCurved: true,
                barWidth: 3,
                color: PremiumTheme.cyan,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: signed,
                isCurved: true,
                barWidth: 3,
                color: PremiumTheme.success,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: rejected,
                isCurved: true,
                barWidth: 3,
                color: PremiumTheme.error,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversionChart() {
    final b = _conversionBreakdown();
    final signed = b['signed'] ?? 0;
    final rejected = b['rejected'] ?? 0;
    final changes = b['requested_changes'] ?? 0;
    final total = signed + rejected + changes;
    if (total <= 0) {
      return _sectionCard(
        title: 'Conversion Breakdown',
        child: Text(
          _overviewLoading ? 'Loading breakdown...' : 'No conversion data yet.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
        ),
      );
    }

    return _sectionCard(
      title: 'Conversion Breakdown',
      child: SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 36,
                  sections: [
                    PieChartSectionData(
                      value: signed.toDouble(),
                      color: PremiumTheme.success,
                      title: '',
                      radius: 62,
                    ),
                    PieChartSectionData(
                      value: rejected.toDouble(),
                      color: PremiumTheme.error,
                      title: '',
                      radius: 62,
                    ),
                    PieChartSectionData(
                      value: changes.toDouble(),
                      color: PremiumTheme.warning,
                      title: '',
                      radius: 62,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legendRow('Signed', signed, PremiumTheme.success),
                  const SizedBox(height: 10),
                  _legendRow('Rejected', rejected, PremiumTheme.error),
                  const SizedBox(height: 10),
                  _legendRow(
                      'Requested Changes', changes, PremiumTheme.warning),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.80), fontSize: 12),
          ),
        ),
        Text(
          value.toString(),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  void _openProposal(Map<String, dynamic> proposal) {
    final rawId = proposal['id'];
    final proposalId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
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
      if (!mounted) return;
      _loadClientProposals();
    });
  }

  void _openProposalComments(Map<String, dynamic> proposal) {
    final rawId = proposal['id'];
    final proposalId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
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
      if (!mounted) return;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = constraints.maxWidth < 900;

        final scaffold = Scaffold(
          backgroundColor: Colors.transparent,
          drawer: useDrawer ? _buildSidebarDrawer() : null,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/client_dashboard_bg.png',
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!useDrawer) _buildSidebar(),
                  Expanded(
                    child: SafeArea(
                      left: false,
                      child: Column(
                        children: [
                          _buildTopHeader(useDrawer: useDrawer),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(18),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final narrow = constraints.maxWidth < 980;
                                  final leftContent = _buildMainLeftContent();

                                  if (narrow) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        leftContent,
                                        const SizedBox(height: 16),
                                        if ((_selectedNavIndex == 1 ||
                                                _selectedNavIndex == 2) &&
                                            widget.showSummary)
                                          _buildRightPanel(),
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: leftContent),
                                      const SizedBox(width: 16),
                                      if ((_selectedNavIndex == 1 ||
                                              _selectedNavIndex == 2) &&
                                          widget.showSummary)
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
                  ),
                ],
              ),
            ],
          ),
        );

        return scaffold;
      },
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
        statusLower.contains('sent to client') ||
        statusLower.contains('released')) {
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
      final raw = date.toString();
      final hasTimezone = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
      final parsedRaw = DateTime.parse(raw);
      final dt = hasTimezone
          ? parsedRaw.toLocal()
          : DateTime.utc(
              parsedRaw.year,
              parsedRaw.month,
              parsedRaw.day,
              parsedRaw.hour,
              parsedRaw.minute,
              parsedRaw.second,
              parsedRaw.millisecond,
              parsedRaw.microsecond,
            ).toLocal();
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
