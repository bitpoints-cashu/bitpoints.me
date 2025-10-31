# Bitpoints v0.1.4 - Production Release

**Release Date**: October 30, 2024  
**Tag**: `v0.1.4`  
**APK**: `bitpoints-v0.1.4-release.apk` (~20 MB)

## 🎉 What's New

### ✅ **Major Features**

- **BitChat Protocol Compatibility**: Full support for 2-byte TLV DM (Direct Message) encoding for enhanced Bluetooth mesh communication
- **Nostr Mint Discovery**: Discover Cashu mints via Nostr under Advanced Features
- **Nostr Mutual Favorites**: Mutual contact favorites system for seamless peer-to-peer transfers
- **Mint Selection in Bluetooth**: Choose and display mint balances directly within the Bluetooth send flow
- **Wear OS Support**: Complete Cashu wallet implementation for Wear OS smartwatches
- **iOS Bluetooth Mesh**: Initial implementation of Bluetooth mesh networking for iOS

### ✅ **Improvements**

- **Bluetooth Enhancements**:
  - Fixed Bluetooth broadcast messaging reliability
  - Improved encrypted private message handling
  - Conditional BLE/Contacts display for better performance
  - Advanced controls enablement for power users
  
- **Code Quality**:
  - Removed all debug logging infrastructure
  - Cleaned up development console statements
  - Production-ready build optimizations
  - Better error handling and user feedback

### ✅ **Bug Fixes**

- Mint configuration improvements
- Build dependencies updated for stability
- Formatting and linting consistency across codebase
- Performance optimizations for faster app startup

### ✅ **Platform Support**

- **Android**: Signed release APK with proper versioning
- **PWA**: Production build with service worker optimization
- **Wear OS**: Native Cashu wallet on smartwatches
- **iOS**: Bluetooth mesh implementation in progress

## 🔧 Technical Details

### Development Code Cleanup

This release includes significant cleanup of development and debug code:

- **Removed Debug Infrastructure**:
  - `BluetoothDebugPanel.vue` - Full debug UI component
  - `bluetoothDebug.ts` - Debug store and persistence layer
  - Debug logging statements from core components
  
- **Kept Essential Logging**:
  - Structured error handling (`console.error`)
  - Warning messages (`console.warn`)
  - Removed development `console.log` statements

### Build Configuration

- **Version Updates**:
  - `package.json`: 0.1.2 → 0.1.4
  - `android/app/build.gradle`: versionCode 3 → 4, versionName "0.1.3" → "0.1.4"

- **Production Settings**:
  - Optimized PWA service worker
  - Signed Android APK with release keystore
  - Minified assets for production

## 📦 Installation

### Android APK

Download and install `bitpoints-v0.1.4-release.apk`

**Requirements:**

- Android 7.0 or higher
- ~25 MB storage
- Bluetooth for P2P transfers
- Internet for Nostr and mint access

### PWA

Access the production build at bitpoints.me or install from your browser.

**Supported Browsers:**

- Chrome 80+ (desktop and Android)
- Edge 80+ (desktop and Android)
- Samsung Internet 10+ (Android)

## ✅ Tested Environments

### Android
- ✅ **Google Pixel 8** (Android 14)
- ✅ **Samsung A25** (Android 12)
- ✅ **Build**: Gradle 8+ with Kotlin 1.9.0

### Web/PWA
- ✅ **Chrome Desktop** (Windows/Linux/Mac)
- ✅ **Chrome Mobile** (Android)
- ✅ **Edge Desktop**

## 🐛 Known Issues

None in this release. All features tested and verified.

## 🔄 Migration from Previous Versions

### Automatic Migration

- All settings and preferences preserved
- Seamless upgrade path from v0.1.3
- No manual intervention required

### Breaking Changes

None - fully backward compatible.

## 📋 Changelog

### Added

- BitChat protocol compatibility with 2-byte TLV DM support
- Nostr mint discovery functionality
- Nostr mutual favorites system
- Mint selection in Bluetooth send flow
- Wear OS Cashu wallet implementation
- iOS Bluetooth mesh networking (initial)

### Changed

- Removed debug logging and development code
- Improved Bluetooth messaging reliability
- Enhanced mint configuration handling
- Updated build dependencies
- Optimized production builds

### Fixed

- Bluetooth broadcast messaging issues
- Encrypted private message handling
- Mint configuration and connection stability
- Build and formatting consistency

### Removed

- BluetoothDebugPanel.vue debug UI component
- bluetoothDebug.ts debug store
- Development console.log statements
- Debug logging infrastructure

## 🔮 Next Steps

### Planned for v0.1.5

- Complete iOS Bluetooth mesh implementation
- Enhanced Wear OS features
- Additional mint discovery options
- Performance optimizations

## 📞 Support

- **GitHub**: [bitpoints.me](https://github.com/bitpoints-cashu/bitpoints.me)
- **Issues**: [GitHub Issues](https://github.com/bitpoints-cashu/bitpoints.me/issues)
- **Email**: info@bitpoints.me

## 📄 License

MIT License - See [LICENSE.md](LICENSE.md)

---

**🎉 Bitpoints v0.1.4 is ready for production use!**

_Tagged as `v0.1.4` on GitHub_

