// Runtime configuration for API URL
// This file is loaded before the Flutter app starts
console.log('🔧 Loading config.js...');
console.log('🔧 Current hostname:', window.location.hostname);
console.log('🔧 Current origin:', window.location.origin);

window.APP_CONFIG = {
  // API URL - can be overridden by environment variable or build-time replacement
  API_URL: (function() {
    // Check for environment variable (set in Netlify dashboard)
    if (window.REACT_APP_API_URL) {
      console.log('🌐 Using REACT_APP_API_URL:', window.REACT_APP_API_URL);
      return window.REACT_APP_API_URL;
    }
    // Check for config in window (can be set via script tag in index.html)
    if (window.APP_API_URL) {
      console.log('🌐 Using APP_API_URL:', window.APP_API_URL);
      return window.APP_API_URL;
    }
    // Default to Render backend URL for production
    const isRender = window.location.hostname.includes('onrender.com');
    const isProduction = isRender || window.location.hostname !== 'localhost';
    const defaultUrl = isProduction 
        ? 'https://backend-sow.onrender.com' 
        : 'http://localhost:8000';
    console.log('🌐 Environment detection:');
    console.log('  - isRender:', isRender);
    console.log('  - isProduction:', isProduction);
    console.log('🌐 Using default API URL:', defaultUrl);
    return defaultUrl;
  })(),
};

console.log('✅ APP_CONFIG loaded:', window.APP_CONFIG);

