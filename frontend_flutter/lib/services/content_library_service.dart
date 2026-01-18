import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../config/api_config.dart';

class ContentLibraryService {
  static String get baseUrl => ApiConfig.backendBaseUrl;

  // Get headers with authentication
  Map<String, String> _getHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Get headers for multipart requests
  Map<String, String> _getMultipartHeaders({String? token}) {
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Get all content modules from the content library
  Future<List<Map<String, dynamic>>> getContentModules({
    String? category,
    String? token,
  }) async {
    try {
      String url = '${ApiConfig.backendBaseUrl}/api/content';
      if (category != null && category.isNotEmpty) {
        url += '?category=$category';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(token: token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Backend returns {'content': [array]} format
        final List<dynamic> data =
            responseData is Map && responseData.containsKey('content')
                ? responseData['content']
                : (responseData is List ? responseData : []);

        return data
            .map((item) => {
                  'id': item['id'],
                  'key': item['key'],
                  'title': item['label'] ?? item['key'],
                  'label': item['label'] ?? item['key'],
                  'content': item['content'] ?? '',
                  'category': item['category'] ?? 'Templates',
                  'is_folder': item['is_folder'] ?? false,
                  'parent_id': item['parent_id'],
                  'public_id': item['public_id'],
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

  // Get a specific content module by ID
  Future<Map<String, dynamic>?> getContentModule(int contentId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/content/$contentId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'id': data['id'],
          'key': data['key'],
          'title': data['label'] ?? data['key'],
          'label': data['label'] ?? data['key'],
          'content': data['content'] ?? '',
          'category': data['category'] ?? 'Templates',
          'is_folder': data['is_folder'] ?? false,
          'parent_id': data['parent_id'],
          'public_id': data['public_id'],
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

  // Create a new content module
  Future<Map<String, dynamic>?> createContentModule({
    required String key,
    required String label,
    String content = '',
    String category = 'Templates',
    bool isFolder = false,
    int? parentId,
    String? publicId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/content'),
        headers: _getHeaders(),
        body: json.encode({
          'key': key,
          'label': label,
          'content': content,
          'category': category,
          'is_folder': isFolder,
          'parent_id': parentId,
          'public_id': publicId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating content module: $e');
      return null;
    }
  }

  // Update an existing content module
  Future<bool> updateContentModule({
    required int contentId,
    String? label,
    String? content,
    String? category,
    String? publicId,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (label != null) body['label'] = label;
      if (content != null) body['content'] = content;
      if (category != null) body['category'] = category;
      if (publicId != null) body['public_id'] = publicId;

      final response = await http.put(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/content/$contentId'),
        headers: _getHeaders(),
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating content module: $e');
      return false;
    }
  }

  // Delete a content module
  Future<bool> deleteContentModule(int contentId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.backendBaseUrl}/api/content/$contentId'),
        headers: _getHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting content module: $e');
      return false;
    }
  }

  // Upload a document file (DOCX, PDF, etc.) to Cloudinary
  Future<Map<String, dynamic>?> uploadDocument({
    required Uint8List fileBytes,
    required String fileName,
    String? token,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.backendBaseUrl}/upload/template'),
      );

      // Add authentication headers
      request.headers.addAll(_getMultipartHeaders(token: token));

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'url': data['url'],
          'public_id': data['public_id'],
          'filename': data['filename'] ?? fileName,
          'size': data['size'],
        };
      } else {
        print('Upload failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading document: $e');
      return null;
    }
  }

  // Upload image file
  Future<Map<String, dynamic>?> uploadImage({
    required Uint8List fileBytes,
    required String fileName,
    String? token,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.backendBaseUrl}/upload/image'),
      );

      // Add authentication headers
      request.headers.addAll(_getMultipartHeaders(token: token));

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'url': data['url'],
          'public_id': data['public_id'],
          'filename': data['filename'] ?? fileName,
          'size': data['size'],
        };
      } else {
        print('Upload failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Upload document and create content block in one operation
  Future<Map<String, dynamic>?> uploadAndCreateContent({
    required Uint8List fileBytes,
    required String fileName,
    required String label,
    String category = 'Documents',
    int? parentId,
  }) async {
    try {
      // First, upload the file to Cloudinary
      final uploadResult = await uploadDocument(
        fileBytes: fileBytes,
        fileName: fileName,
      );

      if (uploadResult == null || uploadResult['success'] != true) {
        print('File upload failed');
        return null;
      }

      // Then, create a content block with the file reference
      final key = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final contentResult = await createContentModule(
        key: key,
        label: label,
        content: uploadResult['url'] ?? '',
        category: category,
        publicId: uploadResult['public_id'],
        parentId: parentId,
      );

      if (contentResult != null) {
        return {
          'success': true,
          'content_id': contentResult['id'],
          'url': uploadResult['url'],
          'public_id': uploadResult['public_id'],
          'label': label,
        };
      }

      return null;
    } catch (e) {
      print('Error uploading and creating content: $e');
      return null;
    }
  }
}
