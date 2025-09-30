import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TemplateService {
  static const String _templatesKey = 'custom_templates';

  /// Save a custom template to local storage
  static Future<bool> saveTemplate(Map<String, dynamic> templateData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingTemplates = await getCustomTemplates();

      // Add the new template
      existingTemplates.add(templateData);

      // Save back to storage
      final templatesJson = jsonEncode(existingTemplates);
      await prefs.setString(_templatesKey, templatesJson);

      return true;
    } catch (e) {
      print('Error saving template: $e');
      return false;
    }
  }

  /// Get all custom templates from local storage
  static Future<List<Map<String, dynamic>>> getCustomTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final templatesJson = prefs.getString(_templatesKey);

      if (templatesJson == null) {
        return [];
      }

      final List<dynamic> templatesList = jsonDecode(templatesJson);
      return templatesList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading templates: $e');
      return [];
    }
  }

  /// Get a specific template by ID
  static Future<Map<String, dynamic>?> getTemplateById(String id) async {
    try {
      final templates = await getCustomTemplates();
      return templates.firstWhere(
        (template) => template['id'] == id,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      print('Error getting template by ID: $e');
      return null;
    }
  }

  /// Update an existing template
  static Future<bool> updateTemplate(
      String id, Map<String, dynamic> updatedData) async {
    try {
      final templates = await getCustomTemplates();
      final index = templates.indexWhere((template) => template['id'] == id);

      if (index == -1) {
        return false;
      }

      templates[index] = updatedData;

      final prefs = await SharedPreferences.getInstance();
      final templatesJson = jsonEncode(templates);
      await prefs.setString(_templatesKey, templatesJson);

      return true;
    } catch (e) {
      print('Error updating template: $e');
      return false;
    }
  }

  /// Delete a template
  static Future<bool> deleteTemplate(String id) async {
    try {
      final templates = await getCustomTemplates();
      templates.removeWhere((template) => template['id'] == id);

      final prefs = await SharedPreferences.getInstance();
      final templatesJson = jsonEncode(templates);
      await prefs.setString(_templatesKey, templatesJson);

      return true;
    } catch (e) {
      print('Error deleting template: $e');
      return false;
    }
  }

  /// Search templates by name or description
  static Future<List<Map<String, dynamic>>> searchTemplates(
      String query) async {
    try {
      final templates = await getCustomTemplates();
      final lowercaseQuery = query.toLowerCase();

      return templates.where((template) {
        final name = template['name']?.toString().toLowerCase() ?? '';
        final description =
            template['description']?.toString().toLowerCase() ?? '';
        final category = template['category']?.toString().toLowerCase() ?? '';

        return name.contains(lowercaseQuery) ||
            description.contains(lowercaseQuery) ||
            category.contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      print('Error searching templates: $e');
      return [];
    }
  }

  /// Get templates by category
  static Future<List<Map<String, dynamic>>> getTemplatesByCategory(
      String category) async {
    try {
      final templates = await getCustomTemplates();
      return templates
          .where((template) => template['category'] == category)
          .toList();
    } catch (e) {
      print('Error getting templates by category: $e');
      return [];
    }
  }

  /// Clear all custom templates
  static Future<bool> clearAllTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_templatesKey);
      return true;
    } catch (e) {
      print('Error clearing templates: $e');
      return false;
    }
  }
}

