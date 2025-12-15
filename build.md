# Bitpoints.me iOS Build Instructions

## ⚠️ CRITICAL: Capacitor Config Overwrite Issue

**DO NOT use `npx cap run ios` or `npx cap sync ios`** - these commands will **overwrite** the iOS-specific capacitor configuration and **remove the BluetoothEcashPlugin**.

### What Happens:
- `npx cap run ios` performs a sync that overwrites `ios/App/App/capacitor.config.json`
- The BluetoothEcashPlugin gets removed from the iOS config
- The app builds but Bluetooth functionality is broken

### ✅ Correct Build Process:

## Prerequisites

1. **Xcode 26.1+** installed
2. **iOS Device** connected (not simulator)
3. **Ruby Gems** updated:
   ```bash
   cd ios/App
   bundle install  # installs CocoaPods 1.16.2 and xcodeproj 1.27.0
   ```

## Build Steps

### 1. Build Web App
```bash
npm run build
```

### 2. Install iOS Dependencies
```bash
cd ios/App
bundle exec pod install
```

### 3. Verify Configurations (CRITICAL)

**Check these files contain BluetoothEcashPlugin:**

- ✅ `capacitor.config.json` (main config) - should have "BluetoothEcashPlugin" in packageClassList
- ✅ `ios/App/App/capacitor.config.json` (iOS-specific config) - should have "BluetoothEcashPlugin" in packageClassList
- ✅ `ios/App/Podfile` (should have CapacitorBluetoothEcash pod)

**Required Podfile configuration:**
```ruby
def capacitor_pods
  pod 'Capacitor', :path => '../../node_modules/@capacitor/ios'
  pod 'CapacitorCordova', :path => '../../node_modules/@capacitor/ios'
  pod 'CapacitorCamera', :path => '../../node_modules/@capacitor/camera'
  pod 'CapacitorClipboard', :path => '../../node_modules/@capacitor/clipboard'
  pod 'CapacitorHaptics', :path => '../../node_modules/@capacitor/haptics'
  pod 'CapacitorPluginSafeArea', :path => '../../node_modules/capacitor-plugin-safe-area'
  pod 'CapacitorBluetoothEcash', :path => 'App/Plugins/BluetoothEcash'  # REQUIRED for Bluetooth
end
```

If any are missing, restore them manually before building.

### 3.5. Data Type Consistency Check

**Critical for preventing crashes:** Ensure Swift ↔ JavaScript data types match exactly.

- `lastSeen` timestamps must be `Int` (Swift) → `number` (TypeScript)
- Never send as `String` - causes Capacitor serialization crashes
- `Peer` interface in `src/plugins/bluetooth-ecash.ts` must match Swift implementation

### 4. Manual Asset Copy (Required)

**DO NOT skip this step:**
```bash
# Copy built web assets to iOS project
cp -r dist/spa/* ios/App/App/public/
```

### 5. Build and Deploy to Device

**DO NOT USE:** ❌ `npx cap run ios`

**USE INSTEAD:** ✅ Direct Xcode build
```bash
cd ios/App
xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug -destination "id=YOUR_DEVICE_ID" install
```

Find your device ID:
```bash
npx cap run ios --list
```

Example:
```bash
xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug -destination "id=00008101-0009388A1E06001E" install
```

### 6. Verify Installation
```bash
ios-deploy --exists --bundle_id me.bitpoints.wallet
```

### 7. TestFlight Release Build

For TestFlight distribution:
```bash
cd ios/App
xcodebuild -workspace App.xcworkspace -scheme App -configuration Release -destination "generic/platform=iOS" -archivePath "build/Bitpoints.xcarchive" archive
```

Then upload to App Store Connect:
```bash
xcodebuild -exportArchive -archivePath "build/Bitpoints.xcarchive" -exportPath "build" -exportOptionsPlist "exportOptions.plist"
```

**exportOptions.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

## File Structure

### Required Files
```
ios/App/App/Plugins/BluetoothEcash/
├── CapacitorBluetoothEcash.podspec    # CocoaPods specification
├── BluetoothEcashPlugin.swift          # Main plugin implementation
├── BluetoothEcashPlugin.m              # Objective-C bridge
├── BluetoothEcash.swift                # Plugin interface
└── BitChat/                            # Core BLE implementation
    ├── BLEService.swift
    ├── BitchatProtocol.swift
    └── [other protocol files...]
```

### Configuration Files
```
capacitor.config.json                    # Main Capacitor config
capacitor.config.ts                     # TypeScript Capacitor config
ios/App/App/capacitor.config.json       # iOS-specific config (gets overwritten!)
ios/App/Podfile                         # CocoaPods dependencies
ios/App/Gemfile                         # Ruby gem versions
```

## Common Issues & Fixes

### Issue: "BluetoothEcashPlugin not found" / "UNIMPLEMENTED"
**Cause:** Capacitor sync overwrote iOS config
**Fix:**
```bash
# Edit ios/App/App/capacitor.config.json
# Add "BluetoothEcashPlugin" to packageClassList array
```

### Issue: "No podspec found for CapacitorBluetoothEcash"
**Cause:** Missing podspec file
**Fix:** Ensure `CapacitorBluetoothEcash.podspec` exists in `ios/App/App/Plugins/BluetoothEcash/`

### Issue: CocoaPods compatibility errors
**Fix:** Use updated versions in `ios/App/Gemfile`:
```ruby
gem 'cocoapods', '1.16.2'
gem 'xcodeproj', '1.27.0'
```

### Issue: Xcode 26.1 compatibility
**Fix:** Update xcodeproj gem to 1.27.0 or higher

### Issue: "NSCFNumber objectForKey" or "NSTaggedDate objectForKey" crashes
**Cause:** Data type mismatch between Swift and JavaScript
**Fix:**
- Ensure `lastSeen` is sent as `Int` from Swift, expected as `number` in TypeScript
- Never send timestamps as `String` - causes Capacitor serialization failures
- Verify `Peer` interface matches between platforms

### Issue: Bluetooth works but contacts show empty or crash
**Cause:** Missing CapacitorBluetoothEcash pod or plugin registration
**Fix:** Verify all three config files contain BluetoothEcashPlugin and pod is installed

## Testing Bluetooth Functionality

1. **Launch App** on device
2. **Go to Contacts** section
3. **Check for yellow Bluetooth warning** (if Bluetooth off)
4. **Tap "Send to Nearby"** buttons
5. **Check iOS console logs** for:
   - "Central state: 5" (poweredOn)
   - "Peripheral state: 5" (poweredOn)
   - "✅ Service added successfully, starting advertising"

## Development Notes

- **BLE Implementation**: Based on bitchat project
- **Protocol**: Custom mesh networking protocol
- **Security**: Noise protocol encryption
- **Platform**: iOS 13.0+
- **Permissions**: Bluetooth Always + Peripheral usage required

## Troubleshooting Commands

```bash
# Check if app is installed
ios-deploy --exists --bundle_id me.bitpoints.wallet

# List connected devices
npx cap run ios --list

# Clean build (if needed)
cd ios/App
xcodebuild clean -workspace App.xcworkspace -scheme App

# Check pod installation
cd ios/App
bundle exec pod install --verbose
```

## Important Reminders

1. **Never use `npx cap run ios` or `npx cap sync ios`** - breaks Bluetooth config
2. **Always verify ALL THREE config files** contain BluetoothEcashPlugin
3. **Maintain data type consistency** between Swift Int and TypeScript number
4. **Use direct xcodebuild** for reliable builds
5. **Check pod installation** before building (CapacitorBluetoothEcash required)
6. **Manual asset copy required** - never skip `cp -r dist/spa/* ios/App/App/public/`
7. **Test Bluetooth functionality** after deployment

---

## Quick Reference

**✅ DO:**
- Use direct `xcodebuild` commands
- Verify ALL THREE config files have BluetoothEcashPlugin
- Maintain Swift↔TypeScript data type consistency
- Manual asset copy: `cp -r dist/spa/* ios/App/App/public/`
- Check CapacitorBluetoothEcash pod installation
- Test Bluetooth functionality after deployment

**❌ DON'T:**
- Use `npx cap run ios` or `npx cap sync ios`
- Skip pod installation (CapacitorBluetoothEcash required)
- Send timestamps as String (causes crashes)
- Forget to verify iOS capacitor.config.json
- Skip manual asset copy step

**Built on:** December 15, 2025
**Last tested:** iOS 26.1, Xcode 26.1
**Bluetooth fixes:** CapacitorBluetoothEcash pod, data type consistency, config verification
