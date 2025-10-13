import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String baseUrl = "http://localhost:8000";

class AppState extends ChangeNotifier {
  List<dynamic> templates = [];
  List<dynamic> contentBlocks = [];
  List<dynamic> proposals = [];
  Map<String, dynamic>? currentProposal;
  Map<String, dynamic> dashboardCounts = {};

  Future<void> init() async {
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
    // For now, return empty content since backend doesn't have this endpoint yet
    contentBlocks = [];
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

  Future<void> createProposal(String title, String client,
      {String? templateKey}) async {
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

  void selectProposal(Map<String, dynamic> p) {
    currentProposal = p;
    notifyListeners();
  }

  // Content library operations
  Future<void> createContent(String key, String label, String content) async {
    final r = await http.post(
      Uri.parse("$baseUrl/content"),
      headers: _headers,
      body: jsonEncode({"key": key, "label": label, "content": content}),
    );
    if (r.statusCode == 200 || r.statusCode == 201) {
      await fetchContent();
      return;
    } else {
      throw Exception("Failed to create content block");
    }
  }

  Future<void> deleteContent(int id) async {
    final r =
        await http.delete(Uri.parse("$baseUrl/content/$id"), headers: _headers);
    if (r.statusCode == 200) {
      await fetchContent();
    } else {
      throw Exception("Failed to delete content block");
    }
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
      await fetchCurrentUser();
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

  void logout() {
    authToken = null;
    currentUser = null;
    notifyListeners();
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
}
