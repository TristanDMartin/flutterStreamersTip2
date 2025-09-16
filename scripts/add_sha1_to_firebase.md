# Add SHA-1 Fingerprint to Firebase Console

## Quick Fix for Google Play Services Error

Your current SHA-1 fingerprint is:
```
AB:6B:A5:1A:D8:7F:C6:B1:A5:AB:07:1D:91:E1:0D:1B:2F:5D:0C:2C
```

## Steps to Fix:

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select Project**: `streamerstip-6cfdb`
3. **Go to Project Settings** (gear icon in top left)
4. **Select "General" tab**
5. **Scroll to "Your apps" section**
6. **Find Android app**: `com.streamerstip.streamersTipApp`
7. **Click on the app**
8. **Scroll to "SHA certificate fingerprints"**
9. **Click "Add fingerprint"**
10. **Paste this SHA-1**: `AB:6B:A5:1A:D8:7F:C6:B1:A5:AB:07:1D:91:E1:0D:1B:2F:5D:0C:2C`
11. **Click "Save"**
12. **Download updated `google-services.json`**
13. **Replace** `android/app/google-services.json` with the new file
14. **Clean and rebuild**:
    ```bash
    flutter clean
    flutter pub get
    flutter run
    ```

## Expected Result:
- ✅ No more `E/GoogleApiManager: Failed to get service from broker` errors
- ✅ Google Sign-In will work properly
- ✅ All Google services will function correctly

## Alternative: Use Firebase CLI (if you have it installed)
```bash
firebase apps:sdkconfig android
```

This will generate the updated `google-services.json` file automatically.
