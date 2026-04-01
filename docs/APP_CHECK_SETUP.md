# App Check Setup (Optional for Production)

## Current State

```
Error getting App Check token; using placeholder token instead.
No AppCheckProvider installed.
```

Firebase uses a placeholder token. This is fine for development.

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
