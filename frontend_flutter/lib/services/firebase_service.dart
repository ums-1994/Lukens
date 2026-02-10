import 'dart:async';

class FirebaseService {
  static Object? get currentUser => null;

  static Stream<Object?> get authStateChanges => const Stream<Object?>.empty();

  static Future<Object?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
  }) async {
    return null;
  }

  static Future<Object?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return null;
  }

  static Future<void> sendEmailVerification() async {}

  static Future<void> signOut() async {}

  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    return null;
  }

  static Future<void> updateUserData(String uid, Map<String, dynamic> data) async {}

  static bool get isEmailVerified => false;

  static Future<void> reloadUser() async {}
}
