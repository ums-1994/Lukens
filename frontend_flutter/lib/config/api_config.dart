// ignore_for_file: unused_field, unused_element, unused_local_variable

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

import '../services/api_service.dart';

/// Centralized API configuration for the Flutter application
class ApiConfig {
  // Production URLs
  static const String _productionBackendUrl =
      'https://lukens-wp8w.onrender.com';
  static const String _productionFrontendUrl =
      'https://frontend-sow.onrender.com';

  // Development URLs
  static const String _developmentFrontendUrl = 'http://localhost:3000';

  /// Get the backend API base URL (uses same logic as ApiService so content library uses local when appropriate)
  static String get backendBaseUrl {
    return ApiService.baseUrl;
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
