// Runtime configuration for API URL
// This file is loaded before the Flutter app starts
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
    // Optional local override: set window.USE_LOCAL_API=true (or "true") in index.html
    // before this script loads.
    const useLocalApi = window.USE_LOCAL_API === true || window.USE_LOCAL_API === 'true';
    if (useLocalApi) {
      const localUrl = 'http://127.0.0.1:5000';
      console.log('🌐 Using local API URL (USE_LOCAL_API):', localUrl);
      return localUrl;
    }
    // Default based on runtime hostname
    const hostname = (window.location && window.location.hostname) ? window.location.hostname : '';
    const defaultUrl = 'https://lukens-wp8w.onrender.com';
    console.log('🌐 Using default API URL (Backend A):', defaultUrl);
    return defaultUrl;
  })(),
};

console.log('✅ APP_CONFIG loaded:', window.APP_CONFIG);

