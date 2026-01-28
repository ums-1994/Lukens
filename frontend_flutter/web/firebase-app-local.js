// Local Firebase App SDK
// This is a minimal implementation that mimics the real Firebase SDK

class FirebaseApp {
  constructor(options) {
    this.name = '[DEFAULT]';
    this.options = options;
  }
}

// Export the initializeApp function
window.initializeApp = function(options) {
  console.log('🔧 Local Firebase App initialized:', options);
  return new FirebaseApp(options);
};

// Mock other Firebase functions that might be needed
window.getApps = function() {
  return [];
};

window.getApp = function() {
  return window.firebaseApp;
};

console.log('✅ Local Firebase App SDK loaded');
