// firebase-messaging-sw.js — SmartIoT v2.2.0
// Firebase Cloud Messaging Service Worker for Web
// Serves background notifications when browser tab is not in focus

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Same values as the 'web' section in lib/firebase_options.dart
firebase.initializeApp({
  apiKey: "AIzaSyDQ8jM-8-ftiIp308RRq7lwT7PhQD01U0U",
  authDomain: "smartiot-8190a.firebaseapp.com",
  databaseURL: "https://smartiot-8190a-default-rtdb.firebaseio.com",
  projectId: "smartiot-8190a",
  storageBucket: "smartiot-8190a.firebasestorage.app",
  messagingSenderId: "353683838193",
  appId: "1:353683838193:web:c23438501b5e4e994bc550",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[SmartIoT SW] Background message:', payload);
  return self.registration.showNotification(
    payload.notification?.title ?? 'SmartIoT Alert',
    {
      body:  payload.notification?.body ?? '',
      icon:  '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      tag:   'smartiot-alert',
    }
  );
});
