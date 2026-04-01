# Android Emulator DNS & Network Fix

## Problem

```
Unable to resolve host "firestore.googleapis.com": No address associated with hostname
EAI_NODATA (No address associated with hostname)
```

Firestore and Firebase services fail because the emulator cannot resolve DNS.

## Solutions

### 1. Start Emulator with Custom DNS (Recommended)

```bash
# List available AVDs
emulator -list-avds

# Start with Google DNS
emulator -avd <your_avd_name> -dns-server 8.8.8.8,8.8.4.4
```

### 2. Android Studio: Edit AVD

1. Tools → Device Manager
2. Edit (pencil) your virtual device
3. Show Advanced Settings
4. Under "Network", set DNS to `8.8.8.8` (or leave default)
5. Ensure "Cold Boot" is not causing issues – try "Quick Boot"

### 3. Wait for Network Ready

After starting the emulator, wait 30–60 seconds before launching the app. Cold start can delay network.

### 4. Physical Device

- Confirm Wi‑Fi or mobile data is working
- Try toggling airplane mode or reconnecting to the network

### 5. Disable IPv6 on Emulator (if needed)

Some environments have IPv6 DNS issues:

```bash
emulator -avd <avd_name> -dns-server 8.8.8.8 -no-snapshot-load
```

## Deploy Updated Storage Rules

After changing `storage.rules`, deploy:

```bash
firebase deploy --only storage
```
