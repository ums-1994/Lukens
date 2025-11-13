import 'package:flutter/material.dart';
import '../services/error_service.dart';

/// A widget that handles async operations with loading, error, and success states
class AsyncWidget<T> extends StatefulWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final Widget Function(Object error)? errorBuilder;
  final Widget? loadingWidget;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showRetryButton;

  const AsyncWidget({
    Key? key,
    required this.future,
    required this.builder,
    this.errorBuilder,
    this.loadingWidget,
    this.errorMessage,
    this.onRetry,
    this.showRetryButton = true,
  }) : super(key: key);

  @override
  State<AsyncWidget<T>> createState() => _AsyncWidgetState<T>();
}

class _AsyncWidgetState<T> extends State<AsyncWidget<T>> {
  late Future<T> _future;
  
  @override
  void initState() {
    super.initState();
    _future = widget.future;
  }

  void _retry() {
    setState(() {
      _future = widget.future;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ?? _buildDefaultLoading();
        }

        if (snapshot.hasError) {
          ErrorService.logError(
            widget.errorMessage ?? 'Async operation failed',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
            context: 'AsyncWidget',
          );

          return widget.errorBuilder?.call(snapshot.error!) ?? 
                 _buildDefaultError(snapshot.error!);
        }

        if (snapshot.hasData) {
          return widget.builder(snapshot.data as T);
        }

        return _buildDefaultEmpty();
      },
    );
  }

  Widget _buildDefaultLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultError(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            SizedBox(height: 16),
            Text(
              widget.errorMessage ?? 'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Please try again or contact support if the problem persists.',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.showRetryButton) ...[
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: Icon(Icons.refresh),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// A widget for handling list async operations
class AsyncListWidget<T> extends StatefulWidget {
  final Future<List<T>> future;
  final Widget Function(List<T> items) builder;
  final Widget Function(T item, int index)? itemBuilder;
  final Widget Function(Object error)? errorBuilder;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showRetryButton;

  const AsyncListWidget({
    Key? key,
    required this.future,
    required this.builder,
    this.itemBuilder,
    this.errorBuilder,
    this.loadingWidget,
    this.emptyWidget,
    this.errorMessage,
    this.onRetry,
    this.showRetryButton = true,
  }) : super(key: key);

  @override
  State<AsyncListWidget<T>> createState() => _AsyncListWidgetState<T>();
}

class _AsyncListWidgetState<T> extends State<AsyncListWidget<T>> {
  late Future<List<T>> _future;
  
  @override
  void initState() {
    super.initState();
    _future = widget.future;
  }

  void _retry() {
    setState(() {
      _future = widget.future;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ?? _buildDefaultLoading();
        }

        if (snapshot.hasError) {
          ErrorService.logError(
            widget.errorMessage ?? 'Failed to load list data',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
            context: 'AsyncListWidget',
          );

          return widget.errorBuilder?.call(snapshot.error!) ?? 
                 _buildDefaultError(snapshot.error!);
        }

        if (snapshot.hasData) {
          final items = snapshot.data!;
          if (items.isEmpty) {
            return widget.emptyWidget ?? _buildDefaultEmpty();
          }
          return widget.builder(items);
        }

        return _buildDefaultEmpty();
      },
    );
  }

  Widget _buildDefaultLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading items...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultError(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            SizedBox(height: 16),
            Text(
              widget.errorMessage ?? 'Failed to load items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Please try again or contact support if the problem persists.',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.showRetryButton) ...[
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: Icon(Icons.refresh),
                label: Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No items found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// A button that handles async operations with loading states
class AsyncButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget child;
  final String? successMessage;
  final String? errorMessage;
  final ButtonStyle? style;
  final bool showSuccessMessage;
  final bool showErrorMessage;

  const AsyncButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.successMessage,
    this.errorMessage,
    this.style,
    this.showSuccessMessage = true,
    this.showErrorMessage = true,
  }) : super(key: key);

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await widget.onPressed();
      
      if (widget.showSuccessMessage && widget.successMessage != null) {
        ErrorService.showSuccess(
          widget.successMessage!,
          context: 'AsyncButton',
        );
      }
    } catch (e) {
      ErrorService.handleError(
        widget.errorMessage ?? 'Operation failed',
        error: e,
        context: 'AsyncButton',
        showToUser: widget.showErrorMessage,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handlePress,
      style: widget.style,
      child: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          : widget.child,
    );
  }
}
