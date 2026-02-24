// Import the functions you need from the SDKs you need
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { getAnalytics } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-analytics.js";

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = window.FIREBASE_CONFIG;

if (!firebaseConfig) {
  console.warn('⚠️ FIREBASE_CONFIG not provided. Firebase will not be initialized.');
} else {
  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  const db = getFirestore(app);
  const analytics = getAnalytics(app);

  window.firebaseApp = app;
  window.firebaseAuth = auth;
  window.firebaseDb = db;
  window.firebaseAnalytics = analytics;
}
