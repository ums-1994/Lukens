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
    // Default based on runtime hostname
    const hostname = (window.location && window.location.hostname) ? window.location.hostname : '';
    const isLocalHost = hostname === 'localhost' || hostname === '127.0.0.1';
    // Your backend is hosted on Render; when running the UI locally, default to Render too.
    // If you *do* want a local backend, set `window.APP_API_URL` (or `window.REACT_APP_API_URL`)
    // to something like `http://127.0.0.1:5000` before this script runs.
    const defaultUrl = isLocalHost ? 'https://lukens-wp8w.onrender.com' : 'https://lukens-wp8w.onrender.com';
    console.log('🌐 Using default API URL:', defaultUrl);
    return defaultUrl;
  })(),
};

console.log('✅ APP_CONFIG loaded:', window.APP_CONFIG);

