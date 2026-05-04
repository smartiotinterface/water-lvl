import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en')
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Smart IoT Interface'**
  String get app_name;

  /// Full product name
  ///
  /// In en, this message translates to:
  /// **'Smart Water Level Control BD'**
  String get product_name;

  /// Login button label
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Register button label
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgot_password;

  /// Water level label
  ///
  /// In en, this message translates to:
  /// **'Water Level'**
  String get water_level;

  /// Pump status label
  ///
  /// In en, this message translates to:
  /// **'Pump Status'**
  String get pump_status;

  /// Pump on state
  ///
  /// In en, this message translates to:
  /// **'Pump ON'**
  String get pump_on;

  /// Pump off state
  ///
  /// In en, this message translates to:
  /// **'Pump OFF'**
  String get pump_off;

  /// Mode label
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get mode;

  /// Auto mode
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get auto;

  /// Manual mode
  ///
  /// In en, this message translates to:
  /// **'MANUAL'**
  String get manual;

  /// On state
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get on;

  /// Off state
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// History screen title
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Dark mode toggle
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get dark_mode;

  /// Language selector
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// About section
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// App version label
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Developer label
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// Contact label
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contact_us;

  /// YouTube subscribe button
  ///
  /// In en, this message translates to:
  /// **'Subscribe on YouTube'**
  String get subscribe;

  /// Facebook follow button
  ///
  /// In en, this message translates to:
  /// **'Follow on Facebook'**
  String get follow;

  /// Offline status banner
  ///
  /// In en, this message translates to:
  /// **'Device Offline'**
  String get offline;

  /// Last update label
  ///
  /// In en, this message translates to:
  /// **'Last Update'**
  String get last_update;

  /// Uptime label
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get uptime;

  /// WiFi signal label
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get signal;

  /// BLE setup button
  ///
  /// In en, this message translates to:
  /// **'BLE Setup'**
  String get ble_setup;

  /// BLE scanning state
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// Connecting state
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// Success state
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Failed state
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// Empty device list message
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get no_devices;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
