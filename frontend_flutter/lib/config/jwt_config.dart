class JwtConfig {
  // JWT Configuration - These should match your backend .env values
  // IMPORTANT: Replace these with your actual JWT secret and encryption key
  static const String jwtSecret = 'your-super-secret-jwt-key-change-this-in-production';
  static const String encryptionKey = 'your-encryption-key-32-chars-long';
  
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
