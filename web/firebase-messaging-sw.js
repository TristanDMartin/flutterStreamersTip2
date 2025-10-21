importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// Initialize Firebase with correct configuration
const firebaseConfig = {
  apiKey: "AIzaSyCcUq1k02c4QRvuZSZK16fD6wpUMnLXxe8",
  authDomain: "streamerstip-6cfdb.firebaseapp.com",
  projectId: "streamerstip-6cfdb",
  storageBucket: "streamerstip-6cfdb.firebasestorage.app",
  messagingSenderId: "161050969080",
  appId: "1:161050969080:android:07a92599a2c1a1f504cc0d"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || 'StreamersTip';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.type || 'default',
    data: payload.data,
    requireInteraction: false,
    vibrate: [200, 100, 200]
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[Service Worker] Notification click received.');
  
  event.notification.close();
  
  // Navigate to appropriate page based on notification data
  const data = event.notification.data;
  let urlToOpen = '/';
  
  if (data) {
    if (data.type === 'follow') {
      urlToOpen = `/?userId=${data.fromUserId}`;
    } else if (data.type === 'like' && data.videoId) {
      urlToOpen = `/?videoId=${data.videoId}`;
    } else if (data.type === 'comment' && data.videoId) {
      urlToOpen = `/?videoId=${data.videoId}`;
    } else if (data.type === 'message' && data.chatId) {
      urlToOpen = `/chat?chatId=${data.chatId}`;
    }
  }
  
  event.waitUntil(
    clients.matchAll({type: 'window', includeUncontrolled: true})
      .then((windowClients) => {
        // Check if there is already a window/tab open with the target URL
        for (let i = 0; i < windowClients.length; i++) {
          const client = windowClients[i];
          if (client.url === urlToOpen && 'focus' in client) {
            return client.focus();
          }
        }
        // If not, open a new window/tab
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});

