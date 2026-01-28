// Local Firebase fallback for development
// This bypasses network issues by providing mock Firebase services

window.firebaseApp = {
  name: '[DEFAULT]',
  options: {
    apiKey: "AIzaSyC0WT1ArMcm6Ah8jM_hNaE9uffM1aTriBc",
    authDomain: "lukens-e17d6.firebaseapp.com",
    projectId: "lukens-e17d6",
    storageBucket: "lukens-e17d6.firebasestorage.app",
    messagingSenderId: "940107272310",
    appId: "1:940107272310:web:bc6601706e2fe1d94d8f57"
  }
};

window.firebaseAuth = {
  currentUser: null,
  onAuthStateChanged: function(callback) {
    // Mock auth state change listener
    console.log('Mock Firebase auth listener registered');
  },
  signInWithEmailAndPassword: function(email, password) {
    return Promise.resolve({
      user: {
        uid: 'mock-user-123',
        email: email,
        getIdToken: function() {
          return Promise.resolve('mock-firebase-token-for-testing');
        }
      }
    });
  }
};

window.firebaseDb = {
  collection: function(name) {
    return {
      doc: function(id) {
        return {
          get: function() {
            return Promise.resolve({
              exists: true,
              data: function() {
                return { mock: 'data' };
              }
            });
          }
        };
      }
    };
  }
};

window.firebaseAnalytics = {
  logEvent: function(name, params) {
    console.log('Mock analytics event:', name, params);
  }
};

console.log('✅ Mock Firebase services loaded (local fallback)');
