class FeatureFlags {
  // Toggle to enable the new Operations Control Center dashboard UI.
  // Default to true in development; can be overridden via window.APP_CONFIG or env in future.
  static bool get enableNewDashboard => true;
}
