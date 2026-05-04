// lib/screens/ble_provisioning_screen.dart
// ──────────────────────────────────────────────────────────────────────────────
// BLE Provisioning Screen — SmartIoT v2.2.0
// Modern animated step-by-step WiFi provisioning via Bluetooth Low Energy.
//
// Steps:
//   1. BLE Scan       — discover nearby ESP32 devices with RSSI
//   2. Device Select  — tap a device to connect
//   3. WiFi Scan      — ESP32 scans available networks (via BLE)
//   4. WiFi Select    — user picks their network
//   5. Password Input — user enters WiFi password
//   6. Result         — connected IP or retry
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../services/ble_provisioning_service.dart';
import '../theme/app_theme.dart';

// ── Entry point ────────────────────────────────────────────────────────────
class BleProvisioningScreen extends StatelessWidget {
  final bool isDark;
  const BleProvisioningScreen({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BleProvisioningService(),
      child: _BleProvisioningView(isDark: isDark),
    );
  }
}

class _BleProvisioningView extends StatefulWidget {
  final bool isDark;
  const _BleProvisioningView({required this.isDark});

  @override
  State<_BleProvisioningView> createState() => _BleProvisioningViewState();
}

class _BleProvisioningViewState extends State<_BleProvisioningView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  final _passCtrl = TextEditingController();
  String? _selectedSSID;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Auto-start scan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleProvisioningService>().startScan();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BleProvisioningService>();
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('BLE Provisioning'),
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (svc.connectedDevice != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: const Text('BLE'),
                avatar: const Icon(Icons.bluetooth_connected, size: 14),
                backgroundColor: AppTheme.success.withValues(alpha: 0.15),
                labelStyle: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0.05, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: _buildStep(svc, isDark),
      ),
    );
  }

  Widget _buildStep(BleProvisioningService svc, bool isDark) {
    switch (svc.step) {
      case BleProvStep.scanning:
        return _ScanningView(
            key: const ValueKey('scanning'), pulse: _pulseCtrl, isDark: isDark);

      case BleProvStep.bluetoothOff:
        return _BluetoothOffView(key: const ValueKey('btoff'), isDark: isDark);

      case BleProvStep.connecting:
        return _ConnectingView(
            key: const ValueKey('connecting'),
            message: svc.message,
            isDark: isDark);

      case BleProvStep.wifiScanning:
        return _WifiScanningView(
            key: const ValueKey('wifiscan'), isDark: isDark);

      case BleProvStep.wifiReady:
        return _WifiListView(
          key: const ValueKey('wifilist'),
          networks: svc.wifiNetworks,
          isDark: isDark,
          selectedSSID: _selectedSSID,
          onSelect: (ssid) => setState(() => _selectedSSID = ssid),
          onRefresh: () => svc.refreshWifiScan(),
          onNext: () {
            if (_selectedSSID != null) {
              setState(() {});
            }
          },
          passCtrl: _passCtrl,
          obscure: _obscurePass,
          onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
          onSend: (ssid, pass) => svc.sendCredentials(
              ssid: ssid, password: pass),
        );

      case BleProvStep.sending:
      case BleProvStep.wifiConnecting:
        return _WifiConnectingView(
            key: const ValueKey('wificonn'), message: svc.message, isDark: isDark);

      case BleProvStep.success:
        return _SuccessView(
          key: const ValueKey('success'),
          message: svc.message,
          ip: svc.connectedIp,
          isDark: isDark,
          onDone: () => Navigator.pop(context),
          onProvisionAnother: () {
            _selectedSSID = null;
            _passCtrl.clear();
            svc.reset().then((_) => svc.startScan());
          },
        );

      case BleProvStep.failed:
        return _FailedView(
          key: const ValueKey('failed'),
          error: svc.error ?? svc.message,
          isDark: isDark,
          onRetry: () {
            // [FIX] If still connected to ESP32, just re-scan WiFi networks.
            // Don't do a full BLE reset — the BLE connection is still alive.
            if (svc.connectedDevice != null) {
              svc.refreshWifiScan();
            } else {
              // BLE disconnected — do full scan to find ESP32 again
              svc.reset().then((_) => svc.startScan());
            }
          },
          onDisconnect: () {
            svc.disconnect();
          },
        );

      // idle — show device list
      case BleProvStep.idle:
      case BleProvStep.connected:
        return _DeviceListView(
          key: const ValueKey('devices'),
          results: svc.scanResults,
          isDark: isDark,
          onRescan: () => svc.startScan(),
          onConnect: (device) => svc.connectToDevice(device),
        );
    }
  }
}

// ── Step 1: Scanning ───────────────────────────────────────────────────────
class _ScanningView extends StatelessWidget {
  final AnimationController pulse;
  final bool isDark;
  const _ScanningView({super.key, required this.pulse, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _PulseRing(controller: pulse),
        const SizedBox(height: 32),
        Text('Scanning for Devices',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 8),
        Text('Looking for nearby SmartIoT ESP32 devices…',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45, fontSize: 13)),
        const SizedBox(height: 32),
        TextButton.icon(
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          onPressed: () => context.read<BleProvisioningService>().stopScan(),
        ),
      ]),
    );
  }
}

// ── Pulse ring animation ──
class _PulseRing extends StatelessWidget {
  final AnimationController controller;
  const _PulseRing({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final scale = 1.0 + controller.value * 0.25;
        return Stack(alignment: Alignment.center, children: [
          Transform.scale(
            scale: scale,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.accent.withValues(
                        alpha: (1 - controller.value) * 0.5),
                    width: 2),
              ),
            ),
          ),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.accent.withValues(alpha: 0.2),
                AppTheme.primaryBlue.withValues(alpha: 0.1),
              ]),
            ),
          ),
          const Icon(Icons.bluetooth_searching, size: 42, color: AppTheme.accent),
        ]);
      },
    );
  }
}

// ── Bluetooth Off ───────────────────────────────────────────────────────────
class _BluetoothOffView extends StatelessWidget {
  final bool isDark;
  const _BluetoothOffView({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.warning.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.bluetooth_disabled,
                size: 48, color: AppTheme.warning),
          ),
          const SizedBox(height: 24),
          Text('Bluetooth is Off',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 10),
          Text(
            'Please enable Bluetooth in your device settings to use BLE provisioning.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: isDark ? Colors.white54 : Colors.black45),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.bluetooth),
            label: const Text('Try Again'),
            onPressed: () =>
                context.read<BleProvisioningService>().startScan(),
          ),
        ]),
      ),
    );
  }
}

// ── Device List ─────────────────────────────────────────────────────────────
class _DeviceListView extends StatelessWidget {
  final List<ScanResult> results;
  final bool isDark;
  final VoidCallback onRescan;
  final void Function(BluetoothDevice) onConnect;

  const _DeviceListView({
    super.key,
    required this.results,
    required this.isDark,
    required this.onRescan,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _StepHeader(
        step: 1,
        title: 'Select Device',
        subtitle: results.isEmpty
            ? 'No devices found nearby'
            : '${results.length} device${results.length == 1 ? '' : 's'} found',
        isDark: isDark,
      ),
      Expanded(
        child: results.isEmpty
            ? _EmptyDevices(isDark: isDark, onRescan: onRescan)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: results.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == results.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Scan Again'),
                        onPressed: onRescan,
                      ),
                    );
                  }
                  final r = results[i];
                  return _DeviceTile(
                    result: r,
                    isDark: isDark,
                    onTap: () => onConnect(r.device),
                  );
                },
              ),
      ),
    ]);
  }
}

class _EmptyDevices extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRescan;
  const _EmptyDevices({required this.isDark, required this.onRescan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bluetooth_searching,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text('No SmartIoT devices found',
              style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 8),
          Text(
            '• Power on your ESP32 device\n'
            '• Make sure BLE is enabled on ESP32\n'
            '• Stay within 10 meters',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
                height: 1.6),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
            onPressed: onRescan,
          ),
        ]),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final ScanResult result;
  final bool isDark;
  final VoidCallback onTap;
  const _DeviceTile(
      {required this.result, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rssi = result.rssi;
    final signalColor = rssi > -60
        ? AppTheme.success
        : rssi > -80
            ? AppTheme.warning
            : AppTheme.danger;
    final signalPct = ((rssi + 100) * 2).clamp(0, 100);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.black12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent.withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.memory, color: AppTheme.accent, size: 24),
        ),
        title: Text(
          result.device.platformName.isNotEmpty
              ? result.device.platformName
              : 'Unknown Device',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              result.device.remoteId.str,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.signal_cellular_alt,
                  size: 12, color: signalColor),
              const SizedBox(width: 4),
              Text(
                '$rssi dBm · $signalPct% · ${_signalLabel(rssi)}',
                style: TextStyle(
                    fontSize: 11,
                    color: signalColor,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            textStyle: const TextStyle(fontSize: 13),
            backgroundColor: AppTheme.primaryLight,
          ),
          child: const Text('Connect'),
        ),
      ),
    );
  }

  String _signalLabel(int rssi) {
    if (rssi > -60) return 'Excellent';
    if (rssi > -70) return 'Good';
    if (rssi > -80) return 'Fair';
    return 'Weak';
  }
}

// ── Connecting ──────────────────────────────────────────────────────────────
class _ConnectingView extends StatelessWidget {
  final String message;
  final bool isDark;
  const _ConnectingView(
      {super.key, required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _SpinningBluetooth(),
          const SizedBox(height: 28),
          Text('Connecting',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 13)),
        ]),
      ),
    );
  }
}

class _SpinningBluetooth extends StatefulWidget {
  const _SpinningBluetooth();
  @override
  State<_SpinningBluetooth> createState() => _SpinningBluetoothState();
}

class _SpinningBluetoothState extends State<_SpinningBluetooth>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.rotate(
        angle: _ctrl.value * 2 * pi,
        child: child,
      ),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              AppTheme.accent.withValues(alpha: 0.1),
              AppTheme.accent,
            ],
          ),
        ),
        child: const Icon(Icons.bluetooth, color: Colors.white, size: 36),
      ),
    );
  }
}

// ── WiFi Scanning ───────────────────────────────────────────────────────────
class _WifiScanningView extends StatelessWidget {
  final bool isDark;
  const _WifiScanningView({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _WifiScanAnimation(),
          const SizedBox(height: 28),
          Text('Scanning WiFi Networks',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 10),
          Text(
            'ESP32 is scanning nearby WiFi networks…\nThis takes a few seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 13,
                height: 1.6),
          ),
        ]),
      ),
    );
  }
}

class _WifiScanAnimation extends StatefulWidget {
  const _WifiScanAnimation();
  @override
  State<_WifiScanAnimation> createState() => _WifiScanAnimationState();
}

class _WifiScanAnimationState extends State<_WifiScanAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: 80,
        height: 80,
        child: Stack(alignment: Alignment.center, children: [
          _arc(_ctrl.value, 70, AppTheme.accent.withValues(alpha: 0.15)),
          _arc((_ctrl.value + 0.33) % 1, 54, AppTheme.accent.withValues(alpha: 0.3)),
          _arc((_ctrl.value + 0.66) % 1, 38, AppTheme.accent.withValues(alpha: 0.5)),
          const Icon(Icons.wifi_find, color: AppTheme.accent, size: 28),
        ]),
      ),
    );
  }

  Widget _arc(double progress, double size, Color color) {
    return Opacity(
      opacity: progress < 0.5 ? progress * 2 : (1 - progress) * 2,
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: color, value: null),
      ),
    );
  }
}

// ── WiFi List + Password ────────────────────────────────────────────────────
class _WifiListView extends StatefulWidget {
  final List<BleWifiNetwork> networks;
  final bool isDark;
  final String? selectedSSID;
  final void Function(String) onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onNext;
  final TextEditingController passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final Future<void> Function(String ssid, String pass) onSend;

  const _WifiListView({
    super.key,
    required this.networks,
    required this.isDark,
    required this.selectedSSID,
    required this.onSelect,
    required this.onRefresh,
    required this.onNext,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSend,
  });

  @override
  State<_WifiListView> createState() => _WifiListViewState();
}

class _WifiListViewState extends State<_WifiListView> {
  bool _showPassword = false;

  void _selectAndProceed(String ssid) {
    widget.onSelect(ssid);
    setState(() => _showPassword = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _StepHeader(
        step: _showPassword ? 4 : 3,
        title: _showPassword ? 'Enter WiFi Password' : 'Select WiFi Network',
        subtitle: _showPassword
            ? 'Selected: ${widget.selectedSSID ?? ''}'
            : '${widget.networks.length} network${widget.networks.length == 1 ? '' : 's'} found',
        isDark: widget.isDark,
      ),
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showPassword
              ? _PasswordPanel(
                  key: const ValueKey('pass'),
                  ssid: widget.selectedSSID!,
                  ctrl: widget.passCtrl,
                  obscure: widget.obscure,
                  onToggle: widget.onToggleObscure,
                  isDark: widget.isDark,
                  onBack: () => setState(() => _showPassword = false),
                  onSend: () =>
                      widget.onSend(widget.selectedSSID!, widget.passCtrl.text),
                )
              : _NetworkListPanel(
                  key: const ValueKey('netlist'),
                  networks: widget.networks,
                  isDark: widget.isDark,
                  onSelect: _selectAndProceed,
                  onRefresh: widget.onRefresh,
                ),
        ),
      ),
    ]);
  }
}

class _NetworkListPanel extends StatelessWidget {
  final List<BleWifiNetwork> networks;
  final bool isDark;
  final void Function(String) onSelect;
  final VoidCallback onRefresh;

  const _NetworkListPanel({
    super.key,
    required this.networks,
    required this.isDark,
    required this.onSelect,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: networks.length + 1,
      itemBuilder: (ctx, i) {
        if (i == networks.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Scan Again'),
              onPressed: onRefresh,
            ),
          );
        }
        final net = networks[i];
        return _WifiTile(
            network: net, isDark: isDark, onTap: () => onSelect(net.ssid));
      },
    );
  }
}

class _WifiTile extends StatelessWidget {
  final BleWifiNetwork network;
  final bool isDark;
  final VoidCallback onTap;
  const _WifiTile(
      {required this.network, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = network.signalPercent;
    final signalColor = pct >= 75
        ? AppTheme.success
        : pct >= 50
            ? AppTheme.warning
            : pct >= 25
                ? AppTheme.warning
                : AppTheme.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.black12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: _SignalIcon(pct: pct, color: signalColor),
        title: Text(network.ssid,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14)),
        subtitle: Text(
          '${network.rssi} dBm · ${network.signalLabel}${network.secured ? '' : ' · Open'}',
          style: TextStyle(
              fontSize: 11,
              color: signalColor,
              fontWeight: FontWeight.w500),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!network.secured)
            const Icon(Icons.lock_open, size: 14, color: AppTheme.warning),
          if (network.secured)
            const Icon(Icons.lock, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right,
              color: isDark ? Colors.white38 : Colors.black26),
        ]),
      ),
    );
  }
}

class _SignalIcon extends StatelessWidget {
  final int pct;
  final Color color;
  const _SignalIcon({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = pct >= 75
        ? Icons.signal_wifi_4_bar
        : pct >= 50
            ? Icons.network_wifi_3_bar
            : pct >= 25
                ? Icons.network_wifi_2_bar
                : Icons.network_wifi_1_bar;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _PasswordPanel extends StatelessWidget {
  final String ssid;
  final TextEditingController ctrl;
  final bool obscure;
  final VoidCallback onToggle;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSend;

  const _PasswordPanel({
    super.key,
    required this.ssid,
    required this.ctrl,
    required this.obscure,
    required this.onToggle,
    required this.isDark,
    required this.onBack,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Selected network card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.wifi, color: AppTheme.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected Network',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent.withValues(alpha: 0.8))),
                  Text(ssid,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                          fontSize: 15)),
                ],
              ),
            ),
            TextButton(
              onPressed: onBack,
              child: Text('Change',
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12)),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // Password field
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          autofocus: true,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            labelText: 'WiFi Password',
            hintText: 'Leave blank for open networks',
            prefixIcon: Icon(Icons.lock_outline,
                color: isDark ? Colors.white38 : Colors.black38, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black38),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkCard : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.black12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Credentials are sent directly to the ESP32 via BLE.',
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38)),
        const SizedBox(height: 28),

        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send to Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onSend,
          ),
        ),
      ]),
    );
  }
}

// ── WiFi Connecting ─────────────────────────────────────────────────────────
class _WifiConnectingView extends StatelessWidget {
  final String message;
  final bool isDark;
  const _WifiConnectingView(
      {super.key, required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
                strokeWidth: 4,
                color: AppTheme.accent),
          ),
          const SizedBox(height: 28),
          Text('Connecting to WiFi',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 13,
                  height: 1.6)),
          const SizedBox(height: 20),
          Text('This may take up to 20 seconds…',
              style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12)),
        ]),
      ),
    );
  }
}

// ── Success ─────────────────────────────────────────────────────────────────
class _SuccessView extends StatefulWidget {
  final String message;
  final String? ip;
  final bool isDark;
  final VoidCallback onDone;
  final VoidCallback onProvisionAnother;

  const _SuccessView({
    super.key,
    required this.message,
    required this.ip,
    required this.isDark,
    required this.onDone,
    required this.onProvisionAnother,
  });

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 52, color: AppTheme.success),
            ),
          ),
          const SizedBox(height: 28),
          Text('Provisioning Complete!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 12),
          if (widget.ip != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.success.withValues(alpha: 0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lan, color: AppTheme.success, size: 16),
                const SizedBox(width: 8),
                Text('IP: ${widget.ip}',
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Your ESP32 is now connected to WiFi.\n'
            'It will appear online in the app shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: widget.isDark ? Colors.white54 : Colors.black45,
                fontSize: 13,
                height: 1.6),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.dashboard_rounded),
              label: const Text('Go to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: widget.onDone,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.add,
                color: widget.isDark ? Colors.white54 : Colors.black54),
            label: Text('Provision Another',
                style: TextStyle(
                    color: widget.isDark ? Colors.white54 : Colors.black54)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: widget.isDark ? Colors.white24 : Colors.black26),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 44)),
            onPressed: widget.onProvisionAnother,
          ),
        ]),
      ),
    );
  }

  bool get isDark => widget.isDark;
}

// ── Failed ──────────────────────────────────────────────────────────────────
class _FailedView extends StatelessWidget {
  final String error;
  final bool isDark;
  final VoidCallback onRetry;
  final VoidCallback onDisconnect;

  const _FailedView({
    super.key,
    required this.error,
    required this.isDark,
    required this.onRetry,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.danger.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.error_outline,
                size: 48, color: AppTheme.danger),
          ),
          const SizedBox(height: 24),
          Text('Something went wrong',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.danger.withValues(alpha: 0.2)),
            ),
            child: Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 13,
                    height: 1.5)),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: onRetry,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(Icons.bluetooth_disabled,
                color: isDark ? Colors.white54 : Colors.black54),
            label: Text('Disconnect',
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 44)),
            onPressed: onDisconnect,
          ),
        ]),
      ),
    );
  }
}

// ── Shared: Step header ─────────────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final bool isDark;

  const _StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.black12),
        ),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent,
          ),
          alignment: Alignment.center,
          child: Text('$step',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45)),
            ],
          ),
        ),
        // Step indicator dots
        Row(mainAxisSize: MainAxisSize.min, children: List.generate(6, (i) {
          final active = i + 1 == step;
          final done = i + 1 < step;
          return Container(
            margin: const EdgeInsets.only(left: 4),
            width: active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: done
                  ? AppTheme.success
                  : active
                      ? AppTheme.accent
                      : (isDark ? Colors.white24 : Colors.black12),
            ),
          );
        })),
      ]),
    );
  }
}
