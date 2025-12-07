// Runtime configuration for API URL
// This file is loaded before the Flutter app starts
window.APP_CONFIG = {
  // API URL - can be overridden by environment variable or build-time replacement
  API_URL: (function() {
    // Check for environment variable (set in Render dashboard)
    if (window.REACT_APP_API_URL) {
      return window.REACT_APP_API_URL;
    }
    // Check for config in window (can be set via script tag in index.html)
    if (window.APP_API_URL) {
      return window.APP_API_URL;
    }
    // Default to production backend URL
    return 'https://lukens-wp8w.onrender.com';
  })(),
};

