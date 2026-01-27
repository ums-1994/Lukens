import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AIAnalysisService {
  static String get _baseUrl => ApiService.baseUrl;
  static String? _authToken;

  // Set authentication token
  static void setAuthToken(String token) {
    _authToken = token;
  }

  // Check if AI is configured (check backend status)
  static Future<bool> get isConfigured async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ai/status'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ai_enabled'] == true;
      }
    } catch (e) {
      print('AI status check failed: $e');
    }
    return false;
  }

  // AI-powered risk analysis (Wildcard Challenge)
  static Future<Map<String, dynamic>> analyzeProposalRisks(
      String proposalId) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/analyze-risks'),
        headers: headers,
        body: jsonEncode({'proposal_id': proposalId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw Exception('Unexpected risk analysis response');
        }

        // Backend currently returns the analysis at the top-level.
        // Keep backward compatibility if a nested `analysis` key exists.
        final analysis = (data['analysis'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(data['analysis'])
            : data;

        return _convertToUIFormat(analysis);
      } else {
        throw Exception('Risk analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      print('AI Risk Analysis Error: $e');
      return _getMockAnalysis({});
    }
  }

  // AI-powered content generation
  static Future<String> generateSection(
      String sectionType, Map<String, dynamic> context) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

      final response = await http.post(
        // Use the unified /ai/generate endpoint implemented in the backend
        Uri.parse('$_baseUrl/ai/generate'),
        headers: headers,
        body: jsonEncode({
          // Generic prompt; backend mainly relies on section_type + context
          'prompt': 'Generate proposal section: $sectionType',
          'section_type': sectionType,
          'context': context,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // New backend returns `content`; keep a fallback for older shape
        final generated = data['content'] ?? data['generated_content'] ?? '';
        if (generated is String && generated.isNotEmpty) {
          return generated;
        }
        throw Exception('Empty AI response');
      } else {
        throw Exception('Content generation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('AI Content Generation Error: $e');
      return 'AI content generation is currently unavailable. Please write content manually.';
    }
  }

  // AI-powered content improvement
  static Future<Map<String, dynamic>> improveContent(
      String content, String sectionType) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

      final response = await http.post(
        // Use the /ai/improve endpoint implemented in the backend
        Uri.parse('$_baseUrl/ai/improve'),
        headers: headers,
        body: jsonEncode({
          'content': content,
          'section_type': sectionType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend already returns the full result map from ai_service.improve_content
        // Keep backward compatibility if a nested "improvements" key exists
        if (data is Map<String, dynamic>) {
          return data['improvements'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['improvements'])
              : data;
        }
        throw Exception('Unexpected AI improve response shape');
      } else {
        throw Exception('Content improvement failed: ${response.statusCode}');
      }
    } catch (e) {
      print('AI Content Improvement Error: $e');
      return {
        'quality_score': 70,
        'strengths': ['Content is present'],
        'improvements': [],
        'improved_version': content,
        'summary': 'AI improvement unavailable'
      };
    }
  }

  // AI-powered compliance check
  static Future<Map<String, dynamic>> checkCompliance(String proposalId) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/ai/check-compliance'),
        headers: headers,
        body: jsonEncode({'proposal_id': proposalId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['compliance'];
      } else {
        throw Exception('Compliance check failed: ${response.statusCode}');
      }
    } catch (e) {
      print('AI Compliance Check Error: $e');
      return {
        'compliant': false,
        'compliance_score': 50,
        'passed_checks': [],
        'failed_checks': [],
        'ready_for_approval': false,
        'summary': 'AI compliance check unavailable'
      };
    }
  }

  // Legacy method for backward compatibility
  static Future<Map<String, dynamic>> analyzeProposalContent(
      Map<String, dynamic> proposalData) async {
    // If proposal has an ID and it's not 'draft', use the new risk analysis
    if (proposalData.containsKey('id') &&
        proposalData['id'] != null &&
        proposalData['id'].toString() != 'draft') {
      try {
        return await analyzeProposalRisks(proposalData['id'].toString());
      } catch (e) {
        print('AI Risk Analysis failed, falling back to basic analysis: $e');
        // Fall through to basic analysis
      }
    }

    // For unsaved proposals or when API fails, use basic analysis
    return _getMockAnalysis(proposalData);
  }

  // Convert backend AI response to UI format
  static Map<String, dynamic> _convertToUIFormat(
      Map<String, dynamic> analysis) {
    final issues = <Map<String, dynamic>>[];

    // Convert backend issues to UI format
    if (analysis['issues'] != null) {
      for (final issue in analysis['issues']) {
        issues.add({
          'type': issue['category'] ?? 'ai_analysis',
          'title': issue['section'] ?? 'Issue',
          'description': issue['description'] ?? '',
          'points': _severityToPoints(issue['severity']),
          'priority': issue['severity'] ?? 'info',
          'action': issue['recommendation'] ?? 'Review and fix',
        });
      }
    }

    // Calculate risk score
    int riskScore = analysis['risk_score'] ?? 0;

    // Determine status
    String status;
    if (analysis['can_release'] == true) {
      status = 'Ready';
    } else if (riskScore <= 30) {
      status = 'At Risk';
    } else {
      status = 'Blocked';
    }

    return {
      'riskScore': riskScore,
      'status': status,
      'issues': issues,
      'summary': analysis['summary'] ?? '',
      'required_actions': analysis['required_actions'] ?? [],
      'kb_recommendations': analysis['kb_recommendations'] ?? {},
    };
  }

  static int _severityToPoints(String? severity) {
    switch (severity) {
      case 'critical':
        return 10;
      case 'high':
        return 7;
      case 'medium':
        return 5;
      case 'low':
        return 3;
      default:
        return 5;
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
    // Add points from AI-style checks to the overall risk score
    riskScore += aiIssues.fold(0, (sum, issue) {
      final points = issue['points'] as int? ?? 0;
      return sum + points;
    });

    // Determine status based on a 0-100 readiness-style score
    // where higher is better (100 = no risk).
    final int readinessScore = (100 - riskScore).clamp(0, 100).toInt();

    String status;
    if (readinessScore >= 90) {
      status = 'Ready';
    } else if (readinessScore >= 60) {
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

    // Check for missing assumptions: treat as a missing section so the
    // Governance UI can auto-add the corresponding module.
    if (!_hasContent(proposalData, 'assumptions') &&
        !_hasContent(proposalData, 'assumptions_risks')) {
      issues.add({
        'type': 'missing_section',
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
