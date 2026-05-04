// lib/screens/history_screen.dart
// SmartIoT v2.2.0 — Device Event History
// Shows chronological event log fetched from Firebase

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/device_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  final DeviceService deviceService;
  const HistoryScreen({super.key, required this.deviceService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.deviceService.selectedDeviceId == null) {
      setState(() { _loading = false; _error = 'No device selected.'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final fb = FirebaseService();
      final events = await fb.getHistory(
        widget.deviceService.selectedDeviceId!,
        limit: 50,
      );
      setState(() { _events = events; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load history.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Event History'),
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.primaryBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.error_outline, size: 48,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
                  ]),
                )
              : _events.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.history, size: 64,
                            color: isDark ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 16),
                        Text('No events recorded yet.',
                            style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        itemBuilder: (ctx, i) => _EventTile(
                          event: _events[i],
                          isDark: isDark,
                        ),
                      ),
                    ),
    );
  }
}

// ── Event tile ──────────────────────────────────────────────
class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isDark;
  const _EventTile({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final eventStr = (event['event'] ?? '').toString();
    final ts = event['ts'];
    final timeStr = _formatTs(ts);
    final info = _eventInfo(eventStr);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.black12),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(info.icon, color: info.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              eventStr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return 'Unknown time';
    try {
      int epoch = (ts is String) ? int.parse(ts) : (ts as num).toInt();
      if (epoch < 1000000000000) epoch *= 1000;
      return DateFormat('dd MMM yyyy, HH:mm:ss')
          .format(DateTime.fromMillisecondsSinceEpoch(epoch).toLocal());
    } catch (_) {
      return 'Unknown time';
    }
  }

  _EventInfo _eventInfo(String event) {
    final e = event.toLowerCase();
    if (e.contains('pump') && e.contains('on')) {
      return const _EventInfo(Icons.power, AppTheme.success);
    } else if (e.contains('pump') && e.contains('off')) {
      return const _EventInfo(Icons.power_off, Colors.grey);
    } else if (e.contains('mode') && e.contains('auto')) {
      return const _EventInfo(Icons.autorenew, AppTheme.accent);
    } else if (e.contains('mode') && e.contains('manual')) {
      return const _EventInfo(Icons.touch_app, AppTheme.warning);
    } else if (e.contains('low') || e.contains('empty')) {
      return const _EventInfo(Icons.water_drop_outlined, AppTheme.danger);
    } else if (e.contains('full') || e.contains('overflow')) {
      return const _EventInfo(Icons.water, AppTheme.accent);
    } else if (e.contains('dry')) {
      return const _EventInfo(Icons.warning_amber, AppTheme.warning);
    } else if (e.contains('register') || e.contains('boot')) {
      return const _EventInfo(Icons.devices, AppTheme.primaryLight);
    } else if (e.contains('ota') || e.contains('update')) {
      return const _EventInfo(Icons.system_update, AppTheme.success);
    }
    return const _EventInfo(Icons.info_outline, AppTheme.accent);
  }
}

class _EventInfo {
  final IconData icon;
  final Color color;
  const _EventInfo(this.icon, this.color);
}
