import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ApiService {
<<<<<<< HEAD
  static const String baseUrl = 'https://lukens-backend.onrender.com';
=======
  // Get API URL from JavaScript config or use default
  static String get baseUrl {
    if (kIsWeb) {
      try {
        // Try to get from window.APP_CONFIG.API_URL
        final config = js.context['APP_CONFIG'];
        if (config != null) {
          final configObj = config as js.JsObject;
          final apiUrl = configObj['API_URL'];
          if (apiUrl != null && apiUrl.toString().isNotEmpty) {
            final url = apiUrl.toString().replaceAll('"', '').trim();
            print('🌐 ApiService: Using API URL from APP_CONFIG: $url');
            return url;
          }
        }
        // Fallback: try window.REACT_APP_API_URL
        final envUrl = js.context['REACT_APP_API_URL'];
        if (envUrl != null && envUrl.toString().isNotEmpty) {
          final url = envUrl.toString().replaceAll('"', '').trim();
          print('🌐 ApiService: Using API URL from REACT_APP_API_URL: $url');
          return url;
        }
      } catch (e) {
        print('⚠️ ApiService: Could not read API URL from config: $e');
      }
    }
    // Check if we're in production (not localhost)
    if (kIsWeb) {
      final hostname = html.window.location.hostname;
      if (hostname != null) {
        final isProduction = hostname.contains('netlify.app') ||
            hostname.contains('onrender.com') ||
            !hostname.contains('localhost');
        
        if (isProduction) {
          print('🌐 ApiService: Using production API URL: https://lukens-wp8w.onrender.com');
          return 'https://lukens-wp8w.onrender.com';
        }
      }
    }
    // Default to Render backend (production)
    print('🌐 ApiService: Using Render API URL: https://lukens-wp8w.onrender.com');
    return 'https://lukens-wp8w.onrender.com';
  }
>>>>>>> origin/Cleaned_Code

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

  // Search users (used for @-mention autocomplete)
  static Future<List<dynamic>> searchUsers({
    String? authToken,
    String? collabToken,
    required String query,
    int? proposalId,
  }) async {
    try {
      final params = {
        'q': query,
        if (proposalId != null) 'proposal_id': proposalId.toString(),
      };
      final uri =
          Uri.parse('$baseUrl/users/search').replace(queryParameters: params);

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (authToken != null && authToken.trim().isNotEmpty)
          'Authorization': authToken.trim().startsWith('Bearer ')
              ? authToken.trim()
              : 'Bearer ${authToken.trim()}',
        if (collabToken != null && collabToken.trim().isNotEmpty)
          'Collab-Token': collabToken.trim(),
      };

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
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
    String? clientEmail,
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
          'client_email': clientEmail,
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
    required dynamic id, // Accept int or UUID
    required String title,
    required String content,
    String? clientName,
    String? clientEmail,
    String? status,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/proposals/${id.toString()}'),
        headers: _getHeaders(token),
        body: json.encode({
          'title': title,
          'content': content,
          'client_name': clientName,
          'client_email': clientEmail,
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
    required dynamic id, // Accept int or UUID
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/proposals/${id.toString()}'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting proposal: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> refreshDocuSignStatus({
    required String token,
    required dynamic proposalId, // Accept int or UUID
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$baseUrl/api/proposals/${proposalId.toString()}/docusign/refresh-status'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      print(
          'Error refreshing DocuSign status: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error refreshing DocuSign status: $e');
      return null;
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
    required dynamic proposalId, // Accept int or UUID
    required int versionNumber,
    required String content,
    String? changeDescription,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/proposals/${proposalId.toString()}/versions'),
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
    required dynamic proposalId, // Accept int or UUID
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/proposals/${proposalId.toString()}/versions'),
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
    required dynamic proposalId, // Accept int or UUID
    required int versionNumber,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/proposals/${proposalId.toString()}/versions/$versionNumber'),
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
    required dynamic proposalId, // Accept int or UUID
    required String commentText,
    String? createdBy,
    int? sectionIndex,
    String? sectionName,
    String? highlightedText,
    int? parentId, // For threaded replies
    String? blockType, // 'text', 'table', 'image'
    String? blockId, // Identifier for the block
    List<String>? taggedUsers,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/comments/document/${proposalId.toString()}'),
        headers: _getHeaders(token),
        body: json.encode({
          'comment_text': commentText,
          'section_index': sectionIndex,
          'section_name': sectionName,
          'highlighted_text': highlightedText,
          'parent_id': parentId,
          'block_type': blockType,
          'block_id': blockId,
          if (taggedUsers != null && taggedUsers.isNotEmpty)
            'tagged_users': taggedUsers,
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

  static Future<Map<String, dynamic>?> getComments({
    required String token,
    required dynamic proposalId, // Accept int or UUID
    int? sectionId,
    String? blockId,
    String? blockType,
    String? status, // 'open', 'resolved', or null for all
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/comments/document/${proposalId.toString()}').replace(
        queryParameters: {
          if (sectionId != null) 'section_id': sectionId.toString(),
          if (blockId != null) 'block_id': blockId,
          if (blockType != null) 'block_type': blockType,
          if (status != null) 'status': status,
        },
      );

      final response = await http.get(
        uri,
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'comments': [], 'total': 0, 'open_count': 0, 'resolved_count': 0};
    } catch (e) {
      print('Error fetching comments: $e');
      return {'comments': [], 'total': 0, 'open_count': 0, 'resolved_count': 0};
    }
  }

  static Future<bool> resolveComment({
    required String token,
    required int commentId,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/comments/$commentId/resolve'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error resolving comment: $e');
      return false;
    }
  }

  static Future<bool> reopenComment({
    required String token,
    required int commentId,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/comments/$commentId/reopen'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error reopening comment: $e');
      return false;
    }
  }

  // User search for @mentions autocomplete
  static Future<List<dynamic>> searchUsersForMentions({
    required String token,
    required String query,
    int limit = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/search').replace(
          queryParameters: {'q': query, 'limit': limit.toString()},
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['users'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Proposal archival
  static Future<Map<String, dynamic>?> archiveProposal({
    required String token,
    required dynamic proposalId, // Accept int or UUID
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/proposals/${proposalId.toString()}/archive'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error archiving proposal: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> restoreProposal({
    required String token,
    required dynamic proposalId, // Accept int or UUID
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/proposals/${proposalId.toString()}/restore'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error restoring proposal: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getArchivedProposals({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/proposals/archived'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching archived proposals: $e');
      return [];
    }
  }

  // AI Assistant Methods
  static Future<Map<String, dynamic>?> generateAIContent({
    required String token,
    required String prompt,
    Map<String, dynamic>? context,
    String sectionType = 'general',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/generate'),
        headers: _getHeaders(token),
        body: json.encode({
          'prompt': prompt,
          'context': context ?? {},
          'section_type': sectionType,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print(
          'Error generating AI content: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error generating AI content: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> improveContent({
    required String token,
    required String content,
    String sectionType = 'general',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/improve'),
        headers: _getHeaders(token),
        body: json.encode({
          'content': content,
          'section_type': sectionType,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print(
          'Error improving content: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error improving content: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> analyzeRisks({
    required String token,
    required dynamic proposalId, // Accept int or UUID
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/analyze-risks'),
        headers: _getHeaders(token),
        body: json.encode({
          'proposal_id': proposalId.toString(),
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Error analyzing risks: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error analyzing risks: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getProposalReadiness({
    required String token,
    required dynamic proposalId, // Accept int or UUID
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/proposals/${proposalId.toString()}/readiness'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print(
          'Error fetching proposal readiness: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error fetching proposal readiness: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> generateFullProposal({
    required String token,
    required String prompt,
    Map<String, dynamic>? context,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/generate-full-proposal'),
        headers: _getHeaders(token),
        body: json.encode({
          'prompt': prompt,
          'context': context ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print(
          'Error generating full proposal: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error generating full proposal: $e');
      return null;
    }
  }
}
