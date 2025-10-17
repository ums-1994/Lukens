import 'dart:convert';
import 'package:http/http.dart' as http;

class SmtpAuthService {
  static const String baseUrl = 'http://localhost:8000';

  // Register user with SMTP email verification
  static Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'username': email.split('@')[0], // Use email prefix as username
          'email': email,
          'password': password,
          'full_name': '$firstName $lastName',
          'role': role,
        }),
      );

      print('Registration response status: ${response.statusCode}');
      print('Registration response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? 'Registration failed');
        } catch (e) {
          throw Exception('Registration failed: ${response.body}');
        }
      }
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }

  // Login user
  static Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login-email'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? 'Login failed');
        } catch (e) {
          throw Exception('Login failed: ${response.body}');
        }
      }
    } catch (e) {
      print('Error logging in user: $e');
      rethrow;
    }
  }

  // Verify email with token
  static Future<Map<String, dynamic>?> verifyEmail({
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-email'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'token': token,
        }),
      );

      print('Verification response status: ${response.statusCode}');
      print('Verification response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? 'Email verification failed');
        } catch (e) {
          throw Exception('Email verification failed: ${response.body}');
        }
      }
    } catch (e) {
      print('Error verifying email: $e');
      rethrow;
    }
  }

  // Resend verification email
  static Future<Map<String, dynamic>?> resendVerificationEmail({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resend-verification'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
        }),
      );

      print('Resend verification response status: ${response.statusCode}');
      print('Resend verification response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(
              error['detail'] ?? 'Failed to resend verification email');
        } catch (e) {
          throw Exception(
              'Failed to resend verification email: ${response.body}');
        }
      }
    } catch (e) {
      print('Error resending verification email: $e');
      rethrow;
    }
  }

  // Forgot password
  static Future<Map<String, dynamic>?> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
        }),
      );

      print('Forgot password response status: ${response.statusCode}');
      print('Forgot password response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(
              error['detail'] ?? 'Failed to send password reset email');
        } catch (e) {
          throw Exception(
              'Failed to send password reset email: ${response.body}');
        }
      }
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Get profile response status: ${response.statusCode}');
      print('Get profile response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          final error = json.decode(response.body);
          throw Exception(error['detail'] ?? 'Failed to get user profile');
        } catch (e) {
          throw Exception('Failed to get user profile: ${response.body}');
        }
      }
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }
}
