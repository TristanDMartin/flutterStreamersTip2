# App Check Setup (Optional for Production)

## Current State

Dart startup calls `activateAppCheckIfEnabled()` in `lib/core/firebase_app_check_startup.dart`
after Firebase init.

- **Debug builds** always activate the App Check **debug provider** and log the debug
  token to the console (register it in Firebase Console → App Check → Manage debug tokens).
- **Release builds** use Play Integrity / DeviceCheck when built with
  `--dart-define=ST_ENABLE_APP_CHECK=true`.

Upload and optimistic placeholder writes call `ensureAppCheckReadyForFirestore()` first.
If attestation fails (`App attestation failed`, placeholder token), Firestore writes
will show `PERMISSION_DENIED` even when UID ownership is correct.

If you see placeholder-token errors while testing, either register the debug token or set
Firestore/Storage App Check enforcement to **Unenforced** in Firebase Console.

## When to Configure

- You want to enforce App Check in Firestore/Storage rules
- You are preparing for production
- You need protection against abuse from unofficial clients

## Setup Steps

### 1. Firebase Console

1. Project → App Check
2. Register your Android app (Debug and Release SHA-1)
3. Choose provider: **Play Integrity** (recommended) or **Debug** for development

### 2. Flutter (Android)

Add to `android/app/build.gradle`:

```gradle
dependencies {
    implementation 'com.google.firebase:firebase-appcheck-playintegrity:17.0.1'
}
```

### 3. Initialize in Dart

```dart
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );
  
  runApp(MyApp());
}
```

### 4. Update Rules (when enforced)

In Firestore and Storage rules, add `request.auth != null` (and optionally App Check). App Check tokens are validated automatically when configured.

## Debug Provider (Development)

For local development, use the Debug provider and add your debug token in the Firebase Console.
