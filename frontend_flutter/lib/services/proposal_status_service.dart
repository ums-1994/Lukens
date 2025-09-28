import 'dart:convert';
import 'package:http/http.dart' as http;

class ProposalStatusService {
  static const String baseUrl = 'http://localhost:8000';

  // Get proposal approval status
  static Future<Map<String, dynamic>?> getProposalStatus(
      String proposalId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/proposal-status/$proposalId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to get proposal status. Status: ${response.statusCode}');
        print('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error getting proposal status: $e');
      return null;
    }
  }

  // Get all proposals with their statuses
  static Future<List<Map<String, dynamic>>> getAllProposalsStatus() async {
    try {
      // This would typically come from a list of proposal IDs
      // For now, we'll return a mock list
      return [
        {
          'proposal_id': 'sample-1',
          'title': 'Sample Proposal 1',
          'client': 'ABC Company',
          'status': 'pending',
          'is_approved': false,
        },
        {
          'proposal_id': 'sample-2',
          'title': 'Sample Proposal 2',
          'client': 'XYZ Corp',
          'status': 'approved',
          'is_approved': true,
          'signed_by': 'John Doe',
          'signed_at': '2023-10-25T14:30:00',
        },
      ];
    } catch (e) {
      print('Error getting all proposals status: $e');
      return [];
    }
  }
}
