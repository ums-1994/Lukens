import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VersioningService extends ChangeNotifier {
  static const String baseUrl = 'http://localhost:8000';

  List<ProposalVersion> _versions = [];
  bool _isLoading = false;
  String? _lastError;

  // Getters
  List<ProposalVersion> get versions => _versions;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// Load all versions for a proposal
  Future<void> loadVersions(String proposalId) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/proposals/$proposalId/versions'),
        headers: {
          'Content-Type': 'application/json',
          // Remove Authorization header since backend doesn't require it for version endpoints
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _versions = (data['versions'] as List)
            .map((v) => ProposalVersion.fromJson(v))
            .toList();
        _lastError = null;
      } else {
        _lastError = 'Failed to load versions';
      }
    } catch (e) {
      _lastError = 'Error loading versions: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new version
  Future<ProposalVersion?> createVersion(
    String proposalId, {
    required String title,
    required Map<String, dynamic> sections,
    String? description,
    bool isMajor = false,
  }) async {
    try {
      print('Creating version for proposal: $proposalId');
      print('Version title: $title');

      final response = await http.post(
        Uri.parse('$baseUrl/proposals/$proposalId/versions'),
        headers: {
          'Content-Type': 'application/json',
          // Remove Authorization header since backend doesn't require it for version endpoints
        },
        body: json.encode({
          'title': title,
          'sections': sections,
          'description': description ?? '',
          'is_major': isMajor,
          'created_by': 'mock-user-id',
        }),
      );

      print(
          'Version creation response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newVersion = ProposalVersion.fromJson(data);
        _versions.insert(0, newVersion);
        notifyListeners();
        return newVersion;
      } else {
        _lastError = 'Failed to create version';
        return null;
      }
    } catch (e) {
      _lastError = 'Error creating version: $e';
      return null;
    }
  }

  /// Restore a version
  Future<bool> restoreVersion(String proposalId, String versionId) async {
    try {
      final user = await _getCurrentUser();
      if (user == null) {
        _lastError = 'User not authenticated';
        return false;
      }

      final token = await user.getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/proposals/$proposalId/versions/$versionId/restore'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Reload versions to get updated data
        await loadVersions(proposalId);
        return true;
      } else {
        _lastError = 'Failed to restore version';
        return false;
      }
    } catch (e) {
      _lastError = 'Error restoring version: $e';
      return false;
    }
  }

  /// Delete a version
  Future<bool> deleteVersion(String proposalId, String versionId) async {
    try {
      final user = await _getCurrentUser();
      if (user == null) {
        _lastError = 'User not authenticated';
        return false;
      }

      final token = await user.getIdToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/proposals/$proposalId/versions/$versionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _versions.removeWhere((v) => v.id == versionId);
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to delete version';
        return false;
      }
    } catch (e) {
      _lastError = 'Error deleting version: $e';
      return false;
    }
  }

  /// Compare two versions using backend diff endpoint
  Future<List<VersionDiff>> compareVersions(
      String versionId1, String versionId2) async {
    try {
      final version1 = _versions.firstWhere((v) => v.id == versionId1);
      final response = await http.get(
        Uri.parse(
            '$baseUrl/proposals/${version1.proposalId}/versions/diff?from=$versionId1&to=$versionId2'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final diffs = <VersionDiff>[];

        // Process added changes
        for (final item in data['added'] as List) {
          diffs.add(VersionDiff(
            section: item.toString(),
            oldContent: '',
            newContent: 'Added',
            changeType: ChangeType.added,
          ));
        }

        // Process modified changes
        for (final item in data['modified'] as List) {
          diffs.add(VersionDiff(
            section: item.toString(),
            oldContent: 'Previous content',
            newContent: 'Updated content',
            changeType: ChangeType.modified,
          ));
        }

        // Process removed changes
        for (final item in data['removed'] as List) {
          diffs.add(VersionDiff(
            section: item.toString(),
            oldContent: 'Removed content',
            newContent: '',
            changeType: ChangeType.removed,
          ));
        }

        return diffs;
      } else {
        _lastError = 'Failed to get version diff';
        return [];
      }
    } catch (e) {
      _lastError = 'Error comparing versions: $e';
      return [];
    }
  }

  /// Get current user (implement based on your auth system)
  Future<dynamic> _getCurrentUser() async {
    // For now, return a mock user for testing
    // In production, this should integrate with your actual auth system
    return MockUser();
  }
}

// Mock user class for testing versioning functionality
class MockUser {
  String get uid => 'mock-user-id';
  Future<String> getIdToken() async => 'mock-token';
}

class ProposalVersion {
  final String id;
  final String proposalId;
  final String title;
  final String description;
  final Map<String, dynamic> sections;
  final bool isMajor;
  final String createdBy;
  final DateTime createdAt;
  final String? restoredFrom;

  ProposalVersion({
    required this.id,
    required this.proposalId,
    required this.title,
    required this.description,
    required this.sections,
    required this.isMajor,
    required this.createdBy,
    required this.createdAt,
    this.restoredFrom,
  });

  factory ProposalVersion.fromJson(Map<String, dynamic> json) {
    return ProposalVersion(
      id: json['id'],
      proposalId: json['proposal_id'],
      title: json['title'] ?? 'Version ${json['version_number']}',
      description: json['description'] ?? 'Auto-saved version',
      sections:
          Map<String, dynamic>.from(json['sections'] ?? json['content'] ?? {}),
      isMajor: json['is_major'] ?? false,
      createdBy: json['created_by'] ?? 'system',
      createdAt: DateTime.parse(json['created_at']),
      restoredFrom: json['restored_from'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proposal_id': proposalId,
      'title': title,
      'description': description,
      'sections': sections,
      'is_major': isMajor,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'restored_from': restoredFrom,
    };
  }

  String get versionNumber {
    // This would be calculated based on major/minor versioning
    return isMajor
        ? 'v${createdAt.millisecondsSinceEpoch}'
        : 'v${createdAt.millisecondsSinceEpoch}.1';
  }

  String get displayTitle {
    return '$title (${versionNumber})';
  }
}

class VersionDiff {
  final String section;
  final String oldContent;
  final String newContent;
  final ChangeType changeType;

  VersionDiff({
    required this.section,
    required this.oldContent,
    required this.newContent,
    required this.changeType,
  });
}

enum ChangeType {
  added,
  removed,
  modified,
}
