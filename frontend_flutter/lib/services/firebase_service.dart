import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to safely execute Firebase operations
  static Future<T?> _safeExecute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      // Handle JavaScript interop errors specifically
      if (e.toString().contains('JavaScriptObject') ||
          e.toString().contains('FirebaseException')) {
        print('Firebase interop error caught: ${e.toString()}');
        return null;
      }
      rethrow;
    }
  }

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get auth state changes stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  static Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile
      await result.user?.updateDisplayName('$firstName $lastName');

      // Save additional user data to Firestore
      await _firestore.collection('users').doc(result.user?.uid).set({
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'isEmailVerified': false,
      });

      return result;
    } catch (e) {
      // Handle Firebase exceptions properly for web
      String errorMessage = 'Registration failed. Please try again.';

      // Check if it's a FirebaseAuthException
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'An account already exists with this email address.';
            break;
          case 'weak-password':
            errorMessage =
                'Password is too weak. Please choose a stronger password.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Email/password accounts are not enabled.';
            break;
          default:
            errorMessage =
                'Registration failed: ${e.message ?? 'Unknown error'}';
        }
      } else {
        // Handle JavaScript interop errors
        String errorString = e.toString();
        if (errorString.contains('email-already-in-use')) {
          errorMessage = 'An account already exists with this email address.';
        } else if (errorString.contains('weak-password')) {
          errorMessage =
              'Password is too weak. Please choose a stronger password.';
        } else if (errorString.contains('invalid-email')) {
          errorMessage = 'Invalid email address.';
        } else if (errorString.contains('operation-not-allowed')) {
          errorMessage = 'Email/password accounts are not enabled.';
        } else if (errorString.contains('JavaScriptObject')) {
          // This is the specific interop error we're seeing
          errorMessage =
              'Authentication service temporarily unavailable. Please try again.';
        }
      }

      print('Error signing up: $errorMessage');
      return null;
    }
  }

  // Sign in with email and password
  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Use safe wrapper to handle JavaScript interop errors
    final result = await _safeExecute(() => _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ));

    if (result != null) {
      return result;
    }

    // If safe wrapper returned null, try the original method with error handling
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Handle Firebase exceptions properly for web
      String errorMessage = 'Login failed. Please check your credentials.';

      // Check if it's a FirebaseAuthException
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email address.';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many failed attempts. Please try again later.';
            break;
          case 'invalid-credential':
            errorMessage =
                'Invalid credentials. Please check your email and password.';
            break;
          default:
            errorMessage = 'Login failed: ${e.message ?? 'Unknown error'}';
        }
      } else {
        // Handle JavaScript interop errors
        String errorString = e.toString();
        if (errorString.contains('user-not-found')) {
          errorMessage = 'No user found with this email address.';
        } else if (errorString.contains('wrong-password')) {
          errorMessage = 'Incorrect password.';
        } else if (errorString.contains('invalid-email')) {
          errorMessage = 'Invalid email address.';
        } else if (errorString.contains('user-disabled')) {
          errorMessage = 'This account has been disabled.';
        } else if (errorString.contains('too-many-requests')) {
          errorMessage = 'Too many failed attempts. Please try again later.';
        } else if (errorString.contains('invalid-credential')) {
          errorMessage =
              'Invalid credentials. Please check your email and password.';
        } else if (errorString.contains('JavaScriptObject')) {
          // This is the specific interop error we're seeing
          errorMessage =
              'Authentication service temporarily unavailable. Please try again.';
        }
      }

      print('Error signing in: $errorMessage');
      return null;
    }
  }

  // Send email verification
  static Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      print('Error sending email verification: $e');
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Get user data from Firestore
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data in Firestore
  static Future<void> updateUserData(
      String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print('Error updating user data: $e');
    }
  }

  // Check if email is verified
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Reload user to get latest data
  static Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }
}
