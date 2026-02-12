import 'package:flutter/foundation.dart';
// Conditional import for JS interop
import 'dart:html' as html show window;

/// Centralized API configuration for the Flutter application
class ApiConfig {
  // Production URLs
  static const String _productionBackendUrl =
      'https://backend-sow.onrender.com';
  static const String _productionFrontendUrl =
      'https://frontend-sow.onrender.com';

  // Development URLs
  static const String _developmentBackendUrl = 'http://localhost:8000';
  static const String _developmentFrontendUrl = 'http://localhost:3000';

  /// Get the backend API base URL
  static String get backendBaseUrl {
    // For web builds, detect environment and use appropriate URL
    if (kIsWeb) {
      try {
        final hostname = html.window.location.hostname;
        print('🔍 Detected hostname: $hostname');
        print('🔍 Current origin: ${html.window.location.origin}');

        if (hostname?.contains('onrender.com') == true) {
          print('🌐 Detected Render environment, using production backend');
          return _productionBackendUrl;
        } else if (hostname == 'localhost') {
          print('🌐 Detected localhost environment, using development backend');
          return _developmentBackendUrl;
        } else {
          print('🌐 Unknown hostname, defaulting to production backend');
          return _productionBackendUrl;
        }
      } catch (e) {
        print('⚠️ Could not detect hostname: $e');
        print('⚠️ Defaulting to production backend');
        return _productionBackendUrl;
      }
    }

    // Final fallback based on build mode
    if (kReleaseMode) {
      print('🌐 Using production backend (release mode)');
      return _productionBackendUrl;
    } else {
      print('🌐 Using development backend (debug mode)');
      return _developmentBackendUrl;
    }
  }

  /// Get the frontend base URL (for deep links, redirects, etc.)
  static String get frontendBaseUrl {
    if (kReleaseMode) {
      return _productionFrontendUrl;
    } else {
      return _developmentFrontendUrl;
    }
  }

  /// Check if we're running in production mode
  static bool get isProduction => kReleaseMode;

  /// Check if we're running in development mode
  static bool get isDevelopment => !kReleaseMode;

  /// Get API endpoint with path
  static String getEndpoint(String path) {
    final baseUrl = backendBaseUrl;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$baseUrl/$cleanPath';
  }

  /// Get WebSocket URL (if needed)
  static String get webSocketUrl {
    final backend = backendBaseUrl;
    return backend.replaceFirst('http', 'ws');
  }

  /// Common API headers
  static Map<String, String> getHeaders({String? authToken}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }

  /// API timeout durations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}
