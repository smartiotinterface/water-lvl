// lib/core/constants.dart
// v12.0 — App name updated to SMART WATER LEVEL CONTROL BD

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'SMART WATER LEVEL CONTROL BD';
  static const String brandName = 'Smart IoT Interface';
  static const String appVersion = '3.1.0';
  static const String developerName = 'Sobuj Billah';
  static const String companyName = 'Smart IoT Interface';

  // Firebase DB paths
  static const String devicesPath = 'devices';
  static const String statusPath = 'status';
  static const String controlPath = 'control';
  static const String metaPath = 'meta';
  static const String historyPath = 'history';
  static const String deviceOwnersPath = 'device_owners';
  static const String deviceSharedPath = 'device_shared';
  static const String usersPath = 'users';
  static const String schedulesPath = 'schedules';

  // Firebase status fields
  static const String fieldWaterLevel = 'water_level';
  static const String fieldWaterLevelPct = 'water_level_pct';
  static const String fieldPumpState = 'pump';
  static const String fieldPumpMode = 'mode';
  static const String fieldSensorMode = 'sensor_mode';
  static const String fieldWifiRssi = 'wifi_rssi';
  static const String fieldUptime = 'uptime';
  static const String fieldTimestamp = 'ts';
  static const String fieldFirmware = 'firmware';
  static const String fieldSerial = 'serial';
  static const String fieldAlarm = 'alarm';
  static const String fieldDryRun = 'dry_run';
  static const String fieldPumpCycles = 'pump_cycles';
  static const String fieldPumpTotalS = 'pump_total_s';
  static const String fieldBootCount = 'boot_count';
  static const String fieldHeapFree = 'heap_free';

  // Firebase control fields
  static const String fieldPumpCommand = 'pump_cmd';
  static const String fieldModeCommand = 'mode_cmd';
  static const String fieldCmdTimestamp = 'cmd_ts';
  static const String fieldDryRunReset = 'dry_run_reset';

  // Water level strings
  static const String levelEmpty = 'EMPTY';
  static const String levelLow = 'LOW';
  static const String levelMid = 'MID';
  static const String levelFull = 'FULL';

  // Sensor modes
  static const String sensorFloat = 'FLOAT';
  static const String sensorUltrasonic = 'ULTRA';

  // Pump states
  static const String pumpOn = 'ON';
  static const String pumpOff = 'OFF';

  // Pump modes
  static const String modeAuto = 'AUTO';
  static const String modeManual = 'MANUAL';

  // Timeouts
  static const Duration offlineThreshold = Duration(seconds: 30);
  static const Duration commandTimeout = Duration(seconds: 10);

  // UI
  static const double borderRadius = 16.0;
  static const double cardElevation = 4.0;

  // Shared preferences keys
  static const String prefDarkMode = 'dark_mode';
  static const String prefLastDeviceId = 'last_device_id';
}
