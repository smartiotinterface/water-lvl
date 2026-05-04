# 🔧 SmartIoT সেটআপ গাইড — v3.6-FIXED

## ⚡ দ্রুত শুরু (5 ধাপে)

---

## ধাপ ১: Firebase Project তৈরি

1. [console.firebase.google.com](https://console.firebase.google.com) → **Add project**
2. **Realtime Database** চালু করুন → Start in test mode (পরে rules দেবেন)
3. **Authentication** → Email/Password → Enable

---

## ধাপ ২: Flutter অ্যাপ সেটআপ

```bash
# Firebase CLI install (একবার)
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# Project clone করার পর
cd SmartIoT_FIXED/
flutter pub get

# Firebase configure করুন (এটি lib/firebase_options.dart তৈরি করবে)
flutterfire configure --project=YOUR_PROJECT_ID

# Run করুন
flutter run
```

### Android-এর জন্য google-services.json:
1. Firebase Console → Project Settings → Your Apps → Android
2. Package name: `com.smartiot.smart_iot_interface` দিন
3. `google-services.json` download করুন → `android/app/` ফোল্ডারে রাখুন

---

## ধাপ ৩: Firebase Database Rules Deploy

```bash
# Firebase CLI দিয়ে:
firebase deploy --only database

# অথবা manual:
# Firebase Console → Realtime Database → Rules
# firebase/database.rules.json এর content paste করুন → Publish
```

---

## ধাপ ৪: ESP32 Firmware সেটআপ

```bash
cd esp32/SmartIoT_v12/
cp secrets.h secrets.h.backup  # এটি already placeholder
# secrets.h edit করুন
```

`secrets.h` এ দিন:
```cpp
#define FIREBASE_HOST   "YOUR_PROJECT_ID-default-rtdb.firebaseio.com"
#define JWT_HMAC_SECRET "64-char-hex-from-openssl-rand-hex-32"
```

### JWT Secret generate করুন:
```bash
# Linux/Mac:
openssl rand -hex 32

# Windows PowerShell:
[System.BitConverter]::ToString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).Replace("-","").ToLower()
```

### Arduino IDE Libraries (Tools → Manage Libraries):
- `ArduinoJson` by Benoit Blanchon (v7.x)
- `Adafruit SSD1306`
- `Adafruit GFX Library`

### Board Settings:
- Board: **ESP32 Dev Module**
- Upload Speed: **921600**
- Flash Size: **4MB (32Mb)**
- Partition Scheme: **Default 4MB with spiffs**

---

## ধাপ ৫: Firebase Cloud Function (JWT Verify)

ESP32 যে JWT তৈরি করে সেটা verify করতে Cloud Function দরকার:

```bash
cd firebase/functions/
npm install
firebase deploy --only functions
```

---

## 🔐 Security Checklist

| চেক | Status |
|-----|--------|
| `lib/firebase_options.dart` — .gitignore এ আছে | ✅ |
| `android/app/google-services.json` — .gitignore এ আছে | ✅ |
| `esp32/SmartIoT_v12/secrets.h` — .gitignore এ আছে | ✅ |
| Firebase credentials কোনো .dart ফাইলে hardcode নেই | ✅ |
| WiFi password ESP32-এ AES-256 encrypted | ✅ |
| Firebase Rules production-ready validation আছে | ✅ |
| OTA URL whitelist active | ✅ |

---

## 🛠️ ট্রাবলশুটিং

| সমস্যা | সমাধান |
|--------|--------|
| `flutter pub get` ব্যর্থ | Dart SDK version চেক: `dart --version` (≥3.4.0) |
| BLE scan কাজ করছে না | Android: Location + Bluetooth permissions দিন |
| Firebase connection নেই | `firebase_options.dart` সঠিকভাবে configure করা? |
| ESP32 WiFi connect হচ্ছে না | BLE provisioning ব্যবহার করুন অথবা secrets.h চেক করুন |
| OTA ব্যর্থ | Firebase Storage URL সঠিক? GOOGLE_ROOT_CA expired? |
| Push notification আসছে না | FCM token Firebase-এ upload হচ্ছে? (fcmToken path দেখুন) |

---

*SmartIoT Interface — Made with 💙 in Bangladesh 🇧🇩*
