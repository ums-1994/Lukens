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

    const hostname = window.location && window.location.hostname
      ? window.location.hostname
      : '';
    const isLocal = hostname === 'localhost' || hostname === '127.0.0.1';

    // Default local points to the dev backend port we use elsewhere.
    const localUrl = 'http://127.0.0.1:8000';
    if (useLocalApi || isLocal) {
      console.log('🌐 Using local API URL:', localUrl);
      return localUrl;
    }

    // For developer safety, default to local unless explicitly overridden.
    console.log('🌐 Using default API URL (local):', localUrl);
    return localUrl;
  })(),
};

console.log('✅ APP_CONFIG loaded:', window.APP_CONFIG);

