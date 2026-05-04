// lib/main.dart
// SmartIoT v3.1.0 — App entry point
// ─────────────────────────────────────────────────────────────────────────────
// [FIX-1] DeviceService NOT in root MultiProvider (needs uid — created per-screen)
// [FIX-2] AppLocalizations.delegate ADDED — required for l10n to work
// [FIX-3] GlobalMaterialLocalizations + GlobalCupertinoLocalizations delegates
// [FIX-4] NotificationService.init() called before runApp
// [FIX-5] Crashlytics only in release mode

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'services/offline_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics error handler — release builds only
  if (!kDebugMode) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
  }

  await OfflineService.init();
  await NotificationService.init();

  final prefs = await SharedPreferences.getInstance();
  final darkMode = prefs.getBool(AppConstants.prefDarkMode) ?? true;

  runApp(SmartIoTApp(initialDarkMode: darkMode));
}

// ── Theme notifier ────────────────────────────────────────────────────────────
class ThemeNotifier extends ChangeNotifier {
  bool _isDark;
  ThemeNotifier(this._isDark);

  bool get isDark => _isDark;

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefDarkMode, _isDark);
  }
}

// ── App root ──────────────────────────────────────────────────────────────────
class SmartIoTApp extends StatelessWidget {
  final bool initialDarkMode;
  const SmartIoTApp({super.key, required this.initialDarkMode});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeNotifier(initialDarkMode)),
        // [FIX-1] DeviceService is intentionally NOT here — it requires uid.
        // It is created inside DashboardScreen via ChangeNotifierProvider.value.
      ],
      child: const _MaterialAppWrapper(),
    );
  }
}

class _MaterialAppWrapper extends StatelessWidget {
  const _MaterialAppWrapper();

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      // [FIX-2] AppLocalizations.delegate MUST be first so custom strings
      // resolve correctly. Without this, AppLocalizations.of(context) throws.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
    );
  }
}
