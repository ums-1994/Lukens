import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:jwt_decode/jwt_decode.dart';
import '../config/jwt_config.dart';

class JwtService {
  /// Decrypt and validate JWT token
  static Map<String, dynamic>? decryptToken(String token) {
    try {
      // First decode the JWT to get the payload
      final payload = Jwt.parseJwt(token);
      
      // Verify the token signature (simplified version)
      // In a real implementation, you'd verify against the secret
      if (!_verifyTokenSignature(token)) {
        throw Exception('Invalid token signature');
      }
      
      // Check if token is expired
      if (Jwt.isExpired(token)) {
        throw Exception('Token has expired');
      }
      
      return payload;
    } catch (e) {
      print('JWT decryption error: $e');
      return null;
    }
  }
  
  /// Verify JWT token signature (simplified implementation)
  static bool _verifyTokenSignature(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      final header = parts[0];
      final payload = parts[1];
      final signature = parts[2];
      
      // Create the signing input
      final signingInput = '$header.$payload';
      
      // Create HMAC SHA256 signature
      final key = utf8.encode(JwtConfig.jwtSecret);
      final bytes = utf8.encode(signingInput);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);
      
      // Base64 url encode the signature
      final computedSignature = base64Url.encode(digest.bytes);
      
      // Compare signatures (remove padding if present)
      final cleanComputed = _removeBase64Padding(computedSignature);
      final cleanSignature = _removeBase64Padding(signature);
      
      return cleanComputed == cleanSignature;
    } catch (e) {
      print('Signature verification error: $e');
      return false;
    }
  }
  
  /// Remove base64 padding for comparison
  static String _removeBase64Padding(String base64) {
    return base64.replaceAll('=', '');
  }
  
  /// Get user information from decrypted token
  static Map<String, dynamic>? getUserFromToken(String token) {
    final payload = decryptToken(token);
    if (payload == null) return null;
    
    // Extract user information from payload
    return {
      'id': payload['sub'] ?? payload['user_id'],
      'email': payload['email'] ?? payload['sub'],
      'role': payload['role'] ?? 'user',
      'name': payload['name'] ?? payload['full_name'] ?? 'User',
      'exp': payload['exp'],
      'iat': payload['iat'],
    };
  }
  
  /// Check if token will expire within the specified minutes
  static bool willExpireSoon(String token, {int minutesWithin = 5}) {
    try {
      final payload = Jwt.parseJwt(token);
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final timeUntilExpiry = exp - now;
      
      return timeUntilExpiry <= (minutesWithin * 60);
    } catch (e) {
      return true; // Assume expired if can't parse
    }
  }
}
