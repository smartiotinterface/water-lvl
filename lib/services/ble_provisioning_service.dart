// lib/services/ble_provisioning_service.dart
// ──────────────────────────────────────────────────────────────────────────────
// BLE Provisioning Service — SmartIoT v2.3.0
// ──────────────────────────────────────────────────────────────────────────────
// BUG FIXES v2.3.0:
//   [FIX-1] requestMtu(512) — Large WiFi list notifications (8+ networks)
//           require MTU > 20 bytes. Without this, WIFI_LIST gets truncated.
//   [FIX-2] onValueReceived → replaces lastValueStream which emits stale
//           cached value on subscribe, causing spurious response handling.
//   [FIX-3] wifiConnecting timeout (35s) — If CONNECTED/FAILED notification
//           is lost (BLE drop after WiFi connects), app no longer hangs forever.
//   [FIX-4] Restart timeout on CONNECTING ack — timer resets when ESP32
//           confirms it received the command, giving full 35s for WiFi auth.
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── BLE UUIDs (must match ESP32 firmware) ─────────────────────────────────
const String bleServiceUuid = '12345678-1234-1234-1234-123456789abc';
const String bleCmdCharUuid = '12345678-1234-1234-1234-123456789abd';
const String bleRspCharUuid = '12345678-1234-1234-1234-123456789abe';

// ── Models ─────────────────────────────────────────────────────────────────
class BleWifiNetwork {
  final String ssid;
  final int rssi;
  final bool secured;

  const BleWifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.secured,
  });

  factory BleWifiNetwork.fromJson(Map<String, dynamic> j) => BleWifiNetwork(
        ssid: (j['s'] ?? j['ssid'] ?? '').toString(),
        rssi: (j['r'] ?? j['rssi'] ?? -100) as int,
        secured: (j['sec'] ?? true) as bool,
      );

  int get signalPercent {
    if (rssi >= -50) return 100;
    if (rssi <= -100) return 0;
    return ((rssi + 100) * 2).clamp(0, 100);
  }

  String get signalLabel {
    final q = signalPercent;
    if (q >= 75) return 'Excellent';
    if (q >= 50) return 'Good';
    if (q >= 25) return 'Fair';
    return 'Weak';
  }
}

// ── Provisioning state ─────────────────────────────────────────────────────
enum BleProvStep {
  idle,
  bluetoothOff,
  scanning,
  connecting,
  connected,
  wifiScanning,
  wifiReady,
  sending,
  wifiConnecting,
  success,
  failed,
}

// ── Service ────────────────────────────────────────────────────────────────
class BleProvisioningService extends ChangeNotifier {
  BleProvStep _step = BleProvStep.idle;
  String _message = '';
  String? _error;
  String? _connectedIp;

  List<ScanResult> _scanResults = [];
  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _rspChar;
  List<BleWifiNetwork> _wifiNetworks = [];

  StreamSubscription? _scanSub;
  StreamSubscription? _notifySub;
  StreamSubscription? _deviceStateSub;

  // [FIX-3] WiFi connecting timeout timer
  Timer? _wifiConnectTimer;

  BleProvStep get step => _step;
  String get message => _message;
  String? get error => _error;
  String? get connectedIp => _connectedIp;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  List<BleWifiNetwork> get wifiNetworks => List.unmodifiable(_wifiNetworks);
  BluetoothDevice? get connectedDevice => _device;

  bool get isScanning => _step == BleProvStep.scanning;
  bool get isBusy =>
      _step == BleProvStep.scanning ||
      _step == BleProvStep.connecting ||
      _step == BleProvStep.wifiScanning ||
      _step == BleProvStep.sending ||
      _step == BleProvStep.wifiConnecting;

  // ── Step 1: BLE scan ───────────────────────────────────────────────────
  Future<void> startScan() async {
    await _cleanup();
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _set(BleProvStep.bluetoothOff, 'Bluetooth is off. Please enable it.');
      return;
    }
    _scanResults = [];
    _set(BleProvStep.scanning, 'Scanning for nearby devices…');
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false,
      );
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results
            .where((r) => r.device.platformName.isNotEmpty)
            .toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        notifyListeners();
      });
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      if (_step == BleProvStep.scanning) {
        if (_scanResults.isEmpty) {
          _set(BleProvStep.failed,
              'No devices found. Make sure the ESP32 is powered on.');
        } else {
          _set(BleProvStep.idle, 'Select a device to connect.');
        }
      }
    } catch (e) {
      _setError('Scan failed: $e');
    }
  }

  void stopScan() => FlutterBluePlus.stopScan();

  // ── Step 2: Connect ────────────────────────────────────────────────────
  Future<void> connectToDevice(BluetoothDevice device) async {
    _set(BleProvStep.connecting, 'Connecting to ${device.platformName}…');
    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      _device = device;

      _deviceStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (_step != BleProvStep.success) {
            _cancelWifiConnectTimer();
            _setError('Device disconnected unexpectedly.');
          }
        }
      });

      // [FIX-1] Request larger MTU — without this, WIFI_LIST for 8+ networks
      // (≈330 bytes) gets silently truncated to 20 bytes (default MTU).
      // This is the #1 cause of "Failed to parse WiFi list" errors.
      _set(BleProvStep.connecting, 'Negotiating connection parameters…');
      try {
        await device.requestMtu(512);
        final mtu = await device.mtu.first;
        debugPrint('[BLE] MTU negotiated: $mtu bytes');
      } catch (e) {
        debugPrint('[BLE] MTU negotiation failed (non-fatal, continuing): $e');
      }

      _set(BleProvStep.connecting, 'Discovering services…');
      final services = await device.discoverServices();

      BluetoothService? iotService;
      for (final s in services) {
        if (s.uuid.toString().toLowerCase() == bleServiceUuid.toLowerCase()) {
          iotService = s;
          break;
        }
      }

      if (iotService == null) {
        await device.disconnect();
        _setError(
          'SmartIoT BLE service not found on this device.\n'
          'Make sure it runs firmware v10 or newer with BLE provisioning.',
        );
        return;
      }

      for (final c in iotService.characteristics) {
        final uid = c.uuid.toString().toLowerCase();
        if (uid == bleCmdCharUuid.toLowerCase()) _cmdChar = c;
        if (uid == bleRspCharUuid.toLowerCase()) _rspChar = c;
      }

      if (_cmdChar == null || _rspChar == null) {
        await device.disconnect();
        _setError(
            'Required BLE characteristics not found. Check firmware version.');
        return;
      }

      // [FIX-2] Use onValueReceived (not lastValueStream).
      // lastValueStream emits the previously cached value immediately
      // on subscribe — this could be an empty byte array or stale data,
      // corrupting the response buffer before the first real response.
      await _rspChar!.setNotifyValue(true);
      _notifySub = _rspChar!.onValueReceived.listen(_handleResponse);

      _set(BleProvStep.connected, 'Connected! Scanning WiFi networks…');
      await _triggerWifiScan();
    } catch (e) {
      _setError('Connection failed: $e');
    }
  }

  // ── Step 3: WiFi scan ──────────────────────────────────────────────────
  Future<void> _triggerWifiScan() async {
    _wifiNetworks = [];
    _set(BleProvStep.wifiScanning, 'ESP32 scanning WiFi networks…');
    await _sendCommand('SCAN');
  }

  Future<void> refreshWifiScan() => _triggerWifiScan();

  // ── Step 4: Send credentials ───────────────────────────────────────────
  Future<void> sendCredentials({
    required String ssid,
    required String password,
  }) async {
    if (ssid.trim().isEmpty) {
      _setError('WiFi network name (SSID) cannot be empty.');
      return;
    }
    if (_cmdChar == null) {
      _setError('Not connected to device. Please reconnect.');
      return;
    }

    _set(BleProvStep.sending, 'Sending credentials to device…');

    final safeSSID = ssid.trim().replaceAll(':', '\\:');
    final safePass = password.replaceAll(':', '\\:');

    await _sendCommand('CONNECT:$safeSSID:$safePass');

    // [FIX-3] Start timeout BEFORE updating state. ESP32 WiFi auth takes
    // up to 15s; network latency and BLE overhead can add several more.
    // 35s gives enough headroom while preventing permanent hang.
    _startWifiConnectTimer();
    _set(BleProvStep.wifiConnecting, 'Device connecting to WiFi…');
  }

  // [FIX-3] Timeout helpers ──────────────────────────────────────────────
  void _startWifiConnectTimer() {
    _cancelWifiConnectTimer();
    _wifiConnectTimer = Timer(const Duration(seconds: 35), () {
      if (_step == BleProvStep.wifiConnecting ||
          _step == BleProvStep.sending) {
        _setError(
          'No response from device after 35 seconds.\n'
          'If WiFi connected, check the device dashboard.\n'
          'Otherwise verify SSID/password and try again.',
        );
      }
    });
  }

  void _cancelWifiConnectTimer() {
    _wifiConnectTimer?.cancel();
    _wifiConnectTimer = null;
  }

  // ── Internal: write command in 20-byte chunks ──────────────────────────
  Future<void> _sendCommand(String cmd) async {
    if (_cmdChar == null) return;
    try {
      final bytes = utf8.encode('$cmd\n');
      const chunk = 20;
      for (int i = 0; i < bytes.length; i += chunk) {
        final end = (i + chunk).clamp(0, bytes.length);
        await _cmdChar!.write(bytes.sublist(i, end), withoutResponse: false);
      }
      debugPrint('[BLE] CMD sent: '
          '${cmd.startsWith('CONNECT:') ? 'CONNECT:[credentials hidden]' : cmd}');
    } catch (e) {
      _setError('Failed to send command: $e');
    }
  }

  // ── Internal: handle ESP32 response notifications ──────────────────────
  final StringBuffer _responseBuffer = StringBuffer();

  void _handleResponse(List<int> bytes) {
    if (bytes.isEmpty) return;
    final chunk = utf8.decode(bytes, allowMalformed: true);
    _responseBuffer.write(chunk);
    final raw = _responseBuffer.toString();

    if (!raw.endsWith('\n') && !_isComplete(raw)) return;
    _responseBuffer.clear();
    final msg = raw.trim();
    debugPrint('[BLE] RSP: '
        '${msg.length > 120 ? '${msg.substring(0, 120)}…' : msg}');

    if (msg.startsWith('WIFI_LIST:')) {
      _parseWifiList(msg.substring('WIFI_LIST:'.length));
    } else if (msg == 'CONNECTING') {
      // [FIX-4] ESP32 confirmed it received CONNECT command — restart timer
      // with full duration so WiFi auth gets its complete 35s window.
      _startWifiConnectTimer();
      _set(BleProvStep.wifiConnecting, 'Device connecting to WiFi…');
    } else if (msg.startsWith('CONNECTED:')) {
      _cancelWifiConnectTimer();
      _connectedIp = msg.substring('CONNECTED:'.length).trim();
      _set(
        BleProvStep.success,
        '✅ WiFi connected!\nDevice IP: $_connectedIp\n'
        'The device will now appear online in ~15 seconds.',
      );
    } else if (msg.startsWith('FAILED:')) {
      _cancelWifiConnectTimer();
      final reason = msg.substring('FAILED:'.length).trim();
      _setError(
          'WiFi connection failed: $reason\nCheck SSID/password and try again.');
    } else if (msg.startsWith('STATUS:')) {
      _handleStatus(msg.substring('STATUS:'.length));
    }
  }

  bool _isComplete(String s) {
    if (s.startsWith('WIFI_LIST:[')) {
      return s.contains(']');
    }
    return s.contains('\n') ||
        s == 'CONNECTING' ||
        s.startsWith('CONNECTED:') ||
        s.startsWith('FAILED:') ||
        s.startsWith('STATUS:');
  }

  void _parseWifiList(String json) {
    try {
      final list = jsonDecode(json) as List;
      _wifiNetworks = list
          .map((e) => BleWifiNetwork.fromJson(e as Map<String, dynamic>))
          .where((n) => n.ssid.isNotEmpty)
          .toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      _set(BleProvStep.wifiReady, 'Select your WiFi network.');
    } catch (e) {
      _setError('Failed to parse WiFi list. Please retry.');
    }
  }

  void _handleStatus(String status) {
    if (status.startsWith('CONNECTED:')) {
      _connectedIp = status.substring('CONNECTED:'.length).trim();
      if (_step == BleProvStep.connected ||
          _step == BleProvStep.wifiScanning) {
        _set(BleProvStep.success,
            '✅ Device already connected.\nIP: $_connectedIp');
      }
    }
  }

  // ── Disconnect / cleanup ───────────────────────────────────────────────
  Future<void> disconnect() async {
    _cancelWifiConnectTimer();
    await _device?.disconnect();
    await _cleanup();
    _set(BleProvStep.idle, '');
  }

  Future<void> reset() async {
    _cancelWifiConnectTimer();
    await _cleanup();
    _scanResults = [];
    _wifiNetworks = [];
    _connectedIp = null;
    _step = BleProvStep.idle;
    _message = '';
    _error = null;
    notifyListeners();
  }

  Future<void> _cleanup() async {
    await _scanSub?.cancel();
    await _notifySub?.cancel();
    await _deviceStateSub?.cancel();
    _scanSub = null;
    _notifySub = null;
    _deviceStateSub = null;
    _cmdChar = null;
    _rspChar = null;
    _device = null;
    _responseBuffer.clear();
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  void _set(BleProvStep step, String message) {
    _step = step;
    _message = message;
    _error = null;
    notifyListeners();
  }

  void _setError(String errorMsg) {
    _step = BleProvStep.failed;
    _message = 'Error';
    _error = errorMsg;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelWifiConnectTimer();
    _cleanup();
    super.dispose();
  }
}
