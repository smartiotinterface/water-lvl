// lib/screens/settings_screen.dart
// SmartIoT v2.2.0 — App Settings & Profile

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../core/constants.dart';
import '../theme/app_theme.dart';
import '../core/utils.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final DeviceService? deviceService;
  // [FIX] onLogout callback — fixes unused _logout in dashboard_screen.dart
  final Future<void> Function()? onLogout;
  const SettingsScreen({super.key, this.deviceService, this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  bool _isEditingProfile = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVersion();
    // Pre-fill display name
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthService>().currentUser;
      if (user?.displayName != null) {
        _nameCtrl.text = user!.displayName!;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final user = context.read<AuthService>().currentUser;
      await user?.updateDisplayName(name);
      if (mounted) {
        AppUtils.showSnack(context, '✅ Display name updated!');
        setState(() => _isEditingProfile = false);
      }
    } catch (e) {
      if (mounted) AppUtils.showSnack(context, 'Failed to update name.', isError: true);
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    } catch (_) {
      setState(() => _appVersion = AppConstants.appVersion);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        AppUtils.showSnack(context, 'Could not open link.', isError: true);
      }
    }
  }

  Future<void> _logout() async {
    // [FIX] Use injected callback from Dashboard (avoids duplicate dialog logic)
    if (widget.onLogout != null) {
      Navigator.pop(context); // close settings first
      await widget.onLogout!();
      return;
    }
    // Fallback: standalone logout (if opened without callback)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: AppTheme.danger)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final auth = context.watch<AuthService>();
    final email = auth.currentUser?.email ?? 'Not signed in';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.primaryBlue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile ──────────────────────────────────────────
          _SectionHeader(label: 'PROFILE', isDark: isDark),
          _ProfileCard(
            isDark: isDark,
            auth: auth,
            email: email,
            nameCtrl: _nameCtrl,
            isEditing: _isEditingProfile,
            onEdit: () => setState(() => _isEditingProfile = true),
            onSave: _saveDisplayName,
            onCancel: () => setState(() {
              _isEditingProfile = false;
              _nameCtrl.text = auth.currentUser?.displayName ?? '';
            }),
          ),

          const SizedBox(height: 16),

          // ── Appearance ────────────────────────────────────────
          _SectionHeader(label: 'APPEARANCE', isDark: isDark),
          _SettingsCard(isDark: isDark, children: [
            _SwitchRow(
              icon: isDark ? Icons.dark_mode : Icons.light_mode,
              label: 'Dark Mode',
              value: isDark,
              isDark: isDark,
              onChanged: (_) => context.read<ThemeNotifier>().toggle(),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Support ───────────────────────────────────────────
          _SectionHeader(label: 'SUPPORT & SOCIAL', isDark: isDark),
          _SettingsCard(isDark: isDark, children: [
            _LinkRow(
              icon: Icons.play_circle_filled,
              label: 'YouTube',
              sublabel: 'Subscribe to our channel',
              color: const Color(0xFFFF0000),
              isDark: isDark,
              onTap: () => _launch('https://www.youtube.com/@SmartIoTInterface'),
            ),
            _Divider(isDark: isDark),
            _LinkRow(
              icon: Icons.facebook,
              label: 'Facebook',
              sublabel: 'Follow our page',
              color: const Color(0xFF1877F2),
              isDark: isDark,
              onTap: () => _launch('https://www.facebook.com/SmartIoTInterface'),
            ),
            _Divider(isDark: isDark),
            _LinkRow(
              icon: Icons.email_outlined,
              label: 'Email Support',
              sublabel: 'smartiotinterface@gmail.com',
              color: AppTheme.accent,
              isDark: isDark,
              onTap: () => _launch(
                  'mailto:smartiotinterface@gmail.com?subject=SmartIoT%20Support'),
            ),
            _Divider(isDark: isDark),
            _LinkRow(
              icon: Icons.phone_outlined,
              label: 'Call Support',
              sublabel: '+8801680603444',
              color: AppTheme.success,
              isDark: isDark,
              onTap: () => _launch('tel:+8801680603444'),
            ),
          ]),

          const SizedBox(height: 16),

          // ── About ─────────────────────────────────────────────
          _SectionHeader(label: 'ABOUT', isDark: isDark),
          _SettingsCard(isDark: isDark, children: [
            _InfoRow(
              icon: Icons.water_drop,
              label: 'App Name',
              value: AppConstants.appName,
              isDark: isDark,
            ),
            _Divider(isDark: isDark),
            _InfoRow(
              icon: Icons.tag,
              label: 'Version',
              value: _appVersion.isNotEmpty ? _appVersion : AppConstants.appVersion,
              isDark: isDark,
            ),
            _Divider(isDark: isDark),
            _InfoRow(
              icon: Icons.code,
              label: 'Developer',
              value: AppConstants.developerName,
              isDark: isDark,
            ),
            _Divider(isDark: isDark),
            _InfoRow(
              icon: Icons.business,
              label: 'Company',
              value: AppConstants.companyName,
              isDark: isDark,
            ),
            _Divider(isDark: isDark),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'Made with 💙 in Bangladesh 🇧🇩',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Logout ────────────────────────────────────────────
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _logout,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable section header ──────────────────────────────────

// ── Premium Profile Card ────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final bool isDark, isEditing;
  final AuthService auth;
  final String email;
  final TextEditingController nameCtrl;
  final VoidCallback onEdit, onSave, onCancel;

  const _ProfileCard({
    required this.isDark,
    required this.auth,
    required this.email,
    required this.nameCtrl,
    required this.isEditing,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName;
    final initials = _getInitials(displayName, email);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppTheme.darkCard, const Color(0xFF0D2035)]
              : [Colors.white, const Color(0xFFEFF6FF)],
        ),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.5) : AppTheme.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.accentGradient,
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 2.5),
                      boxShadow: AppTheme.glowBlue(intensity: 0.4),
                    ),
                    child: photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _InitialsText(initials: initials),
                            ),
                          )
                        : _InitialsText(initials: initials),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.success,
                        border: Border.all(
                          color: isDark ? AppTheme.darkBg : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // User info
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                          ),
                          filled: true,
                          fillColor: AppTheme.accent.withValues(alpha: 0.06),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName ?? 'Set your name',
                            style: TextStyle(
                              color: displayName != null
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.white38,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 12, color: AppTheme.accent),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppTheme.success.withValues(alpha: 0.12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Edit / Save buttons
          if (isEditing)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancel'),
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save Name'),
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Display Name'),
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getInitials(String? displayName, String email) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return displayName[0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }
}

class _InitialsText extends StatelessWidget {
  final String initials;
  const _InitialsText({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }
}

// ── Card container ────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _SettingsCard({required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.black12),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: isDark ? Colors.white12 : Colors.black12,
      );
}

// ── Info row ──────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }
}

// ── Switch row ────────────────────────────────────────────────
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.accent,
        ),
      ]),
    );
  }
}

// ── Link row ──────────────────────────────────────────────────
class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18,
              color: isDark ? Colors.white24 : Colors.black26),
        ]),
      ),
    );
  }
}
