import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists a profile photo only on this device (SharedPreferences).
/// No server or database — tied to the signed-in user's email.
class LocalProfileAvatarStore {
  LocalProfileAvatarStore._();

  static const _kOwner = 'local_profile_avatar_owner_v1';
  static const _kData = 'local_profile_avatar_b64_v1';

  static String? _normalizeEmail(Map<String, dynamic>? user) {
    final e = user?['email']?.toString().trim().toLowerCase();
    if (e == null || e.isEmpty) return null;
    return e;
  }

  static Future<Uint8List?> loadForUser(Map<String, dynamic>? user) async {
    final email = _normalizeEmail(user);
    if (email == null) return null;
    final p = await SharedPreferences.getInstance();
    final owner = p.getString(_kOwner);
    final b64 = p.getString(_kData);
    if (owner != email || b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveForUser(
    Map<String, dynamic>? user,
    Uint8List bytes,
  ) async {
    final email = _normalizeEmail(user);
    if (email == null) {
      throw StateError('Cannot save avatar: user has no email');
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOwner, email);
    await p.setString(_kData, base64Encode(bytes));
  }

  static Future<void> clearForCurrentUser(Map<String, dynamic>? user) async {
    final email = _normalizeEmail(user);
    if (email == null) return;
    final p = await SharedPreferences.getInstance();
    if (p.getString(_kOwner) == email) {
      await p.remove(_kOwner);
      await p.remove(_kData);
    }
  }
}
