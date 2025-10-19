import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AuthService {
  static const String baseUrl = 'http://localhost:8000';
  static String? _token;
  static Map<String, dynamic>? _currentUser;

  // Test method to set a role for debugging
  static void setTestRole(String role) {
    _currentUser = {'role': role, 'name': 'Test User', 'email': 'test@example.com'};
    _token = 'test_token';
    _persistSession();
  }

  // Initialize with default role for testing
  static void initializeDefaultRole() {
    if (_currentUser == null) {
      setTestRole('CEO');
    }
  }

  // Get current user
  static Map<String, dynamic>? get currentUser => _currentUser;
  static String? get token => _token;
  static bool get isLoggedIn => _token != null && _currentUser != null;

  // Persist session in web localStorage so back/refresh keeps user logged in
  static const String _storageKey = 'lukens_auth_session';

  static void _persistSession() {
    try {
      if (kIsWeb && _token != null && _currentUser != null) {
        final data = json.encode({'token': _token, 'user': _currentUser});
        html.window.localStorage[_storageKey] = data;
      }
    } catch (_) {}
  }

  static void restoreSessionFromStorage() {
    try {
      if (kIsWeb) {
        final data = html.window.localStorage[_storageKey];
        if (data != null && data.isNotEmpty) {
          final parsed = json.decode(data) as Map<String, dynamic>;
          final storedToken = parsed['token'] as String?;
          final storedUser = parsed['user'] as Map<String, dynamic>?;
          if (storedToken != null && storedUser != null) {
            _token = storedToken;
            _currentUser = storedUser;
          }
        }
      }
    } catch (_) {}
  }

  static void _clearSessionStorage() {
    try {
      if (kIsWeb) {
        html.window.localStorage.remove(_storageKey);
      }
    } catch (_) {}
  }

  // Register user
  static Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String role = 'creator',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': email, // Using email as username
          'email': email,
          'password': password,
          'full_name': '$firstName $lastName',
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Registration failed');
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // Login user
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      // Use the new email-based login endpoint with JSON data
      final response = await http.post(
        Uri.parse('$baseUrl/login-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        // Create a basic user object since backend doesn't return user data in login
        _currentUser = {
          'email': email,
          'username': email,
          'role': 'Business Developer'
        };
        _persistSession();
        return {
          'access_token': data['access_token'],
          'token_type': data['token_type'],
          'user': _currentUser
        };
      } else {
        final error = json.decode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Verify email
  static Future<Map<String, dynamic>?> verifyEmail(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Email verification failed');
      }
    } catch (e) {
      print('Email verification error: $e');
      rethrow;
    }
  }

  // Resend verification email
  static Future<Map<String, dynamic>?> resendVerification(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to resend verification');
      }
    } catch (e) {
      print('Resend verification error: $e');
      rethrow;
    }
  }

  // Forgot password
  static Future<Map<String, dynamic>?> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to send reset email');
      }
    } catch (e) {
      print('Forgot password error: $e');
      rethrow;
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (_token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentUser = data;
        return data;
      }
      return null;
    } catch (e) {
      print('Get user profile error: $e');
      return null;
    }
  }

  // Set user data manually (for Firebase compatibility)
  static void setUserData(Map<String, dynamic> userData, String token) {
    _currentUser = userData;
    _token = token;
  }

  // Logout
  static void logout() {
    _token = null;
    _currentUser = null;
    _clearSessionStorage();
  }

  // Get headers for authenticated requests
  static Map<String, String> getAuthHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }
}
