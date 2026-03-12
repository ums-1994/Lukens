// ignore_for_file: unused_field, unused_element, unused_local_variable

import 'package:flutter/foundation.dart';

/// Centralized API configuration for the Flutter application
class ApiConfig {
  // Production URLs
  static const String _productionBackendUrl =
      'https://lukens-tae3.onrender.com';
  static const String _productionFrontendUrl =
      'https://frontend-sow.onrender.com';

  // Development URLs
  static const String _developmentBackendUrl = 'http://localhost:8000';
  static const String _developmentFrontendUrl = 'http://localhost:3000';

  /// Get the backend API base URL
  static String get backendBaseUrl {
    // Force production for now - remove this after testing
    print('🔧 FORCING PRODUCTION BACKEND URL: $_productionBackendUrl');
    return _productionBackendUrl;

    // Original logic below - comment out for now
    /*
    // For web builds, try to get from JavaScript config first
    if (kIsWeb) {
      try {
        final config = js.context['APP_CONFIG'];
        if (config != null) {
          final configObj = config as js.JsObject;
          final apiUrl = configObj['API_URL'];
          if (apiUrl != null && apiUrl.toString().isNotEmpty) {
            final url = apiUrl.toString().replaceAll('"', '').trim();
            if (url.isNotEmpty) {
              print('🌐 Using API URL from JavaScript config: $url');
              return url;
            }
          }
        }
      } catch (e) {
        print('⚠️ Failed to read JavaScript config: $e');
        // Fall through to environment-based detection
      }
      
      // Environment-based fallback with better production detection
      try {
        final hostname = js.context['window']['location']['hostname'];
        print('🔍 Detected hostname: ${hostname ?? 'NULL'}');
        print('🔍 Current origin: ${js.context['window']['location']['origin'] ?? 'NULL'}');
        
        if (hostname != null && hostname.toString().contains('onrender.com')) {
          print('🌐 Detected Render environment, using production backend');
          return _productionBackendUrl;
        } else if (hostname != null && hostname.toString() == 'localhost') {
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
    */
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
