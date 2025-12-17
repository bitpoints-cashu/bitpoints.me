# Android App Troubleshooting Guide

## Common Issues and Solutions

### 1. App Shows Second Black Page Instead of Going to Wallet

**Problem**: Android app displays a second empty/black page after the welcome screen instead of proceeding directly to the wallet.

**Solution**: This issue has been fixed in v0.1.9. The app now correctly detects it's running on Android and shows only 1 welcome slide (terms + checkboxes) that proceeds directly to the wallet.

**If you still experience this issue**:
- Ensure you have the latest APK (v0.1.9 or later)
- Clear app data: Settings → Apps → Bitpoints → Storage → Clear Data
- Reinstall the app

### 2. Platform Detection Issues

**Problem**: App behaves like PWA instead of native Android app.

**Symptoms**:
- Shows PWA installation instructions
- Has different UI behavior

**Solution**:
- The app uses Capacitor platform detection
- If issues persist, check that Capacitor is properly initialized
- Clear app cache and reinstall

### 3. Welcome Screen Not Appearing

**Problem**: App goes directly to wallet without showing welcome screen.

**Cause**: Welcome has already been completed and stored in localStorage.

**Solution**:
- Clear app data: Settings → Apps → Bitpoints → Storage → Clear Data
- Or reinstall the app to reset localStorage

### 4. App Crashes on Startup

**Problem**: App crashes immediately when opened.

**Solutions**:
1. Clear app cache and data
2. Reinstall the app
3. Check device storage space
4. Restart device

### 5. Installation Issues

**Problem**: APK fails to install.

**Solutions**:
1. Enable "Install from unknown sources" in device settings
2. Check available storage space
3. Try installing via ADB: `adb install -r app-debug.apk`

### 6. Performance Issues

**Problem**: App is slow or unresponsive.

**Solutions**:
1. Clear app cache
2. Restart device
3. Check for app updates
4. Close other running apps

## Debug Information

### Platform Detection
The app uses this logic to detect if it's running on Android:
```javascript
const isNative = platform === "android" || platform === "ios" || isNativePlatform;
```

### Welcome Flow Logic
- **Android**: 1 slide (slide 0 = last) → Terms + checkboxes → Wallet
- **PWA**: 2 slides (slide 1 = last) → Terms + checkboxes → PWA instructions → Wallet

### Log Collection
To collect debug logs:
```bash
adb logcat -c  # Clear logs
# Run the app and reproduce issue
adb logcat | grep -E "(WelcomePage|WelcomeStore|isNativeApp|Capacitor/Console)"
```

## Version Information
- Current version: v0.1.9
- Fixed Android onboarding flow issues
- Improved platform detection reliability

## Support
If issues persist after trying these solutions, please:
1. Note the exact Android version and device model
2. Describe the exact behavior you're seeing
3. Include any error messages or logs if possible

