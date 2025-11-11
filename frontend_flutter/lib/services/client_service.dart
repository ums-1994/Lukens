import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class ClientService {
  static const String baseUrl = ApiService.baseUrl;

  // Get headers with token
  static Map<String, String> _getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // CLIENT MANAGEMENT
  // ============================================================

  /// Get all clients
  static Future<List<dynamic>> getClients(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clients'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      print('Error fetching clients: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      print('Error fetching clients: $e');
      return [];
    }
  }

  /// Get a single client by ID
  static Future<Map<String, dynamic>?> getClient(String token, int clientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clients/$clientId'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching client: $e');
      return null;
    }
  }

  /// Update client status
  static Future<bool> updateClientStatus(String token, int clientId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/clients/$clientId/status'),
        headers: _getHeaders(token),
        body: json.encode({'status': status}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating client status: $e');
      return false;
    }
  }

  // ============================================================
  // CLIENT INVITATIONS
  // ============================================================

  /// Send a client onboarding invitation
  static Future<Map<String, dynamic>?> sendInvitation({
    required String token,
    required String email,
    String? companyName,
    int expiryDays = 7,
  }) async {
    try {
      final url = '$baseUrl/clients/invite';
      final body = {
        'invited_email': email,
        'expected_company': companyName,
        'expiry_days': expiryDays,
      };
      
      print('[ClientService] POST $url');
      print('[ClientService] Body: $body');
      print('[ClientService] Token length: ${token.length}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: _getHeaders(token),
        body: json.encode(body),
      );

      print('[ClientService] Response status: ${response.statusCode}');
      print('[ClientService] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      print('[ClientService] Error sending invitation: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('[ClientService] Exception sending invitation: $e');
      return null;
    }
  }

  /// Get all invitations
  static Future<List<dynamic>> getInvitations(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clients/invitations'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching invitations: $e');
      return [];
    }
  }

  /// Resend invitation
  static Future<bool> resendInvitation(String token, int invitationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clients/invitations/$invitationId/resend'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error resending invitation: $e');
      return false;
    }
  }

  /// Send email verification code for an invitation (admin action)
  static Future<bool> sendVerificationCode(String token, int invitationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clients/invitations/$invitationId/send-code'),
        headers: _getHeaders(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending verification code: $e');
      return false;
    }
  }

  /// Cancel invitation
  static Future<bool> cancelInvitation(String token, int invitationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/clients/invitations/$invitationId'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error canceling invitation: $e');
      return false;
    }
  }

  // ============================================================
  // CLIENT NOTES
  // ============================================================

  /// Get notes for a client
  static Future<List<dynamic>> getClientNotes(String token, int clientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clients/$clientId/notes'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching client notes: $e');
      return [];
    }
  }

  /// Add a note to a client
  static Future<Map<String, dynamic>?> addClientNote({
    required String token,
    required int clientId,
    required String noteText,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clients/$clientId/notes'),
        headers: _getHeaders(token),
        body: json.encode({'note_text': noteText}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error adding client note: $e');
      return null;
    }
  }

  /// Update a note
  static Future<bool> updateClientNote({
    required String token,
    required int noteId,
    required String noteText,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/clients/notes/$noteId'),
        headers: _getHeaders(token),
        body: json.encode({'note_text': noteText}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating client note: $e');
      return false;
    }
  }

  /// Delete a note
  static Future<bool> deleteClientNote(String token, int noteId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/clients/notes/$noteId'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting client note: $e');
      return false;
    }
  }

  // ============================================================
  // CLIENT PROPOSALS
  // ============================================================

  /// Get proposals linked to a client
  static Future<List<dynamic>> getClientProposals(String token, int clientId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clients/$clientId/proposals'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('Error fetching client proposals: $e');
      return [];
    }
  }

  /// Link a proposal to a client
  static Future<bool> linkProposal({
    required String token,
    required int clientId,
    required int proposalId,
    String relationshipType = 'primary',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clients/$clientId/proposals'),
        headers: _getHeaders(token),
        body: json.encode({
          'proposal_id': proposalId,
          'relationship_type': relationshipType,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error linking proposal: $e');
      return false;
    }
  }

  /// Unlink a proposal from a client
  static Future<bool> unlinkProposal({
    required String token,
    required int clientId,
    required int proposalId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/clients/$clientId/proposals/$proposalId'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error unlinking proposal: $e');
      return false;
    }
  }
}


