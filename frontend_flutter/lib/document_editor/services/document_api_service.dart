import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lightweight API helper for document editor operations.
///
/// This keeps HTTP details out of the widget tree. Callers are responsible
/// for passing auth tokens and updating UI state.
class DocumentApiService {
  DocumentApiService._();

  static const String _baseUrl = 'http://localhost:8000';

  /// Fetch collaborators for a given proposal.
  static Future<List<Map<String, dynamic>>> fetchCollaborators({
    required String token,
    required int proposalId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/proposals/$proposalId/collaborators'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
    }

    throw http.ClientException(
      'Failed to load collaborators: ${response.statusCode}',
    );
  }

  /// Remove a collaborator invitation by id.
  static Future<void> removeCollaborator({
    required String token,
    required int invitationId,
  }) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/collaborations/$invitationId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Failed to remove collaborator: ${response.statusCode}',
      );
    }
  }
}
