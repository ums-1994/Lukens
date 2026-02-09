import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:jwt_decode/jwt_decode.dart';
import '../config/jwt_config.dart';

class JwtService {
  /// Decrypt and validate JWT token
  static Map<String, dynamic>? decryptToken(String token) {
    try {
      final normalized = _normalizeToken(token);
      print('🔑 Parsing JWT token...');

      // Check if token is empty after normalization
      if (normalized.isEmpty) {
        print('❌ Invalid JWT: Token is empty after normalization');
        return null;
      }

      // Check if token has the correct format (3 parts separated by dots)
      final parts = normalized.split('.');
      if (parts.length != 3) {
        print('❌ Invalid JWT format: Expected 3 parts, got ${parts.length}');
        print(
            '📍 Token preview: ${normalized.length > 50 ? normalized.substring(0, 50) + '...' : normalized}');
        return null;
      }

      // First decode the JWT to get the payload
      final payload = Jwt.parseJwt(normalized);
      print('✅ JWT payload decoded successfully');

      // Verify the token signature (simplified version)
      if (!_verifyTokenSignature(normalized)) {
        print('❌ JWT signature verification failed');
        throw Exception('Invalid token signature');
      }

      // Check if token is expired
      if (Jwt.isExpired(normalized)) {
        print('❌ JWT token has expired');
        throw Exception('Token has expired');
      }

      print('✅ JWT token validation successful');
      return payload;
    } catch (e) {
      print('❌ JWT decryption error: $e');
      return null;
    }
  }

  /// Normalize token strings (strip Bearer, quotes, URL params/encoding, whitespace)
  static String _normalizeToken(String token) {
    print(
        '🔍 Original token: "${token.substring(0, token.length > 50 ? 50 : token.length)}${token.length > 50 ? '...' : ''}"');

    String t = token.trim();

    // If full URL pasted, try extract token query param
    try {
      final uri = Uri.parse(t);
      if (uri.queryParameters.containsKey('token')) {
        t = uri.queryParameters['token']!.trim();
        print(
            '🔍 Extracted token from URL: "${t.substring(0, t.length > 50 ? 50 : t.length)}${t.length > 50 ? '...' : ''}"');
      }
    } catch (_) {
      // Not a URL
    }

    // Strip common prefixes and wrappers
    if (t.toLowerCase().startsWith('bearer ')) {
      t = t.substring(7).trim();
      print('🔍 Removed Bearer prefix');
    }
    if ((t.startsWith('"') && t.endsWith('"')) ||
        (t.startsWith("'") && t.endsWith("'"))) {
      t = t.substring(1, t.length - 1).trim();
      print('🔍 Removed quotes');
    }

    // Decode percent-encoding if any
    try {
      t = Uri.decodeComponent(t);
      print('🔍 Decoded percent encoding');
    } catch (_) {}

    // Remove whitespace/newlines
    t = t.replaceAll(RegExp(r"\s+"), '');

    print(
        '🔍 Normalized token: "${t.substring(0, t.length > 50 ? 50 : t.length)}${t.length > 50 ? '...' : ''}"');
    print('🔍 Token length: ${t.length}');

    return t;
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

    // Extract user information from KHONOBUZZ JWT payload
    final roles = payload['roles'] as List<dynamic>? ?? [];
    final userRole = _determineUserRole(roles);

    return {
      'id': payload['user_id'] ?? payload['sub'],
      'email': payload['email'] ?? '',
      'full_name': payload['full_name'] ?? payload['name'] ?? 'User',
      'role': userRole,
      'roles': roles, // Keep original roles array for reference
      'exp': payload['exp'],
      'iat': payload['iat'],
    };
  }

  /// Determine user role based on KHONOBUZZ roles array
  static String _determineUserRole(List<dynamic> roles) {
    // Check for admin role first (highest priority)
    if (roles.contains('Proposal & SOW Builder - Admin')) {
      print('👑 Admin role detected: Proposal & SOW Builder - Admin');
      return 'admin';
    }

    // Check for manager roles
    if (roles.contains('Proposal & SOW Builder - Manager') ||
        roles.contains('Skills Heatmap - Manager')) {
      print('👔 Manager role detected');
      return 'manager';
    }

    // Check for creator roles
    if (roles.contains('Proposal & SOW Builder - Creator') ||
        roles.contains('PDH - Employee')) {
      print('👤 Creator role detected');
      return 'creator';
    }

    // Default to user role
    print('👤 Default user role assigned');
    return 'user';
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
