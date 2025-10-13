import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class FirebaseAuthService {
  static const String _backendBaseUrl = AuthService.baseUrl; // http://localhost:8000

  // Google Sign-In (Web)
  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError('Google Sign-In is implemented for web in this app');
    }

    // Ensure Firebase is initialized
    try {
      Firebase.apps.isEmpty ? await Firebase.initializeApp() : null;
    } catch (_) {}

    final auth = fb.FirebaseAuth.instance;
    final provider = fb.GoogleAuthProvider();

    // Optional scopes
    provider.addScope('email');
    provider.addScope('profile');

    // 1) Google popup
    final cred = await auth.signInWithPopup(provider);
    final user = cred.user;
    if (user == null) return null;

    // 2) Get Firebase ID token
    // Force-refresh to avoid stale/expired cached tokens
    final idToken = await user.getIdToken(true);

    // 3) Exchange for backend JWT
    final resp = await http.post(
      Uri.parse('$_backendBaseUrl/login-google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Google login failed (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;

    // 4) Persist session compatible with existing AuthService
    AuthService.setUserData(data['user'] as Map<String, dynamic>, data['access_token'] as String);

    return data;
  }
}
