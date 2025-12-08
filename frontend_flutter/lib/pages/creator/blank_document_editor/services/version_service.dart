import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../../services/api_service.dart';
import '../../../../document_editor/models/document_section.dart';
import '../../../../document_editor/models/inline_image.dart';
import '../../../../document_editor/models/document_table.dart';

/// Service for managing document versions
class VersionService {
  /// Create a version snapshot
  static Map<String, dynamic> createVersionSnapshot({
    required int versionNumber,
    required String title,
    required List<DocumentSection> sections,
    required String changeDescription,
    required String author,
    required String selectedCurrency,
    required int currentVersionNumber,
  }) {
    return {
      'version_number': versionNumber,
      'timestamp': DateTime.now().toIso8601String(),
      'title': title,
      'sections': sections
          .map((section) => {
                'title': section.titleController.text,
                'content': section.controller.text,
                'backgroundColor': section.backgroundColor.value,
                'backgroundImageUrl': section.backgroundImageUrl,
                'sectionType': section.sectionType,
                'isCoverPage': section.isCoverPage,
                'inlineImages':
                    section.inlineImages.map((img) => img.toJson()).toList(),
                'tables':
                    section.tables.map((table) => table.toJson()).toList(),
              })
          .toList(),
      'change_description': changeDescription,
      'author': author,
    };
  }

  /// Serialize document content for version storage
  static String serializeDocumentContent({
    required String title,
    required List<DocumentSection> sections,
    required String selectedCurrency,
    required int currentVersionNumber,
  }) {
    final documentData = {
      'title': title,
      'sections': sections
          .map((section) => {
                'title': section.titleController.text,
                'content': section.controller.text,
                'backgroundColor': section.backgroundColor.value,
                'backgroundImageUrl': section.backgroundImageUrl,
                'sectionType': section.sectionType,
                'isCoverPage': section.isCoverPage,
                'inlineImages':
                    section.inlineImages.map((img) => img.toJson()).toList(),
                'tables':
                    section.tables.map((table) => table.toJson()).toList(),
              })
          .toList(),
      'metadata': {
        'currency': selectedCurrency,
        'version': currentVersionNumber,
        'last_modified': DateTime.now().toIso8601String(),
      }
    };
    return json.encode(documentData);
  }

  /// Save version to database
  static Future<void> saveVersionToDatabase({
    required int proposalId,
    required int versionNumber,
    required String content,
    required String changeDescription,
    required String token,
  }) async {
    try {
      await ApiService.createVersion(
        token: token,
        proposalId: proposalId,
        versionNumber: versionNumber,
        content: content,
        changeDescription: changeDescription,
      );
      print('✅ Version $versionNumber saved to database');
    } catch (e) {
      print('⚠️ Error saving version to database: $e');
      rethrow;
    }
  }

  /// Restore sections from version data
  static List<DocumentSection> restoreSectionsFromVersion(
    List<dynamic> savedSections,
  ) {
    final sections = <DocumentSection>[];

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
            ?.map((img) => InlineImage.fromJson(img as Map<String, dynamic>))
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

    return sections;
  }
}

