// lib/services/firebase_service.dart
// [FIX CRITICAL] sendDryRunReset was outside the class body — moved inside
// [FIX CRITICAL-4] getUserDevices uses /users/{uid}/devices index
// [FIX CRITICAL-5] Sharing path fixed to /device_shared/{deviceId}/{uid}
// [FIX HIGH-9] User device index maintained on addDevice

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/device_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance; // Singleton
  FirebaseService._internal();

  final _db = FirebaseDatabase.instance;

  // ── Status Stream ──────────────────────────────────────────
  Stream<DeviceStatus?> statusStream(String deviceId) {
    return _db
        .ref('${AppConstants.devicesPath}/$deviceId/${AppConstants.statusPath}')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      if (data is Map) {
        return DeviceStatus.fromMap(Map<dynamic, dynamic>.from(data));
      }
      return null;
    });
  }

  // ── Meta ───────────────────────────────────────────────────
  Future<DeviceMeta?> getMeta(String deviceId) async {
    final snap = await _db
        .ref('${AppConstants.devicesPath}/$deviceId/${AppConstants.metaPath}')
        .get();
    if (!snap.exists || snap.value == null) return null;
    return DeviceMeta.fromMap(Map<dynamic, dynamic>.from(snap.value as Map));
  }

  Future<void> setMeta(String deviceId, DeviceMeta meta) async {
    await _db
        .ref('${AppConstants.devicesPath}/$deviceId/${AppConstants.metaPath}')
        .update(meta.toMap());
  }

  // ── Control Commands ───────────────────────────────────────
  Future<void> sendPumpCommand(String deviceId, String command) async {
    await _db
        .ref('${AppConstants.devicesPath}/$deviceId/${AppConstants.controlPath}')
        .update({
      AppConstants.fieldPumpCommand: command.toUpperCase(),
      AppConstants.fieldCmdTimestamp:
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  Future<void> sendModeCommand(String deviceId, String mode) async {
    await _db
        .ref('${AppConstants.devicesPath}/$deviceId/${AppConstants.controlPath}')
        .update({
      AppConstants.fieldModeCommand: mode.toUpperCase(),
      AppConstants.fieldCmdTimestamp:
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  // ── Dry-run reset ──────────────────────────────────────────
  /// [FIX CRITICAL] This method was accidentally placed OUTSIDE the class
  /// in the original file, causing a compile error. Fixed here.
  Future<void> sendDryRunReset(String deviceId) async {
    await _db
        .ref('${AppConstants.devicesPath}/$deviceId/${AppConstants.controlPath}')
        .update({
      AppConstants.fieldDryRunReset: true,
      AppConstants.fieldCmdTimestamp:
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  // ── Device Ownership ──────────────────────────────────────
  Future<void> claimDevice(String deviceId, String uid) async {
    // Atomic multi-path update: set ownership AND user device index
    await _db.ref().update({
      '${AppConstants.deviceOwnersPath}/$deviceId': uid,
      '${AppConstants.usersPath}/$uid/devices/$deviceId': true,
    });
  }

  Future<String?> getDeviceOwner(String deviceId) async {
    final snap =
        await _db.ref('${AppConstants.deviceOwnersPath}/$deviceId').get();
    return snap.exists ? snap.value?.toString() : null;
  }

  /// [FIX CRITICAL-4]: Use user device index instead of scanning device_owners
  Future<List<String>> getUserDevices(String uid) async {
    final snap = await _db
        .ref('${AppConstants.usersPath}/$uid/devices')
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    // Filter only entries with value == true
    return map.entries
        .where((e) => e.value == true)
        .map((e) => e.key.toString())
        .toList();
  }

  // ── Device Sharing — [FIX CRITICAL-5] Correct path ────────
  /// Share device with another user by their UID
  Future<void> shareDevice(String deviceId, String targetUid) async {
    await _db
        .ref('${AppConstants.deviceSharedPath}/$deviceId/$targetUid')
        .set(true);
  }

  /// Remove sharing for a user
  Future<void> unshareDevice(String deviceId, String targetUid) async {
    await _db
        .ref('${AppConstants.deviceSharedPath}/$deviceId/$targetUid')
        .remove();
  }

  /// Get list of UIDs this device is shared with
  Future<List<String>> getSharedUsers(String deviceId) async {
    final snap = await _db
        .ref('${AppConstants.deviceSharedPath}/$deviceId')
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return map.entries
        .where((e) => e.value == true)
        .map((e) => e.key.toString())
        .toList();
  }

  // ── User Profile ──────────────────────────────────────────
  Future<void> saveUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.ref('${AppConstants.usersPath}/$uid/profile').update(data);
  }

  // [FIX CRITICAL] Upload FCM token to RTDB so Cloud Functions can send push notifications
  // Without this, /users/{uid}/fcmToken is never written, so onStatusChange FCM calls always fail.
  Future<void> uploadFcmToken(String uid, String token) async {
    await _db.ref('users/$uid/fcmToken').set(token);
    debugPrint('[FCM] Token uploaded to RTDB for uid=$uid');
  }

  /// Save user preferences (theme, FCM token, etc.)
  Future<void> savePreference(String uid, String key, dynamic value) async {
    await _db
        .ref('${AppConstants.usersPath}/$uid/preferences/$key')
        .set(value);
  }

  // ── History ────────────────────────────────────────────────
  Future<void> logHistoryEvent(String deviceId, String event) async {
    final entry = {
      'event': event,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    await _db
        .ref('${AppConstants.devicesPath}/$deviceId/history')
        .push()
        .set(entry);
  }

  /// Fetch last N history entries
  Future<List<Map<String, dynamic>>> getHistory(
      String deviceId, {int limit = 20}) async {
    final snap = await _db
        .ref('${AppConstants.devicesPath}/$deviceId/history')
        .orderByChild('ts')
        .limitToLast(limit)
        .get();
    if (!snap.exists || snap.value == null) return [];
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return map.values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList()
      ..sort((a, b) =>
          (b['ts'] as int).compareTo(a['ts'] as int));
  }

  // ── Schedules ─────────────────────────────────────────────
  Future<void> saveSchedule(
      String deviceId, String scheduleId, Map<String, dynamic> data) async {
    await _db
        .ref('schedules/$deviceId/$scheduleId')
        .set(data);
  }

  Future<List<Map<String, dynamic>>> getSchedules(String deviceId) async {
    final snap = await _db.ref('schedules/$deviceId').get();
    if (!snap.exists || snap.value == null) return [];
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return map.entries
        .map((e) => {
              'id': e.key.toString(),
              ...Map<String, dynamic>.from(e.value as Map),
            })
        .toList();
  }

  Future<void> deleteSchedule(String deviceId, String scheduleId) async {
    await _db.ref('schedules/$deviceId/$scheduleId').remove();
  }

  // ── Check if device already claimed ───────────────────────
  /// Returns null if unclaimed, ownerId if claimed
  Future<String?> checkDeviceClaimed(String deviceId) async {
    try {
      final snap =
          await _db.ref('${AppConstants.deviceOwnersPath}/$deviceId').get();
      if (!snap.exists) return null;
      return snap.value?.toString();
    } catch (_) {
      return null;
    }
  }

  // ── Bulk meta fetch for device list ───────────────────────
  /// Fetch meta for multiple devices in parallel
  Future<Map<String, DeviceMeta>> getMetaForDevices(
      List<String> deviceIds) async {
    if (deviceIds.isEmpty) return {};
    final futures = deviceIds.map((id) async {
      final meta = await getMeta(id);
      return MapEntry(id, meta);
    });
    final results = await Future.wait(futures);
    final map = <String, DeviceMeta>{};
    for (final entry in results) {
      if (entry.value != null) map[entry.key] = entry.value!;
    }
    return map;
  }
}
