# Bitpoints.me v1.0.0 Release Notes

**Release Date**: October 16, 2025  
**Tag**: v1.0.0-bitpoints

## 🎉 Major Release: Rebrand to Bitpoints.me

This release represents a complete rebrand from Cashu.me to **Bitpoints.me**, emphasizing our vision of Bitcoin-backed rewards that appreciate over time and are interoperable with any merchant accepting Bitcoin.

## 🌟 What's New

### Complete Rebrand
- **New Package ID**: `me.bitpoints.wallet` (was `me.cashu.wallet`)
- **New App Name**: Bitpoints.me
- **Updated Branding**: Throughout the entire app
- **New Documentation**: Comprehensive README and ABOUT explaining the open protocol merger

### Full Bluetooth Mesh Implementation
Ported from [BitChat](https://github.com/jpgaviria2/bitchat), this is a **complete, production-ready implementation**:

- ✅ **15,000+ lines** of Bluetooth mesh networking code
- ✅ **Noise Protocol encryption** (military-grade end-to-end)
- ✅ **Multi-hop relay** (up to 7 hops, TTL-based routing)
- ✅ **Offline token transfers** (send/receive without internet)
- ✅ **Peer discovery** (automatic BLE scanning)
- ✅ **Auto-redeem** (incoming tokens automatically added to wallet)
- ✅ **Battery optimized** (adaptive duty cycling)
- ✅ **Fragment assembly** (handles large tokens >512 bytes)

### Android Native Components

**Core Services**:
- `BluetoothMeshService.kt` - Main mesh networking service
- `BluetoothEcashPlugin.kt` - Capacitor plugin bridge
- `BluetoothEcashService.kt` - Token transmission service

**Encryption** (Full Noise Protocol):
- `NoiseEncryptionService.kt` - E2E encryption service
- `NoiseSession.kt` - Per-peer encryption sessions
- `NoiseSessionManager.kt` - Session lifecycle management
- Complete crypto library (Curve25519, ChaCha20-Poly1305, Blake2b, etc.)

**Mesh Networking**:
- `BluetoothGattClientManager.kt` - BLE client operations (566 lines)
- `BluetoothGattServerManager.kt` - BLE server operations (417 lines)
- `MessageHandler.kt` - Ecash message processing (619 lines)
- `PacketRelayManager.kt` - Multi-hop relay logic (173 lines)
- `PeerManager.kt` - Peer discovery and tracking (542 lines)
- `FragmentManager.kt` - Message fragmentation (290 lines)

**Protocol & Security**:
- `BinaryProtocol.kt` - Efficient binary encoding
- `SecurityManager.kt` - Rate limiting, attack prevention
- `PowerManager.kt` - Battery optimization
- `CompressionUtil.kt` - Message compression

## 🔐 Security Features

- **Noise Protocol XX Pattern**: Mutual authentication with forward secrecy
- **Ephemeral Keys**: New session keys for each connection
- **TTL-based Relay**: Prevents infinite loops
- **Rate Limiting**: Anti-spam protection
- **RSSI Gating**: Limits Bluetooth range attacks
- **Message Deduplication**: Prevents replay attacks

## 💎 Why Bitpoints?

### Bitcoin-Backed Rewards
Unlike traditional loyalty points that depreciate with inflation, Bitpoints are denominated in Bitcoin (satoshis), so they **appreciate** as Bitcoin's purchasing power increases.

### Universal Interoperability
Built on open protocols (Cashu, Nostr, Bluetooth), Bitpoints work with:
- ✅ Any Cashu-compatible wallet
- ✅ Any Bitcoin/Lightning merchant
- ✅ Any Nostr relay
- ✅ Any Bluetooth mesh-compatible device

### Privacy by Default
- Bearer tokens (no transaction history)
- Noise Protocol encryption for mesh transfers
- Ephemeral peer IDs
- No central servers for Bluetooth

## 📱 Installation

### Android APK
Download: `bitpoints-v1.0.0-android.apk`

**Requirements**:
- Android 5.0+ (API 21+)
- Bluetooth 4.0+ (for mesh networking)
- Android 12+ recommended (best Bluetooth permission experience)

**Permissions**:
- Camera (QR code scanning)
- Bluetooth (mesh networking)
- Location (required for Bluetooth scanning on Android 12+)
- Internet (mint synchronization)
- NFC (optional, for Boltcard support)

### First Launch
1. Grant permissions when prompted
2. Create or restore wallet
3. Add a Cashu mint
4. Enable Bluetooth mesh to start discovering peers

## 🔧 Technical Changes

### Package Migration
All 80+ Java/Kotlin files migrated from `me.cashu.wallet` to `me.bitpoints.wallet`:
- Updated package declarations
- Updated all imports
- Updated manifest and build configs
- Regenerated app icons and splash screens

### Configuration Updates
- `capacitor.config.ts`: Updated app ID and name
- `package.json`: New name, description, and product name
- `android/app/build.gradle`: New namespace and application ID
- `android/app/src/main/res/values/strings.xml`: New app name

### Documentation
- **README.md**: Complete rewrite emphasizing Bitcoin-backed rewards and open protocols
- **ABOUT.md**: Technical deep dive into protocol merger and architecture
- Multiple Bluetooth development guides included in main branch

## 🐛 Known Issues

- iOS Bluetooth implementation not yet ported (Android only for now)
- Web version doesn't support Bluetooth (native platforms only)
- First Bluetooth connection may take 5-10 seconds

## 🗺️ Roadmap

### v1.1 (Coming Soon)
- iOS Bluetooth mesh implementation
- Enhanced peer management UI
- Location-based channels (geohash)
- Social backup (NIP-60)

### v1.2
- Multiple mint support
- Mesh relay incentives
- Network visualization
- Desktop builds

## 📚 Documentation

- [README.md](./README.md) - Overview and quick start
- [ABOUT.md](./ABOUT.md) - Technical architecture
- [BLUETOOTH_DEVELOPMENT_SUMMARY.md](./BLUETOOTH_DEVELOPMENT_SUMMARY.md) - Complete Bluetooth implementation details
- [BLUETOOTH_TESTING_GUIDE.md](./BLUETOOTH_TESTING_GUIDE.md) - Testing procedures
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture

## 🙏 Credits

This release brings together:
- **Cashu Protocol** - Privacy-preserving ecash
- **Nostr Protocol** - Decentralized identity
- **BitChat** - Battle-tested Bluetooth mesh networking
- **Noise Protocol** - Modern cryptographic framework

Thank you to all the open source contributors who made this possible!

## 📥 Download

**Android APK**: `bitpoints-v1.0.0-android.apk` (18 MB)

**Package Details**:
- Package ID: `me.bitpoints.wallet`
- Version Code: 1
- Version Name: 1.0
- Min SDK: 21 (Android 5.0)
- Target SDK: Latest

## 🔗 Links

- GitHub: https://github.com/jpgaviria2/cashu.me
- Tag: v1.0.0-bitpoints
- Commit: bb53d1b

---

**Bitpoints.me** - Your rewards, your Bitcoin, your privacy.



