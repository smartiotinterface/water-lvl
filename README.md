# 💧 Smart Water Level Control BD
### by [Smart IoT Interface](https://www.youtube.com/@SmartIoTInterface) · v3.1.0

একটি ESP32-ভিত্তিক স্মার্ট পানির ট্যাংক মনিটরিং এবং কন্ট্রোল সিস্টেম। Firebase Realtime Database ও BLE WiFi Provisioning সহ সম্পূর্ণ Flutter অ্যাপ।

---

## 📱 অ্যাপ ফিচারসমূহ

| ফিচার | বিবরণ |
|---|---|
| 🔵 BLE Provisioning | Bluetooth দিয়ে ESP32-কে WiFi কানেক্ট করা |
| 💧 Real-time Monitoring | ট্যাংকের পানির স্তর লাইভ দেখা |
| 🔴 Pump Control | অ্যাপ থেকে পাম্প চালু/বন্ধ করা |
| 🤖 Auto Mode | পানি কম হলে স্বয়ংক্রিয়ভাবে পাম্প চালু |
| 📊 History | পাম্প ও পানির ইতিহাস দেখা |
| 🔔 Push Notifications | Dry run, alarm, tank full অ্যালার্ট |
| 🌙 Dark / Light Mode | থিম পরিবর্তন |
| 📡 Offline Support | শেষ known status offline-এও দেখায় |

---

## 🛠️ হার্ডওয়্যার পিন ম্যাপিং

```
GPIO  4  → Float Sensor LOW     (INPUT_PULLUP)
GPIO 15  → Float Sensor MID     (INPUT_PULLUP)
GPIO  5  → Float Sensor FULL    (INPUT_PULLUP)
GPIO  2  → Pump Relay           (OUTPUT, HIGH=ON)
GPIO 18  → Buzzer               (OUTPUT)
GPIO 16  → LED WiFi             (OUTPUT)
GPIO 17  → LED Pump             (OUTPUT)
GPIO 23  → Button MODE          (INPUT_PULLUP)
GPIO 25  → Button PUMP          (INPUT_PULLUP)
GPIO 26  → Button MUTE          (INPUT_PULLUP)
GPIO  0  → Factory Reset        (INPUT_PULLUP, 10s hold)
GPIO 21  → OLED SDA             (I2C)
GPIO 22  → OLED SCL             (I2C)
GPIO 27  → Ultrasonic TRIG      (OUTPUT)
GPIO 14  → Ultrasonic ECHO      (INPUT)
GPIO 33  → Sensor Mode Toggle   (LOW=Float, HIGH=Ultrasonic)
GPIO 34  → Emergency Wakeup     (INPUT)
```

---

## 📦 প্রয়োজনীয় Arduino লাইব্রেরি

Arduino IDE → Library Manager থেকে ইন্সটল করুন:

- **ArduinoJson** by Benoit Blanchon (v7.x)
- **Adafruit SSD1306** by Adafruit
- **Adafruit GFX Library** by Adafruit

বাকি সব (WiFi, BLE, HTTPClient, Preferences, esp_sleep, mbedtls) ESP32 Arduino package-এ built-in।

---

## 🔥 Firebase Setup (একবারই করতে হবে)

### Step 1: Project তৈরি
1. [Firebase Console](https://console.firebase.google.com) → New Project → "smartiot-XXXXX"
2. **Realtime Database** তৈরি করুন (শুরুতে test mode-এ)
3. **Authentication** → Email/Password enable করুন

### Step 2: Database Rules Deploy
```bash
firebase login
firebase use smartiot-XXXXX
firebase deploy --only database
```

### Step 3: Cloud Functions Deploy
```bash
cd firebase/functions
npm install
cd ../..

# Secret set করুন (ESP32 ও Function দুটোতেই এটাই লাগবে)
firebase functions:secrets:set DEVICE_REGISTRATION_SECRET
# Enter করুন: openssl rand -hex 32 দিয়ে generate করা value

firebase deploy --only functions
```

### Step 4: Android App Config
```bash
# FlutterFire CLI install
dart pub global activate flutterfire_cli

# Config generate করুন
flutterfire configure --project=smartiot-XXXXX
```

---

## 🔧 ESP32 Firmware Setup

### Step 1: secrets.h তৈরি করুন
```bash
cd esp32/SmartIoT_v13
cp secrets.h.example secrets.h
```

তারপর `secrets.h` খুলে এই তিনটি value পূরণ করুন:
```cpp
#define FIREBASE_HOST              "smartiot-XXXXX-default-rtdb.firebaseio.com"
#define FIREBASE_WEB_API_KEY       "AIzaSy..."  // Firebase Console → Project Settings
#define DEVICE_REGISTRATION_SECRET "abc123..."  // Step 3 এ যেটা set করেছিলেন
#define CLOUD_FUNCTIONS_BASE_URL   "https://us-central1-smartiot-XXXXX.cloudfunctions.net"
```

### Step 2: Arduino IDE Settings
- Board: **ESP32 Dev Module**
- Upload Speed: 921600
- Flash Size: 4MB (32Mb)
- Partition Scheme: Default 4MB with spiffs

### Step 3: Upload করুন
Arduino IDE → Open `esp32/SmartIoT_v13/SmartIoT_v13.ino` → Upload

---

## 📱 Flutter App Setup

```bash
# Dependencies install
flutter pub get

# Generate l10n files
flutter gen-l10n

# Debug এ run করুন
flutter run

# Release APK build
flutter build apk --release
```

### Android Signing (Production APK)
```bash
keytool -genkey -v -keystore smartiot.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smartiot

cp android/key.properties.template android/key.properties
# key.properties-এ আপনার keystore path ও password দিন
```

---

## 📡 BLE Provisioning ব্যবহার

1. ESP32 প্রথমবার boot করুন — BLE Advertising শুরু হবে
2. অ্যাপে **"Add Device"** → **"BLE Setup"** ট্যাপ করুন
3. ESP32 device খুঁজে পেলে "Connect" করুন
4. WiFi list দেখাবে — আপনার নেটওয়ার্ক বেছে নিন
5. Password দিন → "Send to Device"
6. ESP32 WiFi কানেক্ট হলে IP দেখাবে ✅

---

## 🏗️ প্রজেক্ট স্ট্রাকচার

```
SmartIoT_FINAL/
├── lib/
│   ├── main.dart                        # App entry point
│   ├── core/
│   │   ├── constants.dart               # App constants & DB paths
│   │   ├── utils.dart                   # Helper functions
│   │   └── secure_storage.dart          # Encrypted local storage
│   ├── models/
│   │   └── device_model.dart            # Data models
│   ├── screens/
│   │   ├── splash_screen.dart           # Animated splash
│   │   ├── login_screen.dart            # Firebase Auth
│   │   ├── dashboard_screen.dart        # Main dashboard
│   │   ├── ble_provisioning_screen.dart # BLE WiFi setup
│   │   ├── device_setup_screen.dart     # Add new device
│   │   ├── history_screen.dart          # Event history
│   │   └── settings_screen.dart        # App settings
│   ├── services/
│   │   ├── auth_service.dart            # Firebase Authentication
│   │   ├── firebase_service.dart        # RTDB operations
│   │   ├── device_service.dart          # Device state management
│   │   ├── ble_provisioning_service.dart# BLE logic
│   │   ├── notification_service.dart    # FCM push notifications
│   │   └── offline_service.dart         # Hive offline cache
│   ├── widgets/
│   │   ├── tank_widget.dart             # Animated water tank
│   │   ├── control_panel.dart           # Pump controls
│   │   └── premium_widgets.dart         # Cards, badges etc.
│   └── theme/
│       └── app_theme.dart               # Light/dark themes
├── esp32/
│   └── SmartIoT_v13/
│       ├── SmartIoT_v13.ino             # Main firmware (v13.1.0)
│       ├── secrets.h                    # 🔒 YOUR secrets (gitignored)
│       └── secrets.h.example            # Template — copy & fill
├── firebase/
│   ├── database.rules.json              # RTDB security rules
│   └── functions/
│       └── index.js                     # Cloud Functions (Node 20)
└── android/
    └── app/
        └── src/main/
            └── AndroidManifest.xml      # BLE + FCM permissions
```

---

## 🔒 Security Notes

- `secrets.h` এবং `google-services.json` কখনো GitHub-এ push করবেন না
- `.gitignore` এ এই ফাইলগুলো already listed আছে
- Database rules শুধুমাত্র authenticated devices-কে write করতে দেয়
- ESP32 Firebase Custom Token ব্যবহার করে (legacy database secret নয়)

---

## 🐛 Version History

| Version | Changes |
|---|---|
| v13.1.0 | BLE async state machine, MTU fix, connection timeout |
| v13.0.0 | Firebase Custom Token auth, Cloud Functions v2 |
| v12.1.0 | BLE chunked write, WiFi credential escaping |
| v12.0.0 | BLE provisioning, OLED display, ultrasonic sensor |

---

## 📞 Contact

- **Developer:** Sobuj Billah
- **Company:** Smart IoT Interface
- **Email:** smartiotinterface@gmail.com
- **Phone:** +8801680603444
- **YouTube:** [Smart IoT Interface](https://www.youtube.com/@SmartIoTInterface)

Made with 💙 in Bangladesh 🇧🇩
