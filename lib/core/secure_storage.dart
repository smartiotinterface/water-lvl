// lib/core/secure_storage.dart
// Secure key-value storage using flutter_secure_storage
// Used for sensitive data: auth tokens, device pairing keys, etc.
// NEVER store plain passwords here — Firebase Auth handles that.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // AES-256 via Android Keystore
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── Keys ─────────────────────────────────────────────────────────────
  static const String _keyFcmToken    = 'fcm_token';
  static const String _keyLastUid     = 'last_uid';
  static const String _keyDeviceToken = 'device_token';

  // ── Write ─────────────────────────────────────────────────────────────
  static Future<void> setFcmToken(String token) async {
    await _storage.write(key: _keyFcmToken, value: token);
  }

  static Future<void> setLastUid(String uid) async {
    await _storage.write(key: _keyLastUid, value: uid);
  }

  static Future<void> setDeviceToken(String deviceId, String token) async {
    await _storage.write(key: '${_keyDeviceToken}_$deviceId', value: token);
  }

  // ── Read ──────────────────────────────────────────────────────────────
  static Future<String?> getFcmToken() async {
    return _storage.read(key: _keyFcmToken);
  }

  static Future<String?> getLastUid() async {
    return _storage.read(key: _keyLastUid);
  }

  static Future<String?> getDeviceToken(String deviceId) async {
    return _storage.read(key: '${_keyDeviceToken}_$deviceId');
  }

  // ── Delete ────────────────────────────────────────────────────────────
  static Future<void> deleteDeviceToken(String deviceId) async {
    await _storage.delete(key: '${_keyDeviceToken}_$deviceId');
  }

  /// Clear all secure data on logout
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
