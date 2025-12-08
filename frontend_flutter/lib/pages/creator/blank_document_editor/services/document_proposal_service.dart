import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../services/api_service.dart';
import '../../../../document_editor/models/document_section.dart';
import '../../../../document_editor/models/inline_image.dart';
import '../../../../document_editor/models/document_table.dart';

/// Service for handling document proposal API operations
class DocumentProposalService {
  /// Load proposal from database
  static Future<Map<String, dynamic>?> loadProposalFromDatabase(
    int proposalId,
    String token,
  ) async {
    try {
      print('🔄 Loading proposal content for ID $proposalId...');

      // Get all proposals and find the one we need
      final proposals = await ApiService.getProposals(token);
      final proposal = proposals.firstWhere(
        (p) => p['id'] == proposalId,
        orElse: () => <String, dynamic>{},
      );

      if (proposal.isEmpty) {
        print('⚠️ Proposal $proposalId not found');
        return null;
      }

      return proposal;
    } catch (e) {
      print('⚠️ Error loading proposal: $e');
      return null;
    }
  }

  /// Parse proposal content into sections
  static List<DocumentSection> parseProposalSections(
    Map<String, dynamic> proposal,
  ) {
    final sections = <DocumentSection>[];

    if (proposal['content'] != null) {
      try {
        final contentData = json.decode(proposal['content']);
        final List<dynamic> savedSections = contentData['sections'] ?? [];

        for (var sectionData in savedSections) {
          final newSection = DocumentSection(
            title: sectionData['title'] ?? 'Untitled Section',
            content: sectionData['content'] ?? '',
            backgroundColor: sectionData['backgroundColor'] != null
                ? Color(sectionData['backgroundColor'] as int)
                : Colors.white,
            backgroundImageUrl: sectionData['backgroundImageUrl'] as String?,
            sectionType: sectionData['sectionType'] as String? ?? 'content',
            isCoverPage: sectionData['isCoverPage'] as bool? ?? false,
            inlineImages: (sectionData['inlineImages'] as List<dynamic>?)
                ?.map(
                    (img) => InlineImage.fromJson(img as Map<String, dynamic>))
                .toList(),
            tables: (sectionData['tables'] as List<dynamic>?)?.map((tableData) {
                  try {
                    return tableData is Map<String, dynamic>
                        ? DocumentTable.fromJson(tableData)
                        : DocumentTable.fromJson(
                            Map<String, dynamic>.from(tableData as Map));
                  } catch (e) {
                    print('⚠️ Error loading table: $e');
                    return DocumentTable();
                  }
                }).toList() ??
                [],
          );
          sections.add(newSection);
        }
      } catch (e) {
        print('⚠️ Error parsing proposal content: $e');
      }
    }

    return sections;
  }

  /// Load versions from database
  static Future<List<Map<String, dynamic>>> loadVersionsFromDatabase(
    int proposalId,
    String token,
  ) async {
    try {
      print('🔄 Loading versions for proposal $proposalId...');
      final versions = await ApiService.getVersions(
        token: token,
        proposalId: proposalId,
      );

      final versionHistory = <Map<String, dynamic>>[];
      for (var version in versions.reversed) {
        try {
          final contentMap = json.decode(version['content']);
          versionHistory.add({
            'version_number': version['version_number'],
            'timestamp': version['created_at'],
            'title': contentMap['title'] ?? '',
            'sections': contentMap['sections'] ?? [],
            'change_description': version['change_description'],
            'author': version['created_by_name'] ??
                version['created_by_email'] ??
                'User #${version['created_by']}',
          });
        } catch (e) {
          print('⚠️ Error parsing version content: $e');
        }
      }

      print('✅ Loaded ${versions.length} versions');
      return versionHistory;
    } catch (e) {
      print('⚠️ Error loading versions: $e');
      return [];
    }
  }

  /// Load comments from database
  static Future<Map<String, dynamic>?> loadCommentsFromDatabase(
    int proposalId,
    String token,
    String? statusFilter,
  ) async {
    try {
      print('🔄 Loading comments for proposal $proposalId...');
      final response = await ApiService.getComments(
        token: token,
        proposalId: proposalId,
        status: statusFilter == 'all' ? null : statusFilter,
      );

      if (response == null) {
        print('⚠️ No response from comments API');
        return null;
      }

      return response;
    } catch (e) {
      print('⚠️ Error loading comments: $e');
      return null;
    }
  }

  /// Load collaborators
  static Future<List<Map<String, dynamic>>> loadCollaborators(
    int proposalId,
    String token,
  ) async {
    try {
      print('🔄 Loading collaborators for proposal $proposalId...');
      final response = await http.get(
        Uri.parse(
            '${ApiService.baseUrl}/api/proposals/$proposalId/collaborators'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> collaborators = jsonDecode(response.body);
        final result = <Map<String, dynamic>>[];

        for (var collab in collaborators) {
          final email = collab['invited_email'] ?? collab['email'] ?? '';
          if (email.isEmpty) {
            print('⚠️ Skipping collaborator without email: ${collab['id']}');
            continue;
          }

          final invitedAt = collab['invited_at'] ?? collab['joined_at'];
          final accessedAt =
              collab['accessed_at'] ?? collab['last_accessed_at'];

          result.add({
            'id': collab['id'],
            'email': email,
            'name': email.split('@')[0],
            'role': 'Full Access',
            'status': collab['status'] ?? 'pending',
            'invited_at': invitedAt,
            'accessed_at': accessedAt,
          });
        }

        print('✅ Loaded ${result.length} collaborators');
        return result;
      } else {
        print(
            '⚠️ Failed to load collaborators: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('⚠️ Error loading collaborators: $e');
      return [];
    }
  }

  /// Remove collaborator
  static Future<bool> removeCollaborator(
    int invitationId,
    String token,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/collaborations/$invitationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ Error removing collaborator: $e');
      return false;
    }
  }

  /// Load library images
  static Future<List<Map<String, dynamic>>> loadLibraryImages(
    String token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/content?category=Images'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> content = data is Map && data.containsKey('content')
            ? data['content']
            : (data is List ? data : []);

        final result = content
            .map((item) => {
                  'id': item['id'],
                  'label': item['label'] ?? 'Untitled',
                  'content': item['content'] ?? '',
                  'public_id': item['public_id'],
                })
            .toList();

        print('✅ Loaded ${result.length} images from library');
        return result;
      } else {
        print('⚠️ Failed to load library images: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error loading library images: $e');
      return [];
    }
  }

  /// Load mention suggestions
  static Future<List<Map<String, dynamic>>> loadMentionSuggestions(
    String query,
    String token,
    int? proposalId,
  ) async {
    try {
      final results = await ApiService.searchUsers(
        authToken: token,
        query: query,
        proposalId: proposalId,
      );

      final suggestions = results
          .map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            }
            if (item is Map) {
              return item.cast<String, dynamic>();
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .where((user) =>
              (user['username']?.toString().isNotEmpty ?? false) ||
              (user['email']?.toString().isNotEmpty ?? false))
          .toList();

      return suggestions;
    } catch (e) {
      print('⚠️ Error loading mention suggestions: $e');
      return [];
    }
  }

  /// Save proposal to backend
  static Future<Map<String, dynamic>?> saveToBackend({
    required String token,
    required String title,
    required String content,
    String? clientName,
    String? clientEmail,
    String? status,
    int? existingProposalId,
  }) async {
    try {
      if (existingProposalId == null) {
        // Create new proposal
        print('📝 Creating new proposal...');
        final result = await ApiService.createProposal(
          token: token,
          title: title,
          content: content,
          clientName: clientName,
          clientEmail: clientEmail,
          status: status ?? 'draft',
        );

        print('🔍 Create proposal result: $result');
        return result;
      } else {
        // Update existing proposal
        print('🔄 Updating existing proposal ID: $existingProposalId...');
        final result = await ApiService.updateProposal(
          token: token,
          id: existingProposalId,
          title: title,
          content: content,
          clientName: clientName,
          clientEmail: clientEmail,
          status: status ?? 'draft',
        );
        print('✅ Proposal updated: $existingProposalId');
        return result;
      }
    } catch (e) {
      print('❌ Error saving to backend: $e');
      rethrow;
    }
  }

  /// Send proposal for approval
  static Future<Map<String, dynamic>?> sendForApproval(
    int proposalId,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${ApiService.baseUrl}/api/proposals/$proposalId/send-for-approval'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send for approval');
      }
    } catch (e) {
      print('❌ Error sending for approval: $e');
      rethrow;
    }
  }

  /// Archive proposal
  static Future<Map<String, dynamic>?> archiveProposal(
    int proposalId,
    String token,
  ) async {
    try {
      return await ApiService.archiveProposal(
        token: token,
        proposalId: proposalId,
      );
    } catch (e) {
      print('⚠️ Error archiving proposal: $e');
      rethrow;
    }
  }

  /// Restore proposal
  static Future<Map<String, dynamic>?> restoreProposal(
    int proposalId,
    String token,
  ) async {
    try {
      return await ApiService.restoreProposal(
        token: token,
        proposalId: proposalId,
      );
    } catch (e) {
      print('⚠️ Error restoring proposal: $e');
      rethrow;
    }
  }
}
