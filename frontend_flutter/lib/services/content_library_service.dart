import 'dart:convert';
import 'package:http/http.dart' as http;

class ContentLibraryService {
  static const String baseUrl = 'http://localhost:8000';

  // Get headers
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
    };
  }

  // Get all content modules from the content library
  Future<List<Map<String, dynamic>>> getContentModules() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content-blocks'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => {
                  'id': item['id'],
                  'key': item['key'],
                  'title': item['label'] ?? item['key'],
                  'content': item['content'] ?? '',
                  'created_at': item['created_at'],
                  'updated_at': item['updated_at'],
                })
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching content modules: $e');
      return [];
    }
  }

  // Get a specific content module by key
  Future<Map<String, dynamic>?> getContentModule(String key) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content-blocks/$key'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'id': data['id'],
          'key': data['key'],
          'title': data['label'] ?? data['key'],
          'content': data['content'] ?? '',
          'created_at': data['created_at'],
          'updated_at': data['updated_at'],
        };
      }
      return null;
    } catch (e) {
      print('Error fetching content module: $e');
      return null;
    }
  }

  // Create or update a content module
  Future<bool> saveContentModule({
    required String key,
    required String label,
    required String content,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/content-blocks/$key'),
        headers: _getHeaders(),
        body: json.encode({
          'key': key,
          'label': label,
          'content': content,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error saving content module: $e');
      return false;
    }
  }

  // Delete a content module
  Future<bool> deleteContentModule(String key) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/content-blocks/$key'),
        headers: _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting content module: $e');
      return false;
    }
  }
}
