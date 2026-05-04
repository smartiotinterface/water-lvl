# ✅ SmartIoT Production Fix Checklist
## বাগ টেস্ট + সিমুলেশন রিপোর্ট — v3.5 → v3.6-FIXED

---

## 🔴 CRITICAL BUGS — সমাধান করা হয়েছে

### [C-1] Firebase Credentials Exposed in Git ✅ FIXED
- **সমস্যা:** `lib/firebase_options.dart`-এ real API keys (AIzaSy...) hardcoded ছিল
- **ঝুঁকি:** যে কেউ আপনার Firebase project access করতে পারতো
- **সমাধান:** Placeholder দিয়ে replace করা হয়েছে। `.gitignore`-এ যোগ করা হয়েছে
- **আপনার কাজ:** `flutterfire configure --project=YOUR_PROJECT_ID` চালান

### [C-2] `firebase_options.dart` .gitignore-এ ছিল না ✅ FIXED
- **সমস্যা:** `.gitignore`-এ `lib/firebase_options.dart` এন্ট্রি মিসিং ছিল
- **সমাধান:** `.gitignore`-এ যোগ করা হয়েছে

### [C-3] `secrets.h` .gitignore-এ ছিল ✅ VERIFIED
- **স্ট্যাটাস:** `esp32/SmartIoT_v12/secrets.h` সঠিকভাবে git-ignored

### [C-4] Localization delegates missing from MaterialApp ✅ FIXED
- **সমস্যা:** `intl` package use হচ্ছিল কিন্তু `GlobalMaterialLocalizations.delegate` etc. ছিল না
- **সমাধান:** `main.dart`-এ `localizationsDelegates` এবং `supportedLocales` যোগ করা হয়েছে

---

## 🟠 HIGH BUGS — সমাধান করা হয়েছে

### [H-1] BLE Permission — Android 6-11 vs 12+ ✅ FIXED
- **সমস্যা:** `AndroidManifest.xml`-এ Android 12+ এর `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT` ছিল কিন্তু Android 6-11 এর `ACCESS_FINE_LOCATION` সঠিকভাবে ছিল না
- **সমাধান:** উভয় API level এর জন্য সম্পূর্ণ permission set যোগ করা হয়েছে

### [H-2] Firebase Rules — Insufficient Validation ✅ FIXED
- **সমস্যা:** Original rules-এ field-level `.validate` ছিল না
- **সমাধান:** সব fields-এ type validation + range check যোগ করা হয়েছে
- **নতুন:** `$other: {".validate": false}` — unknown fields block করা হয়েছে

### [H-3] DeviceService not in Provider tree — ProviderNotFoundException ✅ VERIFIED OK
- **স্ট্যাটাস:** `DeviceService` সঠিকভাবে `DashboardScreen.initState()`-এ create করা হয় এবং `ChangeNotifierProvider.value`-এ wrap করা হয়
- **মন্তব্য:** uid দরকার বলে root-এ রাখা যায় না — design সঠিক

### [H-4] `google-services.json` package name ✅ VERIFIED
- **স্ট্যাটাস:** Placeholder-এ `com.smartiot.smart_iot_interface` সেট করা আছে
- **আপনার কাজ:** Firebase Console থেকে real `google-services.json` download করুন

### [H-5] Network Security Config ✅ FIXED
- **সমস্যা:** Original config-এ Firebase domains explicitly listed ছিল না
- **সমাধান:** `firebaseio.com`, `googleapis.com` domains explicitly trust করা হয়েছে

---

## 🟡 MEDIUM ISSUES — সমাধান করা হয়েছে

### [M-1] Cleartext Traffic ✅ FIXED
- `android:usesCleartextTraffic="false"` যোগ করা হয়েছে AndroidManifest.xml-এ

### [M-2] pubspec.yaml dependency versions ✅ VERIFIED
- সব versions compatible এবং latest stable

### [M-3] `allow_backup="false"` ✅ FIXED
- Security best practice — backup disabled করা হয়েছে

---

## ✅ ESP32 Firmware — সিমুলেশন চেক

### Firmware v12.1.0 বাগ সিমুলেশন:

| সমস্যা | Status |
|--------|--------|
| AES-256-CBC separate input/output buffers | ✅ Fixed in v12.1.0 |
| OTA URL whitelist | ✅ Fixed in v12.1.0 |
| BLE CONNECT parser i-1 underflow | ✅ Fixed in v12.1.0 |
| AES decrypt PKCS7 padding guard | ✅ Fixed in v12.1.0 |
| Deep sleep button activity check | ✅ Fixed in v12.1.0 |
| OLED non-blocking screen cycle | ✅ Fixed in v12.1.0 |
| BLECmdCallback static instance | ✅ Fixed in v12.1.0 |
| No delay() in main loop | ✅ Confirmed |
| WiFi password NOT logged to Serial | ✅ Confirmed |
| secrets.h git-ignored | ✅ Confirmed |

---

## 📋 সেটআপ চেকলিস্ট (আপনার করণীয়)

- [ ] `flutterfire configure --project=YOUR_PROJECT_ID` → `lib/firebase_options.dart` generate করুন
- [ ] Firebase Console → Android App → `google-services.json` download → `android/app/` তে রাখুন
- [ ] `esp32/SmartIoT_v12/secrets.h` এ আপনার `FIREBASE_HOST` এবং `JWT_HMAC_SECRET` দিন
- [ ] Firebase Console → Realtime Database → Rules → `firebase/database.rules.json` deploy করুন
- [ ] Firebase Console → Authentication → Email/Password enable করুন
- [ ] Firebase Cloud Messaging → Server key সেট করুন (FCM notifications এর জন্য)

---

## 🧪 Simulate করা হয়েছে যেসব scenario:

1. **নেটওয়ার্ক বিচ্ছিন্ন:** OfflineService Hive cache থেকে data দেখাবে ✅
2. **Firebase error:** DeviceService retry logic 1→30 seconds exponential backoff ✅
3. **Command timeout:** togglePump/toggleMode 10 second timeout — UI freeze হবে না ✅
4. **BLE provisioning:** 20-byte MTU chunking, response buffer accumulation ✅
5. **AES encryption:** ESP32 chip ID থেকে key derivation — hardware bound ✅
6. **Deep sleep:** alarm condition থাকলে sleep skip করবে ✅
7. **OTA:** URL whitelist — শুধু Firebase Storage URLs accept করবে ✅
8. **Dry-run protection:** পাম্প চলছে কিন্তু water level উঠছে না → 3 min পর pump বন্ধ ✅

---

*Report generated: SmartIoT v3.6-FIXED*
