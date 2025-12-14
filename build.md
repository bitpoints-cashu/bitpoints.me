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

- ✅ `capacitor.config.json` (main config)
- ✅ `ios/App/App/capacitor.config.json` (iOS-specific config)
- ✅ `ios/App/Podfile` (should have CapacitorBluetoothEcash pod)

If any are missing, restore them manually before building.

### 4. Build and Deploy to Device

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

### 5. Verify Installation
```bash
ios-deploy --exists --bundle_id me.bitpoints.wallet
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

1. **Never use `npx cap run ios`** - it breaks Bluetooth config
2. **Always verify iOS capacitor.config.json** after any Capacitor operations
3. **Use direct xcodebuild** for reliable builds
4. **Check pod installation** before building
5. **Test Bluetooth functionality** after deployment

---

## Quick Reference

**✅ DO:**
- Use direct `xcodebuild` commands
- Verify configs before building
- Check Bluetooth functionality

**❌ DON'T:**
- Use `npx cap run ios` or `npx cap sync ios`
- Skip pod installation
- Forget to verify iOS capacitor.config.json

**Built on:** December 14, 2025
**Last tested:** iOS 26.1, Xcode 26.1