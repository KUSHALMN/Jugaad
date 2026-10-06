// Firebase Cloud Messaging Service Worker for Flutter Web
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAvnpyKw-suP1qlkCG42aWx78mZ2O1SmfI",
  authDomain: "jugaad-prod-app-2026.firebaseapp.com",
  projectId: "jugaad-prod-app-2026",
  storageBucket: "jugaad-prod-app-2026.firebasestorage.app",
  messagingSenderId: "745766971944",
  appId: "1:745766971944:web:af2ac24da4c2e56280231d"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'Jugaad';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : '',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
