import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RiskApiService {
  late String baseUrl;

  RiskApiService() {
    debugPrint('🔧 RiskApiService constructor called');
    final configured = const String.fromEnvironment(
      'RISK_GATE_API_URL',
      defaultValue: 'https://lorde01v-v3.hf.space/analyze',
    ).trim();
    baseUrl = configured.isEmpty ? 'https://lorde01v-v3.hf.space/analyze' : configured;
    if (!baseUrl.endsWith('/analyze')) {
      baseUrl = '$baseUrl/analyze';
    }
    debugPrint('🔍 Risk Gate API URL: $baseUrl');
  }
  
  Future<Map<String, dynamic>> analyzeProposal(String text) async {
    try {
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
