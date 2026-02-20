import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RiskApiService {
  late String baseUrl;

  RiskApiService() {
    debugPrint('🔧 RiskApiService constructor called');
    // Load environment variables without requiring .env in assets
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    try {
      // For now, hardcode the URL to test connection
      baseUrl = 'https://lorde01v-v3.hf.space/analyze';
      debugPrint('🔍 Using hardcoded Risk Gate API URL: $baseUrl');
      
      // Try to load from .env for future use
      try {
        await dotenv.load(fileName: '../backend/.env');
        final riskGateUrl = dotenv.env['Risk_Gate_engine_API'];
        if (riskGateUrl != null) {
          String finalUrl = riskGateUrl;
          if (!finalUrl.endsWith('/analyze')) {
            finalUrl += '/analyze';
          }
          baseUrl = finalUrl;
          debugPrint('🔍 Updated to .env URL: $baseUrl');
        }
      } catch (e) {
        debugPrint('⚠️ Could not load .env, keeping hardcoded URL');
      }
      
      debugPrint('🔍 Final Risk Gate API URL: $baseUrl');
    } catch (e) {
      debugPrint('⚠️ Error loading API URL: $e');
      baseUrl = 'https://lorde01v-v3.hf.space/analyze';
      debugPrint('🔍 Fallback to default URL: $baseUrl');
    }
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
