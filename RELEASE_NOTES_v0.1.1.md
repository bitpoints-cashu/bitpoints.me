# Bitpoints v0.1.1 - Complete De-branding Release

**Release Date**: October 18, 2024  
**Tag**: `v0.1.1`  
**APK**: `bitpoints-v0.1.1-beta.apk` (19.4 MB)

## 🎉 What's New

### ✅ **Complete De-branding to Bitpoints**
- **Full Rebrand**: All Trails Coffee references replaced with Bitpoints branding
- **Legal Terms Updated**: Terms of Service and legal documents now reference Bitpoints entity
- **UI Consistency**: All user interface elements updated with Bitpoints branding
- **Documentation Updated**: README and all documentation files rebranded to Bitpoints

### ✅ **Mint Configuration Restored**
- **Working Mint**: Restored Trails Coffee mint configuration from v0.1.0-beta
- **Fixed Mint Errors**: Resolved "mint not found" and "mint activation error" issues
- **Minibits Removed**: Completely eliminated all Minibits mint references
- **Default Mint**: Trails Coffee mint (`https://ecash.trailscoffee.com`) remains as default working mint

### ✅ **Code Quality Improvements**
- **Clean Codebase**: Removed all legacy Trails Coffee branded files
- **Updated Terminology**: Changed "Coffee Shop" to "Mint" throughout the app
- **Bluetooth Issues**: Identified and documented Bluetooth mesh service restart issues
- **Version Control**: Clean commit history with proper tagging

## 🔧 Technical Details

### De-branding Changes
- **UI Components**: All Vue components updated with Bitpoints branding
- **Legal Documents**: Terms of Service completely rewritten for Bitpoints entity
- **Internationalization**: Updated i18n strings from coffee shop to mint terminology
- **Styling**: CSS classes renamed from trails-specific to generic naming
- **Assets**: All icons and branding assets updated to Bitpoints

### Mint Configuration
- **Default Mint**: `https://ecash.trailscoffee.com` with nickname "Trails Coffee"
- **Mint Activation**: Restored working mint initialization logic from v0.1.0-beta
- **Error Resolution**: Fixed mint activation and connection issues
- **Minibits Removal**: Completely removed all references to Minibits mint

### Bluetooth Mesh
- **Service Issues**: Identified nickname change restart issues requiring full app restart
- **Peer Discovery**: Bluetooth mesh networking continues to work properly
- **Security Validation**: Documented packet validation failures during nickname changes

## 📦 Installation

### Android APK
Download and install `bitpoints-v0.1.1-beta.apk`

**Requirements:**
- Android 12 or higher
- ~20 MB storage
- Bluetooth for P2P transfers
- Internet for Nostr and mint access

### First-Time Setup
1. Install the APK
2. Grant Bluetooth and Camera permissions when prompted
3. Create a new wallet or restore from backup
4. Trails Coffee mint is pre-configured and working
5. Start sending and receiving!

## ✅ Tested Devices

- ✅ **Samsung A25** (Android 12)
- ✅ **Google Pixel 8** (Android 14)

All features working correctly with clean app data.

## 🐛 Known Issues

### Bluetooth Nickname Changes
- **Issue**: Changing Bluetooth nickname requires full app restart
- **Root Cause**: Mesh service restart gets ignored due to service lifecycle issues
- **Workaround**: Full app restart after nickname changes
- **Status**: Documented, requires service lifecycle fix in future release

### Security Validation Failures
- **Issue**: Occasional "Packet failed security validation" messages
- **Impact**: Does not affect functionality, Bluetooth transfers still work
- **Status**: Related to nickname change restart issues

## 🔄 Migration from v0.1.0-beta

### Clean Installation Recommended
- Clear app data before installing v0.1.1
- This ensures proper initialization with new branding
- Prevents any cached data issues from previous versions

### No Breaking Changes
- All functionality preserved from v0.1.0-beta
- Mint configuration restored to working state
- Bluetooth mesh networking continues to work

## 📋 Changelog

### Added
- Complete Bitpoints branding throughout the app
- Updated legal terms and documentation
- Clean codebase with removed legacy files

### Changed
- All UI text from Trails Coffee to Bitpoints
- Terminology from "Coffee Shop" to "Mint"
- Legal entity references to Bitpoints
- Documentation and README with Bitpoints branding

### Removed
- All Trails Coffee branding references
- All Minibits mint references
- Legacy branded files and documentation
- Old deployment and development files

### Fixed
- Mint activation and connection errors
- "Mint not found" and "mint activation error" issues
- Restored working mint configuration from v0.1.0-beta

## 🔮 Next Steps

### v0.1.2 Planned
- Fix Bluetooth mesh service restart issues
- Improve nickname change handling
- Enhanced error handling for mesh networking

### Future Releases
- iOS implementation
- Enhanced Nostr integration
- Improved Bluetooth mesh stability

## 📞 Support

- **GitHub**: [bitpoints-cashu/bitpoints.me](https://github.com/bitpoints-cashu/bitpoints.me)
- **Issues**: [GitHub Issues](https://github.com/bitpoints-cashu/bitpoints.me/issues)
- **Email**: bitpoints@btclearn.org

## 📄 License

MIT License - See [LICENSE.md](LICENSE.md)

---

**🎉 Bitpoints v0.1.1 with complete de-branding is ready for production use!**

*Tagged as `v0.1.1` on GitHub*
