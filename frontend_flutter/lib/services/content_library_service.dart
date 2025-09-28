import 'dart:convert';
import 'package:http/http.dart' as http;

class ContentLibraryService {
  static const String baseUrl = "http://127.0.0.1:8000";

  Map<String, String> _getHeaders({String? authToken}) {
    final headers = <String, String>{"Content-Type": "application/json"};
    if (authToken != null && authToken.isNotEmpty) {
      headers["Authorization"] = "Bearer $authToken";
    }
    return headers;
  }

  // Get content types as list of maps with id/name (derived from modules)
  Future<List<Map<String, dynamic>>> getContentTypes(
      {String? authToken}) async {
    final modules = await getContentModules(authToken: authToken);
    final types = <String>{};
    for (final m in modules) {
      final ct = (m['content_type'] ?? '').toString();
      if (ct.isNotEmpty) types.add(ct);
    }
    if (types.isEmpty) {
      final defaults = [
        'Company Profile',
        'Team Bio',
        'Legal / Terms',
        'Proposal Module',
        'Services',
        'Case Study',
      ];
      return defaults.map((n) => {"id": n, "name": n}).toList();
    }
    return types.map((n) => {"id": n, "name": n}).toList();
  }

  // Get content modules with filters
  Future<List<Map<String, dynamic>>> getContentModules({
    String? contentType,
    String? search,
    List<String>? tags,
    String? authToken,
  }) async {
    try {
      // Fetch all from Flask and filter locally to handle legacy categories
      final uri = Uri.parse("$baseUrl/api/modules/");
      final response = await http.get(
        uri,
        headers: _getHeaders(authToken: authToken),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        var modules = data.map<Map<String, dynamic>>((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          final category = (m['category'] ?? '').toString();
          return {
            'id': m['id']?.toString() ?? '',
            'title': m['title'] ?? '',
            'content_type':
                category, // Use the actual category name instead of slug
            'content': (m['body'] ?? '').toString(),
            'is_editable': m['is_editable'] ?? true,
            'tags': <String>[],
            'created_by': m['created_by']?.toString() ?? 'system',
            'created_at': m['created_at']?.toString() ?? '',
            'updated_at': m['updated_at']?.toString() ?? '',
          };
        }).toList();

        if (contentType != null && contentType.isNotEmpty) {
          modules = modules
              .where((m) => (m['content_type'] as String) == contentType)
              .toList();
        }
        if (search != null && search.isNotEmpty) {
          final q = search.toLowerCase();
          modules = modules
              .where((m) =>
                  (m['title'] as String).toLowerCase().contains(q) ||
                  (m['content'] as String).toLowerCase().contains(q))
              .toList();
        }
        return modules;
      }
      throw Exception('Failed to load content modules: ${response.statusCode}');
    } catch (_) {
      return [];
    }
  }

  // Update content module (returns updated module or null)
  Future<Map<String, dynamic>?> updateContentModule({
    required String moduleId,
    required String title,
    required String content,
    required List<String> tags,
    String? authToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'body': content,
      };
      final response = await http.put(
        Uri.parse("$baseUrl/api/modules/$moduleId"),
        headers: _getHeaders(authToken: authToken),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception(
          'Failed to update content module: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // Create content module
  Future<Map<String, dynamic>> createContentModule({
    required String title,
    required String contentType,
    required String content,
    required List<String> tags,
    String? authToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'category': contentType,
        'body': content,
        'is_editable': true,
      };
      final response = await http.post(
        Uri.parse("$baseUrl/api/modules/"),
        headers: _getHeaders(authToken: authToken),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'id': (data['id'] ?? '').toString(),
          'title': title,
          'content_type': contentType,
          'content': content,
          'tags': tags,
        };
      }
      throw Exception(
          'Failed to create content module: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  // Delete content module
  Future<bool> deleteContentModule({
    required String moduleId,
    String? authToken,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/api/modules/$moduleId"),
        headers: _getHeaders(authToken: authToken),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }
}
