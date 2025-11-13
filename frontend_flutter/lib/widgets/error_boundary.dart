import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/error_service.dart';

/// Global error boundary widget that catches and handles uncaught errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? errorWidget;
  final void Function(Object error, StackTrace stackTrace)? onError;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.errorWidget,
    this.onError,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    
    // Set up global error handler for Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      ErrorService.logError(
        'Flutter framework error',
        error: details.exception,
        stackTrace: details.stack,
        context: 'ErrorBoundary',
        additionalData: {
          'library': details.library,
          'context': details.context?.toString(),
        },
      );

      // Call custom error handler if provided
      widget.onError?.call(details.exception, details.stack ?? StackTrace.empty);

      // In debug mode, use the default error handler
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Set up error handler for async errors not caught by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorService.logError(
        'Uncaught async error',
        error: error,
        stackTrace: stack,
        context: 'ErrorBoundary',
      );

      widget.onError?.call(error, stack);
      return true; // Indicates the error was handled
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    return ErrorWidget.builder = (FlutterErrorDetails details) {
      // Handle widget build errors
      setState(() {
        _error = details.exception;
        _stackTrace = details.stack;
      });

      ErrorService.handleError(
        'A widget error occurred',
        error: details.exception,
        stackTrace: details.stack,
        context: 'ErrorBoundary - Widget Build',
        severity: ErrorSeverity.high,
      );

      return _buildDefaultErrorWidget();
    };
  }

  Widget _buildDefaultErrorWidget() {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                SizedBox(height: 24),
                Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'We\'re sorry for the inconvenience. The app encountered an unexpected error.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: Icon(Icons.refresh),
                      label: Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _reportError,
                      icon: Icon(Icons.bug_report),
                      label: Text('Report Issue'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
                if (kDebugMode && _error != null) ...[
                  SizedBox(height: 32),
                  ExpansionTile(
                    title: Text(
                      'Debug Information',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Error:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _error.toString(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Colors.grey[800],
                              ),
                            ),
                            if (_stackTrace != null) ...[
                              SizedBox(height: 16),
                              Text(
                                'Stack Trace:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _stackTrace.toString(),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 10,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  void _reportError() {
    // In a real app, you might want to:
    // 1. Send error report to your backend
    // 2. Open email client with pre-filled error report
    // 3. Navigate to a feedback form
    
    ErrorService.showInfo(
      'Error report functionality would be implemented here',
      context: 'ErrorBoundary',
    );
  }
}

/// Wrapper widget for handling async operation errors
class AsyncErrorHandler extends StatelessWidget {
  final Future<Widget> future;
  final Widget Function(Object error)? errorBuilder;
  final Widget? loadingWidget;

  const AsyncErrorHandler({
    Key? key,
    required this.future,
    this.errorBuilder,
    this.loadingWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? 
            Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          ErrorService.handleError(
            'Async operation failed',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
            context: 'AsyncErrorHandler',
          );

          return errorBuilder?.call(snapshot.error!) ?? 
            _buildDefaultAsyncError(snapshot.error!);
        }

        return snapshot.data ?? SizedBox.shrink();
      },
    );
  }

  Widget _buildDefaultAsyncError(Object error) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(
            'Failed to load content',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
