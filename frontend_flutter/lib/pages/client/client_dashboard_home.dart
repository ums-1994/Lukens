import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  String? _deviceId;
  String? _clientSessionToken;
  String? _pendingDeviceOtpChallengeId;
  DateTime? _pendingDeviceOtpExpiresAt;
  List<Map<String, dynamic>> _proposals = [];
  Map<String, dynamic>? _selectedDocument;
  int _selectedNavIndex = 0;
  Map<String, int> _statusCounts = {
    'pending': 0,
    'approved': 0,
    'rejected': 0,
    'viewed': 0,
  };

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractTokenAndLoad();
    });
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
      final id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(100000 + (DateTime.now().microsecondsSinceEpoch % 900000))}';
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

  void _saveCachedClientSession(String? token) {
    if (!kIsWeb) return;
    try {
      if (token == null || token.trim().isEmpty) {
        web.window.localStorage.removeItem('lukens_client_session_token');
      } else {
        web.window.localStorage['lukens_client_session_token'] = token.trim();
      }
    } catch (_) {}
  }

  Future<String?> _promptForOtp() async {
    String? result;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Enter verification code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Check your email for a 6-digit code.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                result = null;
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                result = controller.text.trim();
                Navigator.of(ctx).pop();
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
    return result;
  }

  String _normalizeOtp(String raw) {
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  Future<bool> _ensureDeviceSession({required String token}) async {
    _deviceId ??= _getOrCreateDeviceId();
    final deviceId = _deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to verify device (missing device id).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    // If we already have a cached session token, try it first.
    if (_clientSessionToken != null && _clientSessionToken!.isNotEmpty) {
      return true;
    }

    if (_pendingDeviceOtpChallengeId != null &&
        _pendingDeviceOtpChallengeId!.isNotEmpty) {
      final activeChallengeId = _pendingDeviceOtpChallengeId!;
      final exp = _pendingDeviceOtpExpiresAt;
      if (exp == null || exp.isAfter(DateTime.now())) {
        final otp = await _promptForOtp();
        if (otp == null || otp.trim().isEmpty) {
          return false;
        }

        final normalizedOtp = _normalizeOtp(otp.trim());
        if (normalizedOtp.length != 6) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter the 6-digit code.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        final verifyUri = Uri.parse('$baseUrl/api/client/device-session/verify-otp');
        final verifyResp = await http
            .post(
              verifyUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'challenge_id': activeChallengeId,
                'otp': normalizedOtp,
              }),
            )
            .timeout(
              const Duration(seconds: 12),
              onTimeout: () {
                throw TimeoutException('OTP verification timed out');
              },
            );

        Map<String, dynamic>? verifyDecoded;
        try {
          final body = jsonDecode(verifyResp.body);
          if (body is Map) {
            verifyDecoded = Map<String, dynamic>.from(body);
          }
        } catch (_) {}

        if (verifyResp.statusCode != 200) {
          if (mounted) {
            final msg = verifyDecoded?['detail']?.toString() ??
                'OTP verification failed (HTTP ${verifyResp.statusCode})';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red),
            );
          }
          return false;
        }

        final verifiedSession = verifyDecoded?['session_token']?.toString();
        if (verifiedSession == null || verifiedSession.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP verified but no session token was returned.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        _clientSessionToken = verifiedSession;
        _saveCachedClientSession(verifiedSession);
        _pendingDeviceOtpChallengeId = null;
        _pendingDeviceOtpExpiresAt = null;
        return true;
      }

      _pendingDeviceOtpChallengeId = null;
      _pendingDeviceOtpExpiresAt = null;
    }

    final startUri = Uri.parse('$baseUrl/api/client/device-session/start');
    final startResp = await http
        .post(
          startUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token, 'device_id': deviceId}),
        )
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            throw TimeoutException('Device session start timed out');
          },
        );

    Map<String, dynamic>? decoded;
    try {
      final body = jsonDecode(startResp.body);
      if (body is Map) {
        decoded = Map<String, dynamic>.from(body);
      }
    } catch (_) {}

    if (startResp.statusCode != 200) {
      if (mounted) {
        final msg = decoded?['detail']?.toString() ??
            'Failed to start device session (HTTP ${startResp.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
      return false;
    }

    final sessionToken = decoded?['session_token']?.toString();
    final otpRequired = decoded?['otp_required'] == true;
    if (!otpRequired && sessionToken != null && sessionToken.isNotEmpty) {
      _clientSessionToken = sessionToken;
      _saveCachedClientSession(sessionToken);
      return true;
    }

    if (!otpRequired) {
      // No OTP required but token missing: treat as failure.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device session started but no session token was returned.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    final challengeId = decoded?['challenge_id']?.toString() ?? '';
    if (challengeId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP challenge missing (no challenge_id).'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    _pendingDeviceOtpChallengeId = challengeId;
    final expiresAtRaw = decoded?['expires_at']?.toString();
    if (expiresAtRaw != null && expiresAtRaw.isNotEmpty) {
      try {
        _pendingDeviceOtpExpiresAt = DateTime.parse(expiresAtRaw);
      } catch (_) {
        _pendingDeviceOtpExpiresAt = null;
      }
    }

    final otp = await _promptForOtp();
    if (otp == null || otp.trim().isEmpty) {
      return false;
    }

    final normalizedOtp = _normalizeOtp(otp.trim());
    if (normalizedOtp.length != 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the 6-digit code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    final verifyUri = Uri.parse('$baseUrl/api/client/device-session/verify-otp');
    final verifyResp = await http
        .post(
          verifyUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'challenge_id': challengeId, 'otp': normalizedOtp}),
        )
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            throw TimeoutException('OTP verification timed out');
          },
        );

    Map<String, dynamic>? verifyDecoded;
    try {
      final body = jsonDecode(verifyResp.body);
      if (body is Map) {
        verifyDecoded = Map<String, dynamic>.from(body);
      }
    } catch (_) {}

    if (verifyResp.statusCode != 200) {
      if (mounted) {
        final msg = verifyDecoded?['detail']?.toString() ??
            'OTP verification failed (HTTP ${verifyResp.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
      return false;
    }

    final verifiedSession = verifyDecoded?['session_token']?.toString();
    if (verifiedSession == null || verifiedSession.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP verified but no session token was returned.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    _clientSessionToken = verifiedSession;
    _saveCachedClientSession(verifiedSession);
    return true;
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
    const panelColor = Color(0xFF2A2A2A);
    const activeColor = Color(0xFFD50000);
    return SizedBox(
      width: 192.14,
      height: 410.58,
      child: Container(
      decoration: BoxDecoration(
        color: panelColor,
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KHONOLOGY',
                    style: TextStyle(
                      color: Color(0xFFE11D2E),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Welcome to',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  Text(
                    'Proposal & SOW Builder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildSidebarNavItem(0, Icons.rocket_launch_outlined, 'Dashboard',
                      activeColor: activeColor, itemHeight: 20.7, itemWidth: 111.87),
                  const SizedBox(height: 8),
                  _buildSidebarNavItem(1, Icons.handshake_outlined, 'Proposals',
                      itemHeight: 20.7, itemWidth: 111.87),
                  const SizedBox(height: 8),
                  _buildSidebarNavItem(2, Icons.assignment_outlined, "SOW'S",
                      itemHeight: 20.7, itemWidth: 111.87),
                  const SizedBox(height: 8),
                  _buildSidebarNavItem(3, Icons.request_quote_outlined, 'Invoices',
                      itemHeight: 20.7, itemWidth: 111.87),
                  const SizedBox(height: 8),
                  _buildSidebarNavItem(4, Icons.mail_outline, 'Messages',
                      itemHeight: 20.7, itemWidth: 111.87),
                  const SizedBox(height: 8),
                  _buildSidebarNavItem(5, Icons.description_outlined, 'Documents',
                      itemHeight: 20.7, itemWidth: 111.87),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: 191.77,
                height: 189.92,
                child: Column(
                  children: [
                    const Spacer(),
                    _buildSidebarNavItem(6, Icons.person, 'Account Profile',
                        itemWidth: 111.87, itemHeight: 20.7),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
                    const SizedBox(height: 10),
                    _buildSidebarNavItem(
                      7,
                      Icons.logout,
                      'Logout',
                      itemWidth: 111.87,
                      itemHeight: 20.7,
                      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                    ),
                  ],
                ),
              ),
            ),
            if ((_clientEmail ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  _clientEmail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                ),
              ),
          ],
        ),
      ),
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
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildDrawerNavItem(context, 0, Icons.rocket_launch_outlined,
                            'Dashboard',
                            itemHeight: 20.7, itemWidth: 111.87),
                        const SizedBox(height: 8),
                        _buildDrawerNavItem(
                            context, 1, Icons.handshake_outlined, 'Proposals',
                            itemHeight: 20.7, itemWidth: 111.87),
                        const SizedBox(height: 8),
                        _buildDrawerNavItem(
                            context, 2, Icons.assignment_outlined, "SOW'S",
                            itemHeight: 20.7, itemWidth: 111.87),
                        const SizedBox(height: 8),
                        _buildDrawerNavItem(
                            context, 3, Icons.request_quote_outlined, 'Invoices',
                            itemHeight: 20.7, itemWidth: 111.87),
                        const SizedBox(height: 8),
                        _buildDrawerNavItem(
                            context, 4, Icons.mail_outline, 'Messages',
                            itemHeight: 20.7, itemWidth: 111.87),
                        const SizedBox(height: 8),
                        _buildDrawerNavItem(
                            context, 5, Icons.description_outlined, 'Documents',
                            itemHeight: 20.7, itemWidth: 111.87),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: 191.77,
                      height: 189.92,
                      child: Column(
                        children: [
                          const Spacer(),
                          _buildDrawerNavItem(
                              context, 6, Icons.person, 'Account Profile',
                              itemWidth: 111.87, itemHeight: 20.7),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
                          const SizedBox(height: 10),
                          _buildDrawerNavItem(
                              context, 7, Icons.logout, 'Logout',
                              itemWidth: 111.87,
                              itemHeight: 20.7,
                              onTap: () => Navigator.pushReplacementNamed(context, '/login')),
                        ],
                      ),
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
      {VoidCallback? onTap, double itemHeight = 46, double? itemWidth}) {
    final selected = _selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
        onTap?.call();
        Navigator.of(context).pop();
      },
      child: Container(
        width: itemWidth,
        height: itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD50000) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF1F2937), size: 10),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData icon, String label,
      {Color activeColor = const Color(0xFFD50000),
      VoidCallback? onTap,
      double itemHeight = 46,
      double? itemWidth}) {
    final selected = _selectedNavIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
        onTap?.call();
      },
      child: Container(
        width: itemWidth,
        height: itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF1F2937), size: 10),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
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
                final selected =
                    _selectedDocument?['id']?.toString() == doc['id']?.toString();
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
                            _statusChip(status),
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
                      onPressed: doc == null || isSignedStatus
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
                      onPressed: doc == null || isSignedStatus
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
      final response = await http
          .get(
            uri,
            headers: {
              if (_deviceId != null) 'X-Client-Device-Id': _deviceId!,
              if (_clientSessionToken != null)
                'X-Client-Session-Token': _clientSessionToken!,
            },
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
        if (!mounted) return;
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
            final status = (proposal['status'] as String? ?? '');
            final key = _groupStatusForCounts(status);
            _statusCounts[key] = (_statusCounts[key] ?? 0) + 1;
          }

          _isLoading = false;
        });
      } else if (response.statusCode == 428) {
        _saveCachedClientSession(null);
        _clientSessionToken = null;
        Map<String, dynamic>? decoded;
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            decoded = Map<String, dynamic>.from(body);
          }
        } catch (_) {}

        final bool needsDevice = decoded?['requires_device_session'] == true ||
            decoded?['otp_required'] == true;

        if (needsDevice && _accessToken != null) {
          final token = _sanitizeToken(_accessToken!);
          final ok = await _ensureDeviceSession(token: token);
          if (ok) {
            await _loadClientProposals();
            return;
          }
        }

        if (!mounted) return;
        setState(() {
          _error = decoded?['detail']?.toString() ??
              'Device verification required.';
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
      if (!mounted) return;
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
                    if (!useDrawer) _buildSidebar(),
                    Expanded(
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
                                        if (_selectedNavIndex == 0 ||
                                            _selectedNavIndex == 1 ||
                                            _selectedNavIndex == 2)
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
