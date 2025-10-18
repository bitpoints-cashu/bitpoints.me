# Bluetooth Mesh Testing Guide

## 📦 APK Location
```
/home/juli/git/cashu.me/android/app/build/outputs/apk/debug/app-debug.apk
Size: 13MB
```

## 🔧 Installation

### Device 1 (Already Installed)
- Device ID: TC30042225G210043
- Status: ✅ Installed and ready

### Device 2
Transfer the APK using one of these methods:

**Option 1: ADB over network**
```bash
# If second device is on same network
adb connect <device-ip>:5555
adb -s <device-ip>:5555 install -r android/app/build/outputs/apk/debug/app-debug.apk
```

**Option 2: USB cable**
```bash
# Connect second device via USB
adb devices  # Verify it appears
adb -s <device-id> install -r android/app/build/outputs/apk/debug/app-debug.apk
```

**Option 3: File transfer**
- Copy APK to second device via USB/cloud/email
- Open APK file on device to install

## 🧪 Testing Steps

### Step 1: Grant Permissions (BOTH devices)

When you first open the app, it will request:

1. **Bluetooth Permissions** (Android 12+)
   - BLUETOOTH_SCAN
   - BLUETOOTH_CONNECT
   - BLUETOOTH_ADVERTISE

2. **Location Permission**
   - Required for BLE scanning
   - Grant "While using the app"

3. **Notification Permission**
   - For ecash receive notifications

### Step 2: Verify Bluetooth Service Started (BOTH devices)

Check the logs to confirm service is running:
```bash
# For Device 1
adb logcat -s BluetoothMeshService:I BluetoothEcashService:I | grep -E "Starting|peer ID"

# Should see:
# BluetoothEcashService: Starting Bluetooth ecash service
# BluetoothMeshService: Starting Bluetooth mesh service with peer ID: <id>
```

### Step 3: Test Peer Discovery

**On Device 1:**
1. Open the wallet page
2. Look for "Send to Nearby" button (should appear on Android only)
3. Tap the button
4. Should open "Nearby Contacts" dialog

**On Device 2:**
1. Keep app open on wallet page
2. Service should be advertising

**Expected Result:**
- Device 1 should discover Device 2 in the peer list
- Each device has a unique peer ID (8 hex characters)
- Peers appear within 5-10 seconds

### Step 4: Test Token Transfer

**On Device 1 (Sender):**
1. Tap "Send to Nearby"
2. Select Device 2 from peer list
3. Enter amount (e.g., 10 sats)
4. Add memo (optional)
5. Tap "Send"

**On Device 2 (Receiver):**
1. Watch for notification banner
2. Banner should show: "Received <amount> sats from <sender>"
3. Tap "Claim" button

**Expected Result:**
- Token sent successfully from Device 1
- Notification appears on Device 2
- Token can be claimed and added to balance

### Step 5: Test Mesh Relay (3+ devices)

If you have a 3rd device:

**Setup:**
- Device A & B are in Bluetooth range
- Device B & C are in Bluetooth range
- Device A & C are NOT in direct range

**Test:**
1. Send token from Device A to Device C
2. Should relay through Device B automatically

**Expected Result:**
- Token successfully delivered via mesh routing
- Check logs for relay messages

## 🐛 Troubleshooting

### Peers Not Appearing

**Check 1: Bluetooth is ON**
```bash
adb shell settings get global bluetooth_on
# Should return: 1
```

**Check 2: Location Permission Granted**
```bash
adb shell dumpsys package me.cashu.wallet | grep -A3 "runtime permissions"
```

**Check 3: Service Running**
```bash
adb logcat -s BluetoothMeshService:I PowerManager:I | grep -E "Starting|Power mode"
```

**Check 4: Devices Close Enough**
- BLE typically works within 10-30 meters
- No obstacles between devices works best

### Plugin Not Found Error

If you see `"BluetoothEcash" plugin is not implemented on android`:
- This was fixed in the latest build
- Reinstall the APK
- Force stop and restart the app

### White Screen on Launch

- Make sure you have the latest APK (13MB)
- Web assets were synced in latest build
- Clear app data if needed: `adb shell pm clear me.cashu.wallet`

## 📊 Debug Commands

### Monitor Bluetooth Activity
```bash
adb logcat -s BluetoothMeshService:I BluetoothEcashService:I BluetoothGattClientManager:I BluetoothGattServerManager:I PeerManager:I
```

### Monitor JavaScript Logs
```bash
adb logcat -s "Capacitor/Console:I" | grep -i bluetooth
```

### Monitor All cashu.me App Logs
```bash
adb logcat --pid=$(adb shell pidof -s me.cashu.wallet)
```

### Check Power Management
```bash
adb logcat -s PowerManager:I | grep cashu
```

## ✅ Success Indicators

When everything is working correctly, you should see:

**In Logs:**
```
MainActivity: BluetoothEcash plugin registered successfully
BluetoothEcashService: Starting Bluetooth ecash service
BluetoothMeshService: Starting Bluetooth mesh service with peer ID: ec4cfde9fc61a739
BluetoothEcashPlugin: Bluetooth service started
```

**In JavaScript Console:**
```
Bluetooth ecash service initialized
Bluetooth mesh service started
Bluetooth mesh service initialized
```

**In UI:**
- "Send to Nearby" button visible on wallet page
- Tapping it shows peer discovery dialog
- Peers appear in the list
- Can send and receive tokens

## 🎯 Test Checklist

- [ ] APK installed on both devices
- [ ] Bluetooth permissions granted
- [ ] Location permission granted
- [ ] Services started on both devices
- [ ] Peer discovery works
- [ ] Token sent successfully
- [ ] Token received and claimed
- [ ] Mesh relay tested (optional, 3+ devices)
- [ ] Offline delivery tested (optional)

## 📝 Notes

### Current Limitations

1. **Android Only**: iOS not yet implemented
2. **File Sharing Disabled**: Only ecash tokens work
3. **Contact Management**: Basic peer tracking (no Nostr sync yet)
4. **Debug UI**: Minimal (production-focused)

### Known Issues

- First BLE scan can take 5-10 seconds
- Peers may disappear if devices go to sleep
- Battery optimization may interfere (disable for testing)

### Performance

- **Connection Limit**: Up to 8 simultaneous connections
- **Range**: 10-30 meters typical
- **Packet Size**: ~200 bytes for ecash message
- **Relay Hops**: Maximum 7 hops

## 🚀 Next Steps After Testing

Once basic functionality is verified:

1. Test edge cases (low battery, background, etc.)
2. Implement Nostr contact sync (NIP-02)
3. Add delivery receipts
4. Polish UI/UX
5. Add proper error handling
6. Battery optimization dialogs
7. Release v1.1.0-beta with Bluetooth support!




