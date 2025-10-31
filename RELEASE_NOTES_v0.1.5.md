# Bitpoints v0.1.5 - QR Code Contacts & PWA Support

**Release Date**: January 2025  
**Tag**: `v0.1.5`  
**APK**: `bitpoints-v0.1.5-release.apk`

## 🎉 What's New

### ✨ **Major Features**

- **QR Code Contact Exchange**: Add contacts via QR code scanning without Bluetooth connection
  - One contact shows QR code, the other scans it
  - Same mutual favorites mechanism as Bluetooth but using QR codes
  - Enables Nostr messaging without requiring Bluetooth connection
  
- **PWA Support for Contacts**: Contacts dialog now fully functional in Progressive Web App
  - Works when Bluetooth is not available in browser
  - QR code scanning works in PWA environment
  - Proper dialog positioning and visibility

### 🐛 **Bug Fixes**

- **Fixed Duplicate Token Claiming**: Prevent "Token already spent" errors when receiving via Nostr and Bluetooth
  - Graceful handling of race conditions during token claiming
  - Silent handling of already-spent tokens without user-facing errors
  - Improved error handling at multiple levels (wallet, receive store, dialog)
  
- **Fixed Contacts Dialog Positioning**: 
  - Matches Receive/Send dialog styling and positioning
  - Proper slide-up animation from bottom
  - Maximized on mobile for better UX
  - Fixed dialog visibility issues in PWA

- **Improved PWA Compatibility**:
  - Added `getOfflineFavorites` to web stub for PWA compatibility
  - Better platform detection for Bluetooth availability
  - Graceful fallbacks when native APIs are unavailable

### 🔧 **Technical Improvements**

- Enhanced `autoReceiveIfValid` with duplicate claim detection
- Improved `wallet.redeem()` error handling for race conditions
- Better token history synchronization
- More robust error handling throughout the claiming flow

## 📱 Android APK Build Instructions

To build the release APK:

```bash
# 1. Build the web assets
npm run build

# 2. Sync Capacitor
npx cap sync android

# 3. Build release APK
cd android
./gradlew assembleRelease

# 4. Find APK at:
# android/app/build/outputs/apk/release/app-release.apk
```

**Note**: Ensure `android/app/keystore.properties` is configured for signing.

## 🔄 Migration Notes

- No breaking changes
- Existing contacts and favorites remain intact
- QR code contacts integrate seamlessly with Bluetooth contacts

## 📝 Full Changelog

### Features
- QR code contact exchange with mutual favorites support
- PWA compatibility for contacts dialog
- Web stub implementation for Bluetooth plugin methods

### Bug Fixes
- Fixed "Token already spent" errors during duplicate claims
- Fixed contacts dialog positioning and visibility
- Improved error handling for race conditions
- Better platform detection for native vs web

### Technical
- Enhanced error handling in `wallet.redeem()`
- Improved `receiveIfDecodes()` duplicate claim detection
- Better token history synchronization
- Added `nextTick` to prevent race conditions in watchers

## 🔗 Related Links

- **GitHub Repository**: https://github.com/bitpoints-cashu/bitpoints.me
- **Release Tag**: https://github.com/bitpoints-cashu/bitpoints.me/releases/tag/v0.1.5
- **Previous Release**: [v0.1.4](RELEASE_NOTES_v0.1.4.md)

## 🙏 Credits

Thanks to all contributors and testers who helped identify and fix the duplicate token claiming issues.

