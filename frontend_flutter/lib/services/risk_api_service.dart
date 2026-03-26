import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/risk_gate_config.dart';

class RiskApiService {
  late String baseUrl;

  RiskApiService() {
    debugPrint('🔧 RiskApiService constructor called');
    // Load environment variables without requiring .env in assets
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    try {
      final base = await resolveRiskGateHfBaseUrl();
      if (base.isEmpty) {
        baseUrl = '';
        debugPrint(
            '⚠️ RISK_GATE_HF_BASE_URL not set (use .env or --dart-define); risk calls disabled.');
        return;
      }
      baseUrl = '$base/analyze';
      debugPrint('🔍 Risk Gate API URL: $baseUrl');
    } catch (e) {
      debugPrint('⚠️ Error resolving Risk Gate URL: $e');
      baseUrl = '';
    }
  }
  
  Future<Map<String, dynamic>> analyzeProposal(String text) async {
    try {
      if (baseUrl.isEmpty) {
        throw Exception(
            'Risk Gate URL not configured. Set RISK_GATE_HF_BASE_URL in backend .env or '
            'build with --dart-define=RISK_GATE_HF_BASE_URL=https://your-space.hf.space');
      }
      debugPrint('🔍 Starting risk analysis...');
      debugPrint('🔍 Using Risk Gate API: $baseUrl');
      debugPrint('🔍 Proposal text length: ${text.length} characters');
      
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'proposal_text': text,  // API expects 'proposal_text' parameter
        }),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Successfully parsed response');
        return result;
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('API Error: ${response.statusCode} - ${response.reasonPhrase}\nResponse: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Risk API Error: $e');
      throw Exception('Network Error: ${e.toString()}');
    }
  }
}
