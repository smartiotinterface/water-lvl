// firebase/functions/index.js
// Cloud Functions for Smart IoT Interface — Node.js 20
// ─────────────────────────────────────────────────────────────────────────────
// CHANGES IN v13:
//   [AUTH-NEW]  getDeviceToken — ESP32 Custom Token মিন্ট করে।
//               ESP32 → POST /getDeviceToken {deviceId, deviceSecret}
//               → returns {customToken}
//   [FIX DB-RULE] database.rules.json auth.token.sub → auth.uid (Custom Token)
//
// EXISTING FIXES:
//   [BUG-CRITICAL-1] Field names: snake_case match করছে ESP32 output
//   [BUG-CRITICAL-2] FCM token path: /users/{uid}/fcmToken
// ─────────────────────────────────────────────────────────────────────────────

'use strict';

const { onValueUpdated }  = require('firebase-functions/v2/database');
const { onUserDeleted }   = require('firebase-functions/v2/identity');
const { onRequest }       = require('firebase-functions/v2/https');
const { defineSecret }    = require('firebase-functions/params');
const admin               = require('firebase-admin');

admin.initializeApp();

// Secret: must match DEVICE_REGISTRATION_SECRET in ESP32 secrets.h
// Set with: firebase functions:secrets:set DEVICE_REGISTRATION_SECRET
const deviceSecret = defineSecret('DEVICE_REGISTRATION_SECRET');

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 1 — getDeviceToken  (NEW in v13)
// ESP32 calls this to get a Firebase Custom Token.
// POST { "deviceId": "ABC123", "deviceSecret": "..." }
// → 200 { "customToken": "eyJ..." }
// ─────────────────────────────────────────────────────────────────────────────
exports.getDeviceToken = onRequest(
  {
    region: 'us-central1',
    cors: false,
    secrets: [deviceSecret],
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    const { deviceId, deviceSecret: clientSecret } = req.body || {};

    if (!deviceId || typeof deviceId !== 'string' || deviceId.length > 64) {
      res.status(400).json({ error: 'Invalid deviceId' });
      return;
    }

    if (!clientSecret || typeof clientSecret !== 'string') {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    // Constant-time comparison to prevent timing attacks
    const expectedSecret = deviceSecret.value();
    if (!timingSafeEqual(clientSecret, expectedSecret)) {
      console.warn(`[getDeviceToken] Auth failed for deviceId=${deviceId}`);
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    try {
      const uid = `esp32-device-${deviceId}`;
      const customToken = await admin.auth().createCustomToken(uid, {
        deviceId,
        role: 'device',
      });
      console.log(`[getDeviceToken] Token minted uid=${uid}`);
      res.status(200).json({ customToken });
    } catch (err) {
      console.error('[getDeviceToken] Error:', err.message);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 2 — onStatusChange
// ─────────────────────────────────────────────────────────────────────────────
exports.onStatusChange = onValueUpdated(
  {
    ref: '/devices/{deviceId}/status',
    region: 'us-central1',
  },
  async (event) => {
    const before   = event.data.before.val();
    const after    = event.data.after.val();
    const deviceId = event.params.deviceId;

    if (!before || !after) return null;

    const uidsToNotify = new Set();

    const ownerSnap = await admin.database().ref(`/device_owners/${deviceId}`).get();
    if (ownerSnap.exists()) uidsToNotify.add(ownerSnap.val());

    const sharedSnap = await admin.database().ref(`/device_shared/${deviceId}`).get();
    if (sharedSnap.exists()) {
      const sharedMap = sharedSnap.val() || {};
      Object.keys(sharedMap).forEach(uid => {
        if (sharedMap[uid] === true) uidsToNotify.add(uid);
      });
    }

    if (uidsToNotify.size === 0) return null;

    const messages = [];

    if (!before.dry_run && after.dry_run) {
      messages.push({ title: '⚠️ Dry Run Alert!', body: `Device ${deviceId}: পানি ছাড়া পাম্প চলছে! স্তর: ${after.water_level_pct}%` });
    }
    if (!before.alarm && after.alarm) {
      messages.push({ title: '🚨 Alarm Active', body: `Device ${deviceId}: সতর্কতা সক্রিয়! পানির স্তর: ${after.water_level} (${after.water_level_pct}%)` });
    }
    if (before.pump === 'OFF' && after.pump === 'ON') {
      messages.push({ title: '💧 পাম্প চালু হয়েছে', body: `Device ${deviceId}: পাম্প চলছে। পানির স্তর: ${after.water_level_pct}%` });
    }
    if (before.pump === 'ON' && after.pump === 'OFF') {
      messages.push({ title: '✅ পাম্প বন্ধ হয়েছে', body: `Device ${deviceId}: পাম্প বন্ধ। পানির স্তর: ${after.water_level_pct}%` });
    }
    if (after.water_level_pct <= 10 && before.water_level_pct > 10) {
      messages.push({ title: '🪣 পানি কম!', body: `Device ${deviceId}: পানির স্তর বিপজ্জনকভাবে কম (${after.water_level_pct}%)` });
    }
    if (after.water_level_pct >= 90 && before.water_level_pct < 90) {
      messages.push({ title: '🎉 ট্যাংক পূর্ণ!', body: `Device ${deviceId}: ট্যাংক ভরে গেছে (${after.water_level_pct}%)` });
    }
    if (after.heap_free > 0 && after.heap_free < 20000 && (before.heap_free >= 20000 || !before.heap_free)) {
      messages.push({ title: '⚠️ Low Memory Warning', body: `Device ${deviceId}: Heap memory কম (${Math.round(after.heap_free / 1024)}KB free).` });
    }

    if (messages.length === 0) return null;

    for (const uid of uidsToNotify) {
      const tokenSnap = await admin.database().ref(`/users/${uid}/fcmToken`).get();
      if (!tokenSnap.exists()) continue;
      const token = tokenSnap.val();

      for (const msg of messages) {
        try {
          await admin.messaging().send({
            token,
            notification: { title: msg.title, body: msg.body },
            android: { priority: 'high', notification: { channelId: 'smartiot_alerts', sound: 'default' } },
            apns: { payload: { aps: { sound: 'default', badge: 1 } } },
          });
          console.log(`[FCM] Sent to uid=${uid}: ${msg.title}`);
        } catch (err) {
          console.error(`[FCM] Failed for uid=${uid}:`, err.message);
          if (err.code === 'messaging/registration-token-not-registered' || err.code === 'messaging/invalid-registration-token') {
            await admin.database().ref(`/users/${uid}/fcmToken`).remove();
          }
        }
      }
    }

    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FUNCTION 3 — onUserDelete
// ─────────────────────────────────────────────────────────────────────────────
exports.onUserDelete = onUserDeleted(async (event) => {
  const uid = event.data.uid;
  console.log(`[Cleanup] Deleting data for uid=${uid}`);

  const devicesSnap = await admin.database().ref(`/users/${uid}/devices`).get();
  const updates = {};
  updates[`/users/${uid}`] = null;

  if (devicesSnap.exists()) {
    const deviceMap = devicesSnap.val() || {};
    for (const deviceId of Object.keys(deviceMap)) {
      const ownerSnap = await admin.database().ref(`/device_owners/${deviceId}`).get();
      if (ownerSnap.exists() && ownerSnap.val() === uid) {
        updates[`/device_owners/${deviceId}`] = null;
      }
      updates[`/device_shared/${deviceId}/${uid}`] = null;
    }
  }

  await admin.database().ref().update(updates);
  console.log(`[Cleanup] Done for uid=${uid}`);
  return null;
});
