# Trails Coffee Rewards v1.2.0 - Nostr Auto-Claim

## 🎉 What's New

### 💰 **Automatic Token Claiming**
No more manual claiming! Cashu tokens received via Nostr are now **automatically claimed** when they arrive. Your balance updates instantly without any action required.

### 🔄 **Startup Recovery**
The app now checks for any pending tokens on startup and automatically claims them. This means you'll never lose tokens, even if something went wrong during the initial receive.

### 📱 **Simplified Nostr Messaging**
- Removed unnecessary encryption for Cashu tokens (they're bearer instruments, like cash)
- Faster and more reliable token transmission
- Better compatibility with all Nostr relays

### 💕 **Enhanced Favorites Flow**
- Send favorite requests via Bluetooth or Nostr
- Accept/decline requests with a clean UI
- Badge notifications for pending requests
- Mutual Nostr key exchange for messaging

### ✨ **UX Improvements**
- Replaced all "Close" text with intuitive "X" icons
- Fixed keyboard auto-appearing after QR scans
- Removed autofocus from amount fields
- Nearby Peers section now clickable in settings
- Send dialog automatically closes after successful send

### 📷 **Camera Permission Fixes**
- Improved camera permission handling for Android 12+
- Dual-strategy permission request (web + native)
- Better error messages and retry options
- Removed unnecessary location permission

## 🔧 Technical Details

### Auto-Claim Implementation
1. **On Message Receipt**: Tokens are automatically claimed from the mint when a Nostr DM arrives
2. **On Startup**: Any pending tokens in history are detected and claimed automatically
3. **Fail-Safe**: Tokens always saved to history first, can be recovered via QR code

### Security & Privacy
- Nostr messages still authenticated via your Nostr keys
- Cashu tokens work as bearer instruments (no encryption needed)
- No personal info exposed in token transmission
- Transaction history encrypted locally

### Performance
- Minimal battery impact (event-driven, no polling)
- Low data usage (~1KB per token receive)
- Fast claiming (typically < 2 seconds)

## 📦 Installation

### Android APK
Download and install `trails-coffee-rewards-v1.2.0-nostr-autoclaim.apk`

**Minimum Requirements:**
- Android 12 or higher
- Internet connection for Nostr relay and mint access
- Bluetooth for local peer-to-peer transfers

### First-Time Setup
1. Install the APK
2. Grant Bluetooth and Camera permissions when prompted
3. Create a new wallet or restore from backup
4. Add Trails Coffee mint (pre-configured)
5. Start sending and receiving!

## ✅ Tested Devices

- ✅ **Samsung Galaxy S21 Mini** (Android 12)
- ✅ **Generic Android 14** device
- ✅ **Google Pixel 8** (Android 16)

All features working correctly on all tested devices.

## 🐛 Bug Fixes

- Fixed camera not working on Android 12
- Fixed keyboard appearing after QR scan
- Fixed Nostr send errors ("argument is wrong")
- Fixed missing transactions in history for Nostr sends
- Fixed "no Nostr key" issue for favorites
- Fixed favorites not appearing in contacts
- Fixed Bluetooth permission issues on Android 12+

## 📚 Documentation

See `NOSTR_AUTO_CLAIM_IMPLEMENTATION.md` for detailed technical documentation, including:
- Implementation architecture
- Error handling strategies
- Testing procedures
- Troubleshooting guide

## 🔄 Upgrade Notes

### From v1.1.x
- All existing functionality preserved
- New auto-claim happens automatically
- Favorites will need to re-exchange keys (one-time)
- No data migration needed

### From v1.0.x
- Full feature upgrade
- Recommend clean install if experiencing issues
- Backup your wallet seed before upgrading

## 🚀 Usage

### Sending Ecash via Nostr
1. Tap "Contacts" button
2. Select a favorite contact
3. Enter amount and optional memo
4. Tap "Send"
5. Token automatically saved to your history (recoverable)

### Receiving Ecash via Nostr
- **Nothing to do!** Tokens are auto-claimed when they arrive
- You'll see a notification and your balance will update
- Check transaction history to see received tokens

### Recovering Lost Tokens
1. Go to Settings → Transaction History
2. Find the pending transaction
3. Tap to view QR code
4. Scan with another device or send to someone else

## 🤝 Contributing

This is an open-source project. Contributions welcome!

- **Repository**: https://github.com/jpgaviria2/cashu.me
- **Issues**: Report bugs or request features on GitHub
- **Discord**: Join the Trails Coffee community

## 📄 License

MIT License - See LICENSE file for details

## 🙏 Credits

Built with:
- **Cashu Protocol**: https://github.com/cashubtc
- **Nostr Protocol**: https://github.com/nostr-protocol/nips
- **NDK**: https://github.com/nostr-dev-kit/ndk
- **Quasar Framework**: https://quasar.dev
- **Capacitor**: https://capacitorjs.com

Special thanks to the Cashu and Nostr communities for building amazing open protocols!

---

**Release Date**: October 18, 2025
**Version**: 1.2.0
**Build**: Release
**File**: trails-coffee-rewards-v1.2.0-nostr-autoclaim.apk
**Size**: ~16 MB
**SHA256**: (Will be added after upload)

