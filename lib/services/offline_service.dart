// lib/services/offline_service.dart
// Hive-based offline cache for last-known device status
// Shows stale data when the app or device is offline

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class OfflineService {
  OfflineService._();

  static const String _boxName   = 'device_cache';
  static const String _keyPrefix = 'status_';

  static Box? _box;

  // ── Init (call once in main.dart before runApp) ─────────────────────
  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    debugPrint('[Offline] Hive cache ready (${_box!.length} entries)');
  }

  // ── Cache a device status snapshot ───────────────────────────────────
  static Future<void> saveStatus(
      String deviceId, Map<String, dynamic> status) async {
    if (_box == null || !_box!.isOpen) return;
    try {
      await _box!.put('$_keyPrefix$deviceId', {
        ...status,
        '_cached_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('[Offline] Save failed: $e');
    }
  }

  // ── Load last-cached status ───────────────────────────────────────────
  static Map<String, dynamic>? loadStatus(String deviceId) {
    if (_box == null || !_box!.isOpen) return null;
    try {
      final raw = _box!.get('$_keyPrefix$deviceId');
      if (raw == null) return null;
      return Map<String, dynamic>.from(raw as Map);
    } catch (e) {
      debugPrint('[Offline] Load failed: $e');
      return null;
    }
  }

  // ── Check how old the cache is ────────────────────────────────────────
  static Duration? cacheAge(String deviceId) {
    final data = loadStatus(deviceId);
    if (data == null) return null;
    final cachedAt = data['_cached_at'] as int?;
    if (cachedAt == null) return null;
    return DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
  }

  // ── Invalidate cache for a device ────────────────────────────────────
  static Future<void> clearDevice(String deviceId) async {
    await _box?.delete('$_keyPrefix$deviceId');
  }

  // ── Clear all cached data ─────────────────────────────────────────────
  static Future<void> clearAll() async {
    await _box?.clear();
  }

  // ── Close Hive (call on app exit) ─────────────────────────────────────
  static Future<void> close() async {
    await _box?.close();
  }
}
