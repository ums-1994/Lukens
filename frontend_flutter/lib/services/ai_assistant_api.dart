import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

class AiAssistantApi {
  // Client-side timeouts (web-safe):
  // - connectTimeout: time to receive response headers
  // - receiveTimeout: time to read full response body after headers
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 90);
  static const Duration totalTimeout = Duration(seconds: 105);

  // Keep payload bounded so upstream is faster and avoids gateway timeouts.
  static const int _maxProposalChars = 20000;
  static const bool _useAsyncAiAssistant =
      bool.fromEnvironment('USE_AI_ASSISTANT_ASYNC', defaultValue: kDebugMode);
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _asyncJobTimeout = Duration(seconds: 130);

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': token.trim().startsWith('Bearer ')
            ? token.trim()
            : 'Bearer ${token.trim()}',
      };

  // Do not retry 504 timeouts from backend: it often doubles wait time with no gain.
  static bool _isRetryableStatus(int code) => code == 502;

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
    return Exception(msg);
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
          '[AI][${action ?? 'request'}][$effectiveRequestId] <- status=${resp.statusCode} elapsed_ms=${sw.elapsedMilliseconds}');

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
      } catch (e) {
        // Safety: if async route is unavailable, keep old sync behavior.
        print('[AI][generate-section] async path failed, fallback to sync: $e');
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

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);
      final pollResp = await http
          .get(
            pollUri,
            headers: {
              ..._headers(token),
              'X-AI-Request-ID': requestId,
            },
          )
          .timeout(totalTimeout);
      final decoded = json.decode(pollResp.body);
      final map = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'result': decoded};

      if (pollResp.statusCode >= 200 && pollResp.statusCode < 300) {
        final status = (map['status'] ?? '').toString().toLowerCase();
        if (status == 'pending') {
          continue;
        }
        if (status == 'done') {
          final result = map['result'];
          final resultMap = result is Map<String, dynamic>
              ? result
              : <String, dynamic>{'result': result};
          if (clipped.length != proposalText.length) {
            resultMap['client_truncated'] = true;
            resultMap['client_truncated_chars'] = proposalText.length - clipped.length;
          }
          return resultMap;
        }
      }
      throw _friendlyError(pollResp.statusCode, pollResp.body);
    }
    throw Exception('AI Assistant timed out waiting for async result.');
  }

  static Future<Map<String, dynamic>> improveArea({
    required String token,
    required String areaName,
    required String proposalText,
    int maxTokens = 96,
  }) async {
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
      final m = (decoded is Map<String, dynamic>) ? decoded : {'result': decoded};
      if (clipped.length != proposalText.length) {
        m['client_truncated'] = true;
        m['client_truncated_chars'] = proposalText.length - clipped.length;
      }
      return m;
    }
    throw _friendlyError(resp.statusCode, resp.body);
  }
}

