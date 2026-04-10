import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Only when POST …/async returns 404 — safe to fall back to synchronous proxy.
class AsyncAssistantNotEnabled implements Exception {
  AsyncAssistantNotEnabled(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiAssistantApi {
  // Client timeouts must exceed backend HF read (see AI_ASSISTANT_UPSTREAM_TIMEOUT_S,
  // up to 600s for cold/slow Spaces) or async polling will abort and sync will pile on.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 600);
  static const Duration totalTimeout = Duration(seconds: 660);

  // Match server-side primary compact bound (AI_ASSISTANT_MAX_CHARS default 12k).
  static const int _maxProposalChars = 12000;

  /// Prefer async on web when [USE_AI_ASSISTANT_ASYNC] is not set; override with --dart-define.
  static bool get _useAsyncAiAssistant {
    const hasOverride = bool.hasEnvironment('USE_AI_ASSISTANT_ASYNC');
    if (hasOverride) {
      return const bool.fromEnvironment('USE_AI_ASSISTANT_ASYNC', defaultValue: false);
    }
    return kIsWeb;
  }
  static const Duration _pollInterval = Duration(seconds: 2);
  /// Wall-clock budget for async jobs (must exceed worst-case upstream + cold start).
  static const Duration _asyncJobTimeout = Duration(seconds: 660);
  static const Duration _asyncImproveJobTimeout = Duration(seconds: 660);
  /// Status JSON is tiny; transient 502/504 on polls are retried — allow a generous single GET.
  static const Duration _pollRequestTimeout = Duration(seconds: 90);

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': token.trim().startsWith('Bearer ')
            ? token.trim()
            : 'Bearer ${token.trim()}',
      };

  static bool _isRetryableStatus(int code) => code == 502;

  static bool _isTransientJobPollStatus(int code) =>
      code == 408 || code == 429 || code == 502 || code == 503 || code == 504;

  static Exception _friendlyError(int statusCode, String body) {
    String msg = 'AI Assistant error ($statusCode).';
    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        final detail = decoded['detail'] ?? decoded['error'];
        final upstream = decoded['upstream_status'];
        if (detail != null) {
          msg = detail.toString();
        }
        if (upstream != null && upstream.toString().isNotEmpty) {
          msg = '$msg (upstream $upstream)';
        }
      }
    } catch (_) {
      if (body.trim().isNotEmpty) msg = '$msg ${body.trim()}';
    }
    if (statusCode == 504) {
      msg =
          'AI request timed out on the server. Try again with a shorter section.';
    } else if (statusCode == 502 &&
        msg.startsWith('AI Assistant error (502)')) {
      msg = 'AI service is temporarily unavailable (502).';
    }
    return Exception(msg.trim());
  }

  /// Some HF responses nest text under [result]; merge so Improve callers see one shape.
  static Map<String, dynamic> _flattenImproveResponse(Map<String, dynamic> m) {
    final top = (m['generated_text'] ??
            m['improved_version'] ??
            m['content'] ??
            '')
        .toString()
        .trim();
    if (top.isNotEmpty) return m;
    final r = m['result'];
    if (r is Map<String, dynamic>) {
      return <String, dynamic>{...m, ...r};
    }
    if (r is Map) {
      return <String, dynamic>{...m, ...Map<String, dynamic>.from(r)};
    }
    return m;
  }

  static void _ensureImproveHasText(Map<String, dynamic> m) {
    final text = (m['generated_text'] ??
            m['improved_version'] ??
            m['content'] ??
            '')
        .toString()
        .trim();
    if (text.isEmpty) {
      throw Exception(
          'AI returned no improved text. Shorten the section and try again.');
    }
  }

  /// Poll GET /jobs/:id until done, retrying transient gateway/network failures (do not fall back to sync).
  static Future<Map<String, dynamic>> _waitForAiJobResult({
    required Uri pollUri,
    required Map<String, String> headers,
    required DateTime deadlineAt,
    required String clippedText,
    required String originalText,
    required bool isImproveFlow,
  }) async {
    while (DateTime.now().isBefore(deadlineAt)) {
      await Future<void>.delayed(_pollInterval);
      http.Response pollResp;
      try {
        pollResp =
            await http.get(pollUri, headers: headers).timeout(_pollRequestTimeout);
      } on TimeoutException {
        continue;
      }

      if (pollResp.statusCode == 401) {
        throw _friendlyError(401, pollResp.body);
      }
      if (pollResp.statusCode == 404) {
        throw Exception(
            'AI job not found (server may have restarted). Please try again.');
      }

      Map<String, dynamic> map;
      try {
        final raw = pollResp.body.isEmpty ? '{}' : pollResp.body;
        final decoded = json.decode(raw);
        map = decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'result': decoded};
      } catch (_) {
        if (_isTransientJobPollStatus(pollResp.statusCode) ||
            (pollResp.statusCode >= 200 && pollResp.statusCode < 300)) {
          continue;
        }
        throw Exception('Invalid job status response from server.');
      }

      if (pollResp.statusCode >= 200 && pollResp.statusCode < 300) {
        final status = (map['status'] ?? '').toString().toLowerCase();
        if (status == 'pending' || status == 'running' || status.isEmpty) {
          continue;
        }
        if (status == 'error') {
          throw _friendlyError(
            int.tryParse(map['status_code']?.toString() ?? '') ?? 500,
            json.encode(map['error'] ?? map),
          );
        }
        if (status == 'done') {
          final result = map['result'];
          final resultMap = result is Map<String, dynamic>
              ? Map<String, dynamic>.from(result)
              : <String, dynamic>{'result': result};
          if (clippedText.length != originalText.length) {
            resultMap['client_truncated'] = true;
            resultMap['client_truncated_chars'] =
                originalText.length - clippedText.length;
          }
          if (isImproveFlow) {
            final flat = _flattenImproveResponse(resultMap);
            _ensureImproveHasText(flat);
            return flat;
          }
          return resultMap;
        }
        continue;
      }

      if (_isTransientJobPollStatus(pollResp.statusCode)) {
        continue;
      }
      throw _friendlyError(pollResp.statusCode, pollResp.body);
    }
    throw Exception(
      'AI Assistant timed out waiting for async result. '
      'HF Spaces can take several minutes when cold; try again or shorten the prompt.',
    );
  }

  static Future<http.Response> _postJson(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    int retryCount = 0,
    String? requestId,
    String? action,
  }) async {
    final client = http.Client();
    try {
      final effectiveRequestId = requestId ?? 'ai-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
      final sw = Stopwatch()..start();
      print(
          '[AI][${action ?? 'request'}][$effectiveRequestId] -> ${uri.path} payload_chars=${(body['proposal_text'] ?? '').toString().length} retry=$retryCount');

      // Web note: local backend only returns headers after processing.
      // A strict header timeout can incorrectly fail successful long-running requests.
      final resp = await client
          .post(
            uri,
            headers: {
              ...headers,
              'X-AI-Request-ID': effectiveRequestId,
            },
            body: json.encode(body),
          )
          .timeout(totalTimeout);
      sw.stop();
      print(
          '[AI][${action ?? 'request'}][$effectiveRequestId] <- status=${resp.statusCode} elapsed_ms=${sw.elapsedMilliseconds} chars=${(body['proposal_text'] ?? '').toString().length}');

      if (_isRetryableStatus(resp.statusCode) && retryCount < 1) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        return _postJson(
          uri,
          headers,
          body,
          retryCount: retryCount + 1,
          requestId: effectiveRequestId,
          action: action,
        );
      }
      return resp;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> generateSection({
    required String token,
    required String sectionName,
    required String proposalText,
    int maxTokens = 96,
  }) async {
    if (_useAsyncAiAssistant) {
      try {
        return await _generateSectionAsync(
          token: token,
          sectionName: sectionName,
          proposalText: proposalText,
          maxTokens: maxTokens,
        );
      } on AsyncAssistantNotEnabled catch (e) {
        print('[AI][generate-section] $e — falling back to sync.');
      }
    }

    final uri = Uri.parse('${ApiService.baseUrl}/api/ai-assistant/generate-section');
    final clipped = proposalText.length > _maxProposalChars
        ? proposalText.substring(0, _maxProposalChars)
        : proposalText;

    final resp = await _postJson(
      uri,
      _headers(token),
      {
        'section_name': sectionName,
        'proposal_text': clipped,
        'max_tokens': maxTokens,
      },
      action: 'generate-section',
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = json.decode(resp.body);
      final m = (decoded is Map<String, dynamic>) ? decoded : {'result': decoded};
      if (clipped.length != proposalText.length) {
        m['client_truncated'] = true;
        m['client_truncated_chars'] = proposalText.length - clipped.length;
      }
      return m;
    }
    throw _friendlyError(resp.statusCode, resp.body);
  }

  static Future<Map<String, dynamic>> _generateSectionAsync({
    required String token,
    required String sectionName,
    required String proposalText,
    int maxTokens = 96,
  }) async {
    final clipped = proposalText.length > _maxProposalChars
        ? proposalText.substring(0, _maxProposalChars)
        : proposalText;
    final requestId =
        'ai-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final startUri =
        Uri.parse('${ApiService.baseUrl}/api/ai-assistant/generate-section/async');
    final startResp = await _postJson(
      startUri,
      _headers(token),
      {
        'section_name': sectionName,
        'proposal_text': clipped,
        'max_tokens': maxTokens,
      },
      action: 'generate-section-async-start',
      requestId: requestId,
    );
    if (startResp.statusCode == 404) {
      throw AsyncAssistantNotEnabled(
          'Async AI assistant mode is disabled on the server (404).');
    }
    if (startResp.statusCode != 202) {
      throw _friendlyError(startResp.statusCode, startResp.body);
    }

    final startBody = json.decode(startResp.body);
    if (startBody is! Map<String, dynamic> || startBody['job_id'] == null) {
      throw Exception('Invalid async start response from AI assistant.');
    }
    final jobId = startBody['job_id'].toString();
    final pollUri = Uri.parse('${ApiService.baseUrl}/api/ai-assistant/jobs/$jobId');
    final deadline = DateTime.now().add(_asyncJobTimeout);

    return _waitForAiJobResult(
      pollUri: pollUri,
      headers: {
        ..._headers(token),
        'X-AI-Request-ID': requestId,
      },
      deadlineAt: deadline,
      clippedText: clipped,
      originalText: proposalText,
      isImproveFlow: false,
    );
  }

  static Future<Map<String, dynamic>> improveArea({
    required String token,
    required String areaName,
    required String proposalText,
    int maxTokens = 96,
  }) async {
    if (_useAsyncAiAssistant) {
      try {
        return await _improveAreaAsync(
          token: token,
          areaName: areaName,
          proposalText: proposalText,
          maxTokens: maxTokens,
        );
      } on AsyncAssistantNotEnabled catch (e) {
        print('[AI][improve-area] $e — falling back to sync.');
      }
    }

    final uri = Uri.parse('${ApiService.baseUrl}/api/ai-assistant/improve-area');
    final clipped = proposalText.length > _maxProposalChars
        ? proposalText.substring(0, _maxProposalChars)
        : proposalText;

    final resp = await _postJson(
      uri,
      _headers(token),
      {
        'area_name': areaName,
        'proposal_text': clipped,
        'max_tokens': maxTokens,
      },
      action: 'improve-area',
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = json.decode(resp.body);
      final raw =
          (decoded is Map<String, dynamic>) ? decoded : {'result': decoded};
      final m = _flattenImproveResponse(raw);
      if (clipped.length != proposalText.length) {
        m['client_truncated'] = true;
        m['client_truncated_chars'] = proposalText.length - clipped.length;
      }
      _ensureImproveHasText(m);
      return m;
    }
    throw _friendlyError(resp.statusCode, resp.body);
  }

  static Future<Map<String, dynamic>> _improveAreaAsync({
    required String token,
    required String areaName,
    required String proposalText,
    int maxTokens = 96,
  }) async {
    final clipped = proposalText.length > _maxProposalChars
        ? proposalText.substring(0, _maxProposalChars)
        : proposalText;
    final requestId =
        'ai-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final startUri =
        Uri.parse('${ApiService.baseUrl}/api/ai-assistant/improve-area/async');
    final startResp = await _postJson(
      startUri,
      _headers(token),
      {
        'area_name': areaName,
        'proposal_text': clipped,
        'max_tokens': maxTokens,
      },
      action: 'improve-area-async-start',
      requestId: requestId,
    );
    if (startResp.statusCode == 404) {
      throw AsyncAssistantNotEnabled(
          'Async improve-area is disabled on the server (404).');
    }
    if (startResp.statusCode != 202) {
      throw _friendlyError(startResp.statusCode, startResp.body);
    }

    final startBody = json.decode(startResp.body);
    if (startBody is! Map<String, dynamic> || startBody['job_id'] == null) {
      throw Exception('Invalid async start response from AI assistant.');
    }
    final jobId = startBody['job_id'].toString();
    final pollUri = Uri.parse('${ApiService.baseUrl}/api/ai-assistant/jobs/$jobId');
    final deadline = DateTime.now().add(_asyncImproveJobTimeout);

    return _waitForAiJobResult(
      pollUri: pollUri,
      headers: {
        ..._headers(token),
        'X-AI-Request-ID': requestId,
      },
      deadlineAt: deadline,
      clippedText: clipped,
      originalText: proposalText,
      isImproveFlow: true,
    );
  }
}

