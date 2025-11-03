# Error Handling Guide

This guide explains the comprehensive error handling system implemented in the Lukens Flutter application.

## Overview

The app now includes a robust error handling system with the following components:

1. **Centralized Error Service** - Handles logging, user notifications, and error categorization
2. **Global Error Boundary** - Catches uncaught errors and provides fallback UI
3. **Network Service with Retry Logic** - Handles network requests with automatic retries
4. **Async Widgets** - Simplify handling of async operations with loading/error states
5. **Enhanced Service Layer** - Updated services use the new error handling patterns

## Components

### 1. ErrorService (`lib/services/error_service.dart`)

The central hub for all error handling in the app.

#### Key Features:
- **Structured logging** with context and additional data
- **User-friendly error messages** via SnackBars and Dialogs
- **Error severity levels** (low, medium, high, critical)
- **Network and API error handling** with specific user messages
- **Success and info message display**

#### Usage Examples:

```dart
// Log an error without showing to user
ErrorService.logError(
  'Database connection failed',
  error: e,
  context: 'UserService.fetchUsers',
);

// Handle error with user notification
ErrorService.handleError(
  'Failed to save user data',
  error: e,
  context: 'UserService.saveUser',
  severity: ErrorSeverity.medium,
);

// Show success message
ErrorService.showSuccess(
  'User profile updated successfully',
  context: 'ProfilePage',
);

// Handle network errors
final userMessage = ErrorService.handleNetworkError(
  error,
  context: 'ApiService.fetchData',
);

// Handle API errors
final userMessage = ErrorService.handleApiError(
  response.statusCode,
  response.body,
  context: 'ApiService.createUser',
);
```

### 2. ErrorBoundary (`lib/widgets/error_boundary.dart`)

A global error boundary that catches uncaught errors and provides a fallback UI.

#### Features:
- **Catches Flutter framework errors**
- **Handles async errors not caught by widgets**
- **Provides user-friendly error screen**
- **Debug information in development mode**
- **Retry functionality**

#### Integration:
The ErrorBoundary is automatically integrated in `main.dart` and wraps the entire app.

### 3. NetworkService (`lib/services/network_service.dart`)

Enhanced HTTP client with retry logic and comprehensive error handling.

#### Features:
- **Automatic retry** with exponential backoff
- **Timeout handling**
- **Internet connectivity checks**
- **Structured error responses**
- **JSON parsing with error handling**

#### Usage Examples:

```dart
// GET request with retry
final response = await NetworkService.get(
  'https://api.example.com/users',
  headers: {'Authorization': 'Bearer $token'},
  retryCount: 3,
  context: 'UserService.fetchUsers',
);

// Parse JSON response
final data = NetworkService.parseJsonResponse(
  response,
  context: 'UserService.fetchUsers',
);

// Check connectivity before operation
await NetworkService.executeWithConnectivityCheck(
  () => someNetworkOperation(),
  context: 'UserService.syncData',
);
```

### 4. AsyncWidget (`lib/widgets/async_widget.dart`)

Widgets that simplify handling of async operations with built-in loading, error, and empty states.

#### AsyncWidget Usage:

```dart
AsyncWidget<User>(
  future: userService.fetchUser(userId),
  builder: (user) => UserProfileWidget(user: user),
  errorMessage: 'Failed to load user profile',
  onRetry: () => userService.fetchUser(userId),
)
```

#### AsyncListWidget Usage:

```dart
AsyncListWidget<User>(
  future: userService.fetchUsers(),
  builder: (users) => ListView.builder(
    itemCount: users.length,
    itemBuilder: (context, index) => UserTile(user: users[index]),
  ),
  errorMessage: 'Failed to load users',
  emptyWidget: Text('No users found'),
)
```

#### AsyncButton Usage:

```dart
AsyncButton(
  onPressed: () => userService.saveUser(user),
  successMessage: 'User saved successfully',
  errorMessage: 'Failed to save user',
  child: Text('Save User'),
)
```

## Error Severity Levels

### ErrorSeverity.low
- Minor issues, warnings
- Shown via orange SnackBar
- Examples: Validation warnings, optional feature failures

### ErrorSeverity.medium
- Standard errors that affect functionality
- Shown via red SnackBar
- Examples: Network failures, API errors

### ErrorSeverity.high
- Serious errors that significantly impact user experience
- Shown via error dialog
- Examples: Authentication failures, critical data loss

### ErrorSeverity.critical
- Critical errors that might crash the app
- Shown via non-dismissible error dialog with restart option
- Examples: Unhandled exceptions, memory issues

## Custom Exception Classes

```dart
// Generic app exception
throw AppException(
  'User validation failed',
  context: 'UserService.validateUser',
  severity: ErrorSeverity.medium,
);

// Network-specific exception
throw NetworkException(
  'Unable to connect to server',
  context: 'ApiService.fetchData',
);

// Authentication-specific exception
throw AuthenticationException(
  'Invalid credentials',
  context: 'AuthService.login',
);

// Validation-specific exception
throw ValidationException(
  'Email format is invalid',
  context: 'RegisterForm.validateEmail',
);
```

## Best Practices

### 1. Always Provide Context
```dart
// Good
ErrorService.handleError(
  'Failed to save document',
  error: e,
  context: 'DocumentService.saveDocument',
);

// Bad
ErrorService.handleError('Error occurred', error: e);
```

### 2. Use Appropriate Severity Levels
```dart
// Critical system error
ErrorService.handleError(
  'Database connection lost',
  error: e,
  severity: ErrorSeverity.critical,
);

// User input validation
ErrorService.handleError(
  'Please enter a valid email address',
  severity: ErrorSeverity.low,
);
```

### 3. Provide Actionable Error Messages
```dart
// Good - tells user what to do
ErrorService.handleError(
  'Unable to save changes. Please check your internet connection and try again.',
);

// Bad - generic and unhelpful
ErrorService.handleError('An error occurred');
```

### 4. Use AsyncWidget for Better UX
```dart
// Instead of manual FutureBuilder
AsyncWidget<List<Document>>(
  future: documentService.fetchDocuments(),
  builder: (documents) => DocumentList(documents: documents),
  errorMessage: 'Failed to load documents',
  onRetry: () => documentService.fetchDocuments(),
)
```

### 5. Handle Network Operations Properly
```dart
// Use NetworkService instead of raw http
final response = await NetworkService.post(
  '$baseUrl/documents',
  headers: getAuthHeaders(),
  body: json.encode(documentData),
  context: 'DocumentService.createDocument',
);

final result = NetworkService.parseJsonResponse(
  response,
  context: 'DocumentService.createDocument',
);
```

## Migration Guide

### Updating Existing Services

1. **Import the new services:**
```dart
import '../services/error_service.dart';
import '../services/network_service.dart';
```

2. **Replace raw HTTP calls:**
```dart
// Old
final response = await http.get(Uri.parse(url));
if (response.statusCode == 200) {
  return json.decode(response.body);
}

// New
final response = await NetworkService.get(url, context: 'ServiceName.methodName');
return NetworkService.parseJsonResponse(response, context: 'methodName');
```

3. **Replace print statements:**
```dart
// Old
print('Error: $e');

// New
ErrorService.logError('Operation failed', error: e, context: 'ServiceName.methodName');
```

4. **Add user-friendly error handling:**
```dart
// Old
catch (e) {
  print('Error: $e');
  return null;
}

// New
catch (e) {
  ErrorService.handleError(
    'Failed to perform operation',
    error: e,
    context: 'ServiceName.methodName',
  );
  return null;
}
```

### Updating UI Components

1. **Use AsyncWidget for loading states:**
```dart
// Old
FutureBuilder<Data>(
  future: fetchData(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    return DataWidget(data: snapshot.data!);
  },
)

// New
AsyncWidget<Data>(
  future: fetchData(),
  builder: (data) => DataWidget(data: data),
  errorMessage: 'Failed to load data',
)
```

2. **Use AsyncButton for actions:**
```dart
// Old
ElevatedButton(
  onPressed: () async {
    try {
      await saveData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed')),
      );
    }
  },
  child: Text('Save'),
)

// New
AsyncButton(
  onPressed: () => saveData(),
  successMessage: 'Data saved successfully',
  errorMessage: 'Failed to save data',
  child: Text('Save'),
)
```

## Testing Error Handling

### Unit Tests
```dart
test('should handle network errors gracefully', () async {
  // Arrange
  when(mockHttp.get(any)).thenThrow(SocketException('No internet'));
  
  // Act
  final result = await service.fetchData();
  
  // Assert
  expect(result, isNull);
  verify(mockErrorService.handleError(any, error: any, context: any));
});
```

### Integration Tests
```dart
testWidgets('should show error message when API fails', (tester) async {
  // Arrange
  when(mockService.fetchData()).thenThrow(NetworkException('API unavailable'));
  
  // Act
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.text('API unavailable'), findsOneWidget);
});
```

## Monitoring and Analytics

The error handling system is designed to integrate with monitoring services:

1. **Error Logging**: All errors are logged with structured data
2. **User Impact Tracking**: Errors are categorized by severity
3. **Context Information**: Each error includes context about where it occurred
4. **Performance Metrics**: Network retry attempts and success rates are tracked

To integrate with services like Firebase Crashlytics or Sentry, update the `ErrorService.logError` method to send data to your preferred monitoring service.

## Conclusion

This error handling system provides:
- **Better user experience** with clear, actionable error messages
- **Improved debugging** with structured logging and context
- **Increased reliability** with retry mechanisms and graceful degradation
- **Easier maintenance** with centralized error handling patterns

Follow this guide to ensure consistent, user-friendly error handling throughout the application.
