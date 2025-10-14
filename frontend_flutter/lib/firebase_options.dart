import 'package:firebase_core/firebase_core.dart';

// Fill these values with your Firebase Web app credentials
// Get them from Firebase Console > Project Settings > Your apps > Firebase SDK snippet (Config)
class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    messagingSenderId: 'YOUR_SENDER_ID',
    appId: 'YOUR_WEB_APP_ID',
    measurementId: 'YOUR_MEASUREMENT_ID',
  );
}
