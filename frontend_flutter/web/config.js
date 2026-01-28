// Runtime configuration for API URL
// This file is loaded before the Flutter app starts

(function () {
  // 1) Allow overriding via window variables (handy for deployments)
  if (window.REACT_APP_API_URL) {
    console.log("🌐 Using REACT_APP_API_URL:", window.REACT_APP_API_URL);
    window.APP_CONFIG = { API_URL: window.REACT_APP_API_URL };
    console.log("✅ APP_CONFIG loaded:", window.APP_CONFIG);
    return;
  }

  if (window.APP_API_URL) {
    console.log("🌐 Using APP_API_URL:", window.APP_API_URL);
    window.APP_CONFIG = { API_URL: window.APP_API_URL };
    console.log("✅ APP_CONFIG loaded:", window.APP_CONFIG);
    return;
  }

  // 2) Local default (for local testing)
  const defaultUrl = "http://127.0.0.1:8000";
  console.log("🌐 Using default API URL:", defaultUrl);

  window.APP_CONFIG = { API_URL: defaultUrl };
  console.log("✅ APP_CONFIG loaded:", window.APP_CONFIG);
})();
