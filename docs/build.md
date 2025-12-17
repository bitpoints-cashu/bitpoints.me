# Bitpoints.me Build Instructions

This document covers building Bitpoints.me for both iOS and Android platforms.

## Android Build Instructions

### Prerequisites

1. **Java 17+** (OpenJDK recommended):
   ```bash
   # Using Homebrew (macOS)
   brew install openjdk@17

   # Set environment variables
   export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
   export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
   ```

2. **Android SDK** (Command Line Tools):
   ```bash
   # Install Android command line tools
   brew install --cask android-commandlinetools

   # Set up Android SDK
   export ANDROID_HOME="$HOME/Library/Android/sdk"
   export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

   # Install required SDK components
   mkdir -p "$ANDROID_HOME"
   echo "y" | sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0" --sdk_root="$ANDROID_HOME"
   ```

3. **Android Device** connected via USB with USB debugging enabled

4. **ADB** (Android Debug Bridge) - included with platform tools

### Build Steps

#### 1. Build Web App
```bash
npm run build
```

#### 2. Sync Assets to Android Project
```bash
npx cap sync android
```

#### 3. Build Android APK
```bash
# Option 1: Build only
cd android
./gradlew assembleDebug

# Option 2: Build and install in one step (recommended)
npx cap run android
```

#### 4. Install APK on Device (if not using Option 2 above)
```bash
# Find APK location
find android/app/build/outputs -name "*.apk"

# Install APK
adb install android/app/build/outputs/apk/debug/app-debug.apk
```

### Verify Installation
```bash
# Check if device is connected
adb devices

# Verify app is installed
adb shell pm list packages | grep me.bitpoints.wallet

# Expected output: package:me.bitpoints.wallet
```

### Common Android Issues & Fixes

#### Issue: "Java Runtime not found"
**Fix:** Install Java 17 and set environment variables:
```bash
brew install openjdk@17
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
```

#### Issue: "No valid Android SDK root found"
**Fix:** Install Android SDK and set environment variables:
```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

#### Issue: Gradle compatibility errors with Java 17
**Fix:** Update Gradle wrapper to version 8.5+:
```bash
# Edit android/gradle/wrapper/gradle-wrapper.properties
# Change distributionUrl to:
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-all.zip
```

#### Issue: Merge conflicts preventing build
**Fix:** Resolve git merge conflicts in Vue components:
```bash
# Check for conflicts
git status

# Resolve conflicts in affected files (e.g., ContactsDialog.vue)
# Look for <<<<<<< HEAD, =======, >>>>>>> markers
```

#### Issue: App builds but won't install
**Fix:** Enable USB debugging on device and accept RSA key:
```bash
# Check device connection
adb devices

# If unauthorized, check device screen for RSA key prompt
adb kill-server && adb start-server
```

### Android Development Notes

- **Package Name**: `me.bitpoints.wallet`
- **Minimum Android Version**: API 21 (Android 5.0)
- **Target Android Version**: API 34 (Android 14)
- **Bluetooth Permissions**: Automatically requested at runtime
- **Build Variants**: Debug (development), Release (production)

### Android File Structure
```
android/
├── app/
│   ├── src/main/
│   │   ├── java/me/bitpoints/wallet/  # Native Android code
│   │   ├── res/                       # Android resources
│   │   └── AndroidManifest.xml        # App manifest
│   └── build.gradle                   # App-level build config
├── gradle/wrapper/
│   └── gradle-wrapper.properties      # Gradle version
└── build.gradle                       # Project-level build config
```

---

## iOS Build Instructions

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

## Android Quick Reference

**✅ DO:**
- Install Java 17+ and set JAVA_HOME/PATH
- Install Android SDK platform-tools and build-tools
- Use `npx cap run android` for build + install
- Resolve merge conflicts before building
- Enable USB debugging on device
- Test Bluetooth functionality after installation

**❌ DON'T:**
- Use old Java versions (< 17) with Gradle 8.5+
- Skip Android SDK setup
- Build with incompatible Gradle versions
- Forget to connect device via USB
- Skip merge conflict resolution

---

## iOS Quick Reference

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

**Built on:** December 17, 2025
**Last tested:** iOS 26.1, Xcode 26.1; Android API 34, Gradle 8.5
**Platforms:** iOS (CapacitorBluetoothEcash pod), Android (BluetoothEcashPlugin)
**Bluetooth fixes:** CapacitorBluetoothEcash pod, data type consistency, config verification
