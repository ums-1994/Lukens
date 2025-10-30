import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'services/auth_service.dart';

const String baseUrl = "http://localhost:8000";

class AppState extends ChangeNotifier {
  List<dynamic> templates = [];
  List<dynamic> contentBlocks = [];
  List<dynamic> proposals = [];
  Map<String, dynamic>? currentProposal;
  Map<String, dynamic> dashboardCounts = {};

  Future<void> init() async {
    // IMPORTANT: Sync token from AuthService on startup
    if (AuthService.token != null && AuthService.currentUser != null) {
      authToken = AuthService.token;
      currentUser = AuthService.currentUser;
      print('✅ Synced token from AuthService on startup');
    }

    // Only fetch data if user is authenticated
    if (authToken != null) {
      await Future.wait([
        fetchTemplates(),
        fetchContent(),
        fetchProposals(),
        fetchDashboard()
      ]);
    }
    notifyListeners();
  }

  Map<String, String> get _headers {
    final headers = {"Content-Type": "application/json"};
    // Use authToken (synced from AuthService) for consistency
    if (authToken != null) {
      headers["Authorization"] = "Bearer $authToken";
    }
    return headers;
  }

  // Headers for multipart/form-data requests (file uploads)
  // Don't include Content-Type - it's set automatically by MultipartRequest
  Map<String, String> get _multipartHeaders {
    final headers = <String, String>{};
    // Use authToken (synced from AuthService) for consistency
    if (authToken != null) {
      headers["Authorization"] = "Bearer $authToken";
    }
    return headers;
  }

  Future<void> fetchTemplates() async {
    // For now, return empty templates since backend doesn't have this endpoint yet
    templates = [];
  }

  Future<void> fetchContent() async {
    try {
      final r = await http.get(
        Uri.parse("$baseUrl/content"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        // Handle both array response and object with 'content' key
        if (data is List) {
          contentBlocks = data;
        } else if (data is Map && data.containsKey('content')) {
          contentBlocks = List<dynamic>.from(data['content']);
        } else {
          contentBlocks = [];
        }
      } else {
        print('Error fetching content: ${r.statusCode} - ${r.body}');
        contentBlocks = [];
      }
    } catch (e) {
      print('Error fetching content: $e');
      contentBlocks = [];
    }
  }

  Future<List<dynamic>> fetchTrash() async {
    try {
      final r = await http.get(
        Uri.parse("$baseUrl/content/trash"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data is List) {
          return data;
        }
      } else {
        print('Error fetching trash: ${r.statusCode} - ${r.body}');
      }
    } catch (e) {
      print('Error fetching trash: $e');
    }
    return [];
  }

  Future<bool> restoreContent(int contentId) async {
    try {
      final r = await http.post(
        Uri.parse("$baseUrl/content/$contentId/restore"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        await fetchContent();
        notifyListeners();
        return true;
      } else {
        print('Error restoring content: ${r.statusCode} - ${r.body}');
        return false;
      }
    } catch (e) {
      print('Error restoring content: $e');
      return false;
    }
  }

  Future<bool> deleteContent(int contentId) async {
    try {
      final r = await http.delete(
        Uri.parse("$baseUrl/content/$contentId"),
        headers: _headers,
      );
      if (r.statusCode == 200 || r.statusCode == 204) {
        await fetchContent();
        notifyListeners();
        return true;
      } else {
        print('Error deleting content: ${r.statusCode} - ${r.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting content: $e');
      return false;
    }
  }

  Future<bool> createContent({
    required String key,
    required String label,
    String content = "",
    String category = "Templates",
    bool isFolder = false,
    int? parentId,
    String? publicId,
  }) async {
    try {
      final body = {
        "key": key,
        "label": label,
        "content": content,
        "category": category,
        "is_folder": isFolder,
        if (parentId != null) "parent_id": parentId,
        if (publicId != null) "public_id": publicId,
      };

      final r = await http.post(
        Uri.parse("$baseUrl/content"),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (r.statusCode == 200) {
        await fetchContent();
        notifyListeners();
        return true;
      } else {
        print('Error creating content: ${r.statusCode} - ${r.body}');
        return false;
      }
    } catch (e) {
      print('Error creating content: $e');
      return false;
    }
  }

  Future<bool> updateContent(
    int contentId, {
    String? label,
    String? content,
    String? category,
    String? publicId,
  }) async {
    try {
      final body = {
        if (label != null) "label": label,
        if (content != null) "content": content,
        if (category != null) "category": category,
        if (publicId != null) "public_id": publicId,
      };

      if (body.isEmpty) return false;

      final r = await http.put(
        Uri.parse("$baseUrl/content/$contentId"),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (r.statusCode == 200) {
        await fetchContent();
        notifyListeners();
        return true;
      } else {
        print('Error updating content: ${r.statusCode} - ${r.body}');
        return false;
      }
    } catch (e) {
      print('Error updating content: $e');
      return false;
    }
  }

  Future<bool> permanentlyDeleteContent(int contentId) async {
    try {
      final r = await http.delete(
        Uri.parse("$baseUrl/content/$contentId/permanent"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        return true;
      } else {
        print(
            'Error permanently deleting content: ${r.statusCode} - ${r.body}');
        return false;
      }
    } catch (e) {
      print('Error permanently deleting content: $e');
      return false;
    }
  }

  Future<void> fetchProposals() async {
    try {
      final r = await http.get(
        Uri.parse("$baseUrl/proposals"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        proposals = List<dynamic>.from(data);

        // Calculate dashboard counts from real data
        _updateDashboardCounts();
      } else {
        print('Error fetching proposals: ${r.statusCode} - ${r.body}');
        proposals = [];
      }
    } catch (e) {
      print('Error fetching proposals: $e');
      proposals = [];
    }
  }

  void _updateDashboardCounts() {
    final counts = <String, int>{};
    for (final proposal in proposals) {
      final status = proposal['status'] ?? 'Draft';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    dashboardCounts = counts;
  }

  Future<void> fetchDashboard() async {
    // Dashboard counts are now calculated from real proposal data in fetchProposals
    // This method is kept for compatibility but the real counts come from _updateDashboardCounts()
    if (proposals.isNotEmpty) {
      _updateDashboardCounts();
    }
  }

  Future<Map<String, dynamic>?> createProposal(String title, String client,
      {String? templateKey}) async {
    try {
      final r = await http.post(
        Uri.parse("$baseUrl/proposals"),
        headers: _headers,
        body: jsonEncode(
            {"title": title, "client": client, "template_key": templateKey}),
      );
      final p = jsonDecode(r.body);
      currentProposal = p;
      await fetchProposals();
      await fetchDashboard();
      notifyListeners();
      return p;
    } catch (e) {
      print('Error creating proposal: $e');
      return null;
    }
  }

  Future<void> updateProposal(
      String proposalId, Map<String, dynamic> data) async {
    try {
      final r = await http.put(
        Uri.parse("$baseUrl/proposals/$proposalId"),
        headers: _headers,
        body: jsonEncode(data),
      );
      if (r.statusCode == 200) {
        await fetchProposals();
        notifyListeners();
      }
    } catch (e) {
      print('Error updating proposal: $e');
    }
  }

  Future<void> updateProposalStatus(String proposalId, String status) async {
    try {
      final r = await http.patch(
        Uri.parse("$baseUrl/proposals/$proposalId/status"),
        headers: _headers,
        body: jsonEncode({"status": status}),
      );
      if (r.statusCode == 200) {
        await fetchProposals();
        notifyListeners();
      }
    } catch (e) {
      print('Error updating proposal status: $e');
    }
  }

  Future<List<dynamic>> getTemplates() async {
    try {
      final r = await http.get(
        Uri.parse("$baseUrl/templates"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['templates'] ?? [];
      }
    } catch (e) {
      print('Error fetching templates: $e');
    }
    return [];
  }

  Future<List<dynamic>> getContentModules() async {
    try {
      final r = await http.get(
        Uri.parse("$baseUrl/content-modules"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['modules'] ?? [];
      }
    } catch (e) {
      print('Error fetching content modules: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> analyzeProposalAI(
      Map<String, dynamic> proposalData) async {
    try {
      final r = await http.post(
        Uri.parse("$baseUrl/proposals/ai-analysis"),
        headers: _headers,
        body: jsonEncode(proposalData),
      );
      if (r.statusCode == 200) {
        return jsonDecode(r.body);
      }
    } catch (e) {
      print('Error analyzing proposal with AI: $e');
    }
    return null;
  }

  Future<void> updateSections(Map<String, dynamic> updates) async {
    if (currentProposal == null) return;
    final id = currentProposal!["id"];
    final r = await http.put(
      Uri.parse("$baseUrl/proposals/$id"),
      headers: _headers,
      body: jsonEncode({"sections": updates}),
    );
    currentProposal = jsonDecode(r.body);
    await fetchProposals();
    notifyListeners();
  }

  Future<String?> submitForReview() async {
    if (currentProposal == null) return "No proposal selected";
    final id = currentProposal!["id"];
    final r = await http.post(Uri.parse("$baseUrl/proposals/$id/submit"),
        headers: _headers);
    if (r.statusCode >= 400) {
      try {
        final data = jsonDecode(r.body);
        return data["detail"]["issues"].join("\n");
      } catch (_) {
        return "Readiness checks failed";
      }
    }
    currentProposal = jsonDecode(r.body);
    await fetchDashboard();
    notifyListeners();
    return null;
  }

  Future<void> approveStage(String stage) async {
    if (currentProposal == null) return;
    final id = currentProposal!["id"];
    final r = await http.post(
        Uri.parse("$baseUrl/proposals/$id/approve?stage=$stage"),
        headers: _headers);
    currentProposal = jsonDecode(r.body);
    await fetchDashboard();
    notifyListeners();
  }

  Future<String?> signOff(String signerName) async {
    if (currentProposal == null) return "No proposal selected";
    final id = currentProposal!["id"];
    final r = await http.post(
      Uri.parse("$baseUrl/proposals/$id/sign"),
      headers: _headers,
      body: jsonEncode({"signer_name": signerName}),
    );
    if (r.statusCode >= 400) {
      return "Sign-off failed (ensure status is Released).";
    }
    currentProposal = jsonDecode(r.body);
    await fetchDashboard();
    notifyListeners();
    return null;
  }

  // RBAC Methods
  Future<String?> approveProposal(String proposalId,
      {String comments = ""}) async {
    try {
      final r = await http.post(
        Uri.parse("$baseUrl/proposals/$proposalId/approve?comments=$comments"),
        headers: _headers,
      );
      if (r.statusCode >= 400) {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Approval failed";
      }
      await fetchProposals();
      await fetchDashboard();
      notifyListeners();
      return null;
    } catch (e) {
      return "Error approving proposal: $e";
    }
  }

  Future<String?> rejectProposal(String proposalId,
      {String comments = ""}) async {
    try {
      final r = await http.post(
        Uri.parse("$baseUrl/proposals/$proposalId/reject?comments=$comments"),
        headers: _headers,
      );
      if (r.statusCode >= 400) {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Rejection failed";
      }
      await fetchProposals();
      await fetchDashboard();
      notifyListeners();
      return null;
    } catch (e) {
      return "Error rejecting proposal: $e";
    }
  }

  Future<String?> sendToClient(String proposalId) async {
    try {
      final r = await http.post(
        Uri.parse("$baseUrl/proposals/$proposalId/send_to_client"),
        headers: _headers,
      );
      if (r.statusCode >= 400) {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Send to client failed";
      }
      await fetchProposals();
      await fetchDashboard();
      notifyListeners();
      return null;
    } catch (e) {
      return "Error sending to client: $e";
    }
  }

  Future<String?> clientDeclineProposal(String proposalId,
      {String comments = ""}) async {
    try {
      final r = await http.post(
        Uri.parse(
            "$baseUrl/proposals/$proposalId/client_decline?comments=$comments"),
        headers: _headers,
      );
      if (r.statusCode >= 400) {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Decline failed";
      }
      await fetchProposals();
      await fetchDashboard();
      notifyListeners();
      return null;
    } catch (e) {
      return "Error declining proposal: $e";
    }
  }

  Future<void> trackClientView(String proposalId) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/proposals/$proposalId/client_view"),
        headers: _headers,
      );
    } catch (e) {
      print('Error tracking client view: $e');
    }
  }

  Future<List<dynamic>> getPendingApprovals() async {
    try {
      final r = await http.get(
        Uri.parse("$baseUrl/proposals/pending_approval"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data["proposals"] ?? [];
      }
    } catch (e) {
      print('Error fetching pending approvals: $e');
    }
    return [];
  }

  Future<List<dynamic>> getMyProposals() async {
    try {
      final r = await http.get(
        Uri.parse("$baseUrl/proposals/my_proposals"),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data["proposals"] ?? [];
      }
    } catch (e) {
      print('Error fetching my proposals: $e');
    }
    return [];
  }

  Future<String?> requestEsign() async {
    if (currentProposal == null) return "No proposal selected";
    final id = currentProposal!["id"];
    final r = await http.post(
      Uri.parse("$baseUrl/proposals/$id/create_esign_request"),
      headers: _headers,
      body: jsonEncode({}),
    );
    if (r.statusCode >= 400) {
      try {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Failed to create e-sign request";
      } catch (_) {
        return "Failed to create e-sign request";
      }
    }
    final data = jsonDecode(r.body);
    return data["sign_url"] ?? "No URL returned";
  }

  // DocuSign: Send for signature using backend endpoint
  Future<Map<String, dynamic>?> sendProposalForSignature({
    required int proposalId,
    required String signerName,
    required String signerEmail,
    String? returnUrl,
  }) async {
    try {
      final body = {
        'signer_name': signerName,
        'signer_email': signerEmail,
        if (returnUrl != null) 'return_url': returnUrl,
      };
      final r = await http.post(
        Uri.parse("$baseUrl/api/proposals/$proposalId/docusign/send"),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (r.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(r.body));
      }
      debugPrint('DocuSign send failed: ${r.statusCode} - ${r.body}');
      return null;
    } catch (e) {
      debugPrint('DocuSign send error: $e');
      return null;
    }
  }

  void selectProposal(Map<String, dynamic> p) {
    currentProposal = p;
    notifyListeners();
  }

  Future<void> addContentToProposal(int contentId) async {
    // find block by id in cached contentBlocks and add its content to current proposal sections
    if (currentProposal == null) return;

    // Use where().isNotEmpty to safely find the block
    final matchingBlocks =
        contentBlocks.where((b) => b["id"] == contentId).toList();
    if (matchingBlocks.isEmpty) return;

    final block = matchingBlocks.first;
    // we'll add under the label name if missing; otherwise append
    final key = block["label"];
    final existing = currentProposal!["sections"] ?? {};
    final newText = (existing[key] ?? "") + "\\n" + block["content"];
    await updateSections({key: newText});
    await fetchContent();
  }

  // Client Portal methods
  List<dynamic> clientProposals = [];
  Map<String, dynamic> clientDashboardStats = {};

  Future<void> fetchClientProposals() async {
    final r = await http.get(Uri.parse("$baseUrl/client/proposals"),
        headers: _headers);
    clientProposals = jsonDecode(r.body);
    notifyListeners();
  }

  Future<void> fetchClientDashboardStats() async {
    final r = await http.get(Uri.parse("$baseUrl/client/dashboard_stats"),
        headers: _headers);
    clientDashboardStats = jsonDecode(r.body);
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getClientProposal(String proposalId) async {
    final r = await http.get(Uri.parse("$baseUrl/client/proposals/$proposalId"),
        headers: _headers);
    if (r.statusCode == 200) {
      return jsonDecode(r.body);
    }
    return null;
  }

  Future<String?> clientSignProposal(
      String proposalId, String signerName) async {
    final r = await http.post(
      Uri.parse("$baseUrl/client/proposals/$proposalId/sign"),
      headers: _headers,
      body: jsonEncode({"signer_name": signerName}),
    );
    if (r.statusCode >= 400) {
      try {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Failed to sign proposal";
      } catch (_) {
        return "Failed to sign proposal";
      }
    }
    await fetchClientProposals();
    await fetchClientDashboardStats();
    notifyListeners();
    return null;
  }

  // Authentication methods
  String? authToken;
  Map<String, dynamic>? currentUser;

  Future<String?> login(String username, String password) async {
    final r = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: "username=$username&password=$password",
    );
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      authToken = data["access_token"];

      // IMPORTANT: Sync token with AuthService for content library
      if (currentUser != null) {
        AuthService.setUserData(currentUser!, authToken!);
      }

      await fetchCurrentUser();

      // IMPORTANT: Sync again after fetching user data
      if (currentUser != null && authToken != null) {
        AuthService.setUserData(currentUser!, authToken!);
      }

      // Fetch data after successful login
      await Future.wait([
        fetchTemplates(),
        fetchContent(),
        fetchProposals(),
        fetchDashboard()
      ]);
      notifyListeners();
      return null;
    } else {
      try {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Login failed";
      } catch (_) {
        return "Login failed";
      }
    }
  }

  Future<String?> register(String username, String email, String password,
      String fullName, String role) async {
    final r = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "email": email,
        "password": password,
        "full_name": fullName,
        "role": role,
      }),
    );
    if (r.statusCode == 200 || r.statusCode == 201) {
      return null;
    } else {
      try {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Registration failed";
      } catch (_) {
        return "Registration failed";
      }
    }
  }

  Future<void> fetchCurrentUser() async {
    if (authToken == null) return;
    final r = await http.get(
      Uri.parse("$baseUrl/me"),
      headers: {"Authorization": "Bearer $authToken"},
    );
    if (r.statusCode == 200) {
      currentUser = jsonDecode(r.body);
    }
  }

  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final r = await http.post(
      Uri.parse("$baseUrl/verify-email"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token}),
    );

    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      return {
        "verified": data["verified"],
        "message": data["message"],
      };
    } else {
      try {
        final data = jsonDecode(r.body);
        return {
          "verified": false,
          "message": data["detail"] ?? "Verification failed",
        };
      } catch (_) {
        return {
          "verified": false,
          "message": "Verification failed",
        };
      }
    }
  }

  Future<String?> resendVerificationEmail(String email) async {
    final r = await http.post(
      Uri.parse("$baseUrl/resend-verification"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      return data["message"] ?? "Verification email sent successfully";
    } else {
      try {
        final data = jsonDecode(r.body);
        return data["detail"] ?? "Failed to resend verification email";
      } catch (_) {
        return "Failed to resend verification email";
      }
    }
  }

  // Cloudinary Upload Methods
  Future<Map<String, dynamic>?> uploadImageToCloudinary(String filePath,
      {List<int>? fileBytes, String? fileName}) async {
    try {
      http.MultipartFile file;

      // Use bytes on web, path on native platforms
      if (fileBytes != null && fileName != null) {
        file =
            http.MultipartFile.fromBytes('file', fileBytes, filename: fileName);
      } else {
        file = await http.MultipartFile.fromPath('file', filePath);
      }

      final request =
          http.MultipartRequest('POST', Uri.parse("$baseUrl/upload/image"))
            ..headers.addAll(_multipartHeaders)
            ..files.add(file);

      final response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(await response.stream.bytesToString());
        return data;
      } else {
        print('Error uploading image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading image to Cloudinary: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadTemplateToCloudinary(String filePath,
      {List<int>? fileBytes, String? fileName}) async {
    try {
      http.MultipartFile file;

      // Use bytes on web, path on native platforms
      if (fileBytes != null && fileName != null) {
        file =
            http.MultipartFile.fromBytes('file', fileBytes, filename: fileName);
      } else {
        file = await http.MultipartFile.fromPath('file', filePath);
      }

      final request =
          http.MultipartRequest('POST', Uri.parse("$baseUrl/upload/template"))
            ..headers.addAll(_multipartHeaders)
            ..files.add(file);

      final response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(await response.stream.bytesToString());
        return data;
      } else {
        print('Error uploading template: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading template to Cloudinary: $e');
      return null;
    }
  }

  Future<bool> deleteFromCloudinary(String publicId) async {
    try {
      final r = await http.delete(
        Uri.parse("$baseUrl/upload/$publicId"),
        headers: _headers,
      );
      return r.statusCode == 200;
    } catch (e) {
      print('Error deleting from Cloudinary: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUploadSignature(String publicId) async {
    try {
      final r = await http.post(
        Uri.parse("$baseUrl/upload/signature"),
        headers: _headers,
        body: jsonEncode({"public_id": publicId}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting upload signature: $e');
      return null;
    }
  }

  // Create content with Cloudinary URL
  Future<void> createContentWithCloudinary(String key, String label,
      String cloudinaryUrl, String publicId, String category,
      {int? parentId}) async {
    try {
      final Map<String, dynamic> body = {
        "key": key,
        "label": label,
        "content": cloudinaryUrl, // Store Cloudinary URL
        "public_id": publicId,
        "category": category,
        "created_at": DateTime.now().toIso8601String(),
      };

      // Add parent_id if provided (for files inside folders)
      if (parentId != null) {
        body["parent_id"] = parentId;
      }

      await http.post(
        Uri.parse("$baseUrl/content"),
        headers: _headers,
        body: jsonEncode(body),
      );
      await fetchContent();
      notifyListeners();
    } catch (e) {
      print('Error creating content: $e');
    }
  }

  void logout() {
    // Clear app state on logout
    authToken = null;
    currentUser = null;
    templates = [];
    contentBlocks = [];
    proposals = [];
    currentProposal = null;
    dashboardCounts = {};

    // IMPORTANT: Sync logout with AuthService
    AuthService.logout();

    notifyListeners();
  }
}
