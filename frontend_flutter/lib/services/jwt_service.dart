import 'dart:convert';

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
      final payload = _parseJwtPayload(normalized);
      print('✅ JWT payload decoded successfully');

      // Check if token is expired
      if (_isExpiredFromPayload(payload)) {
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

  /// Parse the JWT payload (claims) without verifying signature.
  ///
  /// Note: In a client app you typically **do not** have the secret key, so you
  /// can’t (and shouldn’t) verify HMAC signatures here. Treat this as claim
  /// extraction only; the backend must validate the token.
  static Map<String, dynamic> _parseJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Invalid JWT format');
    }

    final payloadPart = parts[1];
    final normalized = base64Url.normalize(payloadPart);
    final decodedJson = utf8.decode(base64Url.decode(normalized));
    final decoded = json.decode(decodedJson);

    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }

    throw const FormatException('Invalid JWT payload JSON');
  }

  static bool _isExpiredFromPayload(Map<String, dynamic> payload) {
    final exp = payload['exp'];
    if (exp is! num) return false; // if no expiry claim, treat as non-expiring

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return exp.toInt() <= nowSeconds;
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
      final payload = _parseJwtPayload(_normalizeToken(token));
      final exp = payload['exp'];
      if (exp is! num) return false;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final timeUntilExpiry = exp.toInt() - now;

      return timeUntilExpiry <= (minutesWithin * 60);
    } catch (e) {
      return true; // Assume expired if can't parse
    }
  }
}
