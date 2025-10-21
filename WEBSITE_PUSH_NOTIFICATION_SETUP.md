# Website Push Notification Setup

## Overview
This document explains the push notification setup for the StreamersTip website, including icon configuration and implementation.

## What's Been Configured

### 1. Web Icons (Already Updated)
✅ The following web icons now use your StreamersTip logo (`logo1-0.PNG`):
- `/web/icons/Icon-192.png` - Used for notifications and app installation
- `/web/icons/Icon-512.png` - Used for high-res displays
- `/web/icons/Icon-maskable-192.png` - Adaptive icon (Android)
- `/web/icons/Icon-maskable-512.png` - Adaptive icon (Android)
- `/web/favicon.png` - Browser tab icon

### 2. Manifest Configuration
✅ Updated `/web/manifest.json`:
- App name: "StreamersTip"
- Theme color: #9248D2 (your purple)
- Description: "Social platform for streamers and content creators"
- Icons properly configured with `purpose: "any"` for notifications

### 3. Firebase Cloud Messaging Service Worker
✅ Created `/web/firebase-messaging-sw.js`:
- Handles background push notifications
- Uses `/icons/Icon-192.png` for notification icon
- Handles notification clicks and navigation
- Routes users to appropriate pages based on notification type:
  - Follow notifications → User profile
  - Like/Comment notifications → Video
  - Message notifications → Chat

### 4. HTML Meta Tags
✅ Updated `/web/index.html`:
- Page title: "StreamersTip"
- Meta description for SEO
- Theme color for mobile browsers
- Apple touch icon for iOS

## How Web Push Notifications Work

### Notification Flow:
1. **User grants permission** → Browser requests notification permission
2. **FCM token generated** → Firebase Cloud Messaging creates unique token
3. **Token stored** → Token saved in Firestore for the user
4. **Server sends notification** → Your Cloud Functions send via FCM
5. **Service worker receives** → `firebase-messaging-sw.js` handles it
6. **Notification displays** → Shows with your logo
7. **User clicks** → Routes to appropriate page

### Notification Icon Display:
```javascript
const notificationOptions = {
  icon: '/icons/Icon-192.png',  // Your StreamersTip logo
  badge: '/icons/Icon-192.png', // Shown in system tray
  // ... other options
};
```

## Deployment Steps

### 1. Build the Web App
```bash
flutter build web --release
```

### 2. Deploy to Firebase Hosting
```bash
firebase deploy --only hosting
```

### 3. Verify Service Worker
After deployment, check:
- Open DevTools → Application → Service Workers
- Verify `firebase-messaging-sw.js` is registered
- Check Console for registration messages

### 4. Test Push Notifications
1. Open website in browser
2. Grant notification permission when prompted
3. Trigger a notification (like, follow, comment, message)
4. Verify notification shows with StreamersTip logo

## Important URLs

### Service Worker Registration
The service worker is automatically registered by Firebase SDK when:
- User visits the website
- Firebase Messaging is initialized
- User grants notification permission

### Notification Permissions
```javascript
// Request permission (handled by your Flutter app)
NotificationSettings settings = await messaging.requestPermission(
  alert: true,
  announcement: false,
  badge: true,
  carPlay: false,
  criticalAlert: false,
  provisional: false,
  sound: true,
);
```

## Troubleshooting

### Notifications Not Showing
1. **Check service worker**: Open DevTools → Application → Service Workers
2. **Verify FCM config**: Ensure `firebase-messaging-sw.js` has correct config
3. **Check permissions**: Browser settings → Site settings → Notifications
4. **Clear cache**: Clear browser cache and reload
5. **Check console**: Look for FCM initialization errors

### Wrong Icon Showing
1. **Clear browser cache**: Hard refresh (Cmd+Shift+R / Ctrl+Shift+R)
2. **Rebuild web**: `flutter clean && flutter build web --release`
3. **Redeploy**: `firebase deploy --only hosting`
4. **Unregister service worker**: DevTools → Application → Service Workers → Unregister

### Service Worker Not Registered
1. **HTTPS required**: Service workers only work on HTTPS (or localhost)
2. **Check file location**: Must be at `/firebase-messaging-sw.js`
3. **Check console**: Look for registration errors
4. **Verify Firebase config**: Ensure credentials are correct

## Browser Support

### Push Notifications Supported:
✅ Chrome (Desktop & Mobile)
✅ Firefox (Desktop & Mobile)
✅ Edge (Desktop & Mobile)
✅ Safari (macOS 16.4+, iOS 16.4+)
❌ Opera (Limited support)
❌ Internet Explorer (Not supported)

### Icon Requirements:
- **Format**: PNG (recommended), JPG, SVG
- **Size**: 192x192px minimum, 512x512px recommended
- **Background**: Transparent or solid color
- **Safe area**: Keep important content in center 80%

## Firebase Configuration

### Current Setup:
- Service worker automatically loads Firebase from CDN
- Uses Firebase Messaging v10.7.1
- Configuration includes:
  - API Key
  - Auth Domain
  - Project ID
  - Storage Bucket
  - Messaging Sender ID
  - App ID

### To Update Firebase Config:
1. Get web config from Firebase Console
2. Update `firebase-messaging-sw.js` with new values
3. Rebuild and redeploy web app

## Testing Checklist

### Before Deployment:
- [ ] Icons look correct in `/web/icons/`
- [ ] Manifest has correct app name and colors
- [ ] Service worker has correct Firebase config
- [ ] Build completes without errors

### After Deployment:
- [ ] Website loads correctly
- [ ] Notification permission requested
- [ ] Service worker registered (check DevTools)
- [ ] Test notification shows StreamersTip logo
- [ ] Clicking notification navigates correctly
- [ ] Icons display properly on all supported browsers

## Comparison with Mobile App

| Feature | Mobile App | Website |
|---------|-----------|---------|
| Icon Location | `/android/app/src/main/res/mipmap-*/` | `/web/icons/` |
| Configuration | `pubspec.yaml` + launcher_icons | `manifest.json` + service worker |
| Background Handling | Native OS | Service Worker |
| Permission Request | In-app dialog | Browser prompt |
| Click Handling | Flutter navigation | Service worker event |
| Icon Format | Android Adaptive Icons | Standard PNG |

## Next Steps

1. **Deploy to hosting**:
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

2. **Test on different browsers**:
   - Chrome (most common)
   - Safari (iOS users)
   - Firefox (alternative)

3. **Monitor in production**:
   - Check Firebase Console → Cloud Messaging
   - Monitor delivery rates
   - Track user permissions

4. **Optimize for performance**:
   - Use CDN for icons if needed
   - Compress icon files
   - Test notification load times

## Support

### Firebase Documentation:
- [FCM for Web](https://firebase.google.com/docs/cloud-messaging/js/client)
- [Service Workers](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [Web App Manifest](https://developer.mozilla.org/en-US/docs/Web/Manifest)

### Debugging Tools:
- Chrome DevTools → Application tab
- Firebase Console → Cloud Messaging
- Browser notification settings
- Service worker lifecycle logs

---

**Status**: ✅ Web notification configuration complete with StreamersTip logo
**Last Updated**: October 21, 2025

