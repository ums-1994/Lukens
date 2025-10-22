import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StreamingAIService {
  static GenerativeModel? _model;

  static void initialize() {
    final apiKey = dotenv.env['YOUR_GOOGLE_AI_STUDIO_API_KEY'] ?? 'AIzaSyD4pGgtq5ImBIclXz4Y4Bc9uHvNoXdM4U0';
    print('🔑 API Key from .env: ${apiKey?.substring(0, 10)}...');
    print('🔑 Full API Key: $apiKey');
    
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_actual_api_key_here') {
      print('⚠️ Please set your Google AI Studio API key in the .env file');
      print('   Add: YOUR_GOOGLE_AI_STUDIO_API_KEY=your_actual_api_key_here');
      print('   Location: C:\\Users\\User\\mxm\\.env');
      return;
    }
    
    _model = GenerativeModel(
      model: 'gemini-1.0-pro',
      apiKey: apiKey,
    );
    print('✅ Google AI Studio initialized successfully');
  }

  static Stream<String> generateStreamingContent(
    String sectionType,
    Map<String, dynamic> context,
  ) async* {
    if (_model == null) {
      initialize();
      if (_model == null) {
        yield 'AI service not available. Please check your API key configuration.';
        return;
      }
    }

    try {
      final prompt = _buildPrompt(sectionType, context);
      print('AI Prompt for $sectionType: ${prompt.substring(0, 100)}...');
      
      final content = [Content.text(prompt)];
      final response = _model!.generateContentStream(content);

      await for (final chunk in response) {
        if (chunk.text != null) {
          print('AI Generated chunk: ${chunk.text!.length} chars');
          yield chunk.text!;
        }
      }
    } catch (e) {
      print('Streaming AI Error: $e');
      yield 'Error generating content: $e';
    }
  }

  static String _buildPrompt(String sectionType, Map<String, dynamic> context) {
    final clientName = context['client_name'] ?? '';
    final projectType = context['project_type'] ?? '';
    final opportunityName = context['opportunity_name'] ?? '';
    final templateType = context['template_type'] ?? '';
    final estimatedValue = context['estimated_value'] ?? '';
    final timeline = context['timeline'] ?? '';

    return '''
You are a professional proposal writer for Khonology, a South African technology consulting company.

Write a comprehensive $sectionType section for a $templateType proposal.

Client Details:
- Client Name: $clientName
- Project/Opportunity: $opportunityName
- Project Type: $projectType
- Estimated Value: $estimatedValue
- Timeline: $timeline

Requirements:
1. Write in professional, business-appropriate language
2. Use South African business context and terminology
3. Make it specific to the client and project
4. Include relevant technical details
5. Keep it concise but comprehensive
6. Use proper formatting with clear structure
7. Write in first person plural (we, our, us) for Khonology
8. Include specific deliverables and outcomes

Write the $sectionType section now:
''';
  }

  static Future<String> generateNonStreamingContent(
    String sectionType,
    Map<String, dynamic> context,
  ) async {
    if (_model == null) {
      initialize();
      if (_model == null) {
        return 'AI service not available. Please check your API key configuration.';
      }
    }

    try {
      final prompt = _buildPrompt(sectionType, context);
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      
      return response.text ?? 'No content generated';
    } catch (e) {
      print('Non-streaming AI Error: $e');
      return 'Error generating content: $e';
    }
  }
}
