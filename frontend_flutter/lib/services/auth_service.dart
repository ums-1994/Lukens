import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;
import '../config/api_config.dart';
import 'jwt_service.dart';

class AuthService {
  // Use centralized API configuration
  static String get baseUrl => ApiConfig.backendBaseUrl;
  static String? _token;
  static Map<String, dynamic>? _currentUser;

  // Get current user
  static Map<String, dynamic>? get currentUser => _currentUser;
  static String? get token => _token;
  static bool get isLoggedIn => _token != null && _currentUser != null;

  // Persist session in web localStorage so back/refresh keeps user logged in
  static const String _storageKey = 'lukens_auth_session';

  static void _persistSession() {
    try {
      print('💾 AuthService: Attempting to persist session...');
      print('💾 Token available: ${_token != null}');
      print('💾 User available: ${_currentUser != null}');
      print('💾 Is Web: $kIsWeb');

      if (kIsWeb && _token != null && _currentUser != null) {
        final data = json.encode({'token': _token, 'user': _currentUser});
        print('💾 Data to store length: ${data.length}');
        web.window.localStorage.setItem(_storageKey, data);
        print('✅ Session persisted to localStorage');

        // Verify it was saved
        final saved = web.window.localStorage.getItem(_storageKey);
        print('✅ Verification - Data saved: ${saved != null}');
      } else {
        print(
            '⚠️ Cannot persist: Web=${kIsWeb}, Token=${_token != null}, User=${_currentUser != null}');
      }
    } catch (e) {
      print('❌ Error persisting session: $e');
    }
  }

  static void restoreSessionFromStorage() {
    try {
      print('🔄 AuthService: Attempting to restore session from storage...');
      if (kIsWeb) {
        final data = web.window.localStorage.getItem(_storageKey);
        print('📦 localStorage key: $_storageKey');
        print('📦 Data exists: ${data != null}');
        print('📦 Data isEmpty: ${data?.isEmpty ?? true}');

        if (data != null && data.isNotEmpty) {
          print('📦 Data length: ${data.length}');
          print(
              '📦 Data preview: ${data.substring(0, data.length > 100 ? 100 : data.length)}...');

          final parsed = json.decode(data) as Map<String, dynamic>;
          print('📦 Parsed keys: ${parsed.keys.toList()}');

          final storedToken = parsed['token'] as String?;
          final storedUser = parsed['user'] as Map<String, dynamic>?;

          print('📦 Token exists in parsed data: ${storedToken != null}');
          print('📦 User exists in parsed data: ${storedUser != null}');

          if (storedToken != null && storedUser != null) {
            _token = storedToken;
            _currentUser = storedUser;
            print('✅ Session restored successfully!');
            print('✅ Token: ${_token!.substring(0, 20)}...');
            print('✅ User email: ${_currentUser!['email']}');
          } else {
            print('❌ Token or user is null in parsed data');
          }
        } else {
          print('⚠️ No data in localStorage or data is empty');
        }
      } else {
        print('⚠️ Not running on web platform');
      }
    } catch (e, stackTrace) {
      print('❌ Error restoring session: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  static void _clearSessionStorage() {
    try {
      if (kIsWeb) {
        web.window.localStorage.removeItem(_storageKey);
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

  // Login using external JWT token with local decryption
  static Future<Map<String, dynamic>?> loginWithJwt(String jwtToken) async {
    try {
      print('🔑 Attempting to decrypt JWT token locally...');
      
      // First try to decrypt the token locally
      final userData = JwtService.getUserFromToken(jwtToken);
      
      if (userData == null) {
        throw Exception('Failed to decrypt JWT token or token is invalid');
      }
      
      print('✅ JWT token decrypted successfully');
      print('👤 User email: ${userData['email']}');
      print('🔑 User role: ${userData['role']}');
      
      // Create a session token for the app (you might want to generate a new token)
      final sessionToken = _generateSessionToken(userData);
      
      // Set user data
      setUserData(userData, sessionToken);
      
      return {
        'user': userData,
        'token': sessionToken,
      };
      
    } catch (e) {
      print('❌ JWT decryption failed: $e');
      
      // Fallback to backend verification if local decryption fails
      print('🔄 Falling back to backend verification...');
      return await _loginWithJwtBackend(jwtToken);
    }
  }
  
  // Fallback method for backend JWT verification
  static Future<Map<String, dynamic>?> _loginWithJwtBackend(String jwtToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/khonobuzz/jwt-login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': jwtToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>?;
        final token = data['token'] as String?;

        if (user == null || token == null) {
          throw Exception('Malformed response from jwt-login endpoint');
        }

        setUserData(user, token);
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(
            error['detail'] ?? 'External JWT login failed with status ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Backend JWT verification failed: $e');
      rethrow;
    }
  }
  
  // Generate a simple session token (in production, use proper JWT generation)
  static String _generateSessionToken(Map<String, dynamic> userData) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = {
      'sub': userData['id'],
      'email': userData['email'],
      'role': userData['role'],
      'iat': timestamp,
      'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600, // 1 hour expiry
    };
    
    // Simple encoding (in production, use proper JWT signing)
    return base64.encode(utf8.encode(json.encode(payload)));
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
    print('💾 AuthService.setUserData called');
    print('💾 Setting token: ${token.substring(0, 20)}...');
    print('💾 Setting user: ${userData['email']}');
    _currentUser = userData;
    _token = token;
    // IMPORTANT: Persist to localStorage so it survives navigation/refresh
    _persistSession();
    print('💾 Session data set and persisted');
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
