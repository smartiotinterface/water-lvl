<div align="center">

<img src="https://img.shields.io/badge/Version-v13.1.0-0EA5E9?style=for-the-badge" />
<img src="https://img.shields.io/badge/Flutter-3.1.0-02569B?style=for-the-badge&logo=flutter" />
<img src="https://img.shields.io/badge/ESP32-Arduino-E7352C?style=for-the-badge&logo=arduino" />
<img src="https://img.shields.io/badge/Firebase-Realtime_DB-FFCA28?style=for-the-badge&logo=firebase" />
<img src="https://img.shields.io/badge/Made_in-Bangladesh_🇧🇩-006A4E?style=for-the-badge" />

# 💧 Smart Water Level Control BD

**ESP32 + Flutter + Firebase — সম্পূর্ণ স্মার্ট পানির ট্যাংক মনিটরিং সিস্টেম**

[📱 Download APK](#download) · [🔧 Setup Guide](#setup) · [📡 BLE Provisioning](#ble) · [📞 Contact](#contact)

</div>

---

## ✨ ফিচারসমূহ

| ফিচার | বিবরণ |
|---|---|
| 🔵 **BLE Provisioning** | Bluetooth দিয়ে ESP32-কে WiFi কানেক্ট করা |
| 💧 **Real-time Monitoring** | ট্যাংকের পানির স্তর লাইভ দেখা |
| 🔴 **Pump Control** | অ্যাপ থেকে পাম্প চালু/বন্ধ করা |
| 🤖 **Auto Mode** | পানি কম হলে স্বয়ংক্রিয়ভাবে পাম্প চালু |
| 📊 **History Log** | পাম্প ও পানির ইতিহাস দেখা |
| 🔔 **Push Notifications** | Dry run, alarm, tank full অ্যালার্ট |
| 🌙 **Dark / Light Mode** | থিম পরিবর্তন |
| 📡 **Offline Support** | শেষ known status offline-এও দেখায় |
| 🌐 **Bangla + English** | বাংলা ও ইংরেজি দুটো ভাষা সমর্থন |

---

## 📦 Download

| ফাইল | বিবরণ |
|---|---|
| [`SmartIoT_v13.1_COMPLETE_2026-05-04.zip`](SmartIoT_v13.1_COMPLETE_2026-05-04.zip) | সম্পূর্ণ প্রজেক্ট (Flutter App + ESP32 Firmware + Firebase Functions) |

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
GPIO  0  → Factory Reset        (10s hold করলে reset)
GPIO 21  → OLED SDA             (I2C)
GPIO 22  → OLED SCL             (I2C)
GPIO 27  → Ultrasonic TRIG      (OUTPUT)
GPIO 14  → Ultrasonic ECHO      (INPUT)
GPIO 33  → Sensor Mode Toggle   (LOW=Float, HIGH=Ultrasonic)
```

---

## 📦 Arduino Libraries

Arduino IDE → Library Manager থেকে install করুন:

- **ArduinoJson** by Benoit Blanchon `v7.x`
- **Adafruit SSD1306** by Adafruit
- **Adafruit GFX Library** by Adafruit

> বাকি সব (WiFi, BLE, HTTPClient, Preferences, mbedtls) ESP32 package-এ built-in।

---

## <a name="setup"></a>🔥 Setup Guide

### Step 1 — Firebase Project

1. [Firebase Console](https://console.firebase.google.com) → New Project
2. **Realtime Database** তৈরি করুন
3. **Authentication** → Email/Password enable করুন

### Step 2 — Database Rules Deploy

```bash
firebase login
firebase use YOUR_PROJECT_ID
firebase deploy --only database
```

### Step 3 — Cloud Functions Deploy

```bash
cd firebase/functions && npm install && cd ../..

# Secret set করুন
firebase functions:secrets:set DEVICE_REGISTRATION_SECRET
# Value: openssl rand -hex 32 দিয়ে generate করুন

firebase deploy --only functions
```

### Step 4 — ESP32 Firmware

```bash
cd esp32/SmartIoT_v13
cp secrets.h.example secrets.h
# secrets.h খুলে আপনার Firebase values দিন
```

`secrets.h`-এ এই চারটি value পূরণ করুন:

```cpp
#define FIREBASE_HOST              "your-project-rtdb.firebaseio.com"
#define FIREBASE_WEB_API_KEY       "AIzaSy..."
#define DEVICE_REGISTRATION_SECRET "your-secret-here"
#define CLOUD_FUNCTIONS_BASE_URL   "https://us-central1-your-project.cloudfunctions.net"
```

Arduino IDE → Board: **ESP32 Dev Module** → Upload

### Step 5 — Flutter App

```bash
flutter pub get
flutter gen-l10n
flutter run
```

---

## <a name="ble"></a>📡 BLE Provisioning ব্যবহার

1. ESP32 প্রথমবার boot করুন — BLE শুরু হবে
2. অ্যাপে **"Add Device"** → **"BLE Setup"** ট্যাপ করুন
3. ESP32 device দেখালে **"Connect"** করুন
4. WiFi list দেখাবে — আপনার নেটওয়ার্ক বেছে নিন
5. Password দিন → **"Send to Device"**
6. ESP32 কানেক্ট হলে IP দেখাবে ✅

---

## 🏗️ প্রজেক্ট স্ট্রাকচার

```
SmartIoT_FINAL/
├── lib/
│   ├── main.dart                         # App entry point
│   ├── screens/
│   │   ├── splash_screen.dart            # Animated splash
│   │   ├── login_screen.dart             # Firebase Auth
│   │   ├── dashboard_screen.dart         # Main dashboard
│   │   ├── ble_provisioning_screen.dart  # BLE WiFi setup ← v13.1 fixed
│   │   ├── device_setup_screen.dart      # Add new device
│   │   ├── history_screen.dart           # Event history
│   │   └── settings_screen.dart          # App settings
│   └── services/
│       ├── ble_provisioning_service.dart # BLE logic ← v13.1 fixed
│       ├── firebase_service.dart         # RTDB operations
│       ├── device_service.dart           # Device state
│       ├── auth_service.dart             # Firebase Auth
│       ├── notification_service.dart     # FCM push
│       └── offline_service.dart          # Hive offline cache
├── esp32/SmartIoT_v13/
│   ├── SmartIoT_v13.ino                  # Firmware v13.1.0 ← fixed
│   ├── secrets.h                         # 🔒 gitignored
│   └── secrets.h.example                 # Template ← new
└── firebase/
    ├── database.rules.json               # Security rules
    └── functions/index.js                # Cloud Functions
```

---

## 🐛 Version History

| Version | Changes |
|---|---|
| **v13.1.0** | BLE async state machine, MTU fix, WiFi connect timeout, `AppLocalizations` delegate, `FIRMWARE_VERSION` fix, `.gitignore` security fix |
| v13.0.0 | Firebase Custom Token auth, Cloud Functions v2 |
| v12.1.0 | BLE chunked write, WiFi credential escaping |
| v12.0.0 | BLE provisioning, OLED display, ultrasonic sensor |

---

## 🔒 Security

- `secrets.h` এবং `google-services.json` কখনো GitHub-এ push করবেন না
- `.gitignore`-এ এই ফাইলগুলো listed আছে
- ESP32 Firebase Custom Token ব্যবহার করে (legacy secret নয়)
- Database rules শুধু authenticated devices-কে write করতে দেয়

---

## <a name="contact"></a>📞 Contact

<div align="center">

| | |
|---|---|
| 👨‍💻 **Developer** | Sobuj Billah |
| 🏢 **Company** | Smart IoT Interface |
| 📧 **Email** | smartiotinterface@gmail.com |
| 📱 **Phone** | +8801680603444 |
| ▶️ **YouTube** | [Smart IoT Interface](https://www.youtube.com/@SmartIoTInterface) |

*Made with 💙 in Bangladesh 🇧🇩*

</div>
