// lib/screens/dashboard_screen.dart
// PREMIUM v3 — Glassmorphism header, bottom nav, gradient status, premium cards

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../core/utils.dart';
import '../core/constants.dart';
import '../theme/app_theme.dart';
import '../widgets/tank_widget.dart';
import '../widgets/control_panel.dart';
import '../widgets/premium_widgets.dart';
import 'login_screen.dart';
import 'device_setup_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late DeviceService _deviceService;
  int _navIndex = 0;

  late AnimationController _headerCtrl;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _deviceService = DeviceService(
      uid: uid,
      firebaseService: context.read<FirebaseService>(),
    );
    _deviceService.loadDevices();
    _uploadFcmToken(uid);

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerCtrl.forward();
  }

  Future<void> _uploadFcmToken(String uid) async {
    try {
      final firebaseService = context.read<FirebaseService>();
      final token = await NotificationService.getToken();
      if (token != null && token.isNotEmpty) {
        await firebaseService.uploadFcmToken(uid, token);
      }
    } catch (e) {
      debugPrint('[Dashboard] FCM token upload failed: $e');
    }
  }

  @override
  void dispose() {
    _deviceService.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: AppTheme.danger, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context);
    await auth.logout();
    if (mounted) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Widget _buildNavBody(bool isDark) {
    // [FIX] Provider is now at Scaffold level — no inner wrapper needed.
    return _navIndex == 0
        ? _DashboardBody(isDark: isDark, onDeviceSetup: _openDeviceSetup)
        : _navIndex == 1
            ? HistoryScreen(deviceService: _deviceService)
            : SettingsScreen(deviceService: _deviceService, onLogout: _logout);
  }

  void _openDeviceSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _deviceService,
          child: const DeviceSetupScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final isDark = themeNotifier.isDark;

    // [FIX] ProviderNotFoundException: wrap entire Scaffold so AppBar
    // Consumer<DeviceService> can find the provider above it.
    return ChangeNotifierProvider.value(
      value: _deviceService,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFEEF2FF),
        extendBodyBehindAppBar: true,
        appBar: _buildPremiumAppBar(isDark, themeNotifier),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: KeyedSubtree(
            key: ValueKey(_navIndex),
            child: _buildNavBody(isDark),
          ),
        ),
        bottomNavigationBar: _PremiumBottomNav(
          currentIndex: _navIndex,
          isDark: isDark,
          onTap: (i) => setState(() => _navIndex = i),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(bool isDark, ThemeNotifier themeNotifier) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkCard.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.9),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? AppTheme.darkBorder.withValues(alpha: 0.5)
                  : AppTheme.lightBorder,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Brand
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppTheme.glowBlue(intensity: 0.3),
                  ),
                  child: const Icon(Icons.water_drop, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Consumer<DeviceService>(
                    builder: (_, device, __) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            device.selectedDeviceId != null
                                ? device.deviceName(device.selectedDeviceId!)
                                : AppConstants.appName,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            AppConstants.brandName,
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.accent.withValues(alpha: 0.7)
                                  : AppTheme.primaryBlue.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Theme toggle
                _AppBarIcon(
                  icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  isDark: isDark,
                  onTap: themeNotifier.toggle,
                  tooltip: 'Toggle theme',
                ),

                // Add device
                _AppBarIcon(
                  icon: Icons.add_circle_outline,
                  isDark: isDark,
                  onTap: _openDeviceSetup,
                  tooltip: 'Add device',
                ),

                // User profile avatar
                _UserAvatarButton(isDark: isDark, onTap: () {
                  setState(() => _navIndex = 2); // navigate to Settings
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String tooltip;

  const _AppBarIcon({
    required this.icon,
    required this.isDark,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }
}

// ── User Avatar Button ─────────────────────────────────────
class _UserAvatarButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _UserAvatarButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName;
    final email = user?.email ?? '';
    final initials = _getInitials(displayName, email);

    return Tooltip(
      message: displayName ?? email,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.accentGradient,
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: AppTheme.glowBlue(intensity: 0.3),
          ),
          child: photoUrl != null
              ? ClipOval(
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _getInitials(String? displayName, String email) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName[0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}

// ── Premium Bottom Navigation ───────────────────────────────
class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final void Function(int) onTap;

  const _PremiumBottomNav({
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History'),
    (icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.5) : AppTheme.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? [const BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, -4))]
            : [const BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.accent.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          size: 22,
                          color: isActive
                              ? AppTheme.accent
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? AppTheme.accent
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Main Dashboard Body ─────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final bool isDark;
  final VoidCallback onDeviceSetup;

  const _DashboardBody({required this.isDark, required this.onDeviceSetup});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceService>();

    if (device.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading devices…',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      );
    }

    if (!device.hasDevice) {
      return _NoDevicePlaceholder(isDark: isDark, onAdd: onDeviceSetup);
    }

    final status = device.status;

    return RefreshIndicator(
      color: AppTheme.accent,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      onRefresh: () => device.loadDevices(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Premium hero header ─────────────────────
            _HeroHeader(device: device, isDark: isDark),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (device.deviceIds.length > 1) ...[
                    _DeviceSelector(isDark: isDark),
                    const SizedBox(height: 12),
                  ],

                  // Alarm banner
                  if (status?.alarmActive == true) ...[
                    _AlarmBanner(isDryRun: status?.dryRunActive == true),
                    const SizedBox(height: 14),
                  ],

                  // Control panel
                  const ControlPanel(),
                  const SizedBox(height: 20),

                  // Info cards
                  if (status != null) ...[
                    _SectionLabel(label: 'DEVICE INFO', isDark: isDark),
                    const SizedBox(height: 10),
                    _InfoCardsRow(status: status, isDark: isDark),
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'PUMP STATISTICS', isDark: isDark),
                    const SizedBox(height: 10),
                    _PumpStatsRow(status: status, isDark: isDark),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero header with tank + status ─────────────────────────
class _HeroHeader extends StatelessWidget {
  final DeviceService device;
  final bool isDark;

  const _HeroHeader({required this.device, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final status = device.status;
    final pct = status?.waterLevelPct ?? 0;
    final waterColor = AppUtils.waterLevelColor(pct);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppTheme.darkCard, AppTheme.darkBg]
              : [const Color(0xFFDBEAFE), const Color(0xFFEEF2FF)],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.4) : AppTheme.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
          child: Column(
            children: [
              // Online status
              Center(
                child: AnimatedStatusBadge(
                  isOnline: device.isDeviceOnline,
                  onlineLabel: 'Device Online',
                  offlineLabel: 'Device Offline',
                ),
              ),
              const SizedBox(height: 24),

              // Tank + stats row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tank
                  TankWidget(
                    percent: pct,
                    width: 130,
                    height: 200,
                  ),
                  const SizedBox(width: 20),

                  // Stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Water percentage display
                        FittedBox(
                          child: Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              color: waterColor,
                              height: 1,
                            ),
                          ),
                        ),
                        Text(
                          status != null
                              ? AppUtils.levelLabel(status.waterLevel.toString())
                              : '—',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pump status card
                        if (status != null)
                          PumpStatusCard(isOn: status.isPumpOn, isDark: isDark),

                        const SizedBox(height: 10),

                        // Mode badge
                        if (status != null)
                          Row(
                            children: [
                              GradientBadge(
                                label: status.pumpMode.toString(),
                                gradient: status.isAutoMode
                                    ? AppTheme.accentGradient
                                    : AppTheme.warmGradient,
                                icon: status.isAutoMode
                                    ? Icons.auto_awesome
                                    : Icons.touch_app,
                              ),
                              const SizedBox(width: 8),
                              if (status.alarmActive || status.dryRunActive)
                                GradientBadge(
                                  label: status.dryRunActive ? 'DRY RUN' : 'ALARM',
                                  gradient: AppTheme.dangerGradient,
                                  icon: Icons.warning_amber_rounded,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ───────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }
}

// ── Info cards ──────────────────────────────────────────────
class _InfoCardsRow extends StatelessWidget {
  final dynamic status;
  final bool isDark;

  const _InfoCardsRow({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PremiumInfoCard(
            icon: Icons.access_time_rounded,
            label: 'LAST UPDATE',
            value: AppUtils.formatTimestamp(status.timestamp),
            accentColor: AppTheme.accent,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PremiumInfoCard(
            icon: Icons.radar,
            label: 'SENSOR MODE',
            value: status.sensorMode as String,
            accentColor: AppTheme.primaryLight,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PremiumInfoCard(
            icon: Icons.timer_outlined,
            label: 'UPTIME',
            value: status.uptime as String,
            accentColor: AppTheme.accentCyan,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

// ── Pump stats ──────────────────────────────────────────────
class _PumpStatsRow extends StatelessWidget {
  final dynamic status;
  final bool isDark;

  const _PumpStatsRow({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PremiumInfoCard(
            icon: Icons.repeat_rounded,
            label: 'CYCLES',
            value: '${status.pumpCycles}',
            accentColor: AppTheme.success,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PremiumInfoCard(
            icon: Icons.schedule_rounded,
            label: 'TOTAL RUN',
            value: status.formattedPumpTime,
            accentColor: AppTheme.warning,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PremiumInfoCard(
            icon: Icons.wifi_rounded,
            label: 'SIGNAL',
            value: '${status.wifiRssi} dBm',
            accentColor: AppTheme.primaryLight,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

// ── Alarm banner ────────────────────────────────────────────
class _AlarmBanner extends StatelessWidget {
  final bool isDryRun;
  const _AlarmBanner({required this.isDryRun});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.danger.withValues(alpha: 0.15),
            AppTheme.danger.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
        boxShadow: AppTheme.glowDanger(intensity: 0.2),
      ),
      child: Row(
        children: [
          Icon(
            isDryRun ? Icons.warning_amber_rounded : Icons.notifications_active,
            color: AppTheme.danger,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDryRun ? 'Dry Run Protection' : 'Critical Alert',
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  isDryRun ? 'Check water source immediately!' : 'Tank level is critical!',
                  style: TextStyle(
                    color: AppTheme.danger.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Device selector ─────────────────────────────────────────
class _DeviceSelector extends StatelessWidget {
  final bool isDark;
  const _DeviceSelector({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceService>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
      ),
      child: DropdownButton<String>(
        value: device.selectedDeviceId,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.unfold_more_rounded, size: 18),
        dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        items: device.deviceIds
            .map((id) => DropdownMenuItem(
                  value: id,
                  child: Row(
                    children: [
                      const Icon(Icons.device_hub, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(device.deviceName(id), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ))
            .toList(),
        onChanged: (id) {
          if (id != null) device.selectDevice(id);
        },
      ),
    );
  }
}

// ── No device placeholder ───────────────────────────────────
class _NoDevicePlaceholder extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAdd;

  const _NoDevicePlaceholder({required this.isDark, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  boxShadow: AppTheme.glowBlue(intensity: 0.2),
                ),
                child: Icon(
                  Icons.devices_other_rounded,
                  size: 44,
                  color: AppTheme.accent.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Device Found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Add your ESP32 device to start monitoring your water tank in real-time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black45,
                  height: 1.6,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              GradientButton(
                label: 'Add Device',
                icon: Icons.add_rounded,
                onPressed: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
