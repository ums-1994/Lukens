// Import the functions you need from the SDKs you need
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";
import { getAnalytics } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-analytics.js";

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyC0WT1ArMcm6Ah8jM_hNaE9uffM1aTriBc",
  authDomain: "lukens-e17d6.firebaseapp.com",
  databaseURL: "https://lukens-e17d6-default-rtdb.firebaseio.com",
  projectId: "lukens-e17d6",
  storageBucket: "lukens-e17d6.firebasestorage.app",
  messagingSenderId: "940107272310",
  appId: "1:940107272310:web:bc6601706e2fe1d94d8f57",
  measurementId: "G-QBLQ7YBNGQ"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase Authentication and get a reference to the service
const auth = getAuth(app);

// Initialize Cloud Firestore and get a reference to the service
const db = getFirestore(app);

// Initialize Analytics
const analytics = getAnalytics(app);

// Export for use in Flutter
window.firebaseApp = app;
window.firebaseAuth = auth;
window.firebaseDb = db;
window.firebaseAnalytics = analytics;
