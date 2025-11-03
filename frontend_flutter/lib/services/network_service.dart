import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'error_service.dart';

/// Enhanced network service with retry mechanisms and better error handling
class NetworkService {
  static const int defaultRetryCount = 3;
  static const Duration defaultRetryDelay = Duration(seconds: 2);
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Make a GET request with retry logic and error handling
  static Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    int retryCount = defaultRetryCount,
    Duration retryDelay = defaultRetryDelay,
    Duration timeout = defaultTimeout,
    String? context,
  }) async {
    return _executeWithRetry(
      () => http.get(Uri.parse(url), headers: headers).timeout(timeout),
      retryCount: retryCount,
      retryDelay: retryDelay,
      context: context ?? 'GET $url',
    );
  }

  /// Make a POST request with retry logic and error handling
  static Future<http.Response> post(
    String url, {
    Map<String, String>? headers,
    Object? body,
    int retryCount = defaultRetryCount,
    Duration retryDelay = defaultRetryDelay,
    Duration timeout = defaultTimeout,
    String? context,
  }) async {
    return _executeWithRetry(
      () => http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(timeout),
      retryCount: retryCount,
      retryDelay: retryDelay,
      context: context ?? 'POST $url',
    );
  }

  /// Make a PUT request with retry logic and error handling
  static Future<http.Response> put(
    String url, {
    Map<String, String>? headers,
    Object? body,
    int retryCount = defaultRetryCount,
    Duration retryDelay = defaultRetryDelay,
    Duration timeout = defaultTimeout,
    String? context,
  }) async {
    return _executeWithRetry(
      () => http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(timeout),
      retryCount: retryCount,
      retryDelay: retryDelay,
      context: context ?? 'PUT $url',
    );
  }

  /// Make a DELETE request with retry logic and error handling
  static Future<http.Response> delete(
    String url, {
    Map<String, String>? headers,
    int retryCount = defaultRetryCount,
    Duration retryDelay = defaultRetryDelay,
    Duration timeout = defaultTimeout,
    String? context,
  }) async {
    return _executeWithRetry(
      () => http.delete(Uri.parse(url), headers: headers).timeout(timeout),
      retryCount: retryCount,
      retryDelay: retryDelay,
      context: context ?? 'DELETE $url',
    );
  }

  /// Execute HTTP request with retry logic
  static Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request, {
    required int retryCount,
    required Duration retryDelay,
    required String context,
  }) async {
    int attempts = 0;
    Object? lastError;

    while (attempts <= retryCount) {
      try {
        final response = await request();
        
        // Log successful request
        ErrorService.logError(
          'HTTP request successful',
          context: '$context (attempt ${attempts + 1})',
          additionalData: {
            'statusCode': response.statusCode,
            'attempts': attempts + 1,
          },
        );

        // Check if response indicates a server error that might benefit from retry
        if (attempts < retryCount && _shouldRetry(response.statusCode)) {
          attempts++;
          await Future.delayed(retryDelay * attempts); // Exponential backoff
          continue;
        }

        return response;
      } catch (error) {
        lastError = error;
        attempts++;

        ErrorService.logError(
          'HTTP request failed (attempt $attempts/${retryCount + 1})',
          error: error,
          context: context,
          additionalData: {
            'attempt': attempts,
            'maxAttempts': retryCount + 1,
            'willRetry': attempts <= retryCount,
          },
        );

        if (attempts <= retryCount && _shouldRetryOnError(error)) {
          await Future.delayed(retryDelay * attempts); // Exponential backoff
          continue;
        }

        // If we've exhausted retries or error is not retryable, throw
        break;
      }
    }

    // All retries exhausted, handle the final error
    final userMessage = ErrorService.handleNetworkError(lastError!, context: context);
    throw NetworkException(userMessage, context: context);
  }

  /// Determine if we should retry based on HTTP status code
  static bool _shouldRetry(int statusCode) {
    return statusCode >= 500 || // Server errors
           statusCode == 408 || // Request timeout
           statusCode == 429;   // Too many requests
  }

  /// Determine if we should retry based on the type of error
  static bool _shouldRetryOnError(Object error) {
    final errorString = error.toString().toLowerCase();
    
    // Retry on network connectivity issues
    if (errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('timeout') ||
        errorString.contains('connection reset') ||
        errorString.contains('network unreachable')) {
      return true;
    }

    // Don't retry on authentication or client errors
    if (errorString.contains('certificate') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return false;
    }

    return true; // Default to retry for unknown errors
  }

  /// Parse JSON response with enhanced backend error handling
  static Map<String, dynamic> parseJsonResponse(
    http.Response response, {
    String? context,
  }) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        // Try to parse enhanced backend error response
        try {
          final errorResponse = json.decode(response.body) as Map<String, dynamic>;
          if (errorResponse.containsKey('error')) {
            final error = errorResponse['error'] as Map<String, dynamic>;
            
            // Extract enhanced error information
            final userMessage = error['user_message'] as String? ?? 
                               error['message'] as String? ?? 
                               'An error occurred';
            final traceId = error['trace_id'] as String?;
            final retryAfter = error['retry_after'] as int?;
            final category = error['code'] as String?;
            final severity = error['severity'] as String?;
            
            // Log enhanced error information
            ErrorService.logError(
              'Backend error response',
              context: context,
              additionalData: {
                'statusCode': response.statusCode,
                'traceId': traceId,
                'category': category,
                'severity': severity,
                'retryAfter': retryAfter,
              },
            );
            
            // Handle retry-after for rate limiting
            if (retryAfter != null && category == 'RATE_LIMIT') {
              ErrorService.handleError(
                '$userMessage (Retry in ${retryAfter}s)',
                context: context,
                severity: ErrorSeverity.medium,
              );
            } else {
              // Map backend severity to frontend severity
              ErrorSeverity errorSeverity = ErrorSeverity.medium;
              if (severity != null) {
                switch (severity.toLowerCase()) {
                  case 'low':
                    errorSeverity = ErrorSeverity.low;
                    break;
                  case 'high':
                    errorSeverity = ErrorSeverity.high;
                    break;
                  case 'critical':
                    errorSeverity = ErrorSeverity.critical;
                    break;
                }
              }
              
              ErrorService.handleError(
                userMessage,
                context: context,
                severity: errorSeverity,
              );
            }
            
            throw AppException(userMessage, context: context);
          }
        } catch (e) {
          // Fall back to standard error handling if parsing fails
          final userMessage = ErrorService.handleApiError(
            response.statusCode,
            response.body,
            context: context,
          );
          throw AppException(userMessage, context: context);
        }
        
        // Fallback if no error object found
        final userMessage = ErrorService.handleApiError(
          response.statusCode,
          response.body,
          context: context,
        );
        throw AppException(userMessage, context: context);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      
      ErrorService.logError(
        'Failed to parse JSON response',
        error: e,
        context: context,
        additionalData: {
          'statusCode': response.statusCode,
          'responseBody': response.body,
        },
      );
      
      throw AppException(
        'Invalid response format received from server',
        context: context,
      );
    }
  }

  /// Parse JSON list response with error handling
  static List<dynamic> parseJsonListResponse(
    http.Response response, {
    String? context,
  }) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map && decoded.containsKey('data')) {
          return decoded['data'] as List<dynamic>;
        } else {
          throw AppException(
            'Expected list response but received different format',
            context: context,
          );
        }
      } else {
        final userMessage = ErrorService.handleApiError(
          response.statusCode,
          response.body,
          context: context,
        );
        throw AppException(userMessage, context: context);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      
      ErrorService.logError(
        'Failed to parse JSON list response',
        error: e,
        context: context,
        additionalData: {
          'statusCode': response.statusCode,
          'responseBody': response.body,
        },
      );
      
      throw AppException(
        'Invalid response format received from server',
        context: context,
      );
    }
  }

  /// Check internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      ErrorService.logError(
        'Internet connectivity check failed',
        error: e,
        context: 'NetworkService.hasInternetConnection',
      );
      return false;
    }
  }

  /// Execute operation with internet connectivity check
  static Future<T> executeWithConnectivityCheck<T>(
    Future<T> Function() operation, {
    String? context,
  }) async {
    if (!await hasInternetConnection()) {
      throw NetworkException(
        'No internet connection available. Please check your network settings.',
        context: context,
      );
    }

    return await operation();
  }
}
