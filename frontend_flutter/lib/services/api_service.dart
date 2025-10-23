import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // Get headers with Firebase token
  static Map<String, String> _getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // User Profile
  static Future<Map<String, dynamic>?> getUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createUserProfile({
    required String token,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/profile'),
        headers: _getHeaders(token),
        body: json.encode({
          'firstName': firstName,
          'lastName': lastName,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating user profile: $e');
      return null;
    }
  }

  // Proposals
  static Future<List<dynamic>> getProposals(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/proposals'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching proposals: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createProposal({
    required String token,
    required String title,
    required String content,
    String? clientName,
    String? status,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/proposals'),
        headers: _getHeaders(token),
        body: json.encode({
          'title': title,
          'content': content,
          'client_name': clientName,
          'status': status ?? 'draft',
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating proposal: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateProposal({
    required String token,
    required int id,
    required String title,
    required String content,
    String? clientName,
    String? status,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/proposals/$id'),
        headers: _getHeaders(token),
        body: json.encode({
          'title': title,
          'content': content,
          'client_name': clientName,
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error updating proposal: $e');
      return null;
    }
  }

  static Future<bool> deleteProposal({
    required String token,
    required int id,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/proposals/$id'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting proposal: $e');
      return false;
    }
  }

  // SOWs
  static Future<List<dynamic>> getSows(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sows'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching SOWs: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createSow({
    required String token,
    required String title,
    required String content,
    String? clientName,
    String? status,
    String? projectScope,
    String? deliverables,
    String? timeline,
    double? budget,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sows'),
        headers: _getHeaders(token),
        body: json.encode({
          'title': title,
          'content': content,
          'client_name': clientName,
          'status': status ?? 'draft',
          'project_scope': projectScope,
          'deliverables': deliverables,
          'timeline': timeline,
          'budget': budget,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating SOW: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateSow({
    required String token,
    required int id,
    required String title,
    required String content,
    String? clientName,
    String? status,
    String? projectScope,
    String? deliverables,
    String? timeline,
    double? budget,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/sows/$id'),
        headers: _getHeaders(token),
        body: json.encode({
          'title': title,
          'content': content,
          'client_name': clientName,
          'status': status,
          'project_scope': projectScope,
          'deliverables': deliverables,
          'timeline': timeline,
          'budget': budget,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error updating SOW: $e');
      return null;
    }
  }

  static Future<bool> deleteSow({
    required String token,
    required int id,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/sows/$id'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting SOW: $e');
      return false;
    }
  }

  // -------- Proposal Versioning --------
  static Future<List<dynamic>> listProposalVersions(String proposalId, String token) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/proposals/$proposalId/versions'),
      headers: _getHeaders(token),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json.decode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch versions');
  }

  static Future<Map<String,dynamic>> createProposalVersion(String proposalId, String token, {String? changeSummary}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/proposals/$proposalId/versions'),
      headers: _getHeaders(token),
      body: json.encode({'change_summary': changeSummary}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json.decode(resp.body) as Map<String,dynamic>;
    }
    throw Exception('Failed to create version');
  }

  static Future<Map<String,dynamic>> restoreVersion(String versionId, String token) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/versions/$versionId/restore'),
      headers: _getHeaders(token),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json.decode(resp.body) as Map<String,dynamic>;
    }
    throw Exception('Failed to restore version');
  }

  static Future<Map<String,dynamic>> compareVersions(String leftId, String rightId, String token) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/versions/$leftId/compare/$rightId'),
      headers: _getHeaders(token),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json.decode(resp.body) as Map<String,dynamic>;
    }
    throw Exception('Failed to compare versions');
  }

  // -------- Approval Workflow --------
  static Future<List<dynamic>> getApprovalWorkflows(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/approval-workflows'),
        headers: _getHeaders(token),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error getting approval workflows: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> createApprovalWorkflow({
    required String token,
    required Map<String, dynamic> workflow,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/approval-workflows'),
        headers: _getHeaders(token),
        body: json.encode(workflow),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating approval workflow: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> submitProposalForApproval({
    required String token,
    required String proposalId,
    String? workflowId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/proposals/$proposalId/submit-for-approval'),
        headers: _getHeaders(token),
        body: json.encode({'workflow_id': workflowId}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error submitting proposal for approval: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getPendingApprovals(String token, String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/approval-requests/pending/$userId'),
        headers: _getHeaders(token),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error getting pending approvals: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getProposalApprovalRequests(String token, String proposalId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/approval-requests/proposal/$proposalId'),
        headers: _getHeaders(token),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error getting proposal approval requests: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> takeApprovalAction({
    required String token,
    required String requestId,
    required String action,
    String? actionComments,
    String? delegatedTo,
    String? actionTakenBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/approval-requests/$requestId/action'),
        headers: _getHeaders(token),
        body: json.encode({
          'action': action,
          'action_comments': actionComments,
          'delegated_to': delegatedTo,
          'action_taken_by': actionTakenBy,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error taking approval action: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> sendApprovalReminder({
    required String token,
    required String requestId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/approval-requests/$requestId/remind'),
        headers: _getHeaders(token),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error sending approval reminder: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getApprovalAnalytics(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/approval-analytics'),
        headers: _getHeaders(token),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting approval analytics: $e');
      return null;
    }
  }
}
