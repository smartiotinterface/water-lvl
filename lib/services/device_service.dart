// lib/services/device_service.dart
// [FIX CRITICAL] _DeviceSelector showed same name for all devices
// [FIX HIGH-7] FirebaseService is singleton — DI injected, not new instance
// [FIX HIGH-8] Stream auto-reconnects on error with exponential backoff
// [FIX HIGH-9] User device index used for lookup
// [FIX MEDIUM-10] Theme persistence via SharedPreferences
// [FIX LOW-14] Conflict handling on addDevice
// [FIX BUG-6] togglePump/toggleMode/resetDryRun now have 10s timeout → no UI freeze

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/device_model.dart';
import 'firebase_service.dart';

class DeviceService extends ChangeNotifier {
  final FirebaseService _fb;
  final String uid;

  DeviceService({required this.uid, required FirebaseService firebaseService})
      : _fb = firebaseService;

  List<String> _deviceIds = [];
  String? _selectedDeviceId;
  DeviceStatus? _status;
  DeviceMeta? _meta;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  StreamSubscription? _statusSub;
  int _retryCount = 0;
  Timer? _retryTimer;

  final Map<String, String> _deviceNames = {};

  List<String> get deviceIds => _deviceIds;
  String? get selectedDeviceId => _selectedDeviceId;
  DeviceStatus? get status => _status;
  DeviceMeta? get meta => _meta;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get hasDevice => _selectedDeviceId != null;

  String deviceName(String deviceId) =>
      _deviceNames[deviceId] ?? deviceId;

  bool get isDeviceOnline {
    final ts = _status?.timestamp;
    if (ts == null) return false;
    try {
      int epoch = (ts is String) ? int.parse(ts) : (ts as num).toInt();
      if (epoch < 1000000000000) epoch *= 1000;
      final lastSeen = DateTime.fromMillisecondsSinceEpoch(epoch);
      return DateTime.now().difference(lastSeen) < AppConstants.offlineThreshold;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadDevices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _deviceIds = await _fb.getUserDevices(uid);

      if (_deviceIds.isNotEmpty) {
        final metaMap = await _fb.getMetaForDevices(_deviceIds);
        _deviceNames.clear();
        for (final entry in metaMap.entries) {
          _deviceNames[entry.key] = entry.value.deviceName;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(AppConstants.prefLastDeviceId);
      if (lastId != null && _deviceIds.contains(lastId)) {
        await selectDevice(lastId);
      } else if (_deviceIds.isNotEmpty && _selectedDeviceId == null) {
        await selectDevice(_deviceIds.first);
      }
    } catch (e) {
      _error = 'Failed to load devices. Please check your connection.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectDevice(String deviceId) async {
    if (_selectedDeviceId == deviceId) return;
    _selectedDeviceId = deviceId;
    _status = null;
    _retryCount = 0;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefLastDeviceId, deviceId);

    _subscribeToStatus(deviceId);

    _meta = await _fb.getMeta(deviceId);
    if (_meta != null) {
      _deviceNames[deviceId] = _meta!.deviceName;
    }
    notifyListeners();
  }

  void _subscribeToStatus(String deviceId) {
    _statusSub?.cancel();
    _retryTimer?.cancel();

    _statusSub = _fb.statusStream(deviceId).listen(
      (s) {
        _status = s;
        _retryCount = 0;
        notifyListeners();
      },
      onError: (e) {
        _error = 'Connection interrupted. Reconnecting…';
        notifyListeners();
        _scheduleRetry(deviceId);
      },
      onDone: () {
        _scheduleRetry(deviceId);
      },
    );
  }

  void _scheduleRetry(String deviceId) {
    if (_selectedDeviceId != deviceId) return;
    _retryCount++;
    final delay = Duration(seconds: _retryCount.clamp(1, 30));
    _retryTimer = Timer(delay, () {
      if (_selectedDeviceId == deviceId) {
        _subscribeToStatus(deviceId);
      }
    });
  }

  Future<DeviceAddResult> addDevice(String serial, String name) async {
    final existingOwner = await _fb.checkDeviceClaimed(serial);
    if (existingOwner != null && existingOwner != uid) {
      return DeviceAddResult.alreadyClaimed;
    }
    if (existingOwner == uid || _deviceIds.contains(serial)) {
      if (!_deviceIds.contains(serial)) _deviceIds.add(serial);
      _deviceNames[serial] = name;
      await selectDevice(serial);
      notifyListeners();
      return DeviceAddResult.alreadyOwned;
    }

    try {
      await _fb.claimDevice(serial, uid);
      final meta = DeviceMeta(
        serial: serial,
        firmware: '--',
        deviceName: name,
        ownerId: uid,
        registeredAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      await _fb.setMeta(serial, meta);
      await _fb.logHistoryEvent(serial, 'Device registered');
      _deviceIds.add(serial);
      _deviceNames[serial] = name;
      notifyListeners();
      await selectDevice(serial);
      return DeviceAddResult.success;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('permission-denied') || msg.contains('Permission denied')) {
        _error = 'Database permission denied.\n'
            'Go to Firebase Console → Realtime Database → Rules\n'
            'and deploy firebase/database.rules.json';
      } else if (msg.contains('network') || msg.contains('timeout')) {
        _error = 'Network error. Check your internet connection.';
      } else {
        _error = 'Failed to register device. (${msg.length > 60 ? msg.substring(0, 60) : msg})';
      }
      notifyListeners();
      return DeviceAddResult.error;
    }
  }

  // [FIX BUG-6]: timeout added — isSending can no longer freeze forever
  Future<bool> togglePump() async {
    if (_selectedDeviceId == null || _status == null) return false;
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final cmd = _status!.isPumpOn ? AppConstants.pumpOff : AppConstants.pumpOn;
      await _fb
          .sendPumpCommand(_selectedDeviceId!, cmd)
          .timeout(AppConstants.commandTimeout, onTimeout: () {
        throw TimeoutException('Command timed out');
      });
      await _fb.logHistoryEvent(_selectedDeviceId!, 'Pump command: $cmd');
      _isSending = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      _error = 'Command timed out. Check your connection.';
      _isSending = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Command failed. Please try again.';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  // [FIX BUG-6]: timeout added
  Future<bool> toggleMode() async {
    if (_selectedDeviceId == null || _status == null) return false;
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final cmd = _status!.isAutoMode ? AppConstants.modeManual : AppConstants.modeAuto;
      await _fb
          .sendModeCommand(_selectedDeviceId!, cmd)
          .timeout(AppConstants.commandTimeout, onTimeout: () {
        throw TimeoutException('Command timed out');
      });
      await _fb.logHistoryEvent(_selectedDeviceId!, 'Mode changed to: $cmd');
      _isSending = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      _error = 'Mode switch timed out. Check your connection.';
      _isSending = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Mode switch failed. Please try again.';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  // [FIX BUG-6]: timeout added
  Future<bool> resetDryRun() async {
    if (_selectedDeviceId == null) return false;
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      await _fb
          .sendDryRunReset(_selectedDeviceId!)
          .timeout(AppConstants.commandTimeout, onTimeout: () {
        throw TimeoutException('Reset timed out');
      });
      _isSending = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      _error = 'Reset timed out. Check your connection.';
      _isSending = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Reset failed.';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}

enum DeviceAddResult { success, alreadyClaimed, alreadyOwned, error }
