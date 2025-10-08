import 'dart:convert';
import 'package:http/http.dart' as http;

class AIAnalysisService {
  static const String _openaiApiUrl =
      'https://api.openai.com/v1/chat/completions';
  static String? _apiKey;

  // Set your OpenAI API key
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  // Initialize with your API key
  static void initialize() {
    _apiKey = 'YOUR_OPENAI_API_KEY_HERE'; // Replace with your actual API key
  }

  // Check if AI is configured
  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  // AI-powered content analysis
  static Future<Map<String, dynamic>> analyzeProposalContent(
      Map<String, dynamic> proposalData) async {
    if (!isConfigured) {
      return _getMockAnalysis(proposalData);
    }

    try {
      // First try backend AI analysis
      final backendAnalysis = await _callBackendAI(proposalData);
      if (backendAnalysis != null) {
        return backendAnalysis;
      }

      // Fallback to direct OpenAI call
      final analysisPrompt = _buildAnalysisPrompt(proposalData);
      final response = await _callOpenAI(analysisPrompt);
      return _parseAIResponse(response);
    } catch (e) {
      print('AI Analysis Error: $e');
      // Fallback to mock analysis if AI fails
      return _getMockAnalysis(proposalData);
    }
  }

  // Call backend AI analysis endpoint
  static Future<Map<String, dynamic>?> _callBackendAI(
      Map<String, dynamic> proposalData) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/proposals/ai-analysis'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(proposalData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Backend AI call failed: $e');
    }
    return null;
  }

  // Build analysis prompt for OpenAI
  static String _buildAnalysisPrompt(Map<String, dynamic> proposalData) {
    return '''
Analyze this business proposal for potential risks and issues. Return a JSON response with the following structure:

{
  "riskScore": 0-30,
  "status": "Ready|At Risk|Blocked",
  "issues": [
    {
      "type": "ai_analysis",
      "title": "Issue Title",
      "description": "Detailed description of the issue",
      "points": 1-10,
      "priority": "critical|warning|info",
      "action": "Specific action to resolve the issue"
    }
  ]
}

Proposal Data:
- Title: ${proposalData['title'] ?? 'Untitled'}
- Client: ${proposalData['clientName'] ?? 'Not specified'}
- Project Type: ${proposalData['projectType'] ?? 'Not specified'}
- Timeline: ${proposalData['timeline'] ?? 'Not specified'}
- Executive Summary: ${proposalData['executive_summary'] ?? 'Not provided'}
- Scope: ${proposalData['scope_deliverables'] ?? 'Not provided'}

Look for:
1. Unrealistic timelines or overly aggressive commitments
2. Vague or unclear scope definitions
3. Missing critical information (assumptions, risks, team details)
4. Unprofessional or inconsistent language
5. Potential legal or compliance issues
6. Missing client-specific customization

Return only valid JSON, no additional text.
''';
  }

  // Call OpenAI API
  static Future<String> _callOpenAI(String prompt) async {
    final response = await http.post(
      Uri.parse(_openaiApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert business proposal analyst. Analyze proposals for risks and provide actionable feedback in JSON format.'
          },
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 1000,
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception(
          'OpenAI API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Parse AI response
  static Map<String, dynamic> _parseAIResponse(String response) {
    try {
      // Clean the response (remove any markdown formatting)
      final cleanResponse =
          response.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanResponse);
    } catch (e) {
      print('Error parsing AI response: $e');
      return {
        'riskScore': 15,
        'status': 'At Risk',
        'issues': [
          {
            'type': 'ai_analysis',
            'title': 'AI Analysis Failed',
            'description':
                'Unable to parse AI response, using fallback analysis',
            'points': 5,
            'priority': 'warning',
            'action': 'Check AI configuration and try again'
          }
        ]
      };
    }
  }

  // Mock analysis (fallback when AI is not configured)
  static Map<String, dynamic> _getMockAnalysis(
      Map<String, dynamic> proposalData) {
    final issues = <Map<String, dynamic>>[];
    int riskScore = 0;

    // Check for missing required sections
    final requiredSections = [
      'executive_summary',
      'scope_deliverables',
      'company_profile',
      'terms_conditions',
    ];

    for (final section in requiredSections) {
      if (!_hasContent(proposalData, section)) {
        issues.add({
          'type': 'missing_section',
          'title': _getSectionTitle(section),
          'description': 'This section is required for proposal submission',
          'points': 10,
          'priority': 'critical',
          'action': 'Add content from Content Library',
        });
        riskScore += 10;
      }
    }

    // Check for incomplete content
    final contentChecks = [
      {
        'field': 'clientName',
        'title': 'Client Name',
        'points': 5,
        'priority': 'warning',
      },
      {
        'field': 'projectType',
        'title': 'Project Type',
        'points': 3,
        'priority': 'info',
      },
      {
        'field': 'timeline',
        'title': 'Project Timeline',
        'points': 5,
        'priority': 'warning',
      },
    ];

    for (final check in contentChecks) {
      if (!_hasContent(proposalData, check['field'] as String)) {
        issues.add({
          'type': 'incomplete_content',
          'title': '${check['title']} Missing',
          'description': 'This information is required for a complete proposal',
          'points': check['points'],
          'priority': check['priority'],
          'action': 'Complete the required information',
        });
        riskScore += check['points'] as int;
      }
    }

    // Pattern-based analysis
    final aiIssues = _performPatternAnalysis(proposalData);
    issues.addAll(aiIssues);
    riskScore +=
        aiIssues.fold(0, (sum, issue) => sum + (issue['points'] as int));

    // Determine status
    String status;
    if (riskScore == 0) {
      status = 'Ready';
    } else if (riskScore <= 15) {
      status = 'At Risk';
    } else {
      status = 'Blocked';
    }

    return {
      'riskScore': riskScore,
      'status': status,
      'issues': issues,
    };
  }

  // Pattern-based analysis (simplified AI simulation)
  static List<Map<String, dynamic>> _performPatternAnalysis(
      Map<String, dynamic> proposalData) {
    final issues = <Map<String, dynamic>>[];

    // Check for aggressive timelines
    final timeline = proposalData['timeline']?.toString().toLowerCase() ?? '';
    if (timeline.contains('half') ||
        timeline.contains('quick') ||
        timeline.contains('urgent')) {
      issues.add({
        'type': 'ai_analysis',
        'title': 'Aggressive Timeline Detected',
        'description':
            'Timeline may be unrealistic and could lead to project failure',
        'points': 8,
        'priority': 'warning',
        'action': 'Review timeline with delivery team',
      });
    }

    // Check for vague scope
    final scope =
        proposalData['scope_deliverables']?.toString().toLowerCase() ?? '';
    if (scope.contains('and other') ||
        scope.contains('etc') ||
        scope.contains('various')) {
      issues.add({
        'type': 'ai_analysis',
        'title': 'Vague Scope Detected',
        'description':
            'Scope contains vague language that could lead to scope creep',
        'points': 6,
        'priority': 'warning',
        'action': 'Make deliverables more specific',
      });
    }

    // Check for missing assumptions
    if (!_hasContent(proposalData, 'assumptions') &&
        !_hasContent(proposalData, 'assumptions_risks')) {
      issues.add({
        'type': 'ai_analysis',
        'title': 'No Assumptions Section',
        'description': 'Project assumptions should be clearly documented',
        'points': 4,
        'priority': 'info',
        'action': 'Add assumptions from Content Library',
      });
    }

    // Check for team completeness
    if (_hasContent(proposalData, 'team_bios') &&
        !_hasCompleteTeamInfo(proposalData)) {
      issues.add({
        'type': 'ai_analysis',
        'title': 'Incomplete Team Information',
        'description':
            'Team bios should include relevant experience and qualifications',
        'points': 3,
        'priority': 'info',
        'action': 'Complete team member profiles',
      });
    }

    return issues;
  }

  static bool _hasContent(Map<String, dynamic> data, String field) {
    final content = data[field]?.toString().trim();
    return content != null && content.isNotEmpty && content != 'null';
  }

  static bool _hasCompleteTeamInfo(Map<String, dynamic> data) {
    return (data['team_bios']?.toString().length ?? 0) > 100;
  }

  static String _getSectionTitle(String section) {
    switch (section) {
      case 'executive_summary':
        return 'Executive Summary';
      case 'scope_deliverables':
        return 'Scope & Deliverables';
      case 'company_profile':
        return 'Company Profile';
      case 'terms_conditions':
        return 'Terms & Conditions';
      default:
        return section
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }
}
