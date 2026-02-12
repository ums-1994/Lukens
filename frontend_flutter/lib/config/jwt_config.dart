class JwtConfig {
  static const String secretKey = 'your-secret-key-here';
  static const String jwtSecret = secretKey;
  static const Duration tokenExpiry = Duration(hours: 24);
}
