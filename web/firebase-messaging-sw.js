importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// Initialize Firebase
firebase.initializeApp({
  apiKey: "AIzaSyBF5FZTg6E30JQBcFedgswKCuS2-qUisVw",
  authDomain: "minaret-f3793.firebaseapp.com",
  projectId: "minaret-f3793",
  storageBucket: "minaret-f3793.firebasestorage.app",
  messagingSenderId: "917799173646",
  appId: "1:917799173646:web:8e65f21fe85da3cfee465f",
  measurementId: "G-PELLPNYY3K"
});

// Retrieve Firebase Messaging object
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'Minaret';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function(event) {
  console.log('Notification click received.');
  event.notification.close();
  
  event.waitUntil(
    clients.openWindow('/')
  );
});
