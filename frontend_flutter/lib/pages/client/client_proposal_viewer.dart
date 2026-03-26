// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web/web.dart' as web;
import '../../api.dart';

Map<String, String> _clientDeviceHeadersFromStorage() {
  if (!kIsWeb) return const <String, String>{};
  final headers = <String, String>{};
  try {
    final deviceId = web.window.localStorage.getItem('lukens_client_device_id')?.trim();
    if (deviceId != null && deviceId.isNotEmpty) {
      headers['X-Client-Device-Id'] = deviceId;
    }
    final sessionToken =
        web.window.localStorage.getItem('lukens_client_session_token')?.trim();
    if (sessionToken != null && sessionToken.isNotEmpty) {
      headers['X-Client-Session-Token'] = sessionToken;
    }
  } catch (_) {
    // ignore
  }
  return headers;
}

Map<String, String> _clientJsonHeadersFromStorage() {
  return {
    'Content-Type': 'application/json',
    ..._clientDeviceHeadersFromStorage(),
  };
}

String _clientPortalUrlWithDeviceSession(String url) {
  if (!kIsWeb) return url;
  try {
    final uri = Uri.parse(url);
    final qp = Map<String, String>.from(uri.queryParameters);

    final deviceId =
        web.window.localStorage.getItem('lukens_client_device_id')?.trim();
    final sessionToken =
        web.window.localStorage.getItem('lukens_client_session_token')?.trim();

    if (deviceId != null && deviceId.isNotEmpty) {
      qp['device_id'] = deviceId;
    }
    if (sessionToken != null && sessionToken.isNotEmpty) {
      qp['session_token'] = sessionToken;
    }

    return uri.replace(queryParameters: qp).toString();
  } catch (_) {
    return url;
  }
}

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
  String? _currentSessionId;
  // Section-by-section viewing state for analytics
  List<Map<String, dynamic>> _sections = [];
  int _currentSectionIndex = 0;
  DateTime? _sectionViewStart;

  String? _pdfObjectUrl;
  bool _isPdfLoading = false;
  String? _pdfError;
  late final String _pdfViewType;
  bool _pdfViewRegistered = false;
  html.IFrameElement? _pdfIframe;
  bool _pdfIframeListenersAttached = false;

  static const Duration _networkTimeout = Duration(seconds: 20);

  Future<bool>? _deviceSessionInFlight;
  String? _deviceId;

  String _getOrCreateDeviceId() {
    if (!kIsWeb) {
      return 'flutter-device';
    }
    try {
      final existing = web.window.localStorage.getItem('lukens_client_device_id');
      final clean = existing?.trim();
      if (clean != null && clean.isNotEmpty) return clean;
      final id =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${(100000 + (DateTime.now().microsecondsSinceEpoch % 900000))}';
      web.window.localStorage.setItem('lukens_client_device_id', id);
      return id;
    } catch (_) {
      return 'dev_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Map<String, String> _clientDeviceHeaders() {
    return _clientDeviceHeadersFromStorage();
  }

  Map<String, String> _clientJsonHeaders() {
    return {
      'Content-Type': 'application/json',
      ..._clientDeviceHeaders(),
    };
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

  void _saveCachedClientSession(String? token) {
    if (!kIsWeb) return;
    try {
      if (token == null || token.trim().isEmpty) {
        web.window.localStorage.removeItem('lukens_client_session_token');
        web.window.localStorage.removeItem('lukens_client_session_access_token');
      } else {
        web.window.localStorage
            .setItem('lukens_client_session_token', token.trim());
        web.window.localStorage
            .setItem('lukens_client_session_access_token', widget.accessToken.trim());
      }
    } catch (_) {}
  }

  Future<bool> _ensureDeviceSession() async {
    final inflight = _deviceSessionInFlight;
    if (inflight != null) return inflight;

    final f = _ensureDeviceSessionInternal();
    _deviceSessionInFlight = f;
    try {
      return await f;
    } finally {
      if (identical(_deviceSessionInFlight, f)) {
        _deviceSessionInFlight = null;
      }
    }
  }

  Future<bool> _ensureDeviceSessionInternal() async {
    if (!kIsWeb) return true;

    _deviceId ??= _getOrCreateDeviceId();
    final deviceId = _deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      return false;
    }

    // If a valid cached session exists, trust it.
    try {
      final storedSession =
          web.window.localStorage.getItem('lukens_client_session_token')?.trim();
      final storedAccess =
          web.window.localStorage.getItem('lukens_client_session_access_token')?.trim();
      if (storedAccess != null &&
          storedAccess.isNotEmpty &&
          storedAccess != widget.accessToken.trim()) {
        _saveCachedClientSession(null);
      } else if (storedSession != null && storedSession.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    final startUri = Uri.parse('$baseUrl/api/client/device-session/start');
    final startResp = await http
        .post(
          startUri,
          headers: _clientJsonHeaders(),
          body: jsonEncode({
            'token': widget.accessToken,
            'device_id': deviceId,
          }),
        )
        .timeout(_networkTimeout);

    Map<String, dynamic>? decoded;
    try {
      final body = jsonDecode(startResp.body);
      if (body is Map) decoded = Map<String, dynamic>.from(body);
    } catch (_) {}

    if (startResp.statusCode != 200) {
      final msg = decoded?['detail']?.toString() ??
          'Failed to start verification (HTTP ${startResp.statusCode})';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
      return false;
    }

    final otpRequired = decoded?['otp_required'] == true;
    final sessionToken = decoded?['session_token']?.toString().trim();
    if (!otpRequired && sessionToken != null && sessionToken.isNotEmpty) {
      _saveCachedClientSession(sessionToken);
      return true;
    }

    final challengeId = decoded?['challenge_id']?.toString().trim() ?? '';
    if (!otpRequired || challengeId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification challenge could not be created.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    final otp = await _promptForOtp();
    if (otp == null || otp.trim().isEmpty) return false;
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
          headers: _clientJsonHeaders(),
          body: jsonEncode({
            'challenge_id': challengeId,
            'otp': normalizedOtp,
          }),
        )
        .timeout(_networkTimeout);

    Map<String, dynamic>? verifyDecoded;
    try {
      final body = jsonDecode(verifyResp.body);
      if (body is Map) verifyDecoded = Map<String, dynamic>.from(body);
    } catch (_) {}

    if (verifyResp.statusCode != 200) {
      final msg = verifyDecoded?['detail']?.toString() ??
          'Verification failed (HTTP ${verifyResp.statusCode})';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
      return false;
    }

    final verifiedSession =
        verifyDecoded?['session_token']?.toString().trim() ?? '';
    if (verifiedSession.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verified but no session token was returned.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    _saveCachedClientSession(verifiedSession);
    return true;
  }

  @override
  void initState() {
    super.initState();
    _pdfViewType = 'pdf-preview-${DateTime.now().microsecondsSinceEpoch}';
    _deviceId = _getOrCreateDeviceId();
    _initPdfView();
    _checkIfReturnedFromSigning();
    _loadProposal();
    _startSession();
    _logEvent('open');
  }

  void _initPdfView() {
    if (!kIsWeb || _pdfViewRegistered) return;
    _pdfViewRegistered = true;

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_pdfViewType, (int viewId) {
      _pdfIframe ??= html.IFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen';

      // If we already computed the PDF URL before the iframe existed,
      // ensure we apply it as soon as the iframe is created.
      final pendingUrl = _pdfObjectUrl;
      if (pendingUrl != null && pendingUrl.isNotEmpty) {
        _pdfIframe!.src = pendingUrl;
      }

      if (!_pdfIframeListenersAttached) {
        _pdfIframeListenersAttached = true;
        _pdfIframe!.onLoad.listen((_) {
          if (!mounted) return;
          if (_isPdfLoading) {
            setState(() {
              _isPdfLoading = false;
            });
          }
        });

        _pdfIframe!.onError.listen((_) {
          if (!mounted) return;
          if (_isPdfLoading || _pdfError == null) {
            setState(() {
              _isPdfLoading = false;
              _pdfError =
                  'Failed to load PDF preview. Use Export PDF to open it in a new tab.';
            });
          }
        });
      }
      return _pdfIframe!;
    });
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
        final map = Map<String, dynamic>.from(decoded);
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
    super.dispose();
  }

  Future<void> _loadPdfPreview() async {
    if (!kIsWeb) return;
    _initPdfView();
    setState(() {
      _isPdfLoading = true;
      _pdfError = null;
    });

    try {
      // Load directly via URL so the browser can stream + cache.
      final url = _clientPortalUrlWithDeviceSession(
        '$baseUrl/api/client/proposals/${widget.proposalId}/export/pdf?token=${Uri.encodeComponent(widget.accessToken)}',
      );

// Probe the endpoint first. Iframe load events are unreliable for PDFs
      // and can lead to an endless spinner. A small Range request gives us a
      // fast, deterministic signal.
      http.Response probe;
      try {
        probe = await http.get(
          Uri.parse(url),
          headers: {
            'Range': 'bytes=0-0',
            ..._clientDeviceHeadersFromStorage(),
          },
        ).timeout(const Duration(seconds: 25));
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isPdfLoading = false;
          _pdfError =
              'Unable to load PDF preview (network). Please retry, or use Export PDF.';
        });
        return;
      }

      final status = probe.statusCode;
      final contentType = (probe.headers['content-type'] ?? '').toLowerCase();
      final isPdf = contentType.contains('application/pdf');
      final ok = status == 200 || status == 206;

      if (!ok || !isPdf) {
        String details = '';
        try {
          final decoded = jsonDecode(probe.body);
          if (decoded is Map && decoded['detail'] != null) {
            details = decoded['detail'].toString();
          }
        } catch (_) {
          // ignore
        }

        if (!mounted) return;
        setState(() {
          _isPdfLoading = false;
          _pdfError = details.isNotEmpty
              ? details
              : 'PDF not available. Use Export PDF to open it in a new tab.';
        });
        return;
      }

      // Probe succeeded - load the full PDF in the iframe.
      _pdfObjectUrl = url;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final iframe = _pdfIframe;
        if (iframe != null && mounted) {
          iframe.src = url;
        }
      });

      // _isPdfLoading will flip to false in the iframe onLoad listener.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPdfLoading = false;
        _pdfError = e.toString();
      });
    }
  }

  Future<void> _exportPdf() async {
    final url = _clientPortalUrlWithDeviceSession(
      '$baseUrl/api/client/proposals/${widget.proposalId}/export/pdf?token=${Uri.encodeComponent(widget.accessToken)}&download=1',
    );
    if (kIsWeb) {
      web.window.open(url, '_blank');
      return;
    }
    await launchUrlString(url);
  }

  Future<void> _exportWord() async {
    final url = _clientPortalUrlWithDeviceSession(
      '$baseUrl/api/client/proposals/${widget.proposalId}/export/word?token=${Uri.encodeComponent(widget.accessToken)}',
    );
    if (kIsWeb) {
      web.window.open(url, '_blank');
      return;
    }
    await launchUrlString(url);
  }

  Future<void> _uploadSignedBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uploading signed document...'),
        duration: Duration(seconds: 2),
      ),
    );

    final uri = Uri.parse(
      '$baseUrl/api/client/proposals/${widget.proposalId}/upload-signed',
    );
    final req = http.MultipartRequest('POST', uri)
      ..fields['token'] = widget.accessToken
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    try {
      final streamedResponse = await req.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed document uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh proposal to show the updated signature
        await _loadProposal();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadSignedDocument() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;

      final file = res.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Unable to read file bytes');
      }

      await _uploadSignedBytes(bytes: bytes, filename: file.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanSignedDocument() async {
    try {
      if (kIsWeb) {
        final input = html.FileUploadInputElement();
        input.accept = 'image/*,application/pdf';
        input.setAttribute('capture', 'environment');
        input.click();

        await input.onChange.first;
        final files = input.files;
        if (files == null || files.isEmpty) return;

        final f = files.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(f);
        await reader.onLoadEnd.first;

        final result = reader.result;
        if (result is! ByteBuffer) {
          throw Exception('Unable to read captured file');
        }

        await _uploadSignedBytes(
          bytes: Uint8List.view(result),
          filename: f.name,
        );
        return;
      }

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      await _uploadSignedBytes(bytes: bytes, filename: image.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startSession() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/client/session/start'),
        headers: _clientJsonHeaders(),
        body: jsonEncode({
          'token': widget.accessToken,
          'proposal_id': widget.proposalId,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
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
        await http
            .post(
              Uri.parse('$baseUrl/api/client/session/end'),
              headers: _clientJsonHeaders(),
              body: jsonEncode({
                'session_id': _currentSessionId,
              }),
            )
            .timeout(_networkTimeout);
      } catch (e) {
        print('Error ending session: $e');
      }
    }
  }

  Future<void> _logEvent(String eventType,
      {Map<String, dynamic>? metadata}) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/client/activity'),
            headers: _clientJsonHeaders(),
            body: jsonEncode({
              'token': widget.accessToken,
              'proposal_id': widget.proposalId,
              'event_type': eventType,
              'metadata': metadata ?? {},
            }),
          )
          .timeout(_networkTimeout);
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
      http.Response? response;
      for (var attempt = 0; attempt < 2; attempt++) {
        final extraHeaders =
            kIsWeb ? _clientDeviceHeaders() : const <String, String>{};
        response = await http
            .get(
              Uri.parse(
                  '$baseUrl/api/client/proposals/${widget.proposalId}?token=${Uri.encodeComponent(widget.accessToken)}'),
              headers: extraHeaders.isEmpty ? null : extraHeaders,
            )
            .timeout(_networkTimeout);

        if (response.statusCode == 428) {
          if (attempt == 0) {
            final ok = await _ensureDeviceSession();
            if (ok) {
              continue;
            }
          }
          if (!mounted) return;
          setState(() {
            _error = 'Device verification required. Please retry.';
            _isLoading = false;
          });
          return;
        }

        break;
      }

      final resp = response;
      if (resp == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load proposal. Please retry.';
          _isLoading = false;
        });
        return;
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        print('📄 Proposal data received: ${data['proposal']?['title']}');
        final content = data['proposal']?['content'];
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

        if (!mounted) return;
        setState(() {
          _proposalData = data['proposal'];
          _signatureData = data['signature'] != null
              ? Map<String, dynamic>.from(data['signature'])
              : null;
          _signingUrl = _signatureData?['signing_url']?.toString();
          _signatureStatus = _signatureData?['status']?.toString();

          _sections = parsedSections;
          _currentSectionIndex = 0;
          _sectionViewStart = _sections.isNotEmpty ? DateTime.now() : null;
          _isLoading = false;
        });

        await _loadPdfPreview();
      } else {
        final errorBody = resp.body;
        print('❌ Error loading proposal: ${resp.statusCode}');
        print('❌ Error body: $errorBody');
        try {
          final error = jsonDecode(errorBody);
          if (!mounted) return;
          setState(() {
            _error = error['detail'] ?? 'Failed to load proposal';
            _isLoading = false;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = 'Failed to load proposal (${resp.statusCode}): $errorBody';
            _isLoading = false;
          });
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error =
            'Request timed out. Confirm the backend is running on ${baseUrl.replaceAll("/api", "")} and retry.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
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

          _buildSignaturePanel(),

          // Action Buttons - Always show if proposal is not signed
          if (canTakeAction && !kIsWeb) _buildActionBar(),

          // Content
          Expanded(
            child: _buildProposalContent(proposal),
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
                  'Proposal #${proposal['id']} • v${proposal['version_number'] ?? 1} • ${_formatDate(proposal['version_created_at'] ?? proposal['updated_at'])}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Opp ${proposal['opportunity_id'] ?? '—'} • Stage: ${proposal['engagement_stage'] ?? 'N/A'} • Owner: ${proposal['owner_name'] ?? 'Unknown'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildStatusBadge(status),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Refresh Preview',
            onPressed: _loadPdfPreview,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturePanel() {
    final sig = _signatureData;
    final status = (sig?['status'] ?? _signatureStatus ?? 'unknown').toString();
    final signedAt = (sig?['signed_at'] ?? '').toString();
    final signedUrl = (sig?['signed_document_url'] ?? '').toString();
    final signingUrl = (sig?['signing_url'] ?? _signingUrl ?? '').toString();

    if (signingUrl.trim().isNotEmpty &&
        (_signingUrl == null || _signingUrl!.isEmpty)) {
      _signingUrl = signingUrl;
    }

    String subtitle = status;
    if (signedAt.trim().isNotEmpty) {
      subtitle = '$status • $signedAt';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        children: [
          const Icon(Icons.verified_outlined,
              size: 18, color: Color(0xFF2C3E50)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtitle,
              style: TextStyle(
                  color: Colors.grey[800], fontWeight: FontWeight.w600),
            ),
          ),
          if (signedUrl.trim().isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                if (kIsWeb) {
                  web.window.open(signedUrl, '_blank');
                  return;
                }
                await launchUrlString(signedUrl);
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('View'),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionToolbar() {
    final sig = _signatureData;
    final signedUrl = (sig?['signed_document_url'] ?? '').toString();
    final signingUrl = (sig?['signing_url'] ?? _signingUrl ?? '').toString();
    final canSign = signingUrl.trim().isNotEmpty;

    Widget _toolButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      bool primary = false,
    }) {
      final bg = primary ? const Color(0xFF2D9CDB) : Colors.white;
      final fg = primary ? Colors.white : const Color(0xFF2C3E50);
      return Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toolButton(
          icon: Icons.picture_as_pdf,
          tooltip: 'Export PDF',
          onPressed: _exportPdf,
        ),
        const SizedBox(height: 10),
        _toolButton(
          icon: Icons.description,
          tooltip: 'Export Word',
          onPressed: _exportWord,
        ),
        const SizedBox(height: 10),
        _toolButton(
          icon: Icons.document_scanner,
          tooltip: 'Scan (Phone Camera)',
          onPressed: _scanSignedDocument,
        ),
        const SizedBox(height: 10),
        _toolButton(
          icon: Icons.upload_file,
          tooltip: 'Upload Signed',
          onPressed: _uploadSignedDocument,
        ),
        if (signedUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _toolButton(
            icon: Icons.open_in_new,
            tooltip: 'View Signed',
            onPressed: () {
              if (kIsWeb) {
                web.window.open(signedUrl, '_blank');
                return;
              }
              launchUrlString(signedUrl);
            },
          ),
        ],
        if (canSign) ...[
          const SizedBox(height: 10),
          _toolButton(
            icon: Icons.draw,
            tooltip: 'Sign with DocuSign',
            onPressed: _openSigningModal,
            primary: true,
          ),
        ],
      ],
    );
  }

  Widget _buildActionBar() {
    final signatureStatus = (_signatureStatus ?? '').toLowerCase();
    final isSigned = signatureStatus.contains('completed');
    final isDeclined = signatureStatus.contains('declined');
    final hasSigningUrl = _signingUrl != null && _signingUrl!.isNotEmpty;
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
          if (!isSigned && hasSigningUrl) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                _logEvent('sign', metadata: {'action': 'sign_button_clicked'});

                if (_signingUrl == null || _signingUrl!.isEmpty) {
                  _openSigningModal();
                  return;
                }

                // Open DocuSign in the same tab (redirect mode - works on HTTP)
                final url = _signingUrl!;

                try {
                  // Use replace() to navigate to external URL (bypasses Flutter routing)
                  // This prevents Flutter from intercepting the external DocuSign URL
                  web.window.location.replace(url);
                  // Note: We don't show a SnackBar here because the page will navigate immediately
                  // The navigation happens synchronously, so any mounted check would be unreliable
                } catch (e) {
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
              onPressed: _openSigningModal,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Get signing link'),
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
    _logEvent('sign', metadata: {'action': 'signing_modal_opened'});

    // If no signing URL, try to get/create one
    if (_signingUrl == null || _signingUrl!.isEmpty) {
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
              '$baseUrl/api/client/proposals/${widget.proposalId}/get_signing_url'),
          headers: _clientJsonHeaders(),
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

    try {
      if (kIsWeb) {
        // Navigate to DocuSign in the same tab (redirect mode)
        // Use replace() to navigate to external URL (bypasses Flutter routing)
        web.window.location.replace(urlToOpen);
      } else {
        // For mobile, use external launcher
        await launchUrlString(
          urlToOpen,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
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

  Widget _buildProposalContent(Map<String, dynamic> proposal) {
    if (!kIsWeb) {
      final content = proposal['content']?.toString() ?? '';
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
          child: SelectableText(
            content.isNotEmpty ? content : 'No proposal content available.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.8,
              color: Color(0xFF34495E),
            ),
          ),
        ),
      );
    }

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

  void _onSectionChanged(int newIndex) {
    if (_sections.isEmpty) return;
    final bounded = newIndex.clamp(0, _sections.length - 1);
    if (bounded == _currentSectionIndex) return;

    _logCurrentSectionView();

    setState(() {
      _currentSectionIndex = bounded;
      _sectionViewStart = DateTime.now();
    });
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 380;
              final left = const Text(
                'Sections',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              );
              final right = Text(
                'Section ${index + 1} of $total',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              );

              if (!isNarrow) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    left,
                    right,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  left,
                  const SizedBox(height: 6),
                  right,
                ],
              );
            },
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;
              final prev = TextButton.icon(
                onPressed:
                    index > 0 ? () => _onSectionChanged(index - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous section'),
              );
              final next = TextButton.icon(
                onPressed: index < total - 1
                    ? () => _onSectionChanged(index + 1)
                    : null,
                label: const Text('Next section'),
                icon: const Icon(Icons.chevron_right),
              );

              if (!isNarrow) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    prev,
                    next,
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  prev,
                  next,
                ],
              );
            },
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
              OutlinedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _exportWord,
                icon: const Icon(Icons.description),
                label: const Text('Export Word'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isPdfLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pdfError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load preview: $_pdfError'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadPdfPreview,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pdfObjectUrl == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _loadPdfPreview,
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Load PDF Preview'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(
                child: HtmlElementView(viewType: _pdfViewType),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 20,
            child: _buildFloatingActionToolbar(),
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
