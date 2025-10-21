# Push Notification Icon Setup Guide 🔔

## Current Status
Your push notifications are currently using the default Flutter icon (`@mipmap/ic_launcher`).

**Files to Replace:**
- Android: `/android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS: `/ios/Runner/Assets.xcassets/AppIcon.appiconset/`

---

## ✅ Automatic Solution - Use Flutter Launcher Icons Package

### Step 1: Add the Package

Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1
```

### Step 2: Configure Icons

Add this configuration to `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo.png"  # Your main logo
  
  # Android-specific settings
  android:
    adaptive_icon_background: "#FFFFFF"  # White background
    adaptive_icon_foreground: "assets/logo.png"
  
  # iOS-specific settings
  ios:
    generate_apple_watch_assets: false
  
  # Notification icon (Android only - should be monochrome)
  android_notification_icon:
    name: "ic_notification"
    foreground: "assets/091225_ST_logo_white.PNG"  # White logo for dark backgrounds
```

### Step 3: Generate Icons

Run these commands:

```bash
flutter pub get
dart run flutter_launcher_icons
```

This will automatically:
- ✅ Generate all Android launcher icon sizes
- ✅ Generate all iOS app icon sizes
- ✅ Create a special notification icon for Android status bar

---

## 🎨 Manual Solution (If You Prefer Full Control)

### Android Setup

#### 1. Create Notification Icon (Status Bar)

**Requirements:**
- White icon on transparent background
- Simple, recognizable silhouette
- Size: 24x24dp base size

**Generate sizes:**
- `drawable-mdpi/ic_notification.png` - 24x24px
- `drawable-hdpi/ic_notification.png` - 36x36px
- `drawable-xhdpi/ic_notification.png` - 48x48px
- `drawable-xxhdpi/ic_notification.png` - 72x72px
- `drawable-xxxhdpi/ic_notification.png` - 96x96px

#### 2. Create App Launcher Icon

**Replace these files** with your full-color logo:
- `mipmap-mdpi/ic_launcher.png` - 48x48px
- `mipmap-hdpi/ic_launcher.png` - 72x72px
- `mipmap-xhdpi/ic_launcher.png` - 96x96px
- `mipmap-xxhdpi/ic_launcher.png` - 144x144px
- `mipmap-xxxhdpi/ic_launcher.png` - 192x192px

#### 3. Update Push Notification Service

If using separate notification icon:

```dart
// In lib/services/push_notification_service.dart
const androidDetails = AndroidNotificationDetails(
  'streamers_tip_channel',
  'StreamersTip Notifications',
  channelDescription: 'Notifications for StreamersTip app',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@drawable/ic_notification',  // ← Use notification icon
);
```

### iOS Setup

#### 1. Update App Icon

Replace icons in `/ios/Runner/Assets.xcassets/AppIcon.appiconset/`:

**Required sizes:**
- `Icon-App-20x20@1x.png` - 20x20px
- `Icon-App-20x20@2x.png` - 40x40px
- `Icon-App-20x20@3x.png` - 60x60px
- `Icon-App-29x29@1x.png` - 29x29px
- `Icon-App-29x29@2x.png` - 58x58px
- `Icon-App-29x29@3x.png` - 87x87px
- `Icon-App-40x40@1x.png` - 40x40px
- `Icon-App-40x40@2x.png` - 80x80px
- `Icon-App-40x40@3x.png` - 120x120px
- `Icon-App-60x60@2x.png` - 120x120px
- `Icon-App-60x60@3x.png` - 180x180px
- `Icon-App-76x76@1x.png` - 76x76px
- `Icon-App-76x76@2x.png` - 152x152px
- `Icon-App-83.5x83.5@2x.png` - 167x167px
- `Icon-App-1024x1024@1x.png` - 1024x1024px (App Store)

---

## 🛠️ Recommended: Use Online Icon Generator

### Option 1: AppIcon.co (Free)
1. Go to https://www.appicon.co/
2. Upload `assets/logo.png`
3. Download Android and iOS packages
4. Replace files in your project

### Option 2: MakeAppIcon (Free)
1. Go to https://makeappicon.com/
2. Upload `assets/logo.png`
3. Download all sizes
4. Replace files in project folders

### Option 3: Android Asset Studio (Android Only)
1. Go to https://romannurik.github.io/AndroidAssetStudio/
2. Use "Launcher Icon Generator"
3. Upload `assets/logo.png`
4. Download and replace Android icons

---

## 🎨 Your Logo Files

You have these logos available:
- ✅ `assets/logo.png` - Main logo
- ✅ `assets/091225_ST_logo_white.PNG` - White version (perfect for notifications!)
- ✅ `assets/091225_ST_logo _black.PNG` - Black version

**Recommendation:** Use white logo for Android notification icon (status bar)

---

## 🔧 Quick Fix Code Changes

Update the notification icon references in your code:

### File 1: `lib/services/push_notification_service.dart`

```dart
// Line 73 - Change to notification icon
const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');

// Line 238 - Change notification icon
icon: '@drawable/ic_notification',

// Line 277 - Change notification icon  
icon: '@drawable/ic_notification',
```

### File 2: `lib/services/scheduling_notification_service.dart`

```dart
// Line 20 - Change to notification icon
AndroidInitializationSettings('@drawable/ic_notification');
```

---

## 📱 After Icon Setup

### Clean and Rebuild

```bash
flutter clean
flutter pub get
flutter run
```

### Verify Changes

1. **App Icon:** Check home screen - should show your logo
2. **Notification Icon:** Trigger a notification - status bar should show your logo
3. **Notification Content:** Expanded notification should show your app icon

---

## 🎯 Expected Results

### Before
- 🔵 Flutter logo on app icon
- 🔵 Flutter logo in notifications
- Generic appearance

### After  
- 🎨 StreamersTip logo on app icon
- 🎨 StreamersTip logo in notifications
- Professional branded experience

---

## 🚀 Quick Start (Recommended)

**Easiest method:**

1. Add to pubspec.yaml:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo.png"
  android_notification_icon:
    name: "ic_notification"
    foreground: "assets/091225_ST_logo_white.PNG"
```

2. Run:
```bash
flutter pub get
dart run flutter_launcher_icons
flutter clean
flutter run
```

Done! All icons (app + notifications) will be updated automatically. ✅

---

**Note:** The notification icon will appear in:
- Status bar (when notification arrives)
- Notification drawer
- Lock screen notifications
- Heads-up notifications

