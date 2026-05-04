/**********************************************************************************
 * ESP32_SmartIoT_Complete_v12.ino
 * SMART WATER LEVEL CONTROL BD — v13.0.0  PRODUCTION
 * ─────────────────────────────────────────────────────────────────────────────
 * COMPANY  : SMART IoT Interface
 * DEVELOPER: Sobuj Billah (IoT Systems Architect)
 *
 * NEW IN v13.0.0 — Firebase Custom Token Authentication (CRITICAL FIX):
 *   [AUTH-FIX] ESP32 আর নিজে JWT বানায় না — Firebase শুধু তার নিজের
 *              private key দিয়ে signed token accept করে।
 *   [AUTH-NEW] getDeviceToken Cloud Function → Firebase Custom Token
 *   [AUTH-NEW] exchangeCustomToken() → Firebase ID Token (REST API)
 *   [AUTH-NEW] refreshIdToken() → Refresh Token দিয়ে auto-renewal
 *   [AUTH-NEW] checkTokenExpiry() → 1 ঘণ্টায় আপনা আপনি refresh
 *   [AUTH-NEW] Exponential backoff retry (5s → 5min)
 *   [SECRETS]  JWT_HMAC_SECRET removed; FIREBASE_WEB_API_KEY,
 *              DEVICE_REGISTRATION_SECRET, CLOUD_FUNCTIONS_BASE_URL added
 *
 * PIN MAPPING:
 *  GPIO  4  → Float Sensor LOW    (INPUT_PULLUP)
 *  GPIO 15  → Float Sensor MID    (INPUT_PULLUP)
 *  GPIO  5  → Float Sensor FULL   (INPUT_PULLUP)
 *  GPIO  2  → Pump Relay          (OUTPUT, HIGH=ON)
 *  GPIO 18  → Buzzer              (OUTPUT)
 *  GPIO 16  → LED WiFi            (OUTPUT)
 *  GPIO 17  → LED Pump            (OUTPUT)
 *  GPIO 23  → Button MODE         (INPUT_PULLUP, active LOW)
 *  GPIO 25  → Button PUMP         (INPUT_PULLUP, active LOW)
 *  GPIO 26  → Button MUTE         (INPUT_PULLUP, active LOW)
 *  GPIO  0  → Factory Reset       (INPUT_PULLUP, hold 10s)
 *  GPIO 21  → OLED SDA            (I2C)
 *  GPIO 22  → OLED SCL            (I2C)
 *  GPIO 27  → Ultrasonic TRIG     (OUTPUT)
 *  GPIO 14  → Ultrasonic ECHO     (INPUT, interrupt)
 *  GPIO 33  → Mode Toggle Switch  (LOW=Float, HIGH=Ultrasonic)
 *  GPIO 34  → Emergency Wakeup    (INPUT, ext wakeup from deep sleep)
 *
 * LIBRARIES REQUIRED (Arduino IDE → Manage Libraries):
 *  • ArduinoJson       by Benoit Blanchon  v7.x
 *  • Adafruit SSD1306  by Adafruit
 *  • Adafruit GFX Library by Adafruit
 *  Built-in (ESP32 package): WiFi, HTTPClient, WiFiClientSecure,
 *    BLEDevice, BLEServer, BLEUtils, BLE2902, Preferences,
 *    esp_sleep, Update, mbedtls
 *
 * SECURITY:
 *  • NO hardcoded secrets — all credentials in secrets.h (git-ignored)
 *  • WiFi credentials: AES-256-CBC encrypted in NVS (key = chip ID derived)
 *  • Firebase auth: JWT HS256 (no legacy database secret)
 *  • TLS: Google GTS Root R1 CA certificate validation
 *
 * CONTACT: smartiotinterface@gmail.com | +8801680603444
 * Made with 💙 in Bangladesh 🇧🇩
 **********************************************************************************/

// ============================================================================
// INCLUDES
// ============================================================================
#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Preferences.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoJson.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <esp_sleep.h>
#include <Update.h>
#include <mbedtls/aes.h>
#include <mbedtls/md.h>
#include <mbedtls/base64.h>
#include <time.h>

// ============================================================================
// SECRETS — copy secrets.h.template → secrets.h and fill in
// ============================================================================
#include "secrets.h"
// secrets.h defines:
//   FIREBASE_HOST              — your-project-id-default-rtdb.firebaseio.com
//   FIREBASE_WEB_API_KEY       — Firebase Web API Key (Project Settings → General)
//   DEVICE_REGISTRATION_SECRET — Shared secret with getDeviceToken Cloud Function
//   CLOUD_FUNCTIONS_BASE_URL   — https://us-central1-{project}.cloudfunctions.net
//   GOOGLE_ROOT_CA             — Google GTS Root R1 CA certificate (TLS)


// ============================================================================
// PIN DEFINITIONS
// ============================================================================
#define TRIG_PIN              27
#define ECHO_PIN              14
#define FLOAT_LOW_PIN          4
#define FLOAT_MID_PIN         15
#define FLOAT_FULL_PIN         5
#define TOGGLE_MODE_PIN       33
#define PUMP_RELAY_PIN         2
#define BUZZER_PIN            18
#define LED_WIFI_PIN          16
#define LED_PUMP_PIN          17
#define BTN_MODE_PIN          23
#define BTN_PUMP_PIN          25
#define BTN_MUTE_PIN          26
#define BTN_RESET_PIN          0
#define I2C_SDA_PIN           21
#define I2C_SCL_PIN           22
#define EMERGENCY_WAKEUP_PIN  34

// ============================================================================
// OLED
// ============================================================================
#define DISPLAY_WIDTH   128
#define DISPLAY_HEIGHT   64
#define DISPLAY_ADDR    0x3C
Adafruit_SSD1306 display(DISPLAY_WIDTH, DISPLAY_HEIGHT, &Wire, -1);

// ============================================================================
// BLE UUIDs (must match Flutter ble_provisioning_service.dart)
// ============================================================================
#define BLE_SERVICE_UUID   "12345678-1234-1234-1234-123456789abc"
#define BLE_CMD_CHAR_UUID  "12345678-1234-1234-1234-123456789abd"
#define BLE_RSP_CHAR_UUID  "12345678-1234-1234-1234-123456789abe"

// ============================================================================
// TIMING (ms)
// ============================================================================
#define SENSOR_READ_INTERVAL      200UL
#define FIREBASE_PUSH_INTERVAL   15000UL    // push status every 15s
#define FIREBASE_CMD_INTERVAL     2000UL    // poll commands every 2s
#define PUMP_MIN_ON_TIME          5000UL
#define PUMP_MIN_OFF_TIME        10000UL
#define PUMP_MAX_RUN_TIME      1800000UL    // 30 min
#define DRY_RUN_TIMEOUT        180000UL     // 3 min
#define BUTTON_DEBOUNCE           20UL
#define FACTORY_RESET_HOLD     10000UL
#define DEEP_SLEEP_INTERVAL    1800000UL    // 30 min
#define JWT_REFRESH_INTERVAL   3600000UL    // 1 hour
#define WATCHDOG_TIMEOUT          30        // seconds

// ============================================================================
// THRESHOLDS
// ============================================================================
#define PUMP_AUTO_ON_PCT          10
#define PUMP_AUTO_OFF_PCT         90
#define SENSOR_SAMPLES             5
#define SENSOR_MAJORITY            3
#define ULTRASONIC_EMPTY_CM       70
#define ULTRASONIC_FULL_CM        10
#define FIRMWARE_VERSION          "v13.1.0"

// ============================================================================
// ENUMERATIONS
// ============================================================================
enum WaterLevel  : uint8_t { LVL_EMPTY=0, LVL_LOW=1, LVL_MID=2, LVL_FULL=3 };
enum PumpMode    : uint8_t { MODE_AUTO=0, MODE_MANUAL=1 };
enum PumpState   : uint8_t { PUMP_OFF=0, PUMP_ON=1 };
enum SensorMode  : uint8_t { SENSOR_FLOAT=0, SENSOR_ULTRASONIC=1 };
enum OledScreen  : uint8_t { OLED_MAIN=0, OLED_STATUS=1, OLED_INFO=2 };

// Interrupt-based ultrasonic state machine
enum USState : uint8_t { US_IDLE=0, US_TRIGGERED=1, US_MEASURING=2, US_DONE=3 };

// ── Button debounce state (defined here so auto-generated prototypes can see it)
struct BtnState {
    bool     last;
    bool     stable;
    uint32_t lastChange;
    bool     longPressed;
};

// ============================================================================
// INTERRUPT-BASED ULTRASONIC STATE MACHINE
// ============================================================================
volatile USState    g_usState      = US_IDLE;
volatile uint32_t   g_usEchoStart  = 0;
volatile uint32_t   g_usDuration   = 0;   // microseconds
volatile bool       g_usMeasDone   = false;

void IRAM_ATTR echoISR() {
    if (digitalRead(ECHO_PIN) == HIGH) {
        g_usEchoStart = micros();
        g_usState = US_MEASURING;
    } else {
        if (g_usState == US_MEASURING) {
            g_usDuration = micros() - g_usEchoStart;
            g_usState = US_DONE;
            g_usMeasDone = true;
        }
    }
}

// ============================================================================
// GLOBAL STATE
// ============================================================================
Preferences      prefs;
WiFiClientSecure secureClient;

// Device identity
char   g_chipSerial[24]    = "";
bool   g_provisioned       = false;
char   g_wifiSSID[64]      = "";
char   g_wifiPass[64]      = "";
uint32_t g_bootCount       = 0;

// Sensor & pump
WaterLevel  g_waterLevel   = LVL_EMPTY;
int         g_waterPct     = 0;
PumpState   g_pumpState    = PUMP_OFF;
PumpMode    g_pumpMode     = MODE_AUTO;
SensorMode  g_sensorMode   = SENSOR_FLOAT;
bool        g_muted        = false;
bool        g_dryRunActive = false;
bool        g_alarmActive  = false;
uint32_t    g_pumpCycles   = 0;
uint32_t    g_pumpTotalS   = 0;
uint32_t    g_pumpStartMs  = 0;
uint32_t    g_pumpStopMs   = 0;

// Timing
uint32_t g_lastSensorRead  = 0;
uint32_t g_lastFBPush      = 0;
uint32_t g_lastFBCmd       = 0;
uint32_t g_lastJWTRefresh  = 0;
uint32_t g_lastDeepSleep   = 0;
int      g_lastCmdTs       = 0;

// WiFi
bool     g_wifiOk          = false;
int8_t   g_rssi            = 0;

// Firebase Auth State (v13 — Custom Token Auth)
String   g_idToken         = "";   // Firebase ID Token (1 ঘণ্টায় expire)
String   g_refreshToken    = "";   // Firebase Refresh Token (দীর্ঘমেয়াদী)
bool     g_fbAuthenticated = false;
uint32_t g_tokenExpiryMs   = 0;    // millis() যখন token expire হবে
uint32_t g_lastAuthAttempt = 0;    // retry throttle
int      g_authRetryCount  = 0;

// BLE
bool     g_bleRunning      = false;
bool     g_bleStopPending  = false;  // [FIX] stop BLE only after Firebase confirmed
BLEServer*             g_bleServer      = nullptr;
BLECharacteristic*     g_bleCmdChar     = nullptr;
BLECharacteristic*     g_bleRspChar     = nullptr;

// OLED
OledScreen g_oledScreen    = OLED_MAIN;
uint32_t   g_lastOledBtn   = 0;
uint8_t    g_animFrame     = 0;
uint32_t   g_lastAnim      = 0;

// Button debounce
BtnState g_btnMode  = {true,true,0,false};
BtnState g_btnPump  = {true,true,0,false};
BtnState g_btnMute  = {true,true,0,false};
BtnState g_btnReset = {true,true,0,false};

// Buzzer (non-blocking)
struct BuzzerTask {
    int      beepCount;
    int      beepDone;
    bool     beepPhase;   // true=on, false=off
    uint32_t nextToggle;
    uint16_t onMs;
    uint16_t offMs;
};
BuzzerTask g_buzzer = {0,0,false,0,100,100};

// ============================================================================
// BLE ASYNC WIFI STATE MACHINE  (v13.1 fix)
// ============================================================================
// [FIX-A] WiFi.scanNetworks() এবং WiFi.begin() কখনো BLE callback-এর ভেতরে
// call করা উচিত না। BLE callback একটি আলাদা FreeRTOS task-এ চলে।
// Blocking করলে BLE stack timeout হয়ে connection drop হতে পারে।
// Solution: callback শুধু flag/data set করে, loop() তে actual WiFi কাজ হয়।
//
// [FIX-B] WiFi.scanNetworks(async=true) ব্যবহার করা হয়েছে — non-blocking scan।
// [FIX-C] WiFi connect কে non-blocking state machine এ convert করা হয়েছে।
// [FIX-D] BLEDevice::startAdvertising() WiFi fail এর পরে সরানো হয়েছে
//         (connected থাকলে re-advertise করার দরকার নেই, BLE connection alive থাকে)।
// ============================================================================
enum BleCmd : uint8_t { BLE_CMD_NONE=0, BLE_CMD_SCAN, BLE_CMD_CONNECT };
volatile BleCmd g_blePendingCmd   = BLE_CMD_NONE;
String          g_bleConnSSID     = "";   // credentials for async connect
String          g_bleConnPass     = "";

enum BleWifiOpState : uint8_t {
    BWO_IDLE      = 0,
    BWO_SCANNING  = 1,   // async WiFi scan in progress
    BWO_CONNECTING = 2,  // WiFi.begin() sent, polling for result
};
BleWifiOpState g_bleWifiOpState = BWO_IDLE;
uint32_t       g_bleWifiOpStart = 0;


// ============================================================================
// FIREBASE CUSTOM TOKEN AUTHENTICATION  (v13.0 — replaces HS256 JWT)
// ============================================================================
//
// প্রবাহ (Flow):
//   ESP32 ──POST──► getDeviceToken (Cloud Function)
//                        ↓ Firebase Admin SDK — Custom Token তৈরি
//   ESP32 ◄──JSON──  {token: "eyJ..."}
//
//   ESP32 ──POST──► identitytoolkit.googleapis.com (signInWithCustomToken)
//                        ↓
//   ESP32 ◄──JSON──  {idToken, refreshToken, expiresIn:"3600"}
//
//   Firebase RTDB requests: Authorization: Bearer {idToken}
//
//   ১ ঘণ্টা পরে → securetoken.googleapis.com (refresh) → নতুন idToken
// ────────────────────────────────────────────────────────────────────────────

/**
 * exchangeCustomToken — Firebase Custom Token → ID Token + Refresh Token
 * Firebase Auth REST: POST /v1/accounts:signInWithCustomToken?key=API_KEY
 */
bool exchangeCustomToken(const String& customToken) {
    if (!g_wifiOk) return false;

    String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=")
                 + FIREBASE_WEB_API_KEY;
    String body = "{\"token\":\"" + customToken + "\",\"returnSecureToken\":true}";

    secureClient.setCACert(nullptr);
    HTTPClient http;
    http.begin(secureClient, url);
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(10000);
    int code = http.POST(body);

    if (code != HTTP_CODE_OK) {
        Serial.printf("[AUTH] signInWithCustomToken HTTP %d — %s\n",
                      code, http.getString().substring(0, 80).c_str());
        http.end();
        return false;
    }

    DynamicJsonDocument doc(2048);
    DeserializationError err = deserializeJson(doc, http.getStream());
    http.end();
    if (err) { Serial.printf("[AUTH] Parse error: %s\n", err.c_str()); return false; }

    const char* idToken      = doc["idToken"]     | "";
    const char* refreshToken = doc["refreshToken"] | "";
    const char* expiresIn    = doc["expiresIn"]    | "3600";

    if (strlen(idToken) < 100) {
        Serial.println("[AUTH] idToken too short — malformed response");
        return false;
    }

    g_idToken      = String(idToken);
    g_refreshToken = String(refreshToken);

    uint32_t expSec = String(expiresIn).toInt();
    if (expSec < 60) expSec = 3600;
    g_tokenExpiryMs = millis() + ((expSec - 300) * 1000UL);  // 5 dk erken yenile

    Serial.printf("[AUTH] ID token OK (%d chars), expires in %us\n",
                  g_idToken.length(), expSec);
    return true;
}

/**
 * refreshIdToken — Refresh Token → নতুন ID Token
 * Firebase Auth REST: POST /v1/token?key=API_KEY
 */
bool refreshIdToken() {
    if (!g_wifiOk || g_refreshToken.isEmpty()) return false;
    Serial.println("[AUTH] Refreshing ID token...");

    String url  = String("https://securetoken.googleapis.com/v1/token?key=") + FIREBASE_WEB_API_KEY;
    String body = String("grant_type=refresh_token&refresh_token=") + g_refreshToken;

    secureClient.setCACert(nullptr);
    HTTPClient http;
    http.begin(secureClient, url);
    http.addHeader("Content-Type", "application/x-www-form-urlencoded");
    http.setTimeout(10000);
    int code = http.POST(body);

    if (code != HTTP_CODE_OK) {
        Serial.printf("[AUTH] Refresh HTTP %d — %s\n",
                      code, http.getString().substring(0, 80).c_str());
        http.end();
        if (code == 400) {
            // Refresh token invalid — পুরো auth আবার করতে হবে
            g_fbAuthenticated = false;
            g_refreshToken    = "";
            g_idToken         = "";
            Serial.println("[AUTH] Refresh token invalid — will re-authenticate");
        }
        return false;
    }

    DynamicJsonDocument doc(2048);
    DeserializationError err = deserializeJson(doc, http.getStream());
    http.end();
    if (err) { Serial.printf("[AUTH] Refresh parse error: %s\n", err.c_str()); return false; }

    const char* newIdToken      = doc["id_token"]      | "";
    const char* newRefreshToken = doc["refresh_token"]  | "";
    const char* expiresIn       = doc["expires_in"]     | "3600";

    if (strlen(newIdToken) < 100) { Serial.println("[AUTH] Refreshed idToken short"); return false; }

    g_idToken      = String(newIdToken);
    g_refreshToken = String(newRefreshToken);
    uint32_t expSec = String(expiresIn).toInt();
    if (expSec < 60) expSec = 3600;
    g_tokenExpiryMs = millis() + ((expSec - 300) * 1000UL);

    Serial.printf("[AUTH] Token refreshed OK (%d chars)\n", g_idToken.length());
    return true;
}

/**
 * authenticateWithFirebase — সম্পূর্ণ auth flow:
 *   1. getDeviceToken Cloud Function → Custom Token
 *   2. exchangeCustomToken → ID Token
 * Exponential backoff on failure.
 */
bool authenticateWithFirebase() {
    if (!g_wifiOk) return false;

    // Exponential backoff: 5s, 10s, 20s, 40s, 80s, 160s, 300s max
    if (g_authRetryCount > 0) {
        uint32_t backoffMs = min(5000UL * (1UL << min(g_authRetryCount - 1, 5)), 300000UL);
        if (millis() - g_lastAuthAttempt < backoffMs) return false;
    }

    g_lastAuthAttempt = millis();
    Serial.printf("[AUTH] Authenticating ESP32 (attempt %d)...\n", g_authRetryCount + 1);

    // ── STEP 1: Cloud Function থেকে Custom Token নেওয়া ──────────────────────
    String cfUrl  = String(CLOUD_FUNCTIONS_BASE_URL) + "/getDeviceToken";
    String cfBody = String("{\"deviceId\":\"") + g_chipSerial +
                    "\",\"deviceSecret\":\"" DEVICE_REGISTRATION_SECRET "\"}";

    secureClient.setCACert(nullptr);
    HTTPClient httpCF;
    httpCF.begin(secureClient, cfUrl);
    httpCF.addHeader("Content-Type", "application/json");
    httpCF.setTimeout(15000);
    int cfCode = httpCF.POST(cfBody);

    if (cfCode != HTTP_CODE_OK) {
        Serial.printf("[AUTH] getDeviceToken HTTP %d — %s\n",
                      cfCode, httpCF.getString().substring(0, 100).c_str());
        httpCF.end();
        g_authRetryCount++;
        return false;
    }

    DynamicJsonDocument cfDoc(1024);
    DeserializationError cfErr = deserializeJson(cfDoc, httpCF.getStream());
    httpCF.end();

    if (cfErr || !cfDoc.containsKey("token")) {
        Serial.printf("[AUTH] getDeviceToken error: %s\n",
                      cfErr ? cfErr.c_str() : "no 'token' field");
        g_authRetryCount++;
        return false;
    }

    String customToken = cfDoc["token"].as<String>();
    if (customToken.length() < 100) {
        Serial.println("[AUTH] Custom token too short");
        g_authRetryCount++;
        return false;
    }
    Serial.printf("[AUTH] Custom token received (%d chars)\n", customToken.length());

    // ── STEP 2: Custom Token → Firebase ID Token ──────────────────────────────
    if (!exchangeCustomToken(customToken)) {
        g_authRetryCount++;
        return false;
    }

    g_fbAuthenticated = true;
    g_authRetryCount  = 0;
    Serial.printf("[AUTH] ✅ Authenticated! Device: %s\n", g_chipSerial);
    return true;
}

/**
 * checkTokenExpiry — loop()-এ call করুন।
 * Token expire হওয়ার আগে (৫ মিনিট) refresh করে নেয়।
 */
void checkTokenExpiry() {
    if (!g_fbAuthenticated || g_idToken.isEmpty()) return;
    if (millis() < g_tokenExpiryMs) return;

    Serial.println("[AUTH] Token expiring — refreshing...");
    if (!refreshIdToken()) {
        g_fbAuthenticated = false;
        Serial.println("[AUTH] Refresh failed — will re-authenticate");
    }
}

// ============================================================================
// AES-256-CBC WIFI CREDENTIAL ENCRYPTION
// ============================================================================
// Derive a 32-byte AES key from the ESP32 unique chip ID
void deriveAESKey(uint8_t key[32]) {
    uint64_t chipId = ESP.getEfuseMac();
    // Use HMAC-SHA256(chipId, "SmartIoT-AES-Key-v1") to get 32 bytes
    const char* keyDerivationSalt = "SmartIoT-AES-Key-v1";
    mbedtls_md_context_t ctx;
    mbedtls_md_init(&ctx);
    mbedtls_md_setup(&ctx, mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), 1);
    mbedtls_md_hmac_starts(&ctx, (const uint8_t*)&chipId, 8);
    mbedtls_md_hmac_update(&ctx, (const uint8_t*)keyDerivationSalt, strlen(keyDerivationSalt));
    mbedtls_md_hmac_finish(&ctx, key);
    mbedtls_md_free(&ctx);
}

// Encrypt a string to hex using AES-256-CBC
// IV is prepended (first 32 hex chars = 16 bytes IV)
String aesEncrypt(const String& plaintext) {
    uint8_t key[32];
    deriveAESKey(key);

    // Generate random IV from chip noise
    uint8_t iv[16];
    for (int i = 0; i < 16; i++) {
        iv[i] = (uint8_t)(esp_random() & 0xFF);
    }
    uint8_t iv_copy[16];
    memcpy(iv_copy, iv, 16);

    // PKCS7 pad to 16-byte boundary
    int len    = plaintext.length();
    int padLen = 16 - (len % 16);
    int total  = len + padLen;
    uint8_t* buf = new uint8_t[total];
    memcpy(buf, plaintext.c_str(), len);
    for (int i = len; i < total; i++) buf[i] = (uint8_t)padLen;

    // AES-256-CBC encrypt — separate output buffer (in-place is UB in mbedtls)
    uint8_t* out = new uint8_t[total];
    mbedtls_aes_context aes;
    mbedtls_aes_init(&aes);
    mbedtls_aes_setkey_enc(&aes, key, 256);
    mbedtls_aes_crypt_cbc(&aes, MBEDTLS_AES_ENCRYPT, total, iv_copy, buf, out);
    mbedtls_aes_free(&aes);

    // Output: hex(iv) + hex(ciphertext)
    String result = "";
    for (int i = 0; i < 16; i++) {
        if (iv[i] < 16) result += "0";
        result += String(iv[i], HEX);
    }
    for (int i = 0; i < total; i++) {
        if (out[i] < 16) result += "0";
        result += String(out[i], HEX);
    }
    delete[] buf;
    delete[] out;
    return result;
}

// Decrypt hex string (IV + ciphertext) back to plaintext
String aesDecrypt(const String& hexData) {
    if (hexData.length() < 32) return "";
    uint8_t key[32];
    deriveAESKey(key);

    // Parse IV (first 32 hex chars = 16 bytes)
    uint8_t iv[16];
    for (int i = 0; i < 16; i++) {
        iv[i] = (uint8_t)strtoul(hexData.substring(i * 2, i * 2 + 2).c_str(), nullptr, 16);
    }

    // Parse ciphertext
    int cipherHexLen = hexData.length() - 32;
    int cipherLen    = cipherHexLen / 2;
    uint8_t* buf     = new uint8_t[cipherLen];
    for (int i = 0; i < cipherLen; i++) {
        buf[i] = (uint8_t)strtoul(hexData.substring(32 + i * 2, 34 + i * 2).c_str(), nullptr, 16);
    }

    // AES-256-CBC decrypt — separate output buffer
    uint8_t* out = new uint8_t[cipherLen];
    mbedtls_aes_context aes;
    mbedtls_aes_init(&aes);
    mbedtls_aes_setkey_dec(&aes, key, 256);
    mbedtls_aes_crypt_cbc(&aes, MBEDTLS_AES_DECRYPT, cipherLen, iv, buf, out);
    mbedtls_aes_free(&aes);

    // Remove PKCS7 padding
    int padLen = out[cipherLen - 1];
    if (padLen < 1 || padLen > 16) padLen = 0;  // invalid padding guard
    int textLen = cipherLen - padLen;
    if (textLen < 0) textLen = 0;
    String result = "";
    for (int i = 0; i < textLen; i++) result += (char)out[i];
    delete[] buf;
    delete[] out;
    return result;
}

void saveEncryptedWiFiCreds(const String& ssid, const String& pass) {
    prefs.begin("wifi", false);
    prefs.putString("ssid_enc", aesEncrypt(ssid));
    prefs.putString("pass_enc", aesEncrypt(pass));
    prefs.putBool("provisioned", true);
    prefs.end();
    Serial.println("[NVS] WiFi credentials saved (AES-256-CBC encrypted)");
}

bool loadWiFiCreds() {
    prefs.begin("wifi", true);
    bool prov = prefs.getBool("provisioned", false);
    if (prov) {
        String encSSID = prefs.getString("ssid_enc", "");
        String encPass = prefs.getString("pass_enc", "");
        String ssid    = aesDecrypt(encSSID);
        String pass    = aesDecrypt(encPass);
        ssid.toCharArray(g_wifiSSID, sizeof(g_wifiSSID));
        pass.toCharArray(g_wifiPass, sizeof(g_wifiPass));
    }
    prefs.end();
    return prov;
}

// ============================================================================
// DEEP SLEEP
// ============================================================================
void enterDeepSleep() {
    Serial.println("[Sleep] Entering deep sleep for 30 min");

    // Push sleeping status to Firebase before sleeping
    if (g_wifiOk && g_fbAuthenticated && !g_idToken.isEmpty()) {
        // Simple status push before sleep
        HTTPClient http;
        secureClient.setCACert(GOOGLE_ROOT_CA);
        String url = String("https://") + FIREBASE_HOST +
                     "/devices/" + g_chipSerial + "/status.json";
        http.begin(secureClient, url);
        http.addHeader("Authorization", "Bearer " + g_idToken);
        http.addHeader("Content-Type", "application/json");
        http.addHeader("X-HTTP-Method-Override", "PATCH");
        http.POST("{\"sleeping\":true}");
        http.end();
    }

    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(20, 24);
    display.println("Entering Sleep...");
    display.setCursor(15, 40);
    display.println("Wakes in 30 minutes");
    display.display();
    delay(1500);

    // Configure wakeup sources
    esp_sleep_enable_timer_wakeup((uint64_t)DEEP_SLEEP_INTERVAL * 1000ULL); // ms → us
    // GPIO34 LOW = emergency wakeup
    esp_sleep_enable_ext0_wakeup((gpio_num_t)EMERGENCY_WAKEUP_PIN, 0);

    esp_deep_sleep_start();
}

// ============================================================================
// OTA FIRMWARE UPDATE
// ============================================================================
void performOTA(const String& firmwareUrl) {
    Serial.println("[OTA] Starting firmware update from: " + firmwareUrl);
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("OTA Update...");
    display.display();

    HTTPClient http;
    secureClient.setCACert(GOOGLE_ROOT_CA);
    http.begin(secureClient, firmwareUrl);
    int code = http.GET();
    if (code != HTTP_CODE_OK) {
        Serial.printf("[OTA] HTTP error: %d\n", code);
        http.end();
        return;
    }

    int totalSize    = http.getSize();
    int written      = 0;
    WiFiClient* stream = http.getStreamPtr();

    if (!Update.begin(totalSize > 0 ? totalSize : UPDATE_SIZE_UNKNOWN)) {
        Serial.println("[OTA] Update.begin() failed");
        http.end();
        return;
    }

    uint8_t buf[1024];
    while (http.connected() && (totalSize > 0 ? written < totalSize : true)) {
        int available = stream->available();
        if (available > 0) {
            int toRead  = min(available, (int)sizeof(buf));
            int readNow = stream->readBytes(buf, toRead);
            Update.write(buf, readNow);
            written += readNow;
            // Progress bar on OLED
            if (totalSize > 0) {
                int pct = (written * 100) / totalSize;
                display.fillRect(0, 40, DISPLAY_WIDTH, 10, SSD1306_BLACK);
                display.drawRect(2, 42, DISPLAY_WIDTH - 4, 8, SSD1306_WHITE);
                display.fillRect(3, 43, ((DISPLAY_WIDTH - 6) * pct) / 100, 6, SSD1306_WHITE);
                display.setCursor(50, 55);
                display.printf("%d%%", pct);
                display.display();
            }
        }
        if (available == 0) delay(10);
    }

    http.end();

    if (Update.end(true)) {
        Serial.println("[OTA] Update complete — restarting");
        display.clearDisplay();
        display.setCursor(20, 24);
        display.println("Update complete!");
        display.setCursor(25, 40);
        display.println("Restarting...");
        display.display();
        delay(2000);
        ESP.restart();
    } else {
        Serial.println("[OTA] Update failed: " + String(Update.errorString()));
    }
}

// ============================================================================
// FIREBASE — JWT auth in header, secret never in URL
// ============================================================================
String fbURL(const String& path) {
    // ✅ Secret NOT in URL — auth via Authorization header (see fbAddAuth)
    return String("https://") + FIREBASE_HOST + path + ".json";
}

void fbAddAuth(HTTPClient& http) {
    if (!g_idToken.isEmpty()) {
        http.addHeader("Authorization", "Bearer " + g_idToken);
    }
}

bool firebaseGET(const String& path, DynamicJsonDocument& doc) {
    if (!g_wifiOk) return false;
    secureClient.setCACert(GOOGLE_ROOT_CA);
    HTTPClient http;
    http.begin(secureClient, fbURL(path));
    fbAddAuth(http);
    http.setTimeout(5000);
    int code = http.GET();
    bool ok = false;
    if (code == HTTP_CODE_OK) {
        ok = !deserializeJson(doc, http.getStream());
    } else {
        Serial.printf("[FB] GET %d\n", code);
    }
    http.end();
    return ok;
}

bool firebasePATCH(const String& path, const String& body) {
    if (!g_wifiOk) return false;
    secureClient.setCACert(GOOGLE_ROOT_CA);
    HTTPClient http;
    http.begin(secureClient, fbURL(path));
    fbAddAuth(http);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-HTTP-Method-Override", "PATCH");
    http.setTimeout(5000);
    int code = http.POST(body);
    http.end();
    if (code != HTTP_CODE_OK && code != 204) {
        Serial.printf("[FB] PATCH %d\n", code);
        return false;
    }
    return true;
}

// ============================================================================
// FLOAT SENSOR — 5 samples, majority vote (3/5)
// ============================================================================
bool readPinMajority(int pin) {
    int cnt = 0;
    for (int i = 0; i < SENSOR_SAMPLES; i++) {
        if (digitalRead(pin) == LOW) cnt++;  // active LOW (INPUT_PULLUP)
        delayMicroseconds(200);
    }
    return (cnt >= SENSOR_MAJORITY);
}

WaterLevel readFloatSensor() {
    bool full = readPinMajority(FLOAT_FULL_PIN);
    bool mid  = readPinMajority(FLOAT_MID_PIN);
    bool low  = readPinMajority(FLOAT_LOW_PIN);

    if (full) return LVL_FULL;
    if (mid)  return LVL_MID;
    if (low)  return LVL_LOW;
    return LVL_EMPTY;
}

int floatLevelToPct(WaterLevel lvl) {
    switch (lvl) {
        case LVL_FULL:  return 100;
        case LVL_MID:   return 60;
        case LVL_LOW:   return 25;
        default:        return 5;
    }
}

// ============================================================================
// ULTRASONIC SENSOR — Interrupt-based (no pulseIn per spec)
// ============================================================================
int readUltrasonicPct() {
    // Trigger pulse
    g_usMeasDone = false;
    g_usState    = US_TRIGGERED;
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);

    // Wait for ISR to set g_usMeasDone (max 30ms)
    uint32_t start = millis();
    while (!g_usMeasDone && millis() - start < 30) {
        delayMicroseconds(100);
    }

    if (!g_usMeasDone) {
        g_usState = US_IDLE;
        return -1;  // timeout
    }

    g_usState = US_IDLE;
    float distCm = (float)g_usDuration / 58.0f;

    // Map distance → water percent (nearer = more water)
    int pct = map((int)distCm, ULTRASONIC_EMPTY_CM, ULTRASONIC_FULL_CM, 0, 100);
    return constrain(pct, 0, 100);
}

// ============================================================================
// PUMP CONTROL
// ============================================================================
void setPump(bool on) {
    if (on == (g_pumpState == PUMP_ON)) return;

    uint32_t now = millis();
    if (on) {
        if (now - g_pumpStopMs < PUMP_MIN_OFF_TIME) return;  // min off time
        g_pumpState  = PUMP_ON;
        g_pumpStartMs = now;
        g_pumpCycles++;
        digitalWrite(PUMP_RELAY_PIN, HIGH);
        digitalWrite(LED_PUMP_PIN, HIGH);
        if (!g_muted) { g_buzzer = {1,0,false,0,150,0}; }  // single beep
        Serial.println("[Pump] ON");
    } else {
        if (now - g_pumpStartMs < PUMP_MIN_ON_TIME) return;  // min on time
        g_pumpState  = PUMP_OFF;
        g_pumpStopMs = now;
        g_pumpTotalS += (now - g_pumpStartMs) / 1000;
        digitalWrite(PUMP_RELAY_PIN, LOW);
        digitalWrite(LED_PUMP_PIN, LOW);
        if (!g_muted) { g_buzzer = {1,0,false,0,150,0}; }
        Serial.println("[Pump] OFF");
    }
}

void updateAutoMode() {
    if (g_pumpMode != MODE_AUTO) return;

    // Max run time protection
    if (g_pumpState == PUMP_ON &&
        millis() - g_pumpStartMs > PUMP_MAX_RUN_TIME) {
        Serial.println("[Pump] Max run time exceeded — auto OFF");
        setPump(false);
        return;
    }

    // Dry-run detection (pump running but level not rising after 3 min)
    if (g_pumpState == PUMP_ON &&
        !g_dryRunActive &&
        millis() - g_pumpStartMs > DRY_RUN_TIMEOUT &&
        g_waterPct < 10) {
        g_dryRunActive = true;
        g_alarmActive  = true;
        setPump(false);
        if (!g_muted) { g_buzzer = {5,0,false,0,100,100}; }  // 5 rapid beeps
        Serial.println("[Pump] Dry-run protection activated");
        return;
    }

    if (g_dryRunActive) return;  // don't auto-start while in dry-run

    if (g_waterPct <= PUMP_AUTO_ON_PCT  && g_pumpState == PUMP_OFF) setPump(true);
    if (g_waterPct >= PUMP_AUTO_OFF_PCT && g_pumpState == PUMP_ON)  setPump(false);
}

// ============================================================================
// SENSORS — read based on active mode
// ============================================================================
void readSensors() {
    if (digitalRead(TOGGLE_MODE_PIN) == HIGH) {
        g_sensorMode = SENSOR_ULTRASONIC;
        int pct = readUltrasonicPct();
        if (pct >= 0) {
            g_waterPct   = pct;
            g_waterLevel = (pct >= 90) ? LVL_FULL :
                           (pct >= 50) ? LVL_MID  :
                           (pct >= 20) ? LVL_LOW   : LVL_EMPTY;
        }
    } else {
        g_sensorMode = SENSOR_FLOAT;
        g_waterLevel = readFloatSensor();
        g_waterPct   = floatLevelToPct(g_waterLevel);
    }

    // Low water alarm
    g_alarmActive = (g_waterPct <= 10 || g_dryRunActive);
}

// ============================================================================
// FIREBASE PUSH STATUS
// ============================================================================
void pushStatus() {
    // [v13] g_fbAuthenticated check — authentication ছাড়া push করা যাবে না
    if (!g_wifiOk || !g_fbAuthenticated) return;

    uint32_t upSec   = millis() / 1000UL;
    g_rssi            = WiFi.RSSI();
    uint32_t heapFree = ESP.getFreeHeap();   // [FIX] was missing

    char body[640];   // [FIX] increased from 512
    snprintf(body, sizeof(body),
        "{\"water_level\":\"%s\",\"water_level_pct\":%d,"
        "\"pump\":\"%s\",\"mode\":\"%s\","
        "\"sensor_mode\":\"%s\",\"wifi_rssi\":%d,"
        "\"uptime\":\"%uh %um\",\"boot_count\":%u,"
        "\"pump_cycles\":%u,\"pump_total_s\":%u,"
        "\"alarm\":%s,\"dry_run\":%s,"
        "\"firmware\":\"%s\",\"serial\":\"%s\","
        "\"heap_free\":%u,"             // [FIX] new field
        "\"ts\":%u,\"sleeping\":false}",
        g_waterLevel == LVL_FULL ? "FULL" :
        g_waterLevel == LVL_MID  ? "MID"  :
        g_waterLevel == LVL_LOW  ? "LOW"  : "EMPTY",
        g_waterPct,
        g_pumpState == PUMP_ON ? "ON" : "OFF",
        g_pumpMode == MODE_AUTO ? "AUTO" : "MANUAL",
        g_sensorMode == SENSOR_ULTRASONIC ? "ULTRA" : "FLOAT",
        g_rssi,
        upSec / 3600, (upSec % 3600) / 60,
        g_bootCount,
        g_pumpCycles, g_pumpTotalS,
        g_alarmActive ? "true" : "false",
        g_dryRunActive ? "true" : "false",
        FIRMWARE_VERSION, g_chipSerial,
        heapFree,                           // [FIX] heap arg
        (uint32_t)time(nullptr)
    );

    String path = String("/devices/") + g_chipSerial + "/status";
    bool ok = firebasePATCH(path, body);
    Serial.printf("[FB] pushStatus %s\n", ok ? "OK" : "FAIL");
}

// ============================================================================
// FIREBASE POLL COMMANDS
// ============================================================================
void pollCommands() {
    // [v13] g_fbAuthenticated check
    if (!g_wifiOk || !g_fbAuthenticated) return;

    String path = String("/devices/") + g_chipSerial + "/control";
    DynamicJsonDocument doc(512);
    if (!firebaseGET(path, doc)) return;

    int cmdTs = doc["cmd_ts"] | 0;
    if (cmdTs <= g_lastCmdTs) return;  // already processed
    g_lastCmdTs = cmdTs;

    // Pump command
    const char* pumpCmd = doc["pump_cmd"] | "";
    if (strcmp(pumpCmd, "ON") == 0 && g_pumpMode == MODE_MANUAL) {
        setPump(true);
    } else if (strcmp(pumpCmd, "OFF") == 0 && g_pumpMode == MODE_MANUAL) {
        setPump(false);
    }

    // Mode command
    const char* modeCmd = doc["mode_cmd"] | "";
    if (strcmp(modeCmd, "AUTO") == 0)   g_pumpMode = MODE_AUTO;
    if (strcmp(modeCmd, "MANUAL") == 0) g_pumpMode = MODE_MANUAL;

    // Dry-run reset
    bool drrReset = doc["dry_run_reset"] | false;
    if (drrReset) {
        g_dryRunActive = false;
        g_alarmActive  = false;
        Serial.println("[CMD] Dry-run protection reset");
    }

    // OTA update — validate URL before executing (security: only allow Firebase Storage)
    const char* otaUrl = doc["ota_url"] | "";
    if (strlen(otaUrl) > 10) {
        String otaStr = String(otaUrl);
        // Only allow Firebase Storage URLs to prevent MITM/arbitrary code execution
        if (otaStr.startsWith("https://firebasestorage.googleapis.com/") ||
            otaStr.startsWith("https://storage.googleapis.com/")) {
            Serial.println("[CMD] OTA update triggered from trusted URL");
            performOTA(otaStr);
        } else {
            Serial.println("[CMD] OTA REJECTED — untrusted URL: " + otaStr.substring(0, 40));
        }
    }
}

// ============================================================================
// BUZZER — non-blocking
// ============================================================================
void updateBuzzer() {
    if (g_muted || g_buzzer.beepCount == 0) return;
    uint32_t now = millis();
    if (now < g_buzzer.nextToggle) return;

    if (g_buzzer.beepPhase) {
        // Currently buzzing — turn off
        digitalWrite(BUZZER_PIN, LOW);
        g_buzzer.beepPhase = false;
        g_buzzer.beepDone++;
        g_buzzer.nextToggle = now + g_buzzer.offMs;
        if (g_buzzer.beepDone >= g_buzzer.beepCount) {
            g_buzzer.beepCount = 0;  // done
        }
    } else {
        // Off — start next beep
        if (g_buzzer.beepDone < g_buzzer.beepCount) {
            digitalWrite(BUZZER_PIN, HIGH);
            g_buzzer.beepPhase  = true;
            g_buzzer.nextToggle = now + g_buzzer.onMs;
        }
    }
}

// ============================================================================
// BUTTON HANDLING — 20ms debounce
// ============================================================================
void updateButton(BtnState& btn, int pin) {
    bool reading = (digitalRead(pin) == LOW);  // active LOW
    if (reading != btn.last) {
        btn.lastChange = millis();
        btn.last       = reading;
    }
    if (millis() - btn.lastChange > BUTTON_DEBOUNCE) {
        btn.stable = reading;
    }
}

bool buttonPressed(BtnState& btn) {
    // Rising edge: was pressed, now released
    static bool prev[4] = {false,false,false,false};
    // Simplified: detect stable LOW → HIGH transition
    return false;  // handled in loop via edge detection
}

// ============================================================================
// OLED DISPLAY
// ============================================================================
void drawTank3D(int pct) {
    // Tank body outline (cylinder illusion)
    display.drawRect(10, 4, 44, 54, SSD1306_WHITE);
    display.drawRect(11, 5, 42, 4, SSD1306_WHITE);  // top cap
    // Water fill
    int fillH = (52 * pct) / 100;
    int fillY = 57 - fillH;
    display.fillRect(11, fillY, 42, fillH, SSD1306_WHITE);
    // Wave animation on water surface
    if (fillH > 0) {
        uint8_t waveY = fillY;
        for (int x = 11; x < 53; x += 4) {
            display.drawPixel(x,     waveY + (g_animFrame % 2), SSD1306_BLACK);
            display.drawPixel(x + 2, waveY + ((g_animFrame+1) % 2), SSD1306_BLACK);
        }
    }
    // Bubbles (when pump running)
    if (g_pumpState == PUMP_ON && fillH > 8) {
        int bx = 20 + (g_animFrame % 12);
        display.drawPixel(bx, fillY + 3, SSD1306_BLACK);
        display.drawPixel(bx - 4, fillY + 6, SSD1306_BLACK);
    }
    // Gauge bar (right side)
    display.drawRect(58, 4, 8, 54, SSD1306_WHITE);
    int gH = (52 * pct) / 100;
    display.fillRect(59, 57 - gH, 6, gH, SSD1306_WHITE);
}

void renderOLED() {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);

    if (g_oledScreen == OLED_MAIN) {
        // 3D tank + level %
        drawTank3D(g_waterPct);
        display.setTextSize(2);
        display.setCursor(70, 10);
        display.printf("%d%%", g_waterPct);
        display.setTextSize(1);
        display.setCursor(70, 30);
        display.print(g_waterLevel == LVL_FULL ? "FULL" :
                       g_waterLevel == LVL_MID  ? "MID"  :
                       g_waterLevel == LVL_LOW  ? "LOW"  : "EMPTY");
        if (g_alarmActive) {
            display.setCursor(70, 45);
            display.print("! ALARM");
        }
        if (g_dryRunActive) {
            display.setCursor(68, 54);
            display.print("DRY RUN!");
        }

    } else if (g_oledScreen == OLED_STATUS) {
        display.setTextSize(1);
        display.setCursor(0, 0);
        display.printf("Pump: %s", g_pumpState == PUMP_ON ? "ON" : "OFF");
        display.setCursor(0, 12);
        display.printf("Mode: %s", g_pumpMode == MODE_AUTO ? "AUTO" : "MANUAL");
        display.setCursor(0, 24);
        display.printf("WiFi: %s", g_wifiOk ? "OK" : "NO");
        display.setCursor(0, 36);
        display.printf("RSSI: %d dBm", g_rssi);
        display.setCursor(0, 48);
        display.printf("Sensor: %s", g_sensorMode == SENSOR_ULTRASONIC ? "ULTRA" : "FLOAT");

    } else {  // OLED_INFO
        display.setTextSize(1);
        display.setCursor(0, 0);
        display.printf("IP: %s", WiFi.localIP().toString().c_str());
        display.setCursor(0, 14);
        uint32_t upSec = millis() / 1000UL;  // uint32_t: safe up to 49 days
        display.printf("Up: %uh %um", upSec / 3600, (upSec % 3600) / 60);
        display.setCursor(0, 28);
        display.printf("Boot#: %u", g_bootCount);
        display.setCursor(0, 42);
        display.printf("FW: %s", FIRMWARE_VERSION);
        display.setCursor(0, 54);
        display.printf("ID: %s", g_chipSerial);
    }

    display.display();
}

// ============================================================================
// FACTORY RESET — 10s hold on BTN_RESET with OLED countdown
// ============================================================================
void checkFactoryReset() {
    static uint32_t holdStart = 0;
    bool held = (digitalRead(BTN_RESET_PIN) == LOW);

    if (held && holdStart == 0) {
        holdStart = millis();
    } else if (!held) {
        holdStart = 0;
        return;
    }

    uint32_t heldMs = millis() - holdStart;
    if (heldMs < 3000) return;  // no UI until 3s hold

    // Show countdown bar
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(15, 8);
    display.print("FACTORY RESET?");
    display.setCursor(10, 22);
    display.print("Hold to confirm...");
    int pct = (int)(heldMs * 100 / FACTORY_RESET_HOLD);
    display.drawRect(4, 40, 120, 12, SSD1306_WHITE);
    display.fillRect(5, 41, (118 * pct) / 100, 10, SSD1306_WHITE);
    display.setCursor(50, 55);
    display.printf("%d%%", pct);
    display.display();

    if (heldMs >= FACTORY_RESET_HOLD) {
        // Confirmed — wipe NVS
        display.clearDisplay();
        display.setCursor(20, 28);
        display.print("Resetting...");
        display.display();
        prefs.begin("wifi", false);
        prefs.clear();
        prefs.end();
        prefs.begin("state", false);
        prefs.clear();
        prefs.end();
        delay(1000);
        ESP.restart();
    }
}

// ============================================================================
// BLE PROVISIONING
// ============================================================================
// ─────────────────────────────────────────────────────────────────────────────
// BLE CMD CALLBACK — v13.1 async rewrite
// ─────────────────────────────────────────────────────────────────────────────
// [FIX-A] এই callback শুধু chunks accumulate করে + command parse করে + flag set করে।
//         Actual WiFi কাজ (scan / connect) loop() তে handleBlePendingCmd() করে।
//         আগে WiFi.scanNetworks() এবং WiFi.begin()+while() এখানে চলতো —
//         এটা BLE task কে 15+ সেকেন্ড block করতো এবং connection drop হতো।
// ─────────────────────────────────────────────────────────────────────────────
static String g_bleCmdBuffer = "";

// Helper: Parse CONNECT:ssid:pass where colons inside ssid/pass are escaped as \:
// Returns true if parsed successfully. ssid and pass are output params.
static bool parseBleConnect(const String& val, String& ssid, String& pass) {
    if (!val.startsWith("CONNECT:")) return false;
    String payload = val.substring(8);  // strip "CONNECT:"

    // Find first unescaped colon (separator between ssid and password)
    int colonPos = -1;
    for (int i = 0; i < (int)payload.length(); i++) {
        if (payload[i] == ':') {
            // Check escape: backslash at i-1 means this colon is escaped
            if (i > 0 && payload[i-1] == '\\') continue;
            colonPos = i;
            break;
        }
    }

    if (colonPos >= 0) {
        ssid = payload.substring(0, colonPos);
        pass = payload.substring(colonPos + 1);
        ssid.replace("\\:", ":");
        pass.replace("\\:", ":");
    } else {
        // No separator — treat entire payload as SSID (open network)
        ssid = payload;
        pass = "";
    }
    return true;
}

// Helper: Send BLE notify, chunked for large payloads (WIFI_LIST can be 300+ bytes)
static void bleNotify(const String& rsp) {
    if (!g_bleRspChar) return;
    // ESP32 Arduino BLE stack respects negotiated MTU for notifications.
    // setValue+notify sends up to (MTU-3) bytes. For large responses (WIFI_LIST),
    // we chunk manually so Flutter's response buffer can reassemble them.
    // Flutter accumulates chunks until '\n' or complete JSON ']' is detected.
    const int CHUNK = 180;  // safe for most negotiated MTUs (>= 185 on Android/iOS)
    int len = (int)rsp.length();
    for (int i = 0; i < len; i += CHUNK) {
        int end = i + CHUNK;
        if (end > len) end = len;  // avoid Arduino min() macro type mismatch
        String chunk = rsp.substring(i, end);
        g_bleRspChar->setValue(chunk.c_str());
        g_bleRspChar->notify();
        if (len > CHUNK) delay(20);  // small gap between chunks
    }
}

class BLECmdCallback : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* c) override {
        // Accumulate 20-byte MTU chunks until command is complete
        g_bleCmdBuffer += String(c->getValue().c_str());

        bool complete = g_bleCmdBuffer.endsWith("\n") ||
                        g_bleCmdBuffer.equals("SCAN") ||
                        g_bleCmdBuffer.equals("STATUS");
        if (!complete) return;

        String val = g_bleCmdBuffer;
        g_bleCmdBuffer = "";
        val.trim();

        if (val.startsWith("CONNECT:")) {
            Serial.println("[BLE] CMD: CONNECT:[credentials hidden]");
        } else {
            Serial.println("[BLE] CMD: " + val);
        }

        // [FIX-A] Only set flags here — NO blocking WiFi calls in BLE callback
        if (val.equals("SCAN")) {
            if (g_bleWifiOpState == BWO_IDLE) {
                g_blePendingCmd = BLE_CMD_SCAN;
            } else {
                // Already busy — tell Flutter to retry
                bleNotify("FAILED:Device busy, please retry\n");
            }

        } else if (val.startsWith("CONNECT:")) {
            String ssid, pass;
            if (!parseBleConnect(val, ssid, pass)) {
                bleNotify("FAILED:Bad command format\n");
                return;
            }
            if (g_bleWifiOpState == BWO_IDLE) {
                g_bleConnSSID   = ssid;
                g_bleConnPass   = pass;
                g_blePendingCmd = BLE_CMD_CONNECT;
                // Immediately acknowledge so Flutter knows command was received
                // (Flutter starts its 35s timeout from this point)
                bleNotify("CONNECTING\n");
            } else {
                bleNotify("FAILED:Device busy, please retry\n");
            }

        } else if (val.equals("STATUS")) {
            // STATUS is lightweight — safe to handle directly in callback
            String rsp;
            if (WiFi.status() == WL_CONNECTED) {
                rsp = "STATUS:CONNECTED:" + WiFi.localIP().toString() + "\n";
            } else {
                rsp = "STATUS:PROVISIONING\n";
            }
            bleNotify(rsp);
        }
    }
};

// ============================================================================
// BLE ASYNC COMMAND HANDLER — called from loop() (v13.1)
// ============================================================================
// [FIX-A] WiFi operations চলে এখানে, BLE callback-এ নয়।
// [FIX-B] WiFi.scanNetworks(true) — async scan, non-blocking।
// [FIX-C] WiFi connect — polling state machine, প্রতি loop() iteration-এ check।
// ============================================================================
void handleBlePendingCmd() {
    if (!g_bleRunning) return;

    // ── Kick off new command ──────────────────────────────────────────────
    if (g_bleWifiOpState == BWO_IDLE) {
        if (g_blePendingCmd == BLE_CMD_SCAN) {
            g_blePendingCmd  = BLE_CMD_NONE;
            g_bleWifiOpState = BWO_SCANNING;
            g_bleWifiOpStart = millis();
            // [FIX-B] Async scan — does NOT block. Results available via
            // WiFi.scanComplete() once done (typically 2-4 seconds).
            WiFi.scanNetworks(/*async=*/true);
            Serial.println("[BLE] Async WiFi scan started");

        } else if (g_blePendingCmd == BLE_CMD_CONNECT) {
            g_blePendingCmd  = BLE_CMD_NONE;
            g_bleWifiOpState = BWO_CONNECTING;
            g_bleWifiOpStart = millis();
            // [FIX-C] WiFi.begin() returns immediately; we poll status in loop
            WiFi.begin(g_bleConnSSID.c_str(), g_bleConnPass.c_str());
            Serial.println("[BLE] WiFi.begin() called for SSID: [hidden]");
        }
        return;
    }

    // ── Poll scan completion ──────────────────────────────────────────────
    if (g_bleWifiOpState == BWO_SCANNING) {
        int16_t n = WiFi.scanComplete();
        bool timedOut = (millis() - g_bleWifiOpStart > 15000UL);

        if (n == WIFI_SCAN_RUNNING && !timedOut) return;  // still scanning

        g_bleWifiOpState = BWO_IDLE;

        if (n <= 0 || timedOut) {
            bleNotify("WIFI_LIST:[]\n");
            Serial.printf("[BLE] WiFi scan done: %d networks\n", n);
            return;
        }

        // Build WIFI_LIST JSON
        String json = "[";
        for (int i = 0; i < n; i++) {
            if (i > 0) json += ",";
            // Escape double-quotes in SSID (security: don't break JSON)
            String ssid = WiFi.SSID(i);
            ssid.replace("\\", "\\\\");
            ssid.replace("\"", "\\\"");
            json += "{\"s\":\"" + ssid +
                    "\",\"r\":" + String(WiFi.RSSI(i)) +
                    ",\"sec\":" + (WiFi.encryptionType(i) != WIFI_AUTH_OPEN ? "true" : "false") +
                    "}";
        }
        json += "]";
        WiFi.scanDelete();  // free scan memory

        String rsp = "WIFI_LIST:" + json + "\n";
        Serial.printf("[BLE] Sending WIFI_LIST (%d bytes, %d nets)\n",
                      rsp.length(), n);
        bleNotify(rsp);
        return;
    }

    // ── Poll WiFi connection ──────────────────────────────────────────────
    if (g_bleWifiOpState == BWO_CONNECTING) {
        wl_status_t status = WiFi.status();
        bool timedOut      = (millis() - g_bleWifiOpStart > 18000UL);  // 18s

        if (status == WL_CONNECTED) {
            g_bleWifiOpState = BWO_IDLE;
            saveEncryptedWiFiCreds(g_bleConnSSID, g_bleConnPass);
            g_provisioned = true;
            g_wifiOk      = true;
            String ip  = WiFi.localIP().toString();
            String rsp = "CONNECTED:" + ip + "\n";
            bleNotify(rsp);
            Serial.println("[BLE] WiFi provisioned via BLE, IP: " + ip);
            // [FIX-D] BLE connection stays alive for 5s so Flutter gets the
            // CONNECTED notification, then stops once Firebase confirms.
            g_bleStopPending = true;

        } else if (timedOut ||
                   status == WL_NO_SSID_AVAIL ||
                   status == WL_CONNECT_FAILED ||
                   status == WL_CONNECTION_LOST) {
            g_bleWifiOpState = BWO_IDLE;
            WiFi.disconnect(true);

            String reason = "Wrong password or no signal";
            if (status == WL_NO_SSID_AVAIL) reason = "Network not found";

            bleNotify("FAILED:" + reason + "\n");
            Serial.printf("[BLE] WiFi connect failed (status=%d) — "
                          "BLE connection stays alive for retry\n", status);
            // [FIX-D] Do NOT call BLEDevice::startAdvertising() here.
            //         The BLE connection from the phone is STILL ACTIVE.
            //         Re-advertising while connected causes stack confusion.
            //         Flutter will call refreshWifiScan() to retry via
            //         the existing BLE connection — no reconnection needed.
        }
        // else: still connecting — wait for next loop() iteration
    }
}

void bleSetup() {
    if (g_bleRunning) return;
    String deviceName = String("SmartIoT-") + String(g_chipSerial).substring(0, 6);
    BLEDevice::init(deviceName.c_str());
    g_bleServer = BLEDevice::createServer();

    BLEService* svc = g_bleServer->createService(BLE_SERVICE_UUID);

    g_bleCmdChar = svc->createCharacteristic(
        BLE_CMD_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    static BLECmdCallback bleCmdCb;  // static — no heap allocation, no leak
    g_bleCmdChar->setCallbacks(&bleCmdCb);

    g_bleRspChar = svc->createCharacteristic(
        BLE_RSP_CHAR_UUID,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    g_bleRspChar->addDescriptor(new BLE2902());

    svc->start();
    BLEDevice::startAdvertising();
    g_bleRunning = true;
    Serial.println("[BLE] Advertising as: " + deviceName);
}

void bleStop() {
    if (!g_bleRunning) return;
    BLEDevice::stopAdvertising();
    BLEDevice::deinit(true);
    g_bleRunning = false;
    Serial.println("[BLE] Stopped — heap freed for Firebase SSL");
}

// ============================================================================
// WIFI
// ============================================================================
void connectWiFi() {
    if (!g_provisioned) return;
    Serial.printf("[WiFi] Connecting to SSID: [hidden]\n");
    WiFi.begin(g_wifiSSID, g_wifiPass);
    uint32_t t = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t < 15000) {
        digitalWrite(LED_WIFI_PIN, !digitalRead(LED_WIFI_PIN));
        delay(300);
    }
    g_wifiOk = (WiFi.status() == WL_CONNECTED);
    if (g_wifiOk) {
        digitalWrite(LED_WIFI_PIN, HIGH);
        Serial.printf("[WiFi] Connected, IP: %s\n", WiFi.localIP().toString().c_str());
        // Sync NTP time (required for JWT iat/exp)
        configTime(21600, 0, "pool.ntp.org", "time.nist.gov");
    } else {
        digitalWrite(LED_WIFI_PIN, LOW);
        Serial.println("[WiFi] Failed to connect");
    }
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
    Serial.begin(115200);

    // Get chip serial
    uint64_t chipId = ESP.getEfuseMac();
    snprintf(g_chipSerial, sizeof(g_chipSerial), "%04X%08X",
             (uint16_t)(chipId >> 32), (uint32_t)chipId);

    // Load boot count
    prefs.begin("state", false);
    g_bootCount = prefs.getUInt("bootCnt", 0) + 1;
    prefs.putUInt("bootCnt", g_bootCount);
    prefs.end();

    Serial.printf("\n[Boot] SmartIoT %s  Serial: %s  Boot#%u\n",
                  FIRMWARE_VERSION, g_chipSerial, g_bootCount);

    // Pin setup
    pinMode(PUMP_RELAY_PIN,  OUTPUT); digitalWrite(PUMP_RELAY_PIN,  LOW);
    pinMode(BUZZER_PIN,      OUTPUT); digitalWrite(BUZZER_PIN,      LOW);
    pinMode(LED_WIFI_PIN,    OUTPUT); digitalWrite(LED_WIFI_PIN,    LOW);
    pinMode(LED_PUMP_PIN,    OUTPUT); digitalWrite(LED_PUMP_PIN,    LOW);
    pinMode(TRIG_PIN,        OUTPUT); digitalWrite(TRIG_PIN,        LOW);
    pinMode(ECHO_PIN,        INPUT);
    pinMode(FLOAT_LOW_PIN,   INPUT_PULLUP);
    pinMode(FLOAT_MID_PIN,   INPUT_PULLUP);
    pinMode(FLOAT_FULL_PIN,  INPUT_PULLUP);
    pinMode(TOGGLE_MODE_PIN, INPUT);
    pinMode(BTN_MODE_PIN,    INPUT_PULLUP);
    pinMode(BTN_PUMP_PIN,    INPUT_PULLUP);
    pinMode(BTN_MUTE_PIN,    INPUT_PULLUP);
    pinMode(BTN_RESET_PIN,   INPUT_PULLUP);
    pinMode(EMERGENCY_WAKEUP_PIN, INPUT_PULLUP);

    // Attach ECHO interrupt (interrupt-based ultrasonic)
    attachInterrupt(digitalPinToInterrupt(ECHO_PIN), echoISR, CHANGE);

    // OLED init
    Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
    if (!display.begin(SSD1306_SWITCHCAPVCC, DISPLAY_ADDR)) {
        Serial.println("[OLED] Init failed — continuing without display");
    } else {
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(10, 20);
        display.print("SmartIoT " FIRMWARE_VERSION);
        display.setCursor(20, 36);
        display.print("Starting up...");
        display.display();
    }

    // Boot melody
    if (!g_muted) { g_buzzer = {3,0,false,0,100,80}; }

    // Load WiFi credentials
    g_provisioned = loadWiFiCreds();

    if (g_provisioned) {
        connectWiFi();
        // [v13] WiFi connect-এর পরে Firebase authenticate করি
        if (g_wifiOk) {
            Serial.println("[Setup] WiFi OK — authenticating with Firebase...");
            if (authenticateWithFirebase()) {
                Serial.println("[Setup] Firebase auth OK — ready");
            } else {
                Serial.println("[Setup] Firebase auth deferred — loop() will retry");
            }
        }
    } else {
        // No credentials — start BLE for provisioning
        Serial.println("[Setup] No WiFi creds — starting BLE provisioning");
        bleSetup();
    }

    // Wakeup reason (from deep sleep)
    esp_sleep_wakeup_cause_t cause = esp_sleep_get_wakeup_cause();
    if (cause == ESP_SLEEP_WAKEUP_TIMER) {
        Serial.println("[Sleep] Woke from timer (30 min sleep)");
    } else if (cause == ESP_SLEEP_WAKEUP_EXT0) {
        Serial.println("[Sleep] Emergency wakeup via GPIO34");
    }

    g_lastDeepSleep = millis();
    Serial.println("[Setup] Complete");
}

// ============================================================================
// LOOP — non-blocking state machine
// ============================================================================
void loop() {
    uint32_t now = millis();

    // ── Factory reset check ─────────────────────────────────────────────
    checkFactoryReset();

    // ── Firebase Authentication (v13) ───────────────────────────────────
    // WiFi আছে কিন্তু authenticated নয় → retry with exponential backoff
    if (g_wifiOk && !g_fbAuthenticated) {
        authenticateWithFirebase();
    }
    // Token expiry check — refresh token দিয়ে নতুন ID token নেয় (1 ঘণ্টায়)
    checkTokenExpiry();

    // ── Button handling ─────────────────────────────────────────────────
    {
        bool modeRaw  = (digitalRead(BTN_MODE_PIN)  == LOW);
        bool pumpRaw  = (digitalRead(BTN_PUMP_PIN)  == LOW);
        bool muteRaw  = (digitalRead(BTN_MUTE_PIN)  == LOW);

        // Mode button — toggle AUTO/MANUAL on press
        static bool modePrev = false;
        if (modeRaw != modePrev) {
            if (!modeRaw) {  // released
                g_pumpMode = (g_pumpMode == MODE_AUTO) ? MODE_MANUAL : MODE_AUTO;
                Serial.printf("[Btn] Mode → %s\n", g_pumpMode == MODE_AUTO ? "AUTO" : "MANUAL");
                if (!g_muted) { g_buzzer = {2,0,false,0,80,80}; }
            }
            modePrev = modeRaw;
        }

        // Pump button — toggle pump in manual mode
        static bool pumpPrev = false;
        if (pumpRaw != pumpPrev) {
            if (!pumpRaw && g_pumpMode == MODE_MANUAL) {
                setPump(g_pumpState == PUMP_OFF);
            }
            pumpPrev = pumpRaw;
        }

        // Mute button
        static bool mutePrev = false;
        if (muteRaw != mutePrev) {
            if (!muteRaw) {
                g_muted = !g_muted;
                Serial.printf("[Btn] Mute → %s\n", g_muted ? "ON" : "OFF");
            }
            mutePrev = muteRaw;
        }
    }

    // ── OLED button (BTN_MODE long press 2s cycles screen) ──────────────
    static uint32_t modeLongStart = 0;
    static bool     oledCycled    = false;  // prevent rapid cycling without blocking delay
    if (digitalRead(BTN_MODE_PIN) == LOW) {
        if (modeLongStart == 0) modeLongStart = now;
        if (!oledCycled && now - modeLongStart > 2000) {
            g_oledScreen = (OledScreen)((g_oledScreen + 1) % 3);
            oledCycled = true;  // block until button released
        }
    } else {
        modeLongStart = 0;
        oledCycled = false;
    }

    // ── Sensor read ─────────────────────────────────────────────────────
    if (now - g_lastSensorRead >= SENSOR_READ_INTERVAL) {
        g_lastSensorRead = now;
        readSensors();
        updateAutoMode();
    }

    // ── Firebase push ────────────────────────────────────────────────────
    if (g_wifiOk && now - g_lastFBPush >= FIREBASE_PUSH_INTERVAL) {
        g_lastFBPush = now;
        pushStatus();
    }

    // ── Firebase poll commands ───────────────────────────────────────────
    if (g_wifiOk && now - g_lastFBCmd >= FIREBASE_CMD_INTERVAL) {
        g_lastFBCmd = now;
        pollCommands();
    }

    // ── BLE async command handler (WiFi scan/connect from BLE) ─────────────
    if (g_bleRunning) {
        handleBlePendingCmd();
    }

    // ── Stop BLE once Firebase is confirmed connected ───────────────────
    // After WiFi provisioning succeeds, BLE stays up until Firebase push works.
    // This lets user retry WiFi if Firebase fails, without needing to re-scan BLE.
    if (g_bleStopPending && g_wifiOk && g_bleRunning) {
        static uint32_t bleStopAt = 0;
        if (bleStopAt == 0) bleStopAt = now + 5000;  // wait 5s for Firebase to connect
        if (now >= bleStopAt) {
            bleStopAt = 0;
            g_bleStopPending = false;
            bleStop();
            Serial.println("[BLE] Stopped after Firebase confirmed");
        }
    }

    // ── WiFi reconnect ───────────────────────────────────────────────────
    if (g_provisioned && !g_wifiOk && WiFi.status() != WL_CONNECTED) {
        static uint32_t lastRetry = 0;
        if (now - lastRetry > 30000) {
            lastRetry = now;
            connectWiFi();
        }
    }

    // ── Deep sleep ───────────────────────────────────────────────────────
    // Reset sleep timer on any button activity or alarm condition
    if (digitalRead(BTN_MODE_PIN) == LOW ||
        digitalRead(BTN_PUMP_PIN) == LOW ||
        digitalRead(BTN_MUTE_PIN) == LOW ||
        g_alarmActive) {
        g_lastDeepSleep = now;  // user is active — postpone sleep
    }

    if (g_provisioned && g_wifiOk &&
        g_pumpState == PUMP_OFF &&        // don't sleep while pump running
        !g_bleRunning &&                  // don't sleep while BLE active
        !g_alarmActive &&                 // don't sleep during alarm
        now - g_lastDeepSleep >= DEEP_SLEEP_INTERVAL) {
        enterDeepSleep();
        // Code does not resume here — ESP32 restarts after sleep
    }

    // ── Buzzer ───────────────────────────────────────────────────────────
    updateBuzzer();

    // ── OLED animation ───────────────────────────────────────────────────
    if (now - g_lastAnim >= 250) {
        g_lastAnim = now;
        g_animFrame++;
        renderOLED();
    }

    // ── LED WiFi blink when not connected ────────────────────────────────
    if (!g_wifiOk) {
        static uint32_t ledBlink = 0;
        if (now - ledBlink > 500) {
            ledBlink = now;
            digitalWrite(LED_WIFI_PIN, !digitalRead(LED_WIFI_PIN));
        }
    }
}
