class JwtConfig {
  // JWT Configuration - These match your backend .env values
  static const String jwtSecret = 'PudwjIQa-kMPoQ8KCE9OqN3-HnIu2P12Dkf2U6rFH8I=';
  static const String encryptionKey = '50g5j-Pa1SXyyABDbrghP0Spo1lZnQIGoWAIZBM_zZ0=';
  
  // Alternative: Load from environment variables (more secure)
  // You can set these in your build process or runtime environment
  static String get jwtSecretEnv {
    // For web, you can expose these through window object
    // For mobile, use flutter_dotenv or secure storage
    return jwtSecret; // Fallback to constant
  }
  
  static String get encryptionKeyEnv {
    return encryptionKey; // Fallback to constant
  }
  
  // Token validation settings
  static const int tokenExpiryBufferMinutes = 5;
  static const bool enableLocalDecryption = true;
  static const bool fallbackToBackend = true;
}
