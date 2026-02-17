import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:web/web.dart' as web;
import '../../api.dart';

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
  List<Map<String, dynamic>> _auditTrail = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  String? _currentSessionId;
  // Section-by-section viewing state for analytics
  List<Map<String, dynamic>> _sections = [];
  int _currentSectionIndex = 0;
  DateTime? _sectionViewStart;

  int _selectedTab = 0; // 0: Content, 1: Comments

  final TextEditingController _signerNameDraftController =
      TextEditingController();
  final TextEditingController _signerTitleDraftController =
      TextEditingController();
  final TextEditingController _signedDateDraftController =
      TextEditingController();
  bool _isSavingDraft = false;
  StreamSubscription<html.KeyboardEvent>? _webKeySub;
  Timer? _restoreAnnotTimer;

  final TextEditingController _sectionEditController = TextEditingController();
  int _sectionEditControllerIndex = -1;

  String? _pdfObjectUrl;
  bool _isPdfLoading = false;
  String? _pdfError;
  late final String _pdfViewType;
  bool _pdfViewRegistered = false;
  late final String _pdfContainerId;
  html.DivElement? _pdfDiv;
  double _pdfScale = 1.2;
  String? _activePdfTool;
  double _penWidth = 2.0;
  html.EventListener? _pdfAnnotToolChangedListener;
  html.EventListener? _pdfAnnotChangedListener;

  @override
  void initState() {
    super.initState();
    _pdfViewType = 'pdf-preview-${DateTime.now().microsecondsSinceEpoch}';
    _pdfContainerId = 'pdf-container-${DateTime.now().microsecondsSinceEpoch}';
    _initPdfView();
    _loadDraftSignatureFields();
    if (kIsWeb) {
      _webKeySub = html.window.onKeyDown.listen((event) {
        final isMac =
            (html.window.navigator.platform ?? '').toLowerCase().contains('mac');
        final mod = isMac ? event.metaKey : event.ctrlKey;
        final key = (event.key ?? '').toLowerCase();
        if (mod && key == 's') {
          event.preventDefault();
          event.stopPropagation();
          _saveDraftProgress();
        }
      });
    }
    _checkIfReturnedFromSigning();
    _loadProposal();
    _startSession();
    _logEvent('open');
  }

  String _formatAuditTimestamp(dynamic ts) {
    if (ts == null) return '';
    final s = ts.toString().trim();
    if (s.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(s);
      if (dt == null) return s;
      return DateFormat('MMM d, yyyy • h:mm a').format(dt.toLocal());
    } catch (_) {
      return s;
    }
  }

  String _latestAuditSummary() {
    if (_auditTrail.isEmpty) return '';
    final e = _auditTrail.last;
    final action = (e['action'] ?? '').toString().trim();
    final desc = (e['description'] ?? '').toString().trim();
    final when = _formatAuditTimestamp(e['timestamp']);
    final parts = <String>[];
    if (action.isNotEmpty) parts.add(action);
    if (desc.isNotEmpty) parts.add(desc);
    if (when.isNotEmpty) parts.add(when);
    if (parts.isEmpty) return '';
    return 'Audit: ${parts.join(' • ')}';
  }

  String _createdBySummary() {
    if (_auditTrail.isEmpty) return '';
    Map<String, dynamic>? created;
    for (final e in _auditTrail) {
      final raw = e['raw'];
      final rawType = (raw is Map ? raw['event_type'] : null)?.toString().toLowerCase().trim();
      final action = (e['action'] ?? '').toString().toLowerCase().trim();
      if (rawType == 'created' || action == 'created') {
        created = e;
        break;
      }
    }
    created ??= _auditTrail.first;
    final who = (created['description'] ?? '').toString().trim();
    if (who.isEmpty) return '';
    return 'Created by: $who';
  }

  String _auditLabel(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'created') return 'Created';
    if (t == 'edited') return 'Edited';
    if (t == 'approved') return 'Approved';
    if (t == 'rejected') return 'Rejected';
    if (t == 'signed') return 'Signed';
    if (t == 'physical_signed') return 'Signed (Upload)';
    if (t == 'sent_back') return 'Sent Back';
    return type;
  }

  Future<void> _loadAuditTrail() async {
    if (!kIsWeb) return;
    try {
      final uri = Uri.parse(
        '$baseUrl/api/client/proposals/${widget.proposalId}/audit-trail?token=${Uri.encodeQueryComponent(widget.accessToken)}',
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        return;
      }
      final body = jsonDecode(res.body);
      final events = (body is Map ? body['events'] : null);
      if (events is! List) return;

      final mapped = <Map<String, dynamic>>[];
      for (final e in events) {
        if (e is! Map) continue;
        final eventType = (e['event_type'] ?? '').toString();
        final actor = (e['actor'] is Map) ? (e['actor'] as Map) : const {};
        final actorName = (actor['name'] ?? '').toString().trim();
        final actorEmail = (actor['email'] ?? '').toString().trim();
        final label = _auditLabel(eventType);
        final who = [actorName, actorEmail].where((v) => v.trim().isNotEmpty).join(' · ');
        mapped.add({
          'action': label,
          'description': who.isNotEmpty ? who : label,
          'timestamp': e['timestamp'],
          'raw': e,
        });
      }

      if (!mounted) return;
      setState(() {
        _auditTrail = mapped;
      });
    } catch (_) {
      return;
    }
  }

  int _getActiveAnnotPage() {
    if (!kIsWeb) return 1;
    try {
      final v = js_util.getProperty(web.window, '__pdfAnnotActivePage');
      if (v == null) return 1;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 1;
    } catch (_) {
      return 1;
    }
  }

  bool _canUndo() {
    if (!kIsWeb) return false;
    try {
      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot == null) return false;
      final page = _getActiveAnnotPage();
      final v = js_util.callMethod(annot, 'canUndo', [page]);
      return v == true;
    } catch (_) {
      return false;
    }
  }

  bool _canRedo() {
    if (!kIsWeb) return false;
    try {
      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot == null) return false;
      final page = _getActiveAnnotPage();
      final v = js_util.callMethod(annot, 'canRedo', [page]);
      return v == true;
    } catch (_) {
      return false;
    }
  }

  void _undoDraw() {
    if (!kIsWeb) return;
    try {
      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot == null) return;
      final page = _getActiveAnnotPage();
      js_util.callMethod(annot, 'undo', [page]);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _redoDraw() {
    if (!kIsWeb) return;
    try {
      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot == null) return;
      final page = _getActiveAnnotPage();
      js_util.callMethod(annot, 'redo', [page]);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _initPdfView() {
    if (!kIsWeb || _pdfViewRegistered) return;
    _pdfViewRegistered = true;

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_pdfViewType, (int viewId) {
      _pdfDiv ??= html.DivElement()
        ..id = _pdfContainerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'auto'
        ..style.backgroundColor = '#f5f7f9';

      return _pdfDiv!;
    });
  }

  void _setPdfTool(String? tool) {
    if (!kIsWeb) return;
    _activePdfTool = tool;
    try {
      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot != null) {
        js_util.callMethod(annot, 'setTool', [tool]);
        if (tool == 'draw') {
          js_util.callMethod(annot, 'setStrokeWidth', [_penWidth]);
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
  }

  void _setPenWidth(double w) {
    if (!kIsWeb) return;
    final next = w.clamp(0.5, 12.0);
    _penWidth = next;
    try {
      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot != null) {
        js_util.callMethod(annot, 'setStrokeWidth', [_penWidth]);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
  }

  void _renderPdfJs(String url) {
    if (!kIsWeb) return;
    try {
      final opts = js_util.jsify({'scale': _pdfScale});
      js_util.callMethod(web.window, 'renderPdfInto', [
        _pdfContainerId,
        url,
        opts,
      ]);
      _scheduleRestoreDraftPdfAnnotations();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfError = e.toString();
      });
    }
  }

  Future<void> _uploadInAppEdits() async {
    if (!kIsWeb) return;
    try {
      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot == null) {
        throw Exception('pdfAnnot is not available');
      }

      final exported = js_util.callMethod(annot, 'export', [_pdfContainerId]);
      final annotations = js_util.dartify(exported);
      if (annotations is! List) {
        throw Exception('Unable to export annotations');
      }

      final nameCtrl = TextEditingController(
        text: _signerNameDraftController.text.trim(),
      );
      final titleCtrl = TextEditingController(
        text: _signerTitleDraftController.text.trim(),
      );
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Upload signed / edited PDF'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Your Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Your Title (Optional)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Upload'),
              ),
            ],
          );
        },
      );

      if (ok != true) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading in-app signed PDF...')),
      );

      final uri = Uri.parse(
        '$baseUrl/api/client/proposals/${widget.proposalId}/upload-annotated',
      );

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.accessToken,
          'signer_name': nameCtrl.text.trim(),
          'signer_title': titleCtrl.text.trim(),
          'signed_date': _signedDateDraftController.text.trim(),
          'annotations': annotations,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception(res.body.isNotEmpty ? res.body : 'Upload failed');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _logEvent('in_app_upload');
      await _loadProposal();
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

    try {
      final section = _sections[newIndex];
      final text = section['content']?.toString() ??
          section['text']?.toString() ??
          '';
      _sectionEditControllerIndex = newIndex;
      _sectionEditController.text = text;
      _sectionEditController.selection = TextSelection.fromPosition(
        TextPosition(offset: _sectionEditController.text.length),
      );
    } catch (_) {}
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
    _webKeySub?.cancel();
    _restoreAnnotTimer?.cancel();
    _signerNameDraftController.dispose();
    _signerTitleDraftController.dispose();
    _signedDateDraftController.dispose();
    _sectionEditController.dispose();
    // PDF is loaded via direct URL (no Blob URL to revoke).
    _commentController.dispose();
    super.dispose();
  }

  String _draftSigStorageKey() {
    // Token is sensitive; we store only last 6 chars to reduce exposure.
    final tail = widget.accessToken.length >= 6
        ? widget.accessToken.substring(widget.accessToken.length - 6)
        : widget.accessToken;
    return 'client_sig_draft_${widget.proposalId}_$tail';
  }

  String _draftAnnotStorageKey() {
    final tail = widget.accessToken.length >= 6
        ? widget.accessToken.substring(widget.accessToken.length - 6)
        : widget.accessToken;
    return 'client_pdf_annot_draft_${widget.proposalId}_$tail';
  }

  void _loadDraftSignatureFields() {
    if (!kIsWeb) return;
    try {
      final raw = html.window.localStorage[_draftSigStorageKey()];
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      _signerNameDraftController.text =
          (map['name'] ?? '').toString();
      _signerTitleDraftController.text =
          (map['title'] ?? '').toString();
      _signedDateDraftController.text =
          (map['date'] ?? '').toString();
    } catch (_) {}
  }

  void _persistDraftSignatureFields() {
    if (!kIsWeb) return;
    try {
      html.window.localStorage[_draftSigStorageKey()] = jsonEncode({
        'name': _signerNameDraftController.text.trim(),
        'title': _signerTitleDraftController.text.trim(),
        'date': _signedDateDraftController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void _persistDraftPdfAnnotations() {
    if (!kIsWeb) return;
    try {
      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot == null) return;
      final exported = js_util.callMethod(annot, 'export', [_pdfContainerId]);
      final items = js_util.dartify(exported);
      if (items is! List) return;
      html.window.localStorage[_draftAnnotStorageKey()] = jsonEncode({
        'items': items,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  void _restoreDraftPdfAnnotations() {
    if (!kIsWeb) return;
    try {
      final raw = html.window.localStorage[_draftAnnotStorageKey()];
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      final items = (decoded is Map) ? decoded['items'] : null;
      if (items is! List) return;

      final annot = js_util.getProperty(web.window, 'pdfAnnot');
      if (annot == null) return;

      // Guard: only attempt import once the PDF pages have rendered.
      try {
        final container = html.document.getElementById(_pdfContainerId);
        final wrappers = container?.querySelectorAll('div[data-page]');
        if (wrappers == null || wrappers.isEmpty) return;
      } catch (_) {
        return;
      }

      js_util.callMethod(annot, 'import', [_pdfContainerId, js_util.jsify(items)]);
    } catch (_) {}
  }

  void _scheduleRestoreDraftPdfAnnotations() {
    if (!kIsWeb) return;
    _restoreAnnotTimer?.cancel();
    var attempts = 0;
    _restoreAnnotTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      attempts += 1;
      _restoreDraftPdfAnnotations();
      // Stop once rendered or after a short timeout.
      try {
        final container = html.document.getElementById(_pdfContainerId);
        final hasPages = (container?.querySelectorAll('div[data-page]').isNotEmpty ?? false);
        if (hasPages) {
          t.cancel();
          return;
        }
      } catch (_) {}
      if (attempts >= 12) t.cancel();
    });
  }

  Future<void> _saveDraftProgress() async {
    if (!mounted) return;

    if (_isSavingDraft) return;
    setState(() => _isSavingDraft = true);

    try {
      _persistDraftSignatureFields();
      _persistDraftPdfAnnotations();

      // Save section edits to backend (does not sign; just persists text changes)
      if (_sections.isNotEmpty) {
        final uri = Uri.parse(
          '$baseUrl/api/client/proposals/${widget.proposalId}/content',
        );
        final res = await http.patch(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': widget.accessToken,
            'sections': _sections,
          }),
        );
        if (res.statusCode != 200) {
          throw Exception(res.body.isNotEmpty ? res.body : 'Save failed');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  Future<void> _loadPdfPreview() async {
    if (!kIsWeb) return;

    setState(() {
      _isPdfLoading = true;
      _pdfError = null;
    });

    try {
      // Load directly via URL so the browser can stream + cache.
      final url =
          '$baseUrl/api/client/proposals/${widget.proposalId}/export/pdf?token=${Uri.encodeComponent(widget.accessToken)}';

      // Probe the endpoint first. Iframe load events are unreliable for PDFs
      // and can lead to an endless spinner. A small Range request gives us a
      // fast, deterministic signal.
      http.Response probe;
      try {
        probe = await http.get(
          Uri.parse(url),
          headers: const {
            'Range': 'bytes=0-0',
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
              : 'Failed to load PDF preview (HTTP $status). Use Export PDF to open it in a new tab.';
        });
        return;
      }

      // Always render with a cache-buster so the browser doesn't serve a stale
      // cached response to the iframe/pdf renderer.
      String renderUrl = url;
      try {
        final uri = Uri.parse(url);
        final qp = Map<String, String>.from(uri.queryParameters);
        qp['cb'] = DateTime.now().millisecondsSinceEpoch.toString();
        renderUrl = uri.replace(queryParameters: qp).toString();
      } catch (_) {
        renderUrl = '$url&cb=${DateTime.now().millisecondsSinceEpoch}';
      }

      _pdfObjectUrl = renderUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pending = _pdfObjectUrl;
        if (pending != null && pending.isNotEmpty) {
          _renderPdfJs(pending);
        }
      });

      // Stop spinner immediately after a successful probe. The browser will
      // continue rendering the PDF inside the iframe.
      if (!mounted) return;
      setState(() {
        _isPdfLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPdfLoading = false;
        _pdfError = e.toString();
      });
    }
  }

  Future<void> _exportPdf() async {
    final url =
        '$baseUrl/api/client/proposals/${widget.proposalId}/export/pdf?token=${Uri.encodeComponent(widget.accessToken)}&download=1';
    if (kIsWeb) {
      web.window.open(url, '_blank');
      return;
    }
    await launchUrlString(url);
  }

  Future<void> _exportWord() async {
    final url =
        '$baseUrl/api/client/proposals/${widget.proposalId}/export/word?token=${Uri.encodeComponent(widget.accessToken)}';
    if (kIsWeb) {
      web.window.open(url, '_blank');
      return;
    }
    await launchUrlString(url);
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

  Future<void> _uploadSignedBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading signed document...')),
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

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception(body.isNotEmpty ? body : 'Upload failed');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signed document uploaded'),
        backgroundColor: Colors.green,
      ),
    );

    _logEvent('upload_signed');
    await _loadProposal();
  }

  Future<void> _startSession() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/client/session/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.accessToken,
          'proposal_id': widget.proposalId,
        }),
      );
      if (response.statusCode == 200) {
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
          Uri.parse('$baseUrl/api/client/session/end'),
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
        Uri.parse('$baseUrl/api/client/activity'),
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
            '$baseUrl/api/client/proposals/${widget.proposalId}?token=${widget.accessToken}'),
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
          _proposalData = data;
          _signatureData = data['signature'] as Map<String, dynamic>?;
          _signingUrl = _signatureData?['signing_url']?.toString();
          _signatureStatus = _signatureData?['status']?.toString();
          _comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
          _activityLog = (data['activity'] as List?)
                  ?.map((a) => Map<String, dynamic>.from(a))
                  .toList() ??
              [];
          _sections = parsedSections;
          _currentSectionIndex = 0;
          _sectionViewStart = _sections.isNotEmpty ? DateTime.now() : null;
          _isLoading = false;
        });

        try {
          if (_sections.isNotEmpty) {
            final section = _sections[0];
            final text = section['content']?.toString() ??
                section['text']?.toString() ??
                '';
            _sectionEditControllerIndex = 0;
            _sectionEditController.text = text;
            _sectionEditController.selection = TextSelection.fromPosition(
              TextPosition(offset: _sectionEditController.text.length),
            );
          } else {
            _sectionEditControllerIndex = -1;
            _sectionEditController.text = '';
          }
        } catch (_) {}

        await _loadAuditTrail();
        await _loadPdfPreview();
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
        Uri.parse('$baseUrl/api/client/proposals/${widget.proposalId}/comment'),
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

    final root = _proposalData!;
    final proposal = (root['proposal'] is Map)
        ? Map<String, dynamic>.from(root['proposal'] as Map)
        : root;
    final status = (proposal['status'] ?? root['status']) as String? ?? 'Unknown';
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
            child: _selectedTab == 0
                ? _buildProposalContent(proposal)
                : _buildCommentsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> proposal, String status) {
    final auditSummary = _latestAuditSummary();
    final createdBySummary = _createdBySummary();
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
                  'Proposal #${proposal['id'] ?? widget.proposalId} • ${_formatDate(proposal['updated_at'] ?? _proposalData?['updated_at'])}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                if (createdBySummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    createdBySummary,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (auditSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    auditSummary,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

    final isSigned = status.toLowerCase().contains('completed') ||
        status.toLowerCase().contains('signed');

    if (signingUrl.trim().isNotEmpty && (_signingUrl == null || _signingUrl!.isEmpty)) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      final iframe = html.IFrameElement()
                        ..src = signedUrl
                        ..style.width = '100%'
                        ..style.height = '100vh'
                        ..style.border = 'none'
                        ..style.position = 'fixed'
                        ..style.top = '0'
                        ..style.left = '0'
                        ..style.zIndex = '9999'
                        ..style.backgroundColor = 'white';
                      
                      final closeBtn = html.ButtonElement()
                        ..text = '✕ Close'
                        ..style.position = 'fixed'
                        ..style.top = '10px'
                        ..style.right = '10px'
                        ..style.zIndex = '10000'
                        ..style.padding = '8px 16px'
                        ..style.backgroundColor = '#ff4444'
                        ..style.color = 'white'
                        ..style.border = 'none'
                        ..style.borderRadius = '4px'
                        ..style.cursor = 'pointer';
                      
                      closeBtn.onClick.listen((_) {
                        iframe.remove();
                        closeBtn.remove();
                      });
                      
                      html.document.body?.append(iframe);
                      html.document.body?.append(closeBtn);
                      return;
                    }
                    await launchUrlString(signedUrl);
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View'),
                ),
            ],
          ),
          if (!isSigned) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _signerNameDraftController,
                    onChanged: (_) => _persistDraftSignatureFields(),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _signerTitleDraftController,
                    onChanged: (_) => _persistDraftSignatureFields(),
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _signedDateDraftController,
              onChanged: (_) => _persistDraftSignatureFields(),
              decoration: const InputDecoration(
                labelText: 'Date',
                hintText: 'YYYY-MM-DD',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _isSavingDraft ? 'Saving...' : 'Ctrl+S to save',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                final iframe = html.IFrameElement()
                  ..src = signedUrl
                  ..style.width = '100%'
                  ..style.height = '100vh'
                  ..style.border = 'none'
                  ..style.position = 'fixed'
                  ..style.top = '0'
                  ..style.left = '0'
                  ..style.zIndex = '9999'
                  ..style.backgroundColor = 'white';
                
                final closeBtn = html.ButtonElement()
                  ..text = '✕ Close'
                  ..style.position = 'fixed'
                  ..style.top = '10px'
                  ..style.right = '10px'
                  ..style.zIndex = '10000'
                  ..style.padding = '8px 16px'
                  ..style.backgroundColor = '#ff4444'
                  ..style.color = 'white'
                  ..style.border = 'none'
                  ..style.borderRadius = '4px'
                  ..style.cursor = 'pointer';
                
                closeBtn.onClick.listen((_) {
                  iframe.remove();
                  closeBtn.remove();
                });
                
                html.document.body?.append(iframe);
                html.document.body?.append(closeBtn);
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
              '$baseUrl/api/client/proposals/${widget.proposalId}/get_signing_url'),
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
    if (!kIsWeb) {
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
              const Text('PDF preview is available on web.'),
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
      child: Column(
        children: [
          _buildPdfTopToolbar(),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
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
                child: HtmlElementView(viewType: _pdfViewType),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfTopToolbar() {
    if (!kIsWeb) return const SizedBox.shrink();

    Color fg(bool selected) => selected ? const Color(0xFF1A73E8) : const Color(0xFF2C3E50);
    Color bg(bool selected) => selected ? const Color(0xFFE8F0FE) : Colors.transparent;

    Widget toolBtn({
      required IconData icon,
      required String tooltip,
      required bool selected,
      required VoidCallback onPressed,
      bool enabled = true,
    }) {
      final bg = selected ? const Color(0xFFE8F0FE) : Colors.transparent;
      final fg = selected ? const Color(0xFF1A73E8) : const Color(0xFF2C3E50);
      final border = selected ? const Color(0xFF1A73E8) : Colors.grey.withValues(alpha: 0.25);
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onPressed : null,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Icon(icon, color: fg, size: 20),
          ),
        ),
      );
    }

    Widget divider() => Container(width: 1, height: 20, color: Colors.grey.withValues(alpha: 0.25));

    Widget penChip(double w, String label) {
      final selected = (_activePdfTool == 'draw') && (_penWidth - w).abs() < 0.01;
      return Tooltip(
        message: 'Pen $label',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _setPenWidth(w),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFE8F0FE) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1A73E8)
                    : Colors.grey.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 0,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? const Color(0xFF1A73E8) : const Color(0xFF2C3E50),
                        width: w,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          toolBtn(
            icon: Icons.picture_as_pdf,
            tooltip: 'Export PDF',
            selected: false,
            onPressed: _exportPdf,
          ),
          const SizedBox(width: 6),
          toolBtn(
            icon: Icons.description,
            tooltip: 'Export Word',
            selected: false,
            onPressed: _exportWord,
          ),
          const SizedBox(width: 10),
          divider(),
          const SizedBox(width: 10),
          toolBtn(
            icon: Icons.edit,
            tooltip: 'Draw',
            selected: _activePdfTool == 'draw',
            onPressed: () => _setPdfTool(_activePdfTool == 'draw' ? null : 'draw'),
          ),
          if (_activePdfTool == 'draw') ...[
            const SizedBox(width: 6),
            toolBtn(
              icon: Icons.undo,
              tooltip: 'Undo',
              selected: false,
              enabled: _canUndo(),
              onPressed: _undoDraw,
            ),
            const SizedBox(width: 6),
            toolBtn(
              icon: Icons.redo,
              tooltip: 'Redo',
              selected: false,
              enabled: _canRedo(),
              onPressed: _redoDraw,
            ),
          ],
          if (_activePdfTool == 'draw') ...[
            const SizedBox(width: 10),
            penChip(1.5, 'Thin'),
            const SizedBox(width: 6),
            penChip(2.5, 'Med'),
            const SizedBox(width: 6),
            penChip(4.0, 'Thick'),
          ],
          const SizedBox(width: 6),
          toolBtn(
            icon: Icons.text_fields,
            tooltip: 'Text',
            selected: _activePdfTool == 'text',
            onPressed: () => _setPdfTool(_activePdfTool == 'text' ? null : 'text'),
          ),
          const SizedBox(width: 6),
          toolBtn(
            icon: Icons.gesture,
            tooltip: 'Signature',
            selected: _activePdfTool == 'signature',
            onPressed: () => _setPdfTool(_activePdfTool == 'signature' ? null : 'signature'),
          ),
          const SizedBox(width: 10),
          divider(),
          const SizedBox(width: 10),
          toolBtn(
            icon: Icons.zoom_out,
            tooltip: 'Zoom out',
            selected: false,
            onPressed: () {
              final next = (_pdfScale - 0.1).clamp(0.6, 2.4);
              setState(() => _pdfScale = next);
              final url = _pdfObjectUrl;
              if (url != null && url.isNotEmpty) _renderPdfJs(url);
            },
          ),
          const SizedBox(width: 6),
          Text('${(_pdfScale * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          toolBtn(
            icon: Icons.zoom_in,
            tooltip: 'Zoom in',
            selected: false,
            onPressed: () {
              final next = (_pdfScale + 0.1).clamp(0.6, 2.4);
              setState(() => _pdfScale = next);
              final url = _pdfObjectUrl;
              if (url != null && url.isNotEmpty) _renderPdfJs(url);
            },
          ),
          const SizedBox(width: 10),
          divider(),
          const SizedBox(width: 10),
          toolBtn(
            icon: Icons.cloud_upload,
            tooltip: 'Upload Signed (In App)',
            selected: false,
            onPressed: _uploadInAppEdits,
          ),
          const Spacer(),
          toolBtn(
            icon: Icons.refresh,
            tooltip: 'Reload preview',
            selected: false,
            onPressed: _loadPdfPreview,
          ),
        ],
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

      // If the section changed without going through _onSectionChanged (e.g. initial build), sync controller.
      if (_sectionEditControllerIndex != index && _sectionEditController.text != sectionContent) {
        _sectionEditControllerIndex = index;
        _sectionEditController.text = sectionContent;
        _sectionEditController.selection = TextSelection.fromPosition(
          TextPosition(offset: _sectionEditController.text.length),
        );
      }

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
          TextField(
            controller: _sectionEditController,
            maxLines: null,
            minLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Type here... (Ctrl+S to save)',
            ),
            onChanged: (value) {
              // Keep in-memory sections in sync. Save is handled by Ctrl+S.
              if (_sections.isEmpty) return;
              final safeIndex = index;
              final existing = Map<String, dynamic>.from(_sections[safeIndex]);
              if (existing.containsKey('content')) {
                existing['content'] = value;
              } else {
                existing['text'] = value;
              }
              _sections[safeIndex] = existing;
            },
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
    final items = _auditTrail.isNotEmpty ? _auditTrail : _activityLog;
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
            if (items.isEmpty)
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
              ...items
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
        Uri.parse('$baseUrl/api/client/proposals/${widget.proposalId}/reject'),
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
        Uri.parse('$baseUrl/api/client/proposals/${widget.proposalId}/approve'),
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