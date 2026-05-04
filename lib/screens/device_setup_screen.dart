// lib/screens/device_setup_screen.dart
// SmartIoT v2.2.0
// ──────────────────────────────────────────────────────────────────────────────
// বর্ণনা অনুযায়ী ২টি পদ্ধতি:
//   Tab 1 — Register  : Serial দিয়ে device Firebase-এ নিবন্ধন
//   Tab 2 — BLE Setup : BLE দিয়ে ESP32-এ WiFi পাঠানো (প্রথমবার)
//
// বাদ দেওয়া হয়েছে:
//   ✗ AP Setup (Tab 3)       — বর্ণনায় নেই
//   ✗ provisioning_service   — শুধু AP mode-এর জন্য ছিল
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/device_service.dart';
import '../theme/app_theme.dart';
import '../core/utils.dart';
import 'ble_provisioning_screen.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  final _serialCtrl = TextEditingController();
  final _nameCtrl   = TextEditingController(text: 'Water Tank');
  final _formKey    = GlobalKey<FormState>();
  int _tabIndex     = 0;

  @override
  void dispose() {
    _serialCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerDevice() async {
    if (!_formKey.currentState!.validate()) return;
    final device = context.read<DeviceService>();
    final result = await device.addDevice(
      _serialCtrl.text.trim().toUpperCase(),
      _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    switch (result) {
      case DeviceAddResult.success:
        AppUtils.showSnack(context, '✅ Device registered successfully!');
        Navigator.pop(context);
        break;
      case DeviceAddResult.alreadyOwned:
        AppUtils.showSnack(context, 'ℹ️ This device is already in your account.');
        Navigator.pop(context);
        break;
      case DeviceAddResult.alreadyClaimed:
        AppUtils.showSnack(
          context,
          '🔒 This device is registered to another account.',
          isError: true,
        );
        break;
      case DeviceAddResult.error:
        AppUtils.showSnack(
          context,
          device.error ?? 'Registration failed. Please try again.',
          isError: true,
        );
        device.clearError();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<ThemeNotifier>().isDark;

    return Theme(
      data: isDark ? AppTheme.dark : AppTheme.light,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: const Text('Device Setup'),
          backgroundColor: isDark ? AppTheme.darkCard : AppTheme.primaryBlue,
        ),
        body: Column(
          children: [
            // ── ২টি Tab ──────────────────────────────────────────────
            Container(
              color: isDark ? AppTheme.darkCard : AppTheme.primaryBlue,
              child: Row(
                children: [
                  _Tab(
                    label: 'Register',
                    icon: Icons.add_circle_outline,
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                    isDark: isDark,
                  ),
                  _Tab(
                    label: 'BLE Setup',
                    icon: Icons.bluetooth,
                    badge: 'EASY',
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _tabIndex == 0
                    ? SingleChildScrollView(
                        key: const ValueKey('reg'),
                        padding: const EdgeInsets.all(20),
                        child: _RegisterTab(
                          formKey: _formKey,
                          serialCtrl: _serialCtrl,
                          nameCtrl: _nameCtrl,
                          onSubmit: _registerDevice,
                          isDark: isDark,
                        ),
                      )
                    : _BleTab(key: const ValueKey('ble'), isDark: isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab button ────────────────────────────────────────────────────────────────
class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  final String? badge;

  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final active   = isDark ? AppTheme.accent : Colors.white;
    final inactive = isDark ? Colors.white38 : Colors.white60;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? active : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(icon, size: 18, color: selected ? active : inactive),
              if (badge != null)
                Positioned(
                  top: -7,
                  right: -24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? active : inactive,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── BLE Tab ───────────────────────────────────────────────────────────────────
class _BleTab extends StatelessWidget {
  final bool isDark;
  const _BleTab({super.key, required this.isDark});

  // FIX: extracted as a static const so the list itself can be const
  static const _steps = [
    (1,  'অ্যাপে "Add Device" ট্যাপ করুন'),
    (2,  'অ্যাপ BLE স্ক্যান শুরু করে (৩০ সেকেন্ড)'),
    (3,  'লিস্ট থেকে "SmartIoT_Setup" নামের ESP32 সিলেক্ট করুন'),
    (4,  'অ্যাপ ESP32-এর সাথে BLE কানেক্ট করে'),
    (5,  'অ্যাপ ESP32-কে "SCAN\\n" কমান্ড পাঠায়'),
    (6,  'ESP32 কাছের সব WiFi স্ক্যান করে JSON পাঠায়'),
    (7,  'আপনার WiFi নেটওয়ার্ক সিলেক্ট করুন + পাসওয়ার্ড দিন'),
    (8,  'অ্যাপ "CONNECT:SSID:PASSWORD\\n" পাঠায়'),
    (9,  'ESP32 WiFi-এ connect করে'),
    (10, 'সফল হলে "CONNECTED:IP" response আসে'),
    (11, 'ESP32 credentials এনক্রিপ্ট করে NVS-এ সেভ করে'),
    (12, 'অ্যাপ Dashboard-এ চলে যায় ✅'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── মূল তথ্য কার্ড ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accent.withValues(alpha: 0.12),
                AppTheme.primaryBlue.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.bluetooth, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'BLE WiFi Provisioning',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'প্রথমবারই করুন',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // FIX: use static const list instead of inline const literal
            for (final step in _steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1, right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.$1 >= 10
                          ? AppTheme.success.withValues(alpha: 0.85)
                          : AppTheme.accent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${step.$1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step.$2,
                      style: TextStyle(
                        color: AppTheme.accent.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Protocol detail ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                : AppTheme.primaryBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.code,
                  size: 14,
                  color: AppTheme.primaryLight.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                'BLE কমান্ড প্রোটোকল',
                style: TextStyle(
                  color: AppTheme.primaryLight.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _CodeLine('App → ESP32:', 'utf8.encode("SCAN\\n")',
                isDark: isDark),
            _CodeLine('ESP32 → App:', '"WIFI_LIST:[{\\"s\\":\\"SSID\\",\\"r\\":-60}]"',
                isDark: isDark),
            _CodeLine('App → ESP32:', 'utf8.encode("CONNECT:MyWiFi:pass\\n")',
                isDark: isDark),
            _CodeLine('ESP32 → App:', '"CONNECTED:192.168.1.x"',
                isDark: isDark),
            const SizedBox(height: 6),
            Text(
              'এরপর সব যোগাযোগ Firebase-এর মাধ্যমে — BLE আর লাগে না।',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // ── সুবিধা ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.black12),
          ),
          child: const Column(children: [
            _AdvRow(
              icon: Icons.security,
              color: AppTheme.success,
              text: 'AP network-এ join করতে হয় না — সরাসরি BLE দিয়ে পাঠানো হয়',
            ),
            _AdvRow(
              icon: Icons.speed,
              color: AppTheme.accent,
              text: 'ESP32 নিজেই WiFi scan করে — দ্রুত setup',
            ),
            _AdvRow(
              icon: Icons.signal_cellular_alt,
              color: AppTheme.warning,
              text: 'প্রতিটি WiFi-এর signal strength (RSSI) দেখায়',
            ),
            _AdvRow(
              icon: Icons.lan,
              color: AppTheme.primaryLight,
              text: 'সফল হলে Device IP address দেখায়',
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Start button ─────────────────────────────────────────────────
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bluetooth_searching, size: 22),
            label: const Text(
              'Start BLE Setup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BleProvisioningScreen(isDark: isDark),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────
class _CodeLine extends StatelessWidget {
  final String label;
  final String code;
  final bool isDark;
  const _CodeLine(this.label, this.code, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            code,
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ]),
    );
  }
}

class _AdvRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AdvRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12.5, height: 1.4)),
          ),
        ]),
      );
}

// ── Register Tab ──────────────────────────────────────────────────────────────
class _RegisterTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController serialCtrl;
  final TextEditingController nameCtrl;
  final VoidCallback onSubmit;
  final bool isDark;

  const _RegisterTab({
    required this.formKey,
    required this.serialCtrl,
    required this.nameCtrl,
    required this.onSubmit,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceService>();

    return Form(
      key: formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline, color: AppTheme.accent, size: 16),
              SizedBox(width: 6),
              Text(
                'Instructions',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            for (final line in const [
              'Serial নম্বর OLED screen-এ দেখায় (যেমন: SWT-XXXX1234567890)।',
              'অথবা Arduino Serial Monitor-এ 115200 baud-এ দেখুন।',
              'BLE Setup tab থেকে add করলে auto-register হয়।',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: TextStyle(
                    color: AppTheme.accent.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 24),

        _DarkField(
          controller: serialCtrl,
          label: 'Device Serial Number',
          hint: 'SWT-XXXX12345678',
          icon: Icons.qr_code,
          isDark: isDark,
          textCapitalization: TextCapitalization.characters,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Serial number is required';
            if (!RegExp(r'^SWT-[A-F0-9]{12}$')
                .hasMatch(v.trim().toUpperCase())) {
              return 'Format: SWT-XXXX12345678';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        _DarkField(
          controller: nameCtrl,
          label: 'Device Name',
          hint: 'e.g. Roof Tank',
          icon: Icons.label_outline,
          isDark: isDark,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: 28),

        SizedBox(
          height: 50,
          child: device.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Register Device'),
                  onPressed: onSubmit,
                ),
        ),
      ]),
    );
  }
}

// ── Dark text field ───────────────────────────────────────────────────────────
// FIX: removed unused optional parameters `obscureText` and `suffix`
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool isDark;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    required this.isDark,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      textCapitalization: textCapitalization,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
        hintStyle: TextStyle(
            color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
        prefixIcon: Icon(icon,
            color: isDark ? Colors.white38 : Colors.black38, size: 20),
        filled: true,
        fillColor: isDark ? AppTheme.darkCard : Colors.white,
        enabledBorder: const OutlineInputBorder(             // FIX: const
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.black12),
        ),
        focusedBorder: const OutlineInputBorder(            // FIX: const
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(              // FIX: const
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppTheme.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(       // FIX: const
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppTheme.danger, width: 1.5),
        ),
        errorStyle: const TextStyle(color: AppTheme.danger, fontSize: 12), // FIX: const
      ),
    );
  }
}
