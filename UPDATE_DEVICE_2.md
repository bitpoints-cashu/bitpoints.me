# Update Device 2 to Fix Token Receipt

## Problem

Device 1 sent tokens (points deducted) but Device 2 didn't receive them because:
- ⚠️ "Packet failed security validation" errors
- Device 2 needs the latest APK with proper ecash packet handling

## Solution: Update Device 2

### Latest APK Location
```
/home/juli/git/cashu.me/android/app/build/outputs/apk/debug/app-debug.apk
Size: 14MB
Built: Oct 15 20:39 (latest with all fixes)
```

### Option 1: ADB via USB (Recommended)

If you can connect Device 2 via USB:

```bash
# Connect Device 2 via USB cable
adb devices

# Should show both devices, like:
# TC30042225G210043    device   <- Device 1 (currently connected)
# XXXXXXXXXXXXXXXX     device   <- Device 2 (newly connected)

# Install on Device 2 specifically
adb -s <device-2-id> install -r /home/juli/git/cashu.me/android/app/build/outputs/apk/debug/app-debug.apk

# Enable Bluetooth on Device 2
adb -s <device-2-id> shell svc bluetooth enable

# Launch app
adb -s <device-2-id> shell am start -n me.cashu.wallet/.MainActivity
```

### Option 2: File Transfer

If you can't connect Device 2 via USB:

1. **Copy APK to Device 2:**
   - Via email: Send the APK to yourself
   - Via cloud: Upload to Google Drive/Dropbox
   - Via USB: Copy to Downloads folder

2. **Install on Device 2:**
   - Open Downloads folder
   - Tap app-debug.apk
   - Tap "Install" (may need to allow unknown sources)

3. **Enable Bluetooth:**
   - Go to Settings → Bluetooth → ON

4. **Launch app**

### Option 3: ADB over Network

If both devices are on same WiFi:

```bash
# On Device 2, enable ADB over network:
# Settings → Developer Options → Wireless debugging → ON

# Get Device 2 IP address
# Settings → About Phone → Status → IP address

# Connect from computer
adb connect <device-2-ip>:5555

# Install
adb -s <device-2-ip>:5555 install -r /home/juli/git/cashu.me/android/app/build/outputs/apk/debug/app-debug.apk
```

## After Updating Device 2

### Clear App Data (Important!)

To ensure clean state:

```bash
# Via ADB
adb -s <device-2-id> shell pm clear me.cashu.wallet

# Or manually on Device 2
Settings → Apps → Trails Coffee Rewards → Storage → Clear Data
```

### Verify Bluetooth Service

Check if it starts properly:

```bash
# Monitor Device 2
adb -s <device-2-id> logcat | grep -E "BluetoothMesh|peer ID|ecash"
```

Should see:
```
BluetoothMeshService: Starting Bluetooth mesh service with peer ID: <id>
BluetoothGattServerManager: Advertising started
BluetoothGattClientManager: BLE scan started successfully
```

## Then Test Again

### On Device 1 (Sender):
1. Tap "Send to Nearby"
2. Select "Trails User" peer
3. Enter amount: 10 sats
4. Tap Send

### On Device 2 (Receiver - Updated):
1. Watch for notification banner
2. Should show: "Received 10 sats from <sender>"
3. Tap "Claim" button
4. Balance should increase

## Debug: How to Manually Check for Unclaimed Tokens

If the notification doesn't appear, check localStorage on Device 2:

```bash
# View unclaimed tokens
adb -s <device-2-id> logcat | grep "unclaimedTokens\|ecashReceived"
```

Or in the app:
- The `EcashClaimNotification` component should auto-show if there are unclaimed tokens
- Stored in localStorage key: `bluetooth-unclaimed-tokens`

## What Changed in Latest APK

- ✅ Fixed activeProofs null check
- ✅ Added isBluetoothEnabled() method
- ✅ Added requestBluetoothEnable() method  
- ✅ Better error messages
- ✅ Security validation improvements

## Still Having Issues?

If after updating Device 2, tokens still don't arrive:

### Check Logs for Ecash Packet Type (0xE1)

```bash
adb -s <device-2-id> logcat | grep -E "type.*0xE1|EcashMessage|ecashReceived"
```

### Check Security Validation

The "Packet failed security validation" might indicate:
- Signature mismatch
- Identity verification issue
- Need to investigate SecurityManager

Let me know if you need help debugging further!




