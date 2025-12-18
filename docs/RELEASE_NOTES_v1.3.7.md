# Bitpoints v1.3.7 - Bluetooth Contacts Fix

## 🐛 Bug Fix

### 📱 **Bluetooth Mesh Contacts Display**

**Fixed**: Bluetooth mesh contacts now properly appear in the main contacts dialog.

**Issue**: The contacts card would show "scanning for contacts" indefinitely, while Bluetooth mesh contacts only appeared when navigating to Settings → Nearby Contacts.

**Root Cause**: The ContactsDialog was calling `BluetoothEcash.getAvailablePeers()` directly instead of using the centralized `bluetoothStore.sortedPeers` data source.

**Solution**: Modified ContactsDialog.vue to use the same data source as NearbyContactsDialog, ensuring consistent Bluetooth peer display across all UI components.

## 🔧 Technical Details

### Code Changes

- **ContactsDialog.vue**: Changed from direct API calls to store-based peer management
- **Data Consistency**: Both contacts views now use `bluetoothStore.sortedPeers` for peer data
- **Automatic Updates**: Peer list updates automatically without manual polling

### Testing

- ✅ Bluetooth mesh contacts appear in contacts dialog
- ✅ Settings → Nearby Contacts continues to work as before
- ✅ Android build and installation verified
- ✅ No breaking changes to existing functionality

## 📦 Installation

### Android APK

Download and install `bitpoints-v1.3.7-bluetooth-contacts-fix.apk`

**Requirements:**
- Android 12 or higher
- Bluetooth enabled for peer-to-peer transfers
- Internet connection for mint access

## 🐛 Fixed Issues

- Fixed Bluetooth mesh contacts not displaying in main contacts dialog
- Improved data consistency between different contact views
- Enhanced user experience for Bluetooth peer discovery

## 📚 Documentation

See `BLUETOOTH_DEVELOPMENT_SUMMARY.md` for detailed Bluetooth implementation documentation.

## 🔄 Upgrade Notes

### From v1.3.6

- Bluetooth contacts now work correctly in all views
- No data migration needed
- All existing functionality preserved
- No breaking changes

## 🚀 Usage

### Accessing Bluetooth Contacts

1. Enable Bluetooth in device settings
2. Open Bitpoints app
3. Tap "Contacts" button - Bluetooth mesh contacts should now appear
4. Alternatively, go to Settings → Nearby Contacts

### Testing Bluetooth Functionality

- Look for green/orange avatar icons indicating Bluetooth peers
- "Direct" vs "Via mesh" labels show connection type
- Heart icons show mutual favorites
- Public icons show Nostr messaging capability

---

**Release Date**: December 17, 2025
**Version**: 1.3.7
**Build**: Release
**File**: bitpoints-v1.3.7-bluetooth-contacts-fix.apk
**Size**: ~19 MB
