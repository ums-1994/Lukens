import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized error handling service for the application
class ErrorService {
  static final ErrorService _instance = ErrorService._internal();
  factory ErrorService() => _instance;
  ErrorService._internal();

  /// Global navigator key for showing error dialogs
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Initialize the error service with navigator key
  static void initialize(GlobalKey<NavigatorState> navKey) {
    navigatorKey = navKey;
  }

  /// Log error with structured information
  static void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorInfo = {
      'message': message,
      'error': error?.toString(),
      'context': context,
      'timestamp': DateTime.now().toIso8601String(),
      'additionalData': additionalData,
    };

    if (kDebugMode) {
      developer.log(
        message,
        name: 'ErrorService',
        error: error,
        stackTrace: stackTrace,
      );
      print('🚨 ERROR: $errorInfo');
    }

    // In production, you might want to send this to a crash reporting service
    // like Firebase Crashlytics, Sentry, etc.
  }

  /// Handle and display user-friendly errors
  static void handleError(
    String userMessage, {
    Object? error,
    StackTrace? stackTrace,
    String? context,
    bool showToUser = true,
    ErrorSeverity severity = ErrorSeverity.medium,
  }) {
    // Log the error
    logError(
      userMessage,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );

    // Show to user if requested and navigator is available
    if (showToUser && navigatorKey?.currentContext != null) {
      _showErrorToUser(userMessage, severity);
    }
  }

  /// Show error message to user via SnackBar or Dialog
  static void _showErrorToUser(String message, ErrorSeverity severity) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    switch (severity) {
      case ErrorSeverity.low:
        _showSnackBar(context, message, Colors.orange);
        break;
      case ErrorSeverity.medium:
        _showSnackBar(context, message, Colors.red);
        break;
      case ErrorSeverity.high:
      case ErrorSeverity.critical:
        _showErrorDialog(context, message, severity);
        break;
    }
  }

  /// Show error via SnackBar
  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show error via Dialog for critical errors
  static void _showErrorDialog(
    BuildContext context,
    String message,
    ErrorSeverity severity,
  ) {
    showDialog(
      context: context,
      barrierDismissible: severity != ErrorSeverity.critical,
      builder: (context) => AlertDialog(
        icon: Icon(
          severity == ErrorSeverity.critical ? Icons.error : Icons.warning,
          color: severity == ErrorSeverity.critical ? Colors.red : Colors.orange,
          size: 32,
        ),
        title: Text(
          severity == ErrorSeverity.critical ? 'Critical Error' : 'Error',
          style: TextStyle(
            color: severity == ErrorSeverity.critical ? Colors.red : Colors.orange,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
          if (severity == ErrorSeverity.critical)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // You might want to restart the app or navigate to a safe screen
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Restart App', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  /// Handle network errors specifically
  static String handleNetworkError(Object error, {String? context}) {
    String userMessage;
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('socketexception') || 
        errorString.contains('connection refused')) {
      userMessage = 'Unable to connect to server. Please check your internet connection.';
    } else if (errorString.contains('timeout')) {
      userMessage = 'Request timed out. Please try again.';
    } else if (errorString.contains('certificate') || 
               errorString.contains('handshake')) {
      userMessage = 'Security certificate error. Please try again later.';
    } else if (errorString.contains('format')) {
      userMessage = 'Invalid response format received from server.';
    } else {
      userMessage = 'Network error occurred. Please try again.';
    }

    logError(
      'Network error: $userMessage',
      error: error,
      context: context,
    );

    return userMessage;
  }

  /// Handle API errors with status codes
  static String handleApiError(int statusCode, String? responseBody, {String? context}) {
    String userMessage;

    switch (statusCode) {
      case 400:
        userMessage = 'Invalid request. Please check your input.';
        break;
      case 401:
        userMessage = 'Authentication failed. Please log in again.';
        break;
      case 403:
        userMessage = 'Access denied. You don\'t have permission for this action.';
        break;
      case 404:
        userMessage = 'Requested resource not found.';
        break;
      case 408:
        userMessage = 'Request timed out. Please try again.';
        break;
      case 429:
        userMessage = 'Too many requests. Please wait a moment and try again.';
        break;
      case 500:
        userMessage = 'Server error occurred. Please try again later.';
        break;
      case 502:
      case 503:
        userMessage = 'Service temporarily unavailable. Please try again later.';
        break;
      default:
        userMessage = 'An error occurred (Code: $statusCode). Please try again.';
    }

    logError(
      'API error: $userMessage',
      error: 'Status: $statusCode, Body: $responseBody',
      context: context,
      additionalData: {
        'statusCode': statusCode,
        'responseBody': responseBody,
      },
    );

    return userMessage;
  }

  /// Show success message
  static void showSuccess(String message, {String? context}) {
    final navContext = navigatorKey?.currentContext;
    if (navContext == null) return;

    ScaffoldMessenger.of(navContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    if (kDebugMode && context != null) {
      print('✅ SUCCESS [$context]: $message');
    }
  }

  /// Show info message
  static void showInfo(String message, {String? context}) {
    final navContext = navigatorKey?.currentContext;
    if (navContext == null) return;

    ScaffoldMessenger.of(navContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );

    if (kDebugMode && context != null) {
      print('ℹ️ INFO [$context]: $message');
    }
  }
}

/// Error severity levels
enum ErrorSeverity {
  low,     // Minor issues, warnings
  medium,  // Standard errors
  high,    // Serious errors that affect functionality
  critical // Critical errors that might crash the app
}

/// Custom exception classes for better error categorization
class AppException implements Exception {
  final String message;
  final String? context;
  final ErrorSeverity severity;

  AppException(this.message, {this.context, this.severity = ErrorSeverity.medium});

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  NetworkException(String message, {String? context}) 
    : super(message, context: context, severity: ErrorSeverity.medium);
}

class AuthenticationException extends AppException {
  AuthenticationException(String message, {String? context}) 
    : super(message, context: context, severity: ErrorSeverity.high);
}

class ValidationException extends AppException {
  ValidationException(String message, {String? context}) 
    : super(message, context: context, severity: ErrorSeverity.low);
}
