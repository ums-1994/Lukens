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

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      print(
          'Error creating proposal: ${response.statusCode} - ${response.body}');
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

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      print('Error creating SOW: ${response.statusCode} - ${response.body}');
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

  // Client Portal Methods
  static Future<Map<String, dynamic>?> validateClientToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/client-dashboard/$token'),
        headers: _getHeaders(null),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error validating client token: $e');
      return null;
    }
  }

  static Future<bool> uploadSignature(
      String token, List<int> signatureBytes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/client-dashboard/$token/sign'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'signature': base64Encode(signatureBytes),
          'signature_type': 'png',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error uploading signature: $e');
      return false;
    }
  }

  static Future<String?> getSignedPdfUrl(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/client-dashboard/$token/pdf'),
        headers: _getHeaders(null),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['pdf_url'];
      }
      return null;
    } catch (e) {
      print('Error getting signed PDF URL: $e');
      return null;
    }
  }

  // Proposal Versions
  static Future<Map<String, dynamic>?> createVersion({
    required String token,
    required int proposalId,
    required int versionNumber,
    required String content,
    String? changeDescription,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/proposals/$proposalId/versions'),
        headers: _getHeaders(token),
        body: json.encode({
          'version_number': versionNumber,
          'content': content,
          'change_description': changeDescription ?? 'Version created',
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      }
      print(
          'Error creating version: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error creating version: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getVersions({
    required String token,
    required int proposalId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/proposals/$proposalId/versions'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching versions: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getVersion({
    required String token,
    required int proposalId,
    required int versionNumber,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/proposals/$proposalId/versions/$versionNumber'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching version: $e');
      return null;
    }
  }

  // Document Comments
  static Future<Map<String, dynamic>?> createComment({
    required String token,
    required int proposalId,
    required String commentText,
    required String createdBy,
    int? sectionIndex,
    String? highlightedText,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/comments/document/$proposalId'),
        headers: _getHeaders(token),
        body: json.encode({
          'comment_text': commentText,
          'created_by': createdBy,
          'section_index': sectionIndex,
          'highlighted_text': highlightedText,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      print(
          'Error creating comment: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error creating comment: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getComments({
    required String token,
    required int proposalId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/comments/proposal/$proposalId'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }
}
